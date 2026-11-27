import Testing
@testable import RdpProtocol

struct AudioOutputTests {
    @Test func encodesServerFormatsPdu() throws {
        let pdu = AudioOutputPdu.formats(flags: 0, version: 6, formats: [.pcm(samplesPerSecond: 44100, channels: 2)])
        let bytes = pdu.encode()
        // SNDPROLOG: msgType 0x07, pad, BodySize = 20 fixed bytes + 18 bytes per format.
        #expect(Array(bytes[0..<4]) == [0x07, 0, 38, 0])
        // wNumberOfFormats at 18, wVersion at 21; format: PCM, 2 channels, 44100 Hz, 176400 B/s, align 4, 16 bits.
        #expect(Array(bytes[18..<20]) == [1, 0])
        #expect(Array(bytes[21..<23]) == [6, 0])
        #expect(Array(bytes[24...]) == [1, 0, 2, 0, 0x44, 0xAC, 0, 0, 0x10, 0xB1, 2, 0, 4, 0, 16, 0, 0, 0])
        #expect(try AudioOutputPdu.parse(bytes) == pdu)
    }

    @Test func parsesClientPdus() throws {
        let clientFormats = AudioOutputPdu.formats(flags: AudioOutputPdu.clientAlive | AudioOutputPdu.clientVolume, version: 8, formats: [
            AudioFormat(formatTag: 0x0002, channels: 2, samplesPerSecond: 44100, averageBytesPerSecond: 44359, blockAlign: 2048, bitsPerSample: 4, extraData: [0xF4, 0x07]),
            .pcm(samplesPerSecond: 48000, channels: 2),
        ])
        #expect(try AudioOutputPdu.parse(clientFormats.encode()) == clientFormats)
        #expect(try AudioOutputPdu.parse([0x06, 0, 4, 0, 0x34, 0x12, 0, 0]) == .training(timestamp: 0x1234, packSize: 0))
        #expect(try AudioOutputPdu.parse([0x05, 0, 4, 0, 0x10, 0, 7, 0]) == .waveConfirm(timestamp: 16, blockNumber: 7))
        #expect(try AudioOutputPdu.parse([0x0C, 0, 4, 0, 2, 0, 0, 0]) == .qualityMode(2))
    }

    @Test func splitsAudioIntoWaveInfoAndWavePdus() {
        let data: [UInt8] = Array(1...10)
        let (info, wave) = AudioOutputPdu.wave(timestamp: 0x0102, formatIndex: 3, blockNumber: 9, data: data)
        #expect(info == [0x02, 0, 18, 0, 0x02, 0x01, 3, 0, 9, 0, 0, 0, 1, 2, 3, 4])
        #expect(wave == [0, 0, 0, 0, 5, 6, 7, 8, 9, 10])
    }
}
