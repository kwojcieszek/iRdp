import Foundation
import RdpServer
import Synchronization

/// Observer that records session lifecycle callbacks.
final class RecordingObserver: RdpServerObserver {
    private let started = Mutex<[RdpSessionInfo]>([])
    private let ended = Mutex<[UUID]>([])
    private let failures = Mutex<[String]>([])

    var startedSessions: [RdpSessionInfo] { started.withLock { $0 } }
    var endedSessions: [UUID] { ended.withLock { $0 } }
    var failureReasons: [String] { failures.withLock { $0 } }

    func sessionDidStart(_ session: RdpSessionInfo) { started.withLock { $0.append(session) } }
    func sessionDidEnd(_ sessionId: UUID) { ended.withLock { $0.append(sessionId) } }
    func connectionDidFail(remoteAddress: String, reason: String) { failures.withLock { $0.append(reason) } }
}
