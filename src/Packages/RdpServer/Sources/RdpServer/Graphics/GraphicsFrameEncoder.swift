import Foundation
import os
import RdpProtocol

/// Encodes screen frames as RDPGFX frames (H.264/AVC420, or planar tiles when the client has no AVC support).
final class GraphicsFrameEncoder: FrameEncoding {
    private static let logger = Logger(subsystem: "com.kwojcieszek.irdp", category: "graphics")
    static let surfaceId: UInt16 = 0

    let desktopSize: DesktopSize
    let encodedSize: DesktopSize
    private(set) var codec: GraphicsPipelineCodec
    private let wrap: ([UInt8]) -> [[UInt8]]
    private let bitRate: Int
    private let framesPerSecond: Int
    private var h264: VideoToolboxH264Encoder?
    private var nextFrameId: UInt32 = 1
    private let startTime = Date()
    private(set) var lastFrame: ScreenFrame?
    private(set) var lastFrameId: UInt32 = 0

    var usesFrameAcknowledgements: Bool { true }
    var refinementFrameCount: Int { codec == .avc420 ? 2 : 0 }

    /// `wrap` turns one RDPGFX message into wire packets (segmented data, DVC, SVC, MCS, X.224, TPKT).
    init(desktopSize: DesktopSize, codec: GraphicsPipelineCodec, bitRate: Int, framesPerSecond: Int, wrap: @escaping ([UInt8]) -> [[UInt8]]) {
        self.desktopSize = desktopSize
        self.codec = codec
        self.wrap = wrap
        self.bitRate = bitRate
        self.framesPerSecond = framesPerSecond
        encodedSize = DesktopSize(width: (desktopSize.width + 15) & ~15, height: (desktopSize.height + 15) & ~15)
    }

    /// Setup PDUs sent after the capabilities are confirmed: reset graphics, create the surface and map it.
    func setupMessage(confirming capabilities: GraphicsCapabilitySet) -> [UInt8] {
        GraphicsServerPdu.capsConfirm(capabilities)
            + GraphicsServerPdu.resetGraphics(width: desktopSize.width, height: desktopSize.height)
            + GraphicsServerPdu.createSurface(id: Self.surfaceId, width: encodedSize.width, height: encodedSize.height)
            + GraphicsServerPdu.mapSurfaceToOutput(id: Self.surfaceId)
    }

    func encode(_ frame: ScreenFrame, forceFullUpdate: Bool) -> [[UInt8]] {
        let previous = lastFrame
        let isFull = forceFullUpdate || previous?.size != frame.size
        let content: [UInt8]
        switch codec {
        case .avc420:
            do {
                content = try encodeAvc(frame, keyFrame: isFull)
            } catch {
                Self.logger.error("H.264 failed, switching to planar: \(String(describing: error), privacy: .public)")
                codec = .planar
                h264 = nil
                return encode(frame, forceFullUpdate: true)
            }
        case .planar:
            content = encodePlanar(frame, previous: isFull ? nil : previous)
        }
        lastFrame = frame
        guard !content.isEmpty else { return [] }
        let frameId = nextFrameId
        nextFrameId &+= 1
        lastFrameId = frameId
        let timestamp = UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince(startTime) * 1000))
        let message = GraphicsServerPdu.startFrame(id: frameId, timestamp: timestamp) + content + GraphicsServerPdu.endFrame(id: frameId)
        return wrap(message)
    }

    private func encodeAvc(_ frame: ScreenFrame, keyFrame: Bool) throws -> [UInt8] {
        if h264 == nil {
            h264 = try VideoToolboxH264Encoder(width: encodedSize.width, height: encodedSize.height, bitRate: bitRate, framesPerSecond: framesPerSecond)
        }
        guard let h264 else { return [] }
        let stream = try h264.encode(frame, forceKeyFrame: keyFrame)
        let area = GraphicsRectangle(left: 0, top: 0, right: UInt16(min(frame.width, desktopSize.width)), bottom: UInt16(min(frame.height, desktopSize.height)))
        let bitmap = GraphicsServerPdu.avc420Bitmap(regions: [area], h264: stream)
        let destination = GraphicsRectangle(left: 0, top: 0, right: UInt16(encodedSize.width), bottom: UInt16(encodedSize.height))
        return GraphicsServerPdu.wireToSurface(surfaceId: Self.surfaceId, codec: GraphicsCodec.avc420, destination: destination, bitmap: bitmap)
    }

    private func encodePlanar(_ frame: ScreenFrame, previous: ScreenFrame?) -> [UInt8] {
        var output: [UInt8] = []
        let tile = ScreenUpdateEncoder.tileSize
        frame.pixels.withUnsafeBytes { current in
            for top in stride(from: 0, to: frame.height, by: tile) {
                for left in stride(from: 0, to: frame.width, by: tile) {
                    let width = min(tile, frame.width - left)
                    let height = min(tile, frame.height - top)
                    if let previous, !ScreenUpdateEncoder.tileChanged(current, previous, frame: frame, left: left, top: top, width: width, height: height) { continue }
                    var pixels: [UInt8] = []
                    pixels.reserveCapacity(width * height * 4)
                    for row in top..<(top + height) {
                        PixelFormatConverter.appendRow(from: current, offset: row * frame.bytesPerRow + left * 4, count: width, bitsPerPixel: 32, to: &pixels)
                    }
                    let planar = PlanarBitmapEncoder.encode(bgrx: pixels, width: width, height: height, topDown: true)
                    let destination = GraphicsRectangle(left: UInt16(left), top: UInt16(top), right: UInt16(left + width), bottom: UInt16(top + height))
                    output += GraphicsServerPdu.wireToSurface(surfaceId: Self.surfaceId, codec: GraphicsCodec.planar, destination: destination, bitmap: planar)
                }
            }
        }
        return output
    }
}
