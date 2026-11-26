import CoreGraphics

/// What the logon screen shows. It is generic on purpose: nothing taken from the Mac's screen, no account picture.
public struct LogonScreenAppearance: @unchecked Sendable {
    /// Background picture (blurred by the renderer); `nil` draws a generic abstract background.
    public var wallpaper: CGImage?
    /// User name filled in when the client did not send one.
    public var defaultUserName: String?
    /// Computer name shown in the card and next to the iRdp mark.
    public var serverName: String?

    public init(wallpaper: CGImage? = nil, defaultUserName: String? = nil, serverName: String? = nil) {
        self.wallpaper = wallpaper
        self.defaultUserName = defaultUserName
        self.serverName = serverName
    }
}
