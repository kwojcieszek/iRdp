import Foundation
import os
import RdpProtocol

/// Encodes screen frames as RDPGFX frames: full-surface H.264 (AVC420), refined by re-encoding once the image is still.
/// Clients without AVC get lossless planar tiles of the changed areas.
final class GraphicsFrameEncoder: FrameEncoding {
    private static let logger = Logger(subsystem: "com.irdp", category: "graphics")
    static let surfaceId: UInt16 = 0
    /// Lossless planar tiles are sent in frames of at most this many bytes, so every RDPGFX message fits in one segment.
    static let maximumRefinementBytes = 48 * 1024
    /// H.264 re-encodes of a still image (Good and High; Low does one).
    static let videoRefinementFrames = 3

    let desktopSize: DesktopSize
    let encodedSize: DesktopSize
    private(set) var codec: GraphicsPipelineCodec
    private let wrap: ([UInt8]) -> [[UInt8]]
    private(set) var quality: StreamingQuality
    private let grid: TileGrid
    private var needsVideoKeyFrame = false
    private var h264: VideoToolboxH264Encoder?
    private var nextFrameId: UInt32 = 1
    private let startTime = Date()
    private(set) var lastFrame: ScreenFrame?
    private(set) var lastFrameId: UInt32 = 0
    private var videoRefinementsLeft = 0
    private(set) var framesInLastBatch = 1

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
            + GraphicsServerPdu.createSurface(id: Self.surfaceId, width: desktopSize.width, height: desktopSize.height)
            + GraphicsServerPdu.mapSurfaceToOutput(id: Self.surfaceId)
    }

    func apply(_ quality: StreamingQuality) {
        self.quality = quality
        h264?.setBitRate(quality.videoBitRate, framesPerSecond: quality.framesPerSecond)
    }

    func encode(_ frame: ScreenFrame, forceFullUpdate: Bool) -> [[UInt8]] {
        let previous = lastFrame
        let isFull = forceFullUpdate || previous == nil || previous?.size != frame.size || previous?.bytesPerRow != frame.bytesPerRow || frame.size != desktopSize
        lastFrame = frame
        let content: [UInt8]
        switch codec {
        case .avc420:
            if !isFull, let previous {
                // Keep the video decoder reference chain intact. Small edits can be painted losslessly
                // between video frames, and the next AVC update covers the entire desktop.
                let limit = 5
                let tiles = grid.changedTiles(frame, comparedTo: previous, stoppingAfter: limit)
                guard !tiles.isEmpty else { return [] }
                if tiles.count < limit {
                    videoRefinementsLeft = 0
                    framesInLastBatch = 1
                    needsVideoKeyFrame = true
                    return wrapFrame(encodePlanar(frame, tiles: tiles, comparedTo: previous))
                }
            }
            do {
                content = try encodeAvc(frame, keyFrame: isFull || needsVideoKeyFrame)
                needsVideoKeyFrame = false
                videoRefinementsLeft = quality.sharpensStillImages ? Self.videoRefinementFrames : 1
            } catch {
                Self.logger.error("H.264 failed, switching to planar: \(String(describing: error), privacy: .public)")
                codec = .planar
                h264 = nil
                return encode(frame, forceFullUpdate: true)
            }
        case .planar:
            let tiles = isFull ? grid.allTiles : grid.changedTiles(frame, comparedTo: previous!)
            guard !tiles.isEmpty else { return [] }
            // A desktop update has one presentation boundary and one acknowledgement. Transport
            // batches contain whole graphics PDUs and can be decoded as they arrive.
            let frameId = nextFrameId
            var batch = beginFrame()
            var packets: [[UInt8]] = []
            for tile in tiles.sorted() {
                let command = encodePlanar(frame, tiles: [tile])
                if batch.count + command.count > Self.maximumRefinementBytes {
                    packets += wrap(batch)
                    batch.removeAll(keepingCapacity: true)
                }
                batch += command
            }
            batch += GraphicsServerPdu.endFrame(id: frameId)
            packets += wrap(batch)
            framesInLastBatch = 1
            return packets
        }
        framesInLastBatch = 1
        return wrapFrame(content)
    }

    /// While the image is still, re-encodes it with H.264 a few times: each pass adds detail, so text gets sharp.
    func refinement() -> [[UInt8]]? {
        guard codec == .avc420, videoRefinementsLeft > 0, let frame = lastFrame else { return nil }
        videoRefinementsLeft -= 1
        framesInLastBatch = 1
        guard let content = try? encodeAvc(frame, keyFrame: false) else { return nil }
        return wrapFrame(content)
    }

    private func wrapFrame(_ content: [UInt8]) -> [[UInt8]] {
        guard !content.isEmpty else { return [] }
        let frameId = nextFrameId
        return wrap(beginFrame() + content + GraphicsServerPdu.endFrame(id: frameId))
    }

    private func beginFrame() -> [UInt8] {
        let frameId = nextFrameId
        nextFrameId &+= 1
        lastFrameId = frameId
        let timestamp = UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince(startTime) * 1000))
        return GraphicsServerPdu.startFrame(id: frameId, timestamp: timestamp)
    }

    /// Every H.264 frame updates the whole surface. Microsoft's client does not reliably apply partial
    /// region updates (parts of the screen stayed stale or gray), so regions are not used.
    private func encodeAvc(_ frame: ScreenFrame, keyFrame: Bool) throws -> [UInt8] {
        if h264 == nil {
            h264 = try VideoToolboxH264Encoder(width: encodedSize.width, height: encodedSize.height, bitRate: quality.videoBitRate, framesPerSecond: quality.framesPerSecond)
        }
        guard let h264 else { return [] }
        let stream = try h264.encode(frame, forceKeyFrame: keyFrame)
        let region = GraphicsRectangle(left: 0, top: 0, right: UInt16(desktopSize.width), bottom: UInt16(desktopSize.height))
        let bitmap = GraphicsServerPdu.avc420Bitmap(regions: [region], h264: stream)
        return GraphicsServerPdu.wireToSurface(surfaceId: Self.surfaceId, codec: GraphicsCodec.avc420, destination: region, bitmap: bitmap)
    }

    /// Lossless planar tiles (top-down rows, as the graphics pipeline expects).
    private func encodePlanar(_ frame: ScreenFrame, tiles: Set<Int>, comparedTo previous: ScreenFrame? = nil) -> [UInt8] {
        var output: [UInt8] = []
        frame.pixels.withUnsafeBytes { current in
            for index in tiles.sorted() {
                let tile = grid.frame(ofTile: index)
                guard tile.width > 0, tile.height > 0, tile.left + tile.width <= frame.width, tile.top + tile.height <= frame.height else { continue }
                var bounds = (x: tile.left, y: tile.top, width: tile.width, height: tile.height)
                if let previous {
                    guard let changed = ScreenUpdateEncoder.changedBounds(current, previous, stride: frame.bytesPerRow, tile: bounds) else { continue }
                    bounds = changed
                }
                let planar = PlanarBitmapEncoder.encode(source: current, bytesPerRow: frame.bytesPerRow, left: bounds.x, top: bounds.y, width: bounds.width, height: bounds.height, topDown: true)
                let destination = GraphicsRectangle(left: UInt16(bounds.x), top: UInt16(bounds.y), right: UInt16(bounds.x + bounds.width), bottom: UInt16(bounds.y + bounds.height))
                output += GraphicsServerPdu.wireToSurface(surfaceId: Self.surfaceId, codec: GraphicsCodec.planar, destination: destination, bitmap: planar)
            }
        }
        return output
    }
}
