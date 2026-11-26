import Foundation
import Synchronization

/// Produces an animated synthetic test pattern; used for diagnostics and tests without screen capture.
public final class TestPatternFrameSource: FrameSource {
    public let desktopSize: DesktopSize
    private let interval: Duration
    private let task = Mutex<Task<Void, Never>?>(nil)

    public init(desktopSize: DesktopSize = DesktopSize(width: 1024, height: 768), interval: Duration = .milliseconds(200)) {
        self.desktopSize = desktopSize
        self.interval = interval
    }

    public func start(onFrame: @escaping @Sendable (ScreenFrame) -> Void) async throws {
        let size = desktopSize
        let interval = interval
        let newTask = Task {
            var tick = 0
            while !Task.isCancelled {
                onFrame(Self.makeFrame(size: size, tick: tick))
                tick += 1
                try? await Task.sleep(for: interval)
            }
        }
        task.withLock { $0 = newTask }
    }

    public func stop() async {
        task.withLock { current in
            current?.cancel()
            current = nil
        }
    }

    /// Vertical color bars with a moving white square.
    public static func makeFrame(size: DesktopSize, tick: Int) -> ScreenFrame {
        let bytesPerRow = size.width * 4
        let colors: [(UInt8, UInt8, UInt8)] = [(255, 255, 255), (0, 255, 255), (255, 255, 0), (0, 255, 0), (255, 0, 255), (0, 0, 255), (255, 0, 0), (0, 0, 0)]
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * size.height)
        let barWidth = max(size.width / colors.count, 1)
        let squareSize = max(size.height / 8, 8)
        let squareX = (tick * 16) % max(size.width - squareSize, 1)
        let squareY = size.height / 2 - squareSize / 2
        for y in 0..<size.height {
            for x in 0..<size.width {
                let offset = y * bytesPerRow + x * 4
                let inSquare = x >= squareX && x < squareX + squareSize && y >= squareY && y < squareY + squareSize
                let (blue, green, red) = inSquare ? (255, 255, 255) : colors[min(x / barWidth, colors.count - 1)]
                pixels[offset] = blue
                pixels[offset + 1] = green
                pixels[offset + 2] = red
                pixels[offset + 3] = 255
            }
        }
        return ScreenFrame(width: size.width, height: size.height, bytesPerRow: bytesPerRow, pixels: pixels)
    }
}
