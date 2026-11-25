import RdpProtocol

/// Receives keyboard and mouse input from a remote session.
public protocol InputSink: Sendable {
    func handle(_ event: RdpInputEvent)
    /// Releases keys and buttons still held when the session ends.
    func releaseAll()
}
