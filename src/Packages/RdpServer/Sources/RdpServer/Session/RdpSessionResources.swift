/// Screen and input resources shared with one remote session.
public struct RdpSessionResources: Sendable {
    public var frameSource: any FrameSource
    public var inputSink: (any InputSink)?

    public init(frameSource: any FrameSource, inputSink: (any InputSink)?) {
        self.frameSource = frameSource
        self.inputSink = inputSink
    }
}
