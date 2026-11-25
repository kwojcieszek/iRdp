/// Turns screen frames into ready-to-send wire packets.
protocol FrameEncoding: AnyObject {
    var lastFrame: ScreenFrame? { get }
    /// Whether sent frames are acknowledged by the client (graphics pipeline frame acknowledgements).
    var usesFrameAcknowledgements: Bool { get }
    /// Frames the encoder would like to re-send while the screen is still, to sharpen lossy images.
    var refinementFrameCount: Int { get }
    func encode(_ frame: ScreenFrame, forceFullUpdate: Bool) -> [[UInt8]]
}
