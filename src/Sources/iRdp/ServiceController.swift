import Foundation
import ServiceManagement

/// Starts and stops iRdpService, as a LaunchAgent when the app is bundled, otherwise as a child process.
@MainActor
final class ServiceController {
    static let launchAgentPlistName = "com.kwojcieszek.irdp.service.plist"

    private var childProcess: Process?

    private var launchAgent: SMAppService? {
        let plist = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchAgents/\(Self.launchAgentPlistName)")
        guard FileManager.default.fileExists(atPath: plist.path) else { return nil }
        return SMAppService.agent(plistName: Self.launchAgentPlistName)
    }

    var usesLaunchAgent: Bool { launchAgent != nil }

    /// Whether the service is registered to run (LaunchAgent) or the child process is alive.
    var isEnabled: Bool {
        if let launchAgent { return launchAgent.status == .enabled }
        return childProcess?.isRunning == true
    }

    var requiresApproval: Bool { launchAgent?.status == .requiresApproval }

    func start() throws {
        if let launchAgent {
            if launchAgent.status == .enabled { try? launchAgent.unregister() }
            try launchAgent.register()
            return
        }
        guard childProcess?.isRunning != true else { return }
        let executable = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("iRdpService")
        guard let executable, FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "iRdpService was not found next to the app."])
        }
        let process = Process()
        process.executableURL = executable
        try process.run()
        childProcess = process
    }

    func stop() throws {
        if let launchAgent {
            try launchAgent.unregister()
            return
        }
        childProcess?.terminate()
        childProcess = nil
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
