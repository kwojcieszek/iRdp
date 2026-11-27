/// Format of the samples an audio source delivers: interleaved signed 16-bit little endian PCM.
public struct AudioStreamFormat: Sendable, Equatable {
    public var sampleRate: Int
    public var channels: Int

    public init(sampleRate: Int, channels: Int) {
        self.sampleRate = sampleRate
        self.channels = channels
    }

    public var bytesPerFrame: Int { channels * 2 }
    public var bytesPerSecond: Int { sampleRate * bytesPerFrame }
}

/// Produces the sound played on the server, sent to the client over the audio output channel.
public protocol AudioSource: Sendable {
    /// Starts delivering PCM samples in `format`. Samples may be delivered on any thread.
    func start(format: AudioStreamFormat, onSamples: @escaping @Sendable ([UInt8]) -> Void) async throws
    func stop() async
}
