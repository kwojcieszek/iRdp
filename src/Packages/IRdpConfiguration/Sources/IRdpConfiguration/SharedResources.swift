/// What a remote session is allowed to see and control, and in which quality.
public struct SharedResources: Codable, Equatable, Sendable {
    /// Display to share; `nil` shares the main display.
    public var displayID: UInt32?
    public var shareKeyboard: Bool
    public var shareMouse: Bool
    public var resolution: CaptureResolution
    public var quality: StreamQuality
    /// Maps the Windows Control key to Command and the Windows key to Control.
    public var swapControlAndCommand: Bool
    /// Hardware H.264 video encoding for clients that support it (much less data, lowest latency).
    public var usesVideoEncoding: Bool

    public init(displayID: UInt32? = nil, shareKeyboard: Bool = true, shareMouse: Bool = true, resolution: CaptureResolution = .points, quality: StreamQuality = .good, swapControlAndCommand: Bool = false, usesVideoEncoding: Bool = true) {
        self.displayID = displayID
        self.shareKeyboard = shareKeyboard
        self.shareMouse = shareMouse
        self.resolution = resolution
        self.quality = quality
        self.swapControlAndCommand = swapControlAndCommand
        self.usesVideoEncoding = usesVideoEncoding
    }

    public init(from decoder: any Decoder) throws {
        let defaults = SharedResources()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayID = try container.decodeIfPresent(UInt32.self, forKey: .displayID)
        shareKeyboard = try container.decodeIfPresent(Bool.self, forKey: .shareKeyboard) ?? defaults.shareKeyboard
        shareMouse = try container.decodeIfPresent(Bool.self, forKey: .shareMouse) ?? defaults.shareMouse
        resolution = try container.decodeIfPresent(CaptureResolution.self, forKey: .resolution) ?? defaults.resolution
        quality = try container.decodeIfPresent(StreamQuality.self, forKey: .quality) ?? defaults.quality
        swapControlAndCommand = try container.decodeIfPresent(Bool.self, forKey: .swapControlAndCommand) ?? defaults.swapControlAndCommand
        usesVideoEncoding = try container.decodeIfPresent(Bool.self, forKey: .usesVideoEncoding) ?? defaults.usesVideoEncoding
    }

    /// Settings that require restarting the server; quality changes apply to running sessions.
    public func ignoringQuality() -> SharedResources {
        var copy = self
        copy.quality = .good
        return copy
    }
}
