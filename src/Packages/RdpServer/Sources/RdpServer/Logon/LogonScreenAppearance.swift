import CoreGraphics

/// What the logon screen shows: the wallpaper (blurred by the renderer) and the suggested account.
public struct LogonScreenAppearance: @unchecked Sendable {
    /// Desktop wallpaper of the shared Mac; `nil` uses a gradient.
    public var wallpaper: CGImage?
    /// Short user name filled in by default (e.g. the logged-in macOS user).
    public var defaultUserName: String?
    /// Name shown under the avatar.
    public var displayName: String?
    /// Account picture; `nil` draws the initials.
    public var avatar: CGImage?
    /// Computer name shown next to the iRdp mark at the bottom of the screen.
    public var serverName: String?

    public init(wallpaper: CGImage? = nil, defaultUserName: String? = nil, displayName: String? = nil, avatar: CGImage? = nil, serverName: String? = nil) {
        self.wallpaper = wallpaper
        self.defaultUserName = defaultUserName
        self.displayName = displayName
        self.avatar = avatar
        self.serverName = serverName
    }
}
