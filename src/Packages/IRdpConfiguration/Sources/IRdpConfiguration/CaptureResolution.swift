/// Resolution of the shared desktop relative to the display.
public enum CaptureResolution: String, Codable, CaseIterable, Sendable, Identifiable {
    /// One remote pixel per display point (logical resolution).
    case points
    /// One remote pixel per physical display pixel (Retina resolution).
    case native
    /// Half of the logical resolution, for slow networks.
    case half

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .points: "Logical resolution (points)"
        case .native: "Native resolution (pixels)"
        case .half: "Half resolution"
        }
    }
}
