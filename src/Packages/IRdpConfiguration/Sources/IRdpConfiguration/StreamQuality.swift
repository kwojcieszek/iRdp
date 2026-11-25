/// Image quality of the remote session, a trade-off between sharpness, smoothness and network usage.
public enum StreamQuality: String, Codable, CaseIterable, Sendable, Identifiable {
    case low
    case good
    case high

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .good: "Good"
        case .high: "High"
        }
    }

    public var summary: String {
        switch self {
        case .low: "Slow networks: 5 Mbit/s, 20 fps, 16-bit colors without H.264."
        case .good: "Sharp text: 15 Mbit/s, 30 fps, still images sharpened losslessly."
        case .high: "Fast networks: 40 Mbit/s, 60 fps, still images sharpened losslessly."
        }
    }

    /// H.264 bit rate.
    public var videoBitRate: Int {
        switch self {
        case .low: 5_000_000
        case .good: 15_000_000
        case .high: 40_000_000
        }
    }

    public var framesPerSecond: Int {
        switch self {
        case .low: 20
        case .good: 30
        case .high: 60
        }
    }

    /// Color depth of bitmap updates for clients without the graphics pipeline.
    public var bitsPerPixel: Int {
        self == .low ? 16 : 32
    }

    /// Whether still images are re-sent losslessly after motion stops, which keeps text sharp.
    public var sharpensStillImages: Bool {
        self != .low
    }
}
