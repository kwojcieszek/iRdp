/// Session color depth offered to clients.
public enum ColorDepth: Int, Codable, CaseIterable, Sendable, Identifiable {
    case bits16 = 16
    case bits24 = 24
    case bits32 = 32

    public var id: Int { rawValue }

    public var displayName: String { "\(rawValue)-bit" }
}
