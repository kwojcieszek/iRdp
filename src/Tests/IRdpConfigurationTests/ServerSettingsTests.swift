import Foundation
import Testing
@testable import IRdpConfiguration

struct ServerSettingsTests {
    @Test func decodesMissingKeysWithDefaults() throws {
        let json = Data(#"{"port": 4000, "sharedResources": {"shareMouse": false}}"#.utf8)
        let settings = try JSONDecoder().decode(ServerSettings.self, from: json)
        #expect(settings.port == 4000)
        #expect(settings.loginMode == .macOSAccount)
        #expect(settings.sharedResources.shareMouse == false)
        #expect(settings.sharedResources.shareKeyboard == true)
        #expect(settings.sharedResources.colorDepth == .bits32)
    }

    @Test func roundTripsThroughJson() throws {
        var settings = ServerSettings(port: 5000, loginMode: .applicationPassword)
        settings.sharedResources = SharedResources(displayID: 7, shareKeyboard: false, resolution: .native, colorDepth: .bits16, framesPerSecond: 30, swapControlAndCommand: true)
        let decoded = try JSONDecoder().decode(ServerSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func reportsValidationIssues() {
        #expect(ServerSettings().validationIssues.isEmpty)
        #expect(ServerSettings(port: 0).validationIssues.count == 1)
        let missingPassword = ServerSettings(loginMode: .applicationPassword)
        #expect(missingPassword.validationIssues == ["Password is not set."])
    }
}
