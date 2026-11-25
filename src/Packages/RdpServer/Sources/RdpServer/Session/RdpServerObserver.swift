import Foundation

/// Gets notified about session lifecycle events.
public protocol RdpServerObserver: Sendable {
    func sessionDidStart(_ session: RdpSessionInfo)
    func sessionDidEnd(_ sessionId: UUID)
    func connectionDidFail(remoteAddress: String, reason: String)
}
