import RdpProtocol
import Testing
@testable import RdpServer

struct AudioChannelControllerTests {
    private func chunk(_ pdu: AudioOutputPdu) -> [UInt8] {
        StaticChannelPdu.chunks(for: pdu.encode())[0]
    }

    private func streamingController(clientFormats: [AudioFormat] = [.pcm(samplesPerSecond: 22050, channels: 2), .pcm(samplesPerSecond: 44100, channels: 2)]) throws -> AudioChannelController {
        var controller = AudioChannelController()
        _ = controller.start()
        _ = try controller.receive(chunk: chunk(.formats(flags: AudioOutputPdu.clientAlive, version: 6, formats: clientFormats)), now: 0)
        _ = try controller.receive(chunk: chunk(.training(timestamp: 0, packSize: 0)), now: 0)
        return controller
    }

    @Test func negotiatesPreferredFormatAndStartsAfterTraining() throws {
        var controller = AudioChannelController()
        guard case .send(let offer) = controller.start().first, case .formats(_, _, let offered) = try AudioOutputPdu.parse(offer) else {
            Issue.record("no formats offer"); return
        }
        #expect(offered == AudioChannelController.offeredFormats)
        let clientFormats: [AudioFormat] = [.pcm(samplesPerSecond: 22050, channels: 2), .pcm(samplesPerSecond: 44100, channels: 2)]
        let training = try controller.receive(chunk: chunk(.formats(flags: AudioOutputPdu.clientAlive, version: 6, formats: clientFormats)), now: 5)
        #expect(training == [.send(AudioOutputPdu.training(timestamp: 5, packSize: 0).encode())])
        #expect(controller.state == .awaitingTrainingConfirm)
        let start = try controller.receive(chunk: chunk(.training(timestamp: 5, packSize: 0)), now: 9)
        #expect(start == [.startStreaming(AudioStreamFormat(sampleRate: 44100, channels: 2))])
        #expect(controller.state == .streaming)

        // 44.1 kHz stereo: 20 ms blocks of 3528 bytes, referring to the client's format number 1.
        let messages = controller.messages(forSamples: [UInt8](repeating: 1, count: 4000), now: 20)
        #expect(messages.count == 2)
        var reader = ByteReader(messages[0])
        #expect(try reader.readUInt8() == AudioOutputPdu.MessageType.wave.rawValue)
        try reader.skip(1)
        #expect(try reader.readUInt16LE() == 8 + 3528)
        #expect(try reader.readUInt16LE() == 20)
        #expect(try reader.readUInt16LE() == 1)
        #expect(messages[1].count == 3528)
        // The remaining 472 bytes wait for the next samples.
        #expect(controller.messages(forSamples: [UInt8](repeating: 1, count: 3056), now: 40).count == 2)
    }

    @Test func clientWithoutCommonFormatGetsNoAudio() throws {
        var controller = AudioChannelController()
        _ = controller.start()
        let events = try controller.receive(chunk: chunk(.formats(flags: 0, version: 6, formats: [])), now: 0)
        #expect(events.isEmpty)
        #expect(controller.state == .unavailable)
        #expect(controller.messages(forSamples: [UInt8](repeating: 0, count: 10000), now: 0).isEmpty)
    }

    @Test func dropsAudioWhileTooMuchIsUnconfirmed() throws {
        var controller = try streamingController(clientFormats: [.pcm(samplesPerSecond: 48000, channels: 2)])
        let block = 48000 * 4 / 50
        let maximumBlocks = AudioChannelController.maximumUnconfirmedMilliseconds / AudioChannelController.blockMilliseconds
        let sent = controller.messages(forSamples: [UInt8](repeating: 0, count: block * (maximumBlocks + 5)), now: 0)
        #expect(sent.count == maximumBlocks * 2)
        #expect(controller.droppedBlocks == 5)

        // Confirming block 3 releases blocks 0 to 3.
        _ = try controller.receive(chunk: chunk(.waveConfirm(timestamp: 0, blockNumber: 3)), now: 10)
        #expect(controller.messages(forSamples: [UInt8](repeating: 0, count: block * 6), now: 10).count == 4 * 2)

        // Unconfirmed blocks expire, so a client that stops confirming does not silence the session forever.
        let later = AudioChannelController.confirmationTimeoutMilliseconds + 1
        #expect(controller.messages(forSamples: [UInt8](repeating: 0, count: block), now: later).count == 2)
    }

    @Test func clientCloseStopsStreaming() throws {
        var controller = try streamingController()
        #expect(try controller.receive(chunk: chunk(.close), now: 0) == [.stopStreaming])
        #expect(controller.state == .unavailable)
    }
}
