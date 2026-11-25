/// How clients prove who they are before a session starts.
public enum LoginMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Anyone who can reach the port gets a session.
    case none
    /// A user name and password defined in iRdp settings.
    case applicationPassword
    /// A local macOS account verified by Open Directory.
    case macOSAccount

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: "No authentication"
        case .applicationPassword: "iRdp user name and password"
        case .macOSAccount: "macOS user account"
        }
    }
}
