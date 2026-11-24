/// Produces screen frames for a remote session.
public protocol FrameSource: Sendable {
    /// Size of the frames this source produces; announced to the client before capture starts.
    var desktopSize: DesktopSize { get }
    /// Starts delivering frames. Frames may be delivered on any thread.
    func start(onFrame: @escaping @Sendable (ScreenFrame) -> Void) async throws
    func stop() async
}
