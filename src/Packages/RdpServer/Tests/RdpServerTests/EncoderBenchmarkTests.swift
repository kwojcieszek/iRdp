import Foundation
import RdpProtocol
import Testing
@testable import RdpServer

/// Measures encoder speed. Runs only with IRDP_BENCHMARK=1 (use `swift test -c release`).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["IRDP_BENCHMARK"] == "1"))
struct EncoderBenchmarkTests {
    static func desktopLikeFrame(width: Int, height: Int, seed: Int) -> ScreenFrame {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                // Flat areas with "text" like noise in some bands, similar to UI content.
                let band = (y / 24 + seed) % 5 == 0
                let value: UInt8 = band ? UInt8(truncatingIfNeeded: (x &* 31 &+ y &* 17 &+ seed) % 251) : UInt8(200 + (y / 100) % 40)
                pixels[offset] = value
                pixels[offset + 1] = value &+ 10
                pixels[offset + 2] = value &+ 20
                pixels[offset + 3] = 255
            }
        }
        return ScreenFrame(width: width, height: height, bytesPerRow: width * 4, pixels: pixels)
    }

    private func measure(_ label: String, iterations: Int = 5, _ body: () -> Int) {
        var bytes = 0
        let clock = ContinuousClock()
        let duration = clock.measure { for _ in 0..<iterations { bytes = body() } }
        let ms = Double(duration.components.attoseconds) / 1e15 / Double(iterations) + Double(duration.components.seconds) * 1000 / Double(iterations)
        print("BENCH \(label): \(String(format: "%.1f", ms)) ms, \(bytes / 1024) KiB")
    }

    @Test func encoderSpeed() {
        let first = Self.desktopLikeFrame(width: 1920, height: 1080, seed: 0)
        let second = Self.desktopLikeFrame(width: 1920, height: 1080, seed: 1)
        measure("full frame planar 32bpp") {
            ScreenUpdateEncoder(bitsPerPixel: 32).encode(first).reduce(0) { $0 + $1.count }
        }
        measure("full frame raw 16bpp") {
            ScreenUpdateEncoder(bitsPerPixel: 16).encode(first).reduce(0) { $0 + $1.count }
        }
        let encoder = ScreenUpdateEncoder(bitsPerPixel: 32)
        _ = encoder.encode(first)
        measure("unchanged frame diff") { encoder.encode(first).reduce(0) { $0 + $1.count } }
        var small = first.pixels
        for y in 500..<520 { for x in 900..<1000 { small[(y * 1920 + x) * 4] &+= 1 } }
        let smallFrame = ScreenFrame(width: 1920, height: 1080, bytesPerRow: 7680, pixels: small)
        measure("small change") {
            _ = encoder.encode(first)
            return encoder.encode(smallFrame).reduce(0) { $0 + $1.count }
        }
        measure("everything changed") {
            _ = encoder.encode(first)
            return encoder.encode(second).reduce(0) { $0 + $1.count }
        }
    }
}
