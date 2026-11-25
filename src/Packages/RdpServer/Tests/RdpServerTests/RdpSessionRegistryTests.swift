import Foundation
import Synchronization
import Testing
@testable import RdpServer

/// Thread-safe list of strings for test callbacks.
final class EventLog: Sendable {
    private let items = Mutex<[String]>([])
    func append(_ item: String) { items.withLock { $0.append(item) } }
    var entries: [String] { items.withLock { $0 } }
}

struct RdpSessionRegistryTests {
    private func handle(_ log: EventLog, _ name: String) -> RdpSessionHandle {
        RdpSessionHandle(disconnect: { log.append("disconnect \(name)") }, applyQuality: { quality in log.append("quality \(name) \(quality.framesPerSecond)") })
    }

    @Test func newSessionReplacesOldestWhenFull() {
        let registry = RdpSessionRegistry()
        let log = EventLog()
        #expect(registry.register(UUID(), maximumSessions: 1, handle: handle(log, "first")).isEmpty)
        registry.register(UUID(), maximumSessions: 1, handle: handle(log, "second")).forEach { $0.disconnect() }
        #expect(log.entries == ["disconnect first"])
        #expect(registry.count == 1)
    }

    @Test func allowsSeveralSessionsAndForwardsQuality() {
        let registry = RdpSessionRegistry()
        let log = EventLog()
        _ = registry.register(UUID(), maximumSessions: 2, handle: handle(log, "a"))
        #expect(registry.register(UUID(), maximumSessions: 2, handle: handle(log, "b")).isEmpty)
        registry.applyQuality(StreamingQuality(framesPerSecond: 60))
        #expect(Set(log.entries) == ["quality a 60", "quality b 60"])
    }

    @Test func unregisterAndDisconnectAll() {
        let registry = RdpSessionRegistry()
        let log = EventLog()
        let id = UUID()
        _ = registry.register(id, maximumSessions: 3, handle: handle(log, "a"))
        _ = registry.register(UUID(), maximumSessions: 3, handle: handle(log, "b"))
        registry.unregister(id)
        registry.disconnectAll()
        #expect(log.entries == ["disconnect b"])
        #expect(registry.count == 0)
    }
}
