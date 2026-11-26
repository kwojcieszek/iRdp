import Foundation
import ServiceManagement

/// Starts and stops iRdpService, as a LaunchAgent when the app is bundled, otherwise as a child process.
@MainActor
final class ServiceController {
    static let launchAgentPlistName = "com.irdp.service.plist"

    private var childProcess: Process?

    /// The LaunchAgent is used only by an installed copy (in an Applications folder), so that a development build
    /// from Xcode never registers a second agent with the same label; development builds run the service as a child process.
    private var launchAgent: SMAppService? {
        let plist = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchAgents/\(Self.launchAgentPlistName)")
        guard FileManager.default.fileExists(atPath: plist.path), Self.isInstalled(Bundle.main.bundleURL) else { return nil }
        return SMAppService.agent(plistName: Self.launchAgentPlistName)
    }

    static func isInstalled(_ bundleURL: URL) -> Bool {
        let path = bundleURL.standardizedFileURL.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
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

    /// Stops the service (if running) and starts it again, e.g. to pick up new permissions.
    func restart() throws {
        if let launchAgent {
            if launchAgent.status == .enabled { try launchAgent.unregister() }
        } else if let childProcess, childProcess.isRunning {
            childProcess.terminate()
            childProcess.waitUntilExit()
            self.childProcess = nil
        }
        // Give launchd a moment to tear the old job down before registering it again.
        Thread.sleep(forTimeInterval: 0.5)
        try start()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
