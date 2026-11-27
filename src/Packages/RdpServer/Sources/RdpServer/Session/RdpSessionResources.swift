/// Screen, input and sound resources shared with one remote session.
public struct RdpSessionResources: Sendable {
    public var frameSource: any FrameSource
    public var inputSink: (any InputSink)?
    /// Sound played on the server; sent to clients that open the audio output channel.
    public var audioSource: (any AudioSource)?

    public init(frameSource: any FrameSource, inputSink: (any InputSink)?, audioSource: (any AudioSource)? = nil) {
        self.frameSource = frameSource
        self.inputSink = inputSink
        self.audioSource = audioSource
    }
}
