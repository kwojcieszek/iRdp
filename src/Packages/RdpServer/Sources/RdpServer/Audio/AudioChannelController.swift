import RdpProtocol

/// Drives the "rdpsnd" static channel: format negotiation, training and sending the server's sound in blocks
/// with flow control based on the client's wave confirmations (MS-RDPEA 3.3.5).
struct AudioChannelController {
    static let staticChannelName = "rdpsnd"
    /// PCM formats offered to the client, most preferred first.
    static let offeredFormats: [AudioFormat] = [
        .pcm(samplesPerSecond: 48000, channels: 2),
        .pcm(samplesPerSecond: 44100, channels: 2),
        .pcm(samplesPerSecond: 22050, channels: 2),
        .pcm(samplesPerSecond: 22050, channels: 1),
    ]
    /// Duration of one audio block sent to the client.
    static let blockMilliseconds = 20
    /// Audio sent but not yet confirmed by the client; newer audio is dropped beyond this to keep latency low.
    static let maximumUnconfirmedMilliseconds = 400
    /// A block not confirmed within this time is considered lost.
    static let confirmationTimeoutMilliseconds: UInt64 = 2000

    enum State: Equatable {
        case idle
        case awaitingClientFormats
        case awaitingTrainingConfirm
        case streaming
        /// The client cannot play any offered format, or turned audio off.
        case unavailable
    }

    enum Event: Equatable {
        /// Send this message on the rdpsnd static channel.
        case send([UInt8])
        case startStreaming(AudioStreamFormat)
        case stopStreaming
    }

    private(set) var state: State = .idle
    private(set) var format: AudioStreamFormat?
    private(set) var droppedBlocks = 0
    private var formatIndex: UInt16 = 0
    private var reassembler = StaticChannelReassembler()
    private var pending: [UInt8] = []
    private var nextBlockNumber: UInt8 = 0
    private var unconfirmed: [(block: UInt8, bytes: Int, sentAt: UInt64)] = []

    /// Sends the server's formats; the client answers with the ones it can play.
    mutating func start() -> [Event] {
        state = .awaitingClientFormats
        return [.send(AudioOutputPdu.formats(flags: 0, version: AudioOutputPdu.serverVersion, formats: Self.offeredFormats).encode())]
    }

    /// Handles one static channel chunk received from the client.
    mutating func receive(chunk: [UInt8], now: UInt64) throws -> [Event] {
        guard let message = try reassembler.append(chunk) else { return [] }
        switch try AudioOutputPdu.parse(message) {
        case .formats(_, _, let clientFormats):
            guard state == .awaitingClientFormats else { return [] }
            guard let (index, chosen) = Self.choose(from: clientFormats) else {
                state = .unavailable
                return []
            }
            formatIndex = UInt16(index)
            format = AudioStreamFormat(sampleRate: Int(chosen.samplesPerSecond), channels: Int(chosen.channels))
            state = .awaitingTrainingConfirm
            return [.send(AudioOutputPdu.training(timestamp: Self.timestamp(now), packSize: 0).encode())]
        case .training:
            guard state == .awaitingTrainingConfirm, let format else { return [] }
            state = .streaming
            return [.startStreaming(format)]
        case .waveConfirm(_, let blockNumber):
            if let index = unconfirmed.firstIndex(where: { $0.block == blockNumber }) {
                unconfirmed.removeSubrange(0...index)
            }
            return []
        case .close:
            guard state == .streaming else { return [] }
            state = .unavailable
            return [.stopStreaming]
        case .qualityMode, .other:
            return []
        }
    }

    /// Splits captured samples into blocks and returns the channel messages to send (Wave Info and Wave PDUs).
    mutating func messages(forSamples samples: [UInt8], now: UInt64) -> [[UInt8]] {
        guard state == .streaming, let format else { return [] }
        pending.append(contentsOf: samples)
        let blockLength = format.bytesPerSecond * Self.blockMilliseconds / 1000 / format.bytesPerFrame * format.bytesPerFrame
        let limit = format.bytesPerSecond * Self.maximumUnconfirmedMilliseconds / 1000
        unconfirmed.removeAll { now &- $0.sentAt > Self.confirmationTimeoutMilliseconds }
        var result: [[UInt8]] = []
        var offset = 0
        while pending.count - offset >= blockLength {
            let block = Array(pending[offset..<offset + blockLength])
            offset += blockLength
            guard unconfirmed.reduce(0, { $0 + $1.bytes }) + blockLength <= limit else {
                droppedBlocks += 1
                continue
            }
            let wave = AudioOutputPdu.wave(timestamp: Self.timestamp(now), formatIndex: formatIndex, blockNumber: nextBlockNumber, data: block)
            unconfirmed.append((nextBlockNumber, blockLength, now))
            nextBlockNumber &+= 1
            result.append(wave.info)
            result.append(wave.wave)
        }
        pending.removeFirst(offset)
        return result
    }

    /// Picks the most preferred offered PCM format the client can play; returns its index in the client's list.
    static func choose(from clientFormats: [AudioFormat]) -> (Int, AudioFormat)? {
        for offered in offeredFormats {
            if let index = clientFormats.firstIndex(where: {
                $0.isPcm && $0.channels == offered.channels && $0.samplesPerSecond == offered.samplesPerSecond && $0.bitsPerSample == offered.bitsPerSample
            }) {
                return (index, clientFormats[index])
            }
        }
        return nil
    }

    static func timestamp(_ milliseconds: UInt64) -> UInt16 {
        UInt16(truncatingIfNeeded: milliseconds)
    }
}
