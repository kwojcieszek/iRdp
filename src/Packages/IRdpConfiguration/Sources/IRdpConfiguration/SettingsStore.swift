import Foundation

/// Persists `ServerSettings` in the shared settings file.
public struct SettingsStore: Sendable {
    private let file: JsonFileStore<ServerSettings>

    public init(paths: ApplicationPaths = .standard) {
        file = JsonFileStore(url: paths.settingsURL)
    }

    /// Returns stored settings, or defaults when the file is missing or unreadable.
    public func load() -> ServerSettings {
        (try? file.load()) ?? ServerSettings()
    }

    public func save(_ settings: ServerSettings) throws {
        try file.save(settings)
    }

    public var modificationDate: Date? { file.modificationDate }
}
