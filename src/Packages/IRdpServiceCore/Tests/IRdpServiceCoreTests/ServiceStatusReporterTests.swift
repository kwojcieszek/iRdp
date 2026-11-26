import Foundation
import IRdpConfiguration
import RdpServer
import Testing
@testable import IRdpServiceCore

struct ServiceStatusReporterTests {
    @Test func publishesSessionsToStatusFile() throws {
        let paths = ApplicationPaths(baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
        defer { try? FileManager.default.removeItem(at: paths.baseDirectory) }
        let store = StatusStore(paths: paths)
        let reporter = ServiceStatusReporter(store: store)
        let info = RdpSessionInfo(id: UUID(), remoteAddress: "192.168.1.5", clientName: "LAPTOP", userName: "kamil", desktopSize: DesktopSize(width: 1920, height: 1080), bitsPerPixel: 32, startedAt: Date())
        reporter.update { $0.state = .listening }
        reporter.sessionDidStart(info)
        #expect(store.load()?.sessions.map(\.clientName) == ["LAPTOP"])
        #expect(store.load()?.state == .listening)
        reporter.sessionDidEnd(info.id)
        #expect(store.load()?.sessions.isEmpty == true)
        reporter.connectionDidFail(remoteAddress: "10.0.0.1", reason: "authentication failed")
        #expect(store.load()?.lastError == "10.0.0.1: authentication failed")
    }
}

struct ServiceRuntimeQualityTests {
    @Test func detectsQualityOnlyChanges() {
        let base = ServerSettings()
        var quality = base
        quality.sharedResources.quality = .high
        var port = quality
        port.port = 4000
        #expect(ServiceRuntime.differOnlyInQuality(base, quality))
        #expect(!ServiceRuntime.differOnlyInQuality(base, port))
        #expect(!ServiceRuntime.differOnlyInQuality(base, base))
    }

    @Test func mapsQualityLevels() {
        let high = ServiceRuntime.streamingQuality(for: .high)
        #expect(high.videoBitRate == 40_000_000 && high.framesPerSecond == 60 && high.sharpensStillImages)
        let low = ServiceRuntime.streamingQuality(for: .low)
        #expect(low.bitsPerPixel == 16 && !low.sharpensStillImages)
    }
}

struct NetworkPasswordHashTests {
    @Test func returnsHashOnlyForAllowedAccounts() {
        var settings = ServerSettings(loginMode: .macOSAccount, restrictToCurrentUser: true)
        settings.networkPasswordHashes = ["kamil": "AAECAw==", "other": "BAUGBw=="]
        #expect(ServiceRuntime.networkPasswordHash(for: "Kamil", settings: settings, currentUserName: "kamil") == [0, 1, 2, 3])
        #expect(ServiceRuntime.networkPasswordHash(for: "other", settings: settings, currentUserName: "kamil") == nil)
        settings.loginMode = .none
        #expect(ServiceRuntime.networkPasswordHash(for: "kamil", settings: settings, currentUserName: "kamil") == nil)
        settings.loginMode = .applicationPassword
        settings.applicationUserName = "irdp"
        settings.networkPasswordHashes = ["irdp": "AAECAw=="]
        #expect(ServiceRuntime.networkPasswordHash(for: "IRDP", settings: settings, currentUserName: "kamil") == [0, 1, 2, 3])
    }
}
