/// What the registry can do with a running session.
struct RdpSessionHandle: Sendable {
    var disconnect: @Sendable () -> Void
    var applyQuality: @Sendable (StreamingQuality) -> Void
}
