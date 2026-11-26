import Foundation
import Testing
@testable import IRdpConfiguration

struct StoreTests {
    private func temporaryPaths() -> ApplicationPaths {
        ApplicationPaths(baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    @Test func settingsStoreReturnsDefaultsWhenEmptyAndPersistsChanges() throws {
        let paths = temporaryPaths()
        defer { try? FileManager.default.removeItem(at: paths.baseDirectory) }
        let store = SettingsStore(paths: paths)
        #expect(store.load() == ServerSettings())
        #expect(store.modificationDate == nil)
        try store.save(ServerSettings(port: 3390))
        #expect(store.load().port == 3390)
        let permissions = try FileManager.default.attributesOfItem(atPath: paths.settingsURL.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }

    @Test func statusStoreRoundTrips() throws {
        let paths = temporaryPaths()
        defer { try? FileManager.default.removeItem(at: paths.baseDirectory) }
        let store = StatusStore(paths: paths)
        #expect(store.load() == nil)
        let session = SessionStatus(id: UUID(), remoteAddress: "10.0.0.2", clientName: "PC", userName: "kamil", width: 1280, height: 800, startedAt: Date(timeIntervalSince1970: 1_000_000))
        let status = ServiceStatus(state: .listening, port: 3389, processIdentifier: 42, sessions: [session], updatedAt: Date(timeIntervalSince1970: 1_000_000))
        try store.save(status)
        #expect(store.load() == status)
    }

    @Test func statusFreshnessDependsOnAge() {
        let status = ServiceStatus(state: .listening, processIdentifier: 1, updatedAt: Date(timeIntervalSince1970: 100))
        #expect(status.isFresh(now: Date(timeIntervalSince1970: 105)))
        #expect(!status.isFresh(now: Date(timeIntervalSince1970: 200)))
    }

    @Test func pathsAreDerivedFromBaseDirectory() {
        let paths = ApplicationPaths(baseDirectory: URL(fileURLWithPath: "/tmp/irdp"))
        #expect(paths.settingsURL.path == "/tmp/irdp/settings.json")
        #expect(paths.statusURL.path == "/tmp/irdp/status.json")
        #expect(paths.certificateDirectory.path == "/tmp/irdp/Certificates")
    }
}
