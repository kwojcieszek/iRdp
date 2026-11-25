import Foundation
import Synchronization

/// Tracks active sessions so that a new session can take over from the previous one and quality changes reach them.
final class RdpSessionRegistry: Sendable {
    private let sessions = Mutex<[UUID: RdpSessionHandle]>([:])

    /// Registers a session and returns the sessions it replaces (to be disconnected by the caller).
    func register(_ id: UUID, maximumSessions: Int, handle: RdpSessionHandle) -> [RdpSessionHandle] {
        sessions.withLock { sessions in
            var replaced: [RdpSessionHandle] = []
            while sessions.count >= max(maximumSessions, 1), let oldest = sessions.keys.first {
                if let handle = sessions.removeValue(forKey: oldest) { replaced.append(handle) }
            }
            sessions[id] = handle
            return replaced
        }
    }

    func unregister(_ id: UUID) {
        _ = sessions.withLock { $0.removeValue(forKey: id) }
    }

    var count: Int { sessions.withLock { $0.count } }

    func applyQuality(_ quality: StreamingQuality) {
        let handles = sessions.withLock { Array($0.values) }
        handles.forEach { $0.applyQuality(quality) }
    }

    func disconnectAll() {
        let handles = sessions.withLock { sessions in
            defer { sessions.removeAll() }
            return Array(sessions.values)
        }
        handles.forEach { $0.disconnect() }
    }
}
