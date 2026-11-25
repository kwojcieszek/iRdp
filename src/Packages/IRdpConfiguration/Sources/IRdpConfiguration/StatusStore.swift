import Foundation

/// Persists `ServiceStatus` in the shared status file.
public struct StatusStore: Sendable {
    private let file: JsonFileStore<ServiceStatus>

    public init(paths: ApplicationPaths = .standard) {
        file = JsonFileStore(url: paths.statusURL)
    }

    public func load() -> ServiceStatus? {
        try? file.load()
    }

    public func save(_ status: ServiceStatus) throws {
        try file.save(status)
    }
}
