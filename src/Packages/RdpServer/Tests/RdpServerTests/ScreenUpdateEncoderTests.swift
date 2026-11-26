import RdpProtocol
import Testing
@testable import RdpServer

struct ScreenUpdateEncoderTests {
    private func solidFrame(width: Int, height: Int, blue: UInt8 = 10, green: UInt8 = 20, red: UInt8 = 30) -> ScreenFrame {
        var pixels: [UInt8] = []
        for _ in 0..<(width * height) { pixels += [blue, green, red, 255] }
        return ScreenFrame(width: width, height: height, bytesPerRow: width * 4, pixels: pixels)
    }

    private func rectangles(_ pdus: [[UInt8]]) throws -> [BitmapRectangle] {
        try pdus.flatMap { pdu in try FastPathUpdate.parsePdu(pdu).flatMap { try BitmapUpdate.parse($0.data).rectangles } }
    }

    @Test func firstFrameSendsEveryTile() throws {
        let encoder = ScreenUpdateEncoder(bitsPerPixel: 32, usesPlanarCompression: false)
        let pdus = encoder.encode(solidFrame(width: 130, height: 70))
        // 3 columns (64, 64, 2) x 2 rows (64, 6).
        #expect(pdus.count < 6)
        let rects = try rectangles(pdus)
        #expect(rects.count == 6)
        let edge = try #require(rects.first { $0.destLeft == 128 && $0.destTop == 64 })
        #expect(edge.destRight == 129 && edge.destBottom == 69)
        #expect(edge.width == 4, "width is padded to a multiple of four pixels")
        #expect(edge.data.count == 4 * 6 * 4)
    }

    @Test func sparseChangesAcross4KDesktop() throws {
        let width = 3840, height = 2160
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let encoder = ScreenUpdateEncoder(bitsPerPixel: 32)
        func frame() -> ScreenFrame {
            ScreenFrame(width: width, height: height, bytesPerRow: width * 4, pixels: pixels)
        }
        _ = encoder.encode(frame())
        for y in stride(from: 0, to: height, by: 64) {
            for x in stride(from: 0, to: width, by: 64) {
                pixels[(y * width + x) * 4] = 255
            }
        }
        let start = ContinuousClock.now
        let packets = encoder.encode(frame())
        print("4K sparse update:", packets.count, "packets,", packets.reduce(0) { $0 + $1.count }, "bytes,", start.duration(to: .now))
        let rects = try rectangles(packets)
        #expect(rects.count == 2040)
        #expect(rects.allSatisfy { $0.width == 1 && $0.height == 1 })
        #expect(packets.count < 10)
    }

