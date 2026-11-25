import RdpProtocol
import RdpServer
import Synchronization

/// Input sink that records the events it receives.
final class RecordingInputSink: InputSink {
    private let storage = Mutex<[RdpInputEvent]>([])
    private let releases = Mutex(0)

    var events: [RdpInputEvent] { storage.withLock { $0 } }
    var releaseCount: Int { releases.withLock { $0 } }

    func handle(_ event: RdpInputEvent) {
        storage.withLock { $0.append(event) }
    }

    func releaseAll() {
        releases.withLock { $0 += 1 }
    }
}
