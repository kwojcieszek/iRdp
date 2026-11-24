/// What a remote session is allowed to see and control.
public struct SharedResources: Codable, Equatable, Sendable {
    /// Display to share; `nil` shares the main display.
    public var displayID: UInt32?
    public var shareKeyboard: Bool
    public var shareMouse: Bool
    public var resolution: CaptureResolution
    public var colorDepth: ColorDepth
    public var framesPerSecond: Int
    /// Maps the Windows Control key to Command and the Windows key to Control.
    public var swapControlAndCommand: Bool

    public init(displayID: UInt32? = nil, shareKeyboard: Bool = true, shareMouse: Bool = true, resolution: CaptureResolution = .points, colorDepth: ColorDepth = .bits32, framesPerSecond: Int = 20, swapControlAndCommand: Bool = false) {
        self.displayID = displayID
        self.shareKeyboard = shareKeyboard
        self.shareMouse = shareMouse
        self.resolution = resolution
        self.colorDepth = colorDepth
        self.framesPerSecond = framesPerSecond
        self.swapControlAndCommand = swapControlAndCommand
    }

    public init(from decoder: any Decoder) throws {
        let defaults = SharedResources()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayID = try container.decodeIfPresent(UInt32.self, forKey: .displayID)
        shareKeyboard = try container.decodeIfPresent(Bool.self, forKey: .shareKeyboard) ?? defaults.shareKeyboard
        shareMouse = try container.decodeIfPresent(Bool.self, forKey: .shareMouse) ?? defaults.shareMouse
        resolution = try container.decodeIfPresent(CaptureResolution.self, forKey: .resolution) ?? defaults.resolution
        colorDepth = try container.decodeIfPresent(ColorDepth.self, forKey: .colorDepth) ?? defaults.colorDepth
        framesPerSecond = try container.decodeIfPresent(Int.self, forKey: .framesPerSecond) ?? defaults.framesPerSecond
        swapControlAndCommand = try container.decodeIfPresent(Bool.self, forKey: .swapControlAndCommand) ?? defaults.swapControlAndCommand
    }
}
