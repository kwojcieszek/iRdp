/// Encoding parameters of a session; can be changed while sessions run.
public struct StreamingQuality: Sendable, Equatable {
    public var videoBitRate: Int
    public var framesPerSecond: Int
    /// Color depth of bitmap updates for clients without the graphics pipeline (applies to new connections).
    public var bitsPerPixel: Int
    /// Re-send still images losslessly after motion stops, so text is sharp.
    public var sharpensStillImages: Bool

    public init(videoBitRate: Int = 15_000_000, framesPerSecond: Int = 30, bitsPerPixel: Int = 32, sharpensStillImages: Bool = true) {
        self.videoBitRate = videoBitRate
        self.framesPerSecond = framesPerSecond
        self.bitsPerPixel = bitsPerPixel
        self.sharpensStillImages = sharpensStillImages
    }
}
