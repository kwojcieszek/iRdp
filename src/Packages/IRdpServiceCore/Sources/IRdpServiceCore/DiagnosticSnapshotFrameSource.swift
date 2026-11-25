import CoreGraphics
import Foundation
import ImageIO
import RdpServer
import Synchronization
import UniformTypeIdentifiers

/// Diagnostics only (enabled with IRDP_DEBUG_SNAPSHOT_DIR): saves a PNG of the captured screen once per second,
/// which shows what an RDP client window on this Mac renders.
final class DiagnosticSnapshotFrameSource: FrameSource {
    private let inner: any FrameSource
    private let directory: URL
    private let lastWrite = Mutex<Date>(.distantPast)

    init(wrapping inner: any FrameSource, directory: URL) {
        self.inner = inner
        self.directory = directory
    }

    var desktopSize: DesktopSize { inner.desktopSize }

    func start(onFrame: @escaping @Sendable (ScreenFrame) -> Void) async throws {
        let directory = directory
        try await inner.start { [self] frame in
            onFrame(frame)
            let now = Date()
            let due = self.lastWrite.withLock { last -> Bool in
                guard now.timeIntervalSince(last) >= 1 else { return false }
                last = now
                return true
            }
            if due { Self.write(frame, to: directory.appendingPathComponent("snapshot-\(Int(now.timeIntervalSince1970)).png")) }
        }
    }

    func stop() async {
        await inner.stop()
    }

    func setFrameRate(_ framesPerSecond: Int) async {
        await inner.setFrameRate(framesPerSecond)
    }

    static func write(_ frame: ScreenFrame, to url: URL) {
        guard let provider = CGDataProvider(data: Data(frame.pixels) as CFData),
              let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.bytesPerRow,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
