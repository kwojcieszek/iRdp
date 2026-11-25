import Foundation

/// Describes an authenticated remote session.
public struct RdpSessionInfo: Sendable, Equatable {
    public var id: UUID
    public var remoteAddress: String
    public var clientName: String
    public var userName: String
    public var desktopSize: DesktopSize
    public var bitsPerPixel: Int
    public var startedAt: Date

    public init(id: UUID, remoteAddress: String, clientName: String, userName: String, desktopSize: DesktopSize, bitsPerPixel: Int, startedAt: Date) {
        self.id = id
        self.remoteAddress = remoteAddress
        self.clientName = clientName
        self.userName = userName
        self.desktopSize = desktopSize
        self.bitsPerPixel = bitsPerPixel
        self.startedAt = startedAt
    }
}
