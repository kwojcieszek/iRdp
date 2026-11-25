import Foundation

/// Snapshot the service publishes for the menu bar app.
public struct ServiceStatus: Codable, Equatable, Sendable {
    public var state: ServiceState
    public var port: Int?
    public var processIdentifier: Int32
    public var sessions: [SessionStatus]
    public var lastError: String?
    public var screenRecordingGranted: Bool
    public var accessibilityGranted: Bool
    public var certificateFingerprint: String?
    public var updatedAt: Date

    public init(state: ServiceState, port: Int? = nil, processIdentifier: Int32, sessions: [SessionStatus] = [], lastError: String? = nil, screenRecordingGranted: Bool = false, accessibilityGranted: Bool = false, certificateFingerprint: String? = nil, updatedAt: Date = Date()) {
        self.state = state
        self.port = port
        self.processIdentifier = processIdentifier
        self.sessions = sessions
        self.lastError = lastError
        self.screenRecordingGranted = screenRecordingGranted
        self.accessibilityGranted = accessibilityGranted
        self.certificateFingerprint = certificateFingerprint
        self.updatedAt = updatedAt
    }

    /// The service refreshes its status every few seconds; older snapshots mean it is not running.
    public func isFresh(now: Date = Date(), tolerance: TimeInterval = 10) -> Bool {
        now.timeIntervalSince(updatedAt) <= tolerance
    }
}
