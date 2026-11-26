/// Turns screen frames into ready-to-send wire packets.
protocol FrameEncoding: AnyObject {
    var lastFrame: ScreenFrame? { get }
    /// Whether sent frames are acknowledged by the client (graphics pipeline frame acknowledgements).
    var usesFrameAcknowledgements: Bool { get }
    func encode(_ frame: ScreenFrame, forceFullUpdate: Bool) -> [[UInt8]]
    /// One step of improving a still image after motion stopped; nil when there is nothing left to improve.
    func refinement() -> [[UInt8]]?
    func apply(_ quality: StreamingQuality)
    /// Number of acknowledged frames produced by the last `encode` or `refinement` call.
    var framesInLastBatch: Int { get }
}