    @Test(arguments: [-37, 37])
    func scrollCopiesVerifiedRowsAndPreservesFixedBars(offset: Int) throws {
        let width = 3840, height = 2160, stride = width * 4
        var base = [UInt8](repeating: 0, count: height * stride)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * stride + x * 4
                base[i] = UInt8(truncatingIfNeeded: y)
                base[i + 1] = UInt8(truncatingIfNeeded: y >> 8)
                base[i + 2] = UInt8(truncatingIfNeeded: x)
                base[i + 3] = 255
            }
        }
        var moved = base
        let band = 130..<2000
        for y in band {
            let source = y + offset
            moved.replaceSubrange(y * stride..<(y + 1) * stride, with: base[source * stride..<(source + 1) * stride])
        }
        // Rows revealed inside the scrolling window have new content.
        let exposed = offset > 0 ? (band.upperBound - offset)..<band.upperBound : band.lowerBound..<(band.lowerBound - offset)
        for y in exposed {
            for x in 0..<width { moved[(y * width + x) * 4] ^= 255 }
        }
        moved[(2001 * width + 17) * 4] ^= 255
        let encoder = ScreenUpdateEncoder(bitsPerPixel: 32, usesPlanarCompression: false, supportsScreenCopy: true)
        func frame(_ bytes: [UInt8]) -> ScreenFrame {
            ScreenFrame(width: width, height: height, bytesPerRow: stride, pixels: bytes)
        }
        _ = encoder.encode(frame(base))
        let bitmapOnly = ScreenUpdateEncoder(bitsPerPixel: 32, usesPlanarCompression: false)
        _ = bitmapOnly.encode(frame(base))
        let bitmapPackets = bitmapOnly.encode(frame(moved))
        let bitmapBytes = bitmapPackets.reduce(0) { $0 + $1.count }
        let start = ContinuousClock.now
        let packets = encoder.encode(frame(moved))
        #expect(packets.reduce(0) { $0 + $1.count } < bitmapBytes / 20)
        print("Bitmap-only scroll:", bitmapBytes, "bytes")
        print("4K scroll", offset, packets.reduce(0) { $0 + $1.count }, "bytes", start.duration(to: .now))
        var compressedSizes: [Int] = []
        for canCopy in [false, true] {
            let planar = ScreenUpdateEncoder(bitsPerPixel: 32, supportsScreenCopy: canCopy)
            _ = planar.encode(frame(base))
            compressedSizes.append(planar.encode(frame(moved)).reduce(0) { $0 + $1.count })
        }
        print("4K planar bitmap scroll", offset, "without/with ScrBlt:", compressedSizes)
        #expect(compressedSizes[1] < compressedSizes[0] / 10)
        let updates = try packets.flatMap(FastPathUpdate.parsePdu)
        let first = try #require(updates.first)
        #expect(first.code == .orders)
        var order = ByteReader(first.data)
        #expect(try order.readUInt16LE() == 1)
        #expect(try order.readBytes(3) == [0x09, 0x02, 0x7f])
        #expect(try order.readUInt16LE() == 0)
        let top = Int(try order.readUInt16LE())
        #expect(Int(try order.readUInt16LE()) == width)
        let bottom = top + Int(try order.readUInt16LE())
        #expect(try order.readUInt8() == 0xcc)
        #expect(try order.readUInt16LE() == 0)
        let source = Int(try order.readUInt16LE())
        var decoded = base
        decoded.replaceSubrange(top * stride..<bottom * stride, with: base[source * stride..<(source + bottom - top) * stride])
        for update in updates.dropFirst() {
            for rect in try BitmapUpdate.parse(update.data).rectangles {
                let length = Int(rect.destRight - rect.destLeft + 1) * 4
                for row in 0..<Int(rect.height) {
                    let dst = (Int(rect.destBottom) - row) * stride + Int(rect.destLeft) * 4
                    let src = row * Int(rect.width) * 4
                    decoded.replaceSubrange(dst..<dst + length, with: rect.data[src..<src + length])
                }
            }
        }
        #expect(decoded == moved)
    }

    @Test func unchangedFrameSendsNothing() {
        let encoder = ScreenUpdateEncoder(bitsPerPixel: 32)
        _ = encoder.encode(solidFrame(width: 128, height: 128))
        #expect(encoder.encode(solidFrame(width: 128, height: 128)).isEmpty)
    }

    @Test func changedPixelSendsOnlyItsTile() throws {
        let encoder = ScreenUpdateEncoder(bitsPerPixel: 32)
        let base = solidFrame(width: 128, height: 128)
        _ = encoder.encode(base)
        var pixels = base.pixels
        let offset = (100 * 128 + 70) * 4
        pixels[offset] = 0xFF
        let changed = ScreenFrame(width: 128, height: 128, bytesPerRow: 512, pixels: pixels)
        let rects = try rectangles(encoder.encode(changed))
        #expect(rects.count == 1)
        #expect(rects.first?.destLeft == 70 && rects.first?.destTop == 100)
    }

    @Test func forcedRefreshSendsEveryTile() throws {
        let encoder = ScreenUpdateEncoder(bitsPerPixel: 16)
        let frame = solidFrame(width: 64, height: 128)
        _ = encoder.encode(frame)
        #expect(try rectangles(encoder.encode(frame, forceFullUpdate: true)).count == 2)
    }

    @Test func rowsAreStoredBottomUp() throws {
        var pixels = [UInt8](repeating: 0, count: 4 * 2 * 4)
        pixels[0] = 0xAA // top-left blue
        let frame = ScreenFrame(width: 4, height: 2, bytesPerRow: 16, pixels: pixels)
        let rect = try #require(try rectangles(ScreenUpdateEncoder(bitsPerPixel: 32, usesPlanarCompression: false).encode(frame)).first)
        #expect(rect.data[16] == 0xAA, "the top row comes last")
        #expect(rect.data[0] == 0x00)
    }

    @Test func compressesThirtyTwoBitTilesWithPlanarCodec() throws {
        let rects = try rectangles(ScreenUpdateEncoder(bitsPerPixel: 32).encode(solidFrame(width: 64, height: 64)))
        let rect = try #require(rects.first)
        #expect(rect.flags == BitmapRectangle.compressionFlag | BitmapRectangle.noCompressionHeaderFlag)
        #expect(rect.data.first == PlanarBitmapEncoder.formatHeader)
        #expect(rect.data.count < 64 * 64)
    }

    @Test func addsCompressionHeaderWhenClientNeedsIt() throws {
        let rects = try rectangles(ScreenUpdateEncoder(bitsPerPixel: 32, includesCompressionHeader: true).encode(solidFrame(width: 8, height: 2)))
        let rect = try #require(rects.first)
        #expect(rect.flags == BitmapRectangle.compressionFlag)
        var reader = ByteReader(rect.data)
        #expect(try reader.readUInt16LE() == 0)
        #expect(Int(try reader.readUInt16LE()) == rect.data.count - 8)
        #expect(try reader.readUInt16LE() == 32)
        #expect(try reader.readUInt16LE() == 64)
    }

    @Test func doesNotCompressLowerColorDepths() throws {
        let rect = try #require(try rectangles(ScreenUpdateEncoder(bitsPerPixel: 16).encode(solidFrame(width: 4, height: 1))).first)
        #expect(rect.flags == 0)
        #expect(rect.data.count == 8)
    }

    @Test func everyPduFitsInAFastPathFrame() {
        let pdus = ScreenUpdateEncoder(bitsPerPixel: 32).encode(solidFrame(width: 256, height: 256))
        #expect(pdus.allSatisfy { $0.count <= FastPathLength.maximumFrameLength })
    }
}
