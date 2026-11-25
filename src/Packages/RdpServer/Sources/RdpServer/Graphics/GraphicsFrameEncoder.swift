import Foundation
import os
import RdpProtocol

/// Encodes screen frames as RDPGFX frames: H.264 (AVC420) for changed areas while things move, and lossless planar
/// tiles over the H.264 areas once the image is still, so text ends up sharp. Clients without AVC get planar tiles only.
final class GraphicsFrameEncoder: FrameEncoding {
    private static let logger = Logger(subsystem: "com.irdp", category: "graphics")
    static let surfaceId: UInt16 = 0
    /// Above this many region rectangles a frame updates the whole screen.
    static let maximumRegions = 256
    /// H.264 refinement frames for qualities without lossless sharpening.
    static let videoRefinementFrames = 2

    let desktopSize: DesktopSize
    let encodedSize: DesktopSize
    private(set) var codec: GraphicsPipelineCodec
    private let wrap: ([UInt8]) -> [[UInt8]]
    private(set) var quality: StreamingQuality
    private let grid: TileGrid
    private var h264: VideoToolboxH264Encoder?
    private var nextFrameId: UInt32 = 1
    private let startTime = Date()
    private(set) var lastFrame: ScreenFrame?
    private(set) var lastFrameId: UInt32 = 0
    /// Tiles last drawn with lossy H.264 and not yet replaced by lossless tiles.
    private(set) var lossyTiles = Set<Int>()
    private var videoRefinementsLeft = 0

    var usesFrameAcknowledgements: Bool { true }

    /// `wrap` turns one RDPGFX message into wire packets (segmented data, DVC, SVC, MCS, X.224, TPKT).
    init(desktopSize: DesktopSize, codec: GraphicsPipelineCodec, quality: StreamingQuality, wrap: @escaping ([UInt8]) -> [[UInt8]]) {
        self.desktopSize = desktopSize
        self.codec = codec
        self.wrap = wrap
        self.quality = quality
        grid = TileGrid(size: desktopSize)
        encodedSize = DesktopSize(width: (desktopSize.width + 15) & ~15, height: (desktopSize.height + 15) & ~15)
    }

    /// Setup PDUs sent after the capabilities are confirmed: reset graphics, create the surface and map it.
    func setupMessage(confirming capabilities: GraphicsCapabilitySet) -> [UInt8] {
        GraphicsServerPdu.capsConfirm(capabilities)
            + GraphicsServerPdu.resetGraphics(width: desktopSize.width, height: desktopSize.height)
            + GraphicsServerPdu.createSurface(id: Self.surfaceId, width: encodedSize.width, height: encodedSize.height)
            + GraphicsServerPdu.mapSurfaceToOutput(id: Self.surfaceId)
    }

    func apply(_ quality: StreamingQuality) {
        self.quality = quality
        h264?.setBitRate(quality.videoBitRate, framesPerSecond: quality.framesPerSecond)
    }

    func encode(_ frame: ScreenFrame, forceFullUpdate: Bool) -> [[UInt8]] {
        let previous = lastFrame
        let isFull = forceFullUpdate || previous == nil || previous?.size != frame.size || frame.size != desktopSize
        let tiles: Set<Int> = if isFull { grid.allTiles } else if let previous { grid.changedTiles(frame, comparedTo: previous) } else { grid.allTiles }
        lastFrame = frame
        guard !tiles.isEmpty else { return [] }
        let content: [UInt8]
        switch codec {
        case .avc420:
            do {
                content = try encodeAvc(frame, tiles: tiles, keyFrame: isFull)
                lossyTiles.formUnion(tiles)
                videoRefinementsLeft = Self.videoRefinementFrames
            } catch {
                Self.logger.error("H.264 failed, switching to planar: \(String(describing: error), privacy: .public)")
                codec = .planar
                h264 = nil
                lossyTiles = []
                return encode(frame, forceFullUpdate: true)
            }
        case .planar:
            content = encodePlanar(frame, tiles: tiles)
        }
        return wrapFrame(content)
    }

