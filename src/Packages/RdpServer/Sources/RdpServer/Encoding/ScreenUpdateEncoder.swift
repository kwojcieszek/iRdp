import Foundation
import RdpProtocol

/// Turns screen frames into fast-path bitmap update PDUs, sending only tiles that changed since the previous frame.
public final class ScreenUpdateEncoder: FrameEncoding {
    public static let tileSize = 64

    private let supportsScreenCopy: Bool
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

    public init(bitsPerPixel: Int, usesPlanarCompression: Bool = true, includesCompressionHeader: Bool = false, supportsScreenCopy: Bool = false) {
        self.supportsScreenCopy = supportsScreenCopy
        self.bitsPerPixel = [16, 24, 32].contains(bitsPerPixel) ? bitsPerPixel : 32
        self.usesPlanarCompression = usesPlanarCompression && self.bitsPerPixel == 32
        self.includesCompressionHeader = includesCompressionHeader
    }

    /// Groups changed rectangles into bounded fast-path bitmap updates.
    public func encode(_ frame: ScreenFrame, forceFullUpdate: Bool = false) -> [[UInt8]] {
        let previous = lastFrame
        let isFull = forceFullUpdate || previous == nil || previous?.size != frame.size || previous?.bytesPerRow != frame.bytesPerRow
        var pdus: [[UInt8]] = []
        let scroll = !isFull && supportsScreenCopy ? previous.flatMap { VerticalScroll.detect(frame, previous: $0) } : nil
        if let scroll { pdus.append(scroll.order(width: frame.width)) }
        var rectangles: [BitmapRectangle] = []
        var rectangleBytes = 0
        func flush() {
            guard !rectangles.isEmpty else { return }
            let update = FastPathUpdate(code: .bitmap, data: BitmapUpdate(rectangles: rectangles).encode())
            pdus.append(FastPathUpdate.pdu([update]))
            rectangles.removeAll(keepingCapacity: true)
            rectangleBytes = 0
        }
        let tile = Self.tileSize
        frame.pixels.withUnsafeBytes { current in
            func encodeRows(_ rows: Range<Int>) {
                for top in stride(from: rows.lowerBound, to: rows.upperBound, by: tile) {
                    for left in stride(from: 0, to: frame.width, by: tile) {
                        let width = min(tile, frame.width - left)
                        let height = min(tile, rows.upperBound - top)
                        var bounds = (x: left, y: top, width: width, height: height)
                        if !isFull, let previous {
                            guard let changed = Self.changedBounds(current, previous, stride: frame.bytesPerRow, tile: bounds) else { continue }
                            bounds = changed
                        }
                        let rectangle = makeRectangle(current, frame: frame, left: bounds.x, top: bounds.y, width: bounds.width, height: bounds.height)
                        let length = BitmapRectangle.headerLength + rectangle.data.count
                        // Reserve 10 bytes for fast-path, update and bitmap headers.
                        if rectangleBytes + length + 10 > 16384 { flush() }
                        rectangles.append(rectangle)
                        rectangleBytes += length
                    }
                }
            }
            if let scroll {
                encodeRows(0..<scroll.top)
                encodeRows(scroll.bottom..<frame.height)
            } else {
                encodeRows(0..<frame.height)
            }
        }
        flush()
        lastFrame = frame
        return pdus
    }

    typealias Bounds = (x: Int, y: Int, width: Int, height: Int)

    static func changedBounds(_ current: UnsafeRawBufferPointer, _ previous: ScreenFrame, stride: Int, tile: Bounds) -> Bounds? {
        previous.pixels.withUnsafeBytes { old in
            // Scrolling and video often change both opposite corners, establishing the full bounds immediately.
            let first = tile.y * stride + tile.x * 4
            let last = first + (tile.height - 1) * stride + (tile.width - 1) * 4
            if current.loadUnaligned(fromByteOffset: first, as: UInt32.self) != old.loadUnaligned(fromByteOffset: first, as: UInt32.self),
               current.loadUnaligned(fromByteOffset: last, as: UInt32.self) != old.loadUnaligned(fromByteOffset: last, as: UInt32.self) {
                return tile
            }
            var left = tile.width, right = 0, top = tile.height, bottom = 0
            for y in 0..<tile.height {
                let offset = (tile.y + y) * stride + tile.x * 4
                let a = current.baseAddress! + offset
                let b = old.baseAddress! + offset
                guard memcmp(a, b, tile.width * 4) != 0 else { continue }
                top = min(top, y)
                bottom = y + 1
                for x in 0..<left where a.loadUnaligned(fromByteOffset: x * 4, as: UInt32.self) != b.loadUnaligned(fromByteOffset: x * 4, as: UInt32.self) {
                    left = x
                    break
                }
                for x in (right..<tile.width).reversed() where a.loadUnaligned(fromByteOffset: x * 4, as: UInt32.self) != b.loadUnaligned(fromByteOffset: x * 4, as: UInt32.self) {
                    right = x + 1
                    break
                }
            }
            guard bottom > top else { return nil }
            return (tile.x + left, tile.y + top, right - left, bottom - top)
        }
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
            // Padding columns (to a multiple of four pixels) are left out; the planar data covers the real width.
            rectangle.width = UInt16(width)
            let compressed = PlanarBitmapEncoder.encode(source: source, bytesPerRow: frame.bytesPerRow, left: left, top: top, width: width, height: height, topDown: false)
            if includesCompressionHeader {
                var header = ByteWriter(capacity: 8 + compressed.count)
                header.writeUInt16LE(0)
                header.writeUInt16LE(UInt16(compressed.count))
                header.writeUInt16LE(UInt16(width * 4))
                header.writeUInt16LE(UInt16(truncatingIfNeeded: width * height * 4))
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
