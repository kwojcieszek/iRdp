import Foundation
import Synchronization

/// Tracks active sessions so that a new session can take over from the previous one.
final class RdpSessionRegistry: Sendable {
    private let sessions = Mutex<[UUID: @Sendable () -> Void]>([:])

    /// Registers a session and returns the disconnect handlers of the sessions it replaces.
    func register(_ id: UUID, maximumSessions: Int, disconnect: @escaping @Sendable () -> Void) -> [@Sendable () -> Void] {
        sessions.withLock { sessions in
            var replaced: [@Sendable () -> Void] = []
            while sessions.count >= max(maximumSessions, 1), let oldest = sessions.keys.first {
                if let handler = sessions.removeValue(forKey: oldest) { replaced.append(handler) }
            }
            sessions[id] = disconnect
            return replaced
        }
    }

    func unregister(_ id: UUID) {
        _ = sessions.withLock { $0.removeValue(forKey: id) }
    }

    var count: Int { sessions.withLock { $0.count } }

    func disconnectAll() {
        let handlers = sessions.withLock { sessions in
            defer { sessions.removeAll() }
            return Array(sessions.values)
        }
        handlers.forEach { $0() }
    }
}
