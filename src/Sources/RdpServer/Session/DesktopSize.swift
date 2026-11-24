/// Size of the remote desktop in pixels.
public struct DesktopSize: Sendable, Equatable, Hashable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}
