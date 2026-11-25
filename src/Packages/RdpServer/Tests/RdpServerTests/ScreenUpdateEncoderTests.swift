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
        #expect(pdus.count == 6)
        let rects = try rectangles(pdus)
        let edge = try #require(rects.first { $0.destLeft == 128 && $0.destTop == 64 })
        #expect(edge.destRight == 129 && edge.destBottom == 69)
        #expect(edge.width == 4, "width is padded to a multiple of four pixels")
        #expect(edge.data.count == 4 * 6 * 4)
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
        #expect(rects.first?.destLeft == 64 && rects.first?.destTop == 64)
    }

    @Test func forcedRefreshSendsEveryTile() {
        let encoder = ScreenUpdateEncoder(bitsPerPixel: 16)
        let frame = solidFrame(width: 64, height: 128)
        _ = encoder.encode(frame)
        #expect(encoder.encode(frame, forceFullUpdate: true).count == 2)
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
