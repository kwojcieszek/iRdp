import Synchronization

/// The server's current streaming quality, read by new sessions.
final class StreamingQualityHolder: Sendable {
    private let value: Mutex<StreamingQuality>

    init(_ quality: StreamingQuality) {
        value = Mutex(quality)
    }

    var current: StreamingQuality {
        get { value.withLock { $0 } }
        set { value.withLock { $0 = newValue } }
    }
}
