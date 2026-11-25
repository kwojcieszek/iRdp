import CoreGraphics

/// A display that can be shared.
public struct DisplayInfo: Sendable, Equatable, Identifiable, Hashable {
    public var id: UInt32
    public var name: String
    /// Frame in global display coordinates (points).
    public var bounds: CGRect
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var isMain: Bool

    public init(id: UInt32, name: String, bounds: CGRect, pixelWidth: Int, pixelHeight: Int, isMain: Bool) {
        self.id = id
        self.name = name
        self.bounds = bounds
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.isMain = isMain
    }
}
