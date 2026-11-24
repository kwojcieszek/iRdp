/// Lifecycle state reported by the service.
public enum ServiceState: String, Codable, Sendable {
    case starting
    case listening
    case stopped
    case failed
}
