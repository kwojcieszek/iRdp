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
        #expect(settings.sharedResources.quality == .good)
    }

    @Test func roundTripsThroughJson() throws {
        var settings = ServerSettings(port: 5000, loginMode: .applicationPassword)
        settings.sharedResources = SharedResources(displayID: 7, shareKeyboard: false, resolution: .native, quality: .high, swapControlAndCommand: true, usesVideoEncoding: false)
        let decoded = try JSONDecoder().decode(ServerSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func qualityLevelsScaleUp() {
        let levels = StreamQuality.allCases
        #expect(levels == [.low, .good, .high])
        #expect(zip(levels, levels.dropFirst()).allSatisfy { $0.videoBitRate < $1.videoBitRate && $0.framesPerSecond < $1.framesPerSecond })
        #expect(!StreamQuality.low.sharpensStillImages && StreamQuality.good.sharpensStillImages)
        #expect(StreamQuality.low.bitsPerPixel == 16 && StreamQuality.high.bitsPerPixel == 32)
    }

    @Test func qualityChangesDoNotRequireRestart() {
        var resources = SharedResources(quality: .low)
        let other = SharedResources(quality: .high)
        #expect(resources.ignoringQuality() == other.ignoringQuality())
        resources.shareMouse = false
        #expect(resources.ignoringQuality() != other.ignoringQuality())
    }

    @Test func reportsValidationIssues() {
        #expect(ServerSettings().validationIssues.isEmpty)
        #expect(ServerSettings(port: 0).validationIssues.count == 1)
        let missingPassword = ServerSettings(loginMode: .applicationPassword)
        #expect(missingPassword.validationIssues == ["Password is not set."])
    }
}
