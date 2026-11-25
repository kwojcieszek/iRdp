import Testing
@testable import RdpServer

struct PixelFormatConverterTests {
    private func convert(_ pixel: [UInt8], bitsPerPixel: Int) -> [UInt8] {
        var output: [UInt8] = []
        pixel.withUnsafeBytes { PixelFormatConverter.appendRow(from: $0, offset: 0, count: 1, bitsPerPixel: bitsPerPixel, to: &output) }
        return output
    }

    @Test func convertsTo32BitsWithOpaqueAlpha() {
        #expect(convert([1, 2, 3, 0], bitsPerPixel: 32) == [1, 2, 3, 0xFF])
    }

    @Test func convertsTo24Bits() {
        #expect(convert([1, 2, 3, 4], bitsPerPixel: 24) == [1, 2, 3])
    }

    @Test func convertsToRgb565() {
        // Pure red: 0xF800, pure green: 0x07E0, pure blue: 0x001F (little endian).
        #expect(convert([0, 0, 255, 255], bitsPerPixel: 16) == [0x00, 0xF8])
        #expect(convert([0, 255, 0, 255], bitsPerPixel: 16) == [0xE0, 0x07])
        #expect(convert([255, 0, 0, 255], bitsPerPixel: 16) == [0x1F, 0x00])
    }

    @Test func reportsBytesPerPixel() {
        #expect(PixelFormatConverter.bytesPerPixel(for: 32) == 4)
        #expect(PixelFormatConverter.bytesPerPixel(for: 24) == 3)
        #expect(PixelFormatConverter.bytesPerPixel(for: 16) == 2)
    }
}
