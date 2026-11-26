/// Result of preparing a session while the client authenticates.
enum SessionResourcesOutcome: Sendable {
    /// Screen capture and input are ready (credentials were valid, or the legacy eager mode is used).
    case ready(RdpSessionResources)
    case failed(any Error)
    /// Nothing that can see the screen was created; only the logon screen of this size is shown.
    case deferred(DesktopSize)
}
