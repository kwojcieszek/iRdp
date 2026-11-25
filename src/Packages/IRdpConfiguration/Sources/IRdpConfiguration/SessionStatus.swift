import Foundation

/// A connected client as reported by the service.
public struct SessionStatus: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var remoteAddress: String
    public var clientName: String
    public var userName: String
    public var width: Int
    public var height: Int
    public var startedAt: Date

    public init(id: UUID, remoteAddress: String, clientName: String, userName: String, width: Int, height: Int, startedAt: Date) {
        self.id = id
        self.remoteAddress = remoteAddress
        self.clientName = clientName
        self.userName = userName
        self.width = width
        self.height = height
        self.startedAt = startedAt
    }
}
