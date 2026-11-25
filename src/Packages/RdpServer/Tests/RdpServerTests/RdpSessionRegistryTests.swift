import Foundation
import Synchronization
import Testing
@testable import RdpServer

struct RdpSessionRegistryTests {
    @Test func newSessionReplacesOldestWhenFull() {
        let registry = RdpSessionRegistry()
        let disconnected = Mutex<[String]>([])
        let first = UUID()
        #expect(registry.register(first, maximumSessions: 1) { disconnected.withLock { $0.append("first") } }.isEmpty)
        let replaced = registry.register(UUID(), maximumSessions: 1) { disconnected.withLock { $0.append("second") } }
        replaced.forEach { $0() }
        #expect(disconnected.withLock { $0 } == ["first"])
        #expect(registry.count == 1)
    }

    @Test func allowsSeveralSessionsWhenConfigured() {
        let registry = RdpSessionRegistry()
        _ = registry.register(UUID(), maximumSessions: 2) {}
        #expect(registry.register(UUID(), maximumSessions: 2) {}.isEmpty)
        #expect(registry.count == 2)
    }

    @Test func unregisterAndDisconnectAll() {
        let registry = RdpSessionRegistry()
        let id = UUID()
        let calls = Mutex(0)
        _ = registry.register(id, maximumSessions: 3) { calls.withLock { $0 += 1 } }
        _ = registry.register(UUID(), maximumSessions: 3) { calls.withLock { $0 += 1 } }
        registry.unregister(id)
        registry.disconnectAll()
        #expect(calls.withLock { $0 } == 1)
        #expect(registry.count == 0)
    }
}
