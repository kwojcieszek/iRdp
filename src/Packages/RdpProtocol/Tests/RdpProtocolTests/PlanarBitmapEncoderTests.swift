import Testing
@testable import RdpProtocol

struct PlanarBitmapEncoderTests {
    private func roundTrip(_ pixels: [UInt8], width: Int, height: Int) throws -> [UInt8] {
        try PlanarBitmapDecoder.decode(PlanarBitmapEncoder.encode(bgrx: pixels, width: width, height: height), width: width, height: height)
    }

    private func opaque(_ pixels: [UInt8]) -> [UInt8] {
        var copy = pixels
        for index in stride(from: 3, to: copy.count, by: 4) { copy[index] = 0xFF }
        return copy
    }

    @Test func compressesSolidColorWell() throws {
        let pixels = [UInt8]((0..<(64 * 64)).flatMap { _ in [40, 80, 120, 255] as [UInt8] })
        let encoded = PlanarBitmapEncoder.encode(bgrx: pixels, width: 64, height: 64)
        #expect(encoded.count < 64 * 64 / 4)
        #expect(try roundTrip(pixels, width: 64, height: 64) == pixels)
    }

    @Test(arguments: [(1, 1), (3, 2), (17, 5), (64, 64), (33, 47), (100, 3)])
    func roundTripsRandomImages(width: Int, height: Int) throws {
        var generator = SystemRandomNumberGenerator()
        let pixels = (0..<(width * height * 4)).map { _ in UInt8.random(in: 0...255, using: &generator) }
        #expect(try roundTrip(pixels, width: width, height: height) == opaque(pixels))
    }

    @Test func roundTripsGradientsAndLongRuns() throws {
        let width = 120
        let height = 9
        var pixels: [UInt8] = []
        for row in 0..<height {
            for column in 0..<width {
                let value = UInt8(column < 60 ? 0 : (column + row * 7) % 256)
                pixels += [value, UInt8(row * 20), value &+ 3, 255]
            }
        }
        #expect(try roundTrip(pixels, width: width, height: height) == pixels)
    }

    @Test func encodesRunsWithSpecialLengths() {
        for run in [3, 15, 16, 31, 32, 47, 48, 50, 63, 64, 100] {
            var output: [UInt8] = []
            PlanarBitmapEncoder.encodeScanline([UInt8](repeating: 0, count: run), into: &output)
            var decodedCount = 0
            var index = 0
            while index < output.count {
                let control = output[index]
                var length = Int(control & 0x0F)
                var raw = Int(control >> 4)
                if length == 1 { length = raw + 16; raw = 0 } else if length == 2 { length = raw + 32; raw = 0 }
                decodedCount += raw + length
                index += 1 + raw
            }
            #expect(decodedCount == run, "run of \(run)")
        }
    }
}
