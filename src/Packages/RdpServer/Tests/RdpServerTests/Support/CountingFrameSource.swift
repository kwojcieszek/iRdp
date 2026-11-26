import RdpServer
import Synchronization

/// Wraps a frame source and counts how often capture was started.
final class CountingFrameSource: FrameSource {
    private let inner: any FrameSource
    private let starts = Mutex(0)

    init(_ inner: any FrameSource) {
        self.inner = inner
    }

    var startCount: Int { starts.withLock { $0 } }
    var desktopSize: DesktopSize { inner.desktopSize }

    func start(onFrame: @escaping @Sendable (ScreenFrame) -> Void) async throws {
        starts.withLock { $0 += 1 }
        try await inner.start(onFrame: onFrame)
    }

    func stop() async {
        await inner.stop()
    }
}