    func refinement() -> [[UInt8]]? {
        guard codec == .avc420, let frame = lastFrame else { return nil }
        if quality.sharpensStillImages {
            guard !lossyTiles.isEmpty else { return nil }
            let tiles = lossyTiles
            lossyTiles = []
            return wrapFrame(encodePlanar(frame, tiles: tiles))
        }
        guard videoRefinementsLeft > 0, !lossyTiles.isEmpty else { return nil }
        videoRefinementsLeft -= 1
        guard let content = try? encodeAvc(frame, tiles: lossyTiles, keyFrame: false) else { return nil }
        return wrapFrame(content)
    }

    private func wrapFrame(_ content: [UInt8]) -> [[UInt8]] {
        guard !content.isEmpty else { return [] }
        let frameId = nextFrameId
        nextFrameId &+= 1
        lastFrameId = frameId
        let timestamp = UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince(startTime) * 1000))
        return wrap(GraphicsServerPdu.startFrame(id: frameId, timestamp: timestamp) + content + GraphicsServerPdu.endFrame(id: frameId))
    }

    private func encodeAvc(_ frame: ScreenFrame, tiles: Set<Int>, keyFrame: Bool) throws -> [UInt8] {
        if h264 == nil {
            h264 = try VideoToolboxH264Encoder(width: encodedSize.width, height: encodedSize.height, bitRate: quality.videoBitRate, framesPerSecond: quality.framesPerSecond)
        }
        guard let h264 else { return [] }
        let stream = try h264.encode(frame, forceKeyFrame: keyFrame)
        var rectangles = grid.rectangles(covering: tiles)
        if rectangles.count > Self.maximumRegions {
            rectangles = [(0, 0, desktopSize.width, desktopSize.height)]
        }
        let regions = rectangles.map { GraphicsRectangle(left: UInt16($0.left), top: UInt16($0.top), right: UInt16($0.right), bottom: UInt16($0.bottom)) }
        let bitmap = GraphicsServerPdu.avc420Bitmap(regions: regions, h264: stream)
        let destination = GraphicsRectangle(left: 0, top: 0, right: UInt16(encodedSize.width), bottom: UInt16(encodedSize.height))
        return GraphicsServerPdu.wireToSurface(surfaceId: Self.surfaceId, codec: GraphicsCodec.avc420, destination: destination, bitmap: bitmap)
    }

    /// Lossless planar tiles (top-down rows, as the graphics pipeline expects).
    private func encodePlanar(_ frame: ScreenFrame, tiles: Set<Int>) -> [UInt8] {
        var output: [UInt8] = []
        frame.pixels.withUnsafeBytes { current in
            for index in tiles.sorted() {
                let tile = grid.frame(ofTile: index)
                guard tile.width > 0, tile.height > 0, tile.left + tile.width <= frame.width, tile.top + tile.height <= frame.height else { continue }
                var pixels: [UInt8] = []
                pixels.reserveCapacity(tile.width * tile.height * 4)
                for row in tile.top..<(tile.top + tile.height) {
                    PixelFormatConverter.appendRow(from: current, offset: row * frame.bytesPerRow + tile.left * 4, count: tile.width, bitsPerPixel: 32, to: &pixels)
                }
                let planar = PlanarBitmapEncoder.encode(bgrx: pixels, width: tile.width, height: tile.height, topDown: true)
                let destination = GraphicsRectangle(left: UInt16(tile.left), top: UInt16(tile.top), right: UInt16(tile.left + tile.width), bottom: UInt16(tile.top + tile.height))
                output += GraphicsServerPdu.wireToSurface(surfaceId: Self.surfaceId, codec: GraphicsCodec.planar, destination: destination, bitmap: planar)
            }
        }
        return output
    }
}
