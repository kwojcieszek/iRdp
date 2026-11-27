import AVFAudio
import Testing
@testable import MacIntegration
@testable import RdpServer

struct PcmConverterTests {
    /// Stereo 48 kHz float buffer like the ones ScreenCaptureKit delivers (non-interleaved).
    private func captureBuffer(frames: Int, value: Float) throws -> AVAudioPCMBuffer {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)
        for channel in 0..<2 {
            for index in 0..<frames { buffer.floatChannelData![channel][index] = value }
        }
        return buffer
    }

    private func samples(_ bytes: [UInt8]) -> [Int16] {
        stride(from: 0, to: bytes.count - 1, by: 2).map { Int16(bitPattern: UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8) }
    }

    @Test func convertsToInterleavedInt16AtSameRate() throws {
        let input = try captureBuffer(frames: 960, value: 0.5)
        let converter = try #require(PcmConverter(input: input.format, output: AudioStreamFormat(sampleRate: 48000, channels: 2)))
        let bytes = try #require(converter.convert(input))
        #expect(bytes.count == 960 * 4)
        #expect(samples(bytes).allSatisfy { abs(Int($0) - 16384) <= 1 })
    }

    @Test func resamplesTo44100AcrossBuffers() throws {
        let input = try captureBuffer(frames: 4800, value: 0.25)
        let converter = try #require(PcmConverter(input: input.format, output: AudioStreamFormat(sampleRate: 44100, channels: 2)))
        var total = 0
        var all: [Int16] = []
        for _ in 0..<10 {
            let bytes = try #require(converter.convert(input))
            total += bytes.count / 4
            all += samples(bytes)
        }
        // One second of input gives about one second at 44.1 kHz (the resampler keeps a few frames back).
        #expect(abs(total - 44100) < 200)
        #expect(all.suffix(1000).allSatisfy { abs(Int($0) - 8192) <= 64 })
    }

    @Test func mixesDownToMono() throws {
        let input = try captureBuffer(frames: 960, value: 0.5)
        let converter = try #require(PcmConverter(input: input.format, output: AudioStreamFormat(sampleRate: 22050, channels: 1)))
        var total = 0
        for _ in 0..<5 { total += try #require(converter.convert(input)).count / 2 }
        #expect(total > 2000)
    }

    @Test func rejectsUnsupportedChannelCount() {
        #expect(PcmConverter.outputFormat(AudioStreamFormat(sampleRate: 48000, channels: 6)) == nil)
    }
}
