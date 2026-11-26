import Foundation
import RdpProtocol

/// Turns screen frames into fast-path bitmap update PDUs, sending only tiles that changed since the previous frame.
public final class ScreenUpdateEncoder: FrameEncoding {
    public static let tileSize = 64

    public let bitsPerPixel: Int
    /// 32 bpp tiles are compressed with the RDP 6.0 planar codec.
    public let usesPlanarCompression: Bool
    /// Whether compressed data must start with TS_CD_HEADER (clients without NO_BITMAP_COMPRESSION_HDR support).
    public let includesCompressionHeader: Bool
    public private(set) var lastFrame: ScreenFrame?
    var usesFrameAcknowledgements: Bool { false }

    func refinement() -> [[UInt8]]? { nil }

    var framesInLastBatch: Int { 1 }

    func apply(_ quality: StreamingQuality) {}

    public init(bitsPerPixel: Int, usesPlanarCompression: Bool = true, includesCompressionHeader: Bool = false) {
        self.bitsPerPixel = [16, 24, 32].contains(bitsPerPixel) ? bitsPerPixel : 32
        self.usesPlanarCompression = usesPlanarCompression && self.bitsPerPixel == 32
        self.includesCompressionHeader = includesCompressionHeader
    }

    /// Returns one fast-path PDU per changed tile.
    public func encode(_ frame: ScreenFrame, forceFullUpdate: Bool = false) -> [[UInt8]] {
        let previous = lastFrame
        let isFull = forceFullUpdate || previous == nil || previous?.size != frame.size || previous?.bytesPerRow != frame.bytesPerRow
        var pdus: [[UInt8]] = []
        let tile = Self.tileSize
        frame.pixels.withUnsafeBytes { current in
            for top in stride(from: 0, to: frame.height, by: tile) {
                for left in stride(from: 0, to: frame.width, by: tile) {
                    let width = min(tile, frame.width - left)
                    let height = min(tile, frame.height - top)
                    if !isFull, let previous, !Self.tileChanged(current, previous, frame: frame, left: left, top: top, width: width, height: height) {
                        continue
                    }
                    let rectangle = makeRectangle(current, frame: frame, left: left, top: top, width: width, height: height)
                    let update = FastPathUpdate(code: .bitmap, data: BitmapUpdate(rectangles: [rectangle]).encode())
                    pdus.append(FastPathUpdate.pdu([update]))
                }
            }
        }
        lastFrame = frame
        return pdus
    }

    static func tileChanged(_ current: UnsafeRawBufferPointer, _ previous: ScreenFrame, frame: ScreenFrame, left: Int, top: Int, width: Int, height: Int) -> Bool {
        previous.pixels.withUnsafeBytes { old in
            guard let currentBase = current.baseAddress, let oldBase = old.baseAddress else { return true }
            for row in top..<(top + height) {
                let offset = row * frame.bytesPerRow + left * 4
                if memcmp(currentBase + offset, oldBase + offset, width * 4) != 0 { return true }
            }
            return false
        }
    }

    func makeRectangle(_ source: UnsafeRawBufferPointer, frame: ScreenFrame, left: Int, top: Int, width: Int, height: Int) -> BitmapRectangle {
        let paddedWidth = (width + 3) & ~3
        var rectangle = BitmapRectangle(
            destLeft: UInt16(left), destTop: UInt16(top),
            destRight: UInt16(left + width - 1), destBottom: UInt16(top + height - 1),
            width: UInt16(paddedWidth), height: UInt16(height),
            bitsPerPixel: UInt16(bitsPerPixel), data: []
        )
        if usesPlanarCompression {
            var tile: [UInt8] = []
            tile.reserveCapacity(paddedWidth * height * 4)
            for row in top..<(top + height) {
                PixelFormatConverter.appendRow(from: source, offset: row * frame.bytesPerRow + left * 4, count: width, bitsPerPixel: 32, to: &tile)
                if paddedWidth > width { tile.append(contentsOf: repeatElement(0, count: (paddedWidth - width) * 4)) }
            }
            let compressed = PlanarBitmapEncoder.encode(bgrx: tile, width: paddedWidth, height: height)
            if includesCompressionHeader {
                var header = ByteWriter(capacity: 8 + compressed.count)
                header.writeUInt16LE(0)
                header.writeUInt16LE(UInt16(compressed.count))
                header.writeUInt16LE(UInt16(paddedWidth * 4))
                header.writeUInt16LE(UInt16(truncatingIfNeeded: paddedWidth * height * 4))
                header.writeBytes(compressed)
                rectangle.data = header.bytes
                rectangle.flags = BitmapRectangle.compressionFlag
            } else {
                rectangle.data = compressed
                rectangle.flags = BitmapRectangle.compressionFlag | BitmapRectangle.noCompressionHeaderFlag
            }
            return rectangle
        }
        let bytesPerPixel = PixelFormatConverter.bytesPerPixel(for: bitsPerPixel)
        var data: [UInt8] = []
        data.reserveCapacity(paddedWidth * height * bytesPerPixel)
        let padding = (paddedWidth - width) * bytesPerPixel
        for row in stride(from: top + height - 1, through: top, by: -1) {
            PixelFormatConverter.appendRow(from: source, offset: row * frame.bytesPerRow + left * 4, count: width, bitsPerPixel: bitsPerPixel, to: &data)
            if padding > 0 { data.append(contentsOf: repeatElement(0, count: padding)) }
        }
        rectangle.data = data
        return rectangle
    }
}
