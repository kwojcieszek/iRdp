/// A captured screen image in 32-bit BGRA format, rows ordered top to bottom.
public struct ScreenFrame: Sendable {
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let pixels: [UInt8]

    public init(width: Int, height: Int, bytesPerRow: Int, pixels: [UInt8]) {
        precondition(bytesPerRow >= width * 4 && pixels.count >= bytesPerRow * height, "invalid frame layout")
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.pixels = pixels
    }

    public var size: DesktopSize { DesktopSize(width: width, height: height) }
}
