import Foundation
import RdpProtocol
import Testing
@testable import RdpServer

/// Plays the server's sound on a client that opens the "rdpsnd" static channel.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct AudioOutputEndToEndTests {
    private func makeServer(audio: SineAudioSource?) -> RdpServer {
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: { RdpSessionResources(frameSource: TestPatternFrameSource(desktopSize: DesktopSize(width: 320, height: 192), interval: .milliseconds(50)), inputSink: nil, audioSource: audio) }
        )
        return RdpServer(configuration: RdpServerConfiguration(host: "127.0.0.1", port: 0, certificate: TestCertificate.shared), environment: environment)
    }

    @Test func streamsAudioBlocksAfterNegotiation() async throws {
        let audio = SineAudioSource()
        let server = makeServer(audio: audio)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let (client, _) = try await RdpTestClient.connect(port: port)
        let session = try await client.connectSession(userName: "kamil", password: "secret", extraChannels: ["rdpdr", "rdpsnd"])
        _ = try await session.activate()

        guard case .formats(_, let version, let offered) = try AudioOutputPdu.parse(try await session.nextStaticChannelMessage(channel: "rdpsnd")) else {
            Issue.record("no server formats"); return
        }
        #expect(version == AudioOutputPdu.serverVersion)
        #expect(offered.contains(.pcm(samplesPerSecond: 44100, channels: 2)))
        try await session.sendStaticChannelMessage(AudioOutputPdu.formats(flags: AudioOutputPdu.clientAlive, version: 6, formats: [.pcm(samplesPerSecond: 44100, channels: 2)]).encode(), channel: "rdpsnd")
        guard case .training(let timestamp, let packSize) = try AudioOutputPdu.parse(try await session.nextStaticChannelMessage(channel: "rdpsnd")) else {
            Issue.record("no training"); return
        }
        try await session.sendStaticChannelMessage(AudioOutputPdu.training(timestamp: timestamp, packSize: packSize).encode(), channel: "rdpsnd")

        var blocks: [UInt8] = []
        for _ in 0..<5 {
            let info = try await session.nextStaticChannelMessage(channel: "rdpsnd")
            #expect(info.first == AudioOutputPdu.MessageType.wave.rawValue)
            #expect(info.count == 16)
            var reader = ByteReader(info)
            try reader.skip(2)
            let bodySize = Int(try reader.readUInt16LE())
            try reader.skip(2)
            #expect(try reader.readUInt16LE() == 0)
            let block = try reader.readUInt8()
            blocks.append(block)
            let wave = try await session.nextStaticChannelMessage(channel: "rdpsnd")
            #expect(Array(wave.prefix(4)) == [0, 0, 0, 0])
            #expect(wave.count == bodySize - 8)
            #expect(wave.count == 44100 * 4 / 50)
            try await session.sendStaticChannelMessage(AudioOutputPdu.waveConfirm(timestamp: 0, blockNumber: block).encode(), channel: "rdpsnd")
        }
        #expect(blocks == [0, 1, 2, 3, 4])
        #expect(audio.startedFormat == AudioStreamFormat(sampleRate: 44100, channels: 2))

        await session.close()
        for _ in 0..<50 where audio.stopCount == 0 { try await Task.sleep(for: .milliseconds(20)) }
        #expect(audio.stopCount == 1)
    }
}
