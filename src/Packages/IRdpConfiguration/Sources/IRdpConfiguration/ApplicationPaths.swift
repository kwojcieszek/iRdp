import Foundation

/// File locations shared by the app and the service.
public struct ApplicationPaths: Sendable {
    public static let environmentOverrideKey = "IRDP_HOME"

    public let baseDirectory: URL

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    /// `~/Library/Application Support/iRdp`, or `$IRDP_HOME` when set.
    public static var standard: ApplicationPaths {
        if let override = ProcessInfo.processInfo.environment[environmentOverrideKey], !override.isEmpty {
            return ApplicationPaths(baseDirectory: URL(fileURLWithPath: override, isDirectory: true))
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return ApplicationPaths(baseDirectory: support.appendingPathComponent("iRdp", isDirectory: true))
    }

    public var settingsURL: URL { baseDirectory.appendingPathComponent("settings.json") }
    public var statusURL: URL { baseDirectory.appendingPathComponent("status.json") }
    public var certificateDirectory: URL { baseDirectory.appendingPathComponent("Certificates", isDirectory: true) }
}
