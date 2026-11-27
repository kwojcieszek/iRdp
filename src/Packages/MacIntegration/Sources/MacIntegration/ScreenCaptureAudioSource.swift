import AVFAudio
import CoreMedia
import Foundation
import os
import RdpServer
import ScreenCaptureKit

/// Captures the sound played on the Mac with ScreenCaptureKit and converts it to the client's PCM format.
public final class ScreenCaptureAudioSource: NSObject, AudioSource, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    public enum CaptureError: Error, CustomStringConvertible {
        case noDisplay
        case unsupportedFormat(AudioStreamFormat)

        public var description: String {
            switch self {
            case .noDisplay: "no display is available for audio capture"
            case .unsupportedFormat(let format): "cannot convert audio to \(format.sampleRate) Hz with \(format.channels) channels"
            }
        }
    }

    private static let logger = Logger(subsystem: "com.irdp", category: "audio")
    /// Rate ScreenCaptureKit captures at; the converter resamples to the client's rate.
    static let captureSampleRate = 48000

    private let displayID: UInt32?
    private let queue = DispatchQueue(label: "com.irdp.audio", qos: .userInteractive)
    private let videoQueue = DispatchQueue(label: "com.irdp.audio.video", qos: .utility)
    private let lock = NSLock()
    // Guarded by `lock`.
    private var stream: SCStream?
    private var onSamples: (@Sendable ([UInt8]) -> Void)?
    // Used only on `queue`.
    private var converter: PcmConverter?
    private var outputFormat: AudioStreamFormat?

    /// `displayID` selects the display the capture filter is attached to; the sound of the whole Mac is captured.
    public init(displayID: UInt32?) {
        self.displayID = displayID
    }

    public func start(format: AudioStreamFormat, onSamples: @escaping @Sendable ([UInt8]) -> Void) async throws {
        guard PcmConverter.outputFormat(format) != nil else { throw CaptureError.unsupportedFormat(format) }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.sampleRate = Self.captureSampleRate
        configuration.channelCount = 2
        configuration.excludesCurrentProcessAudio = true
        // Video is not used: keep it as small and rare as possible.
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.queueDepth = 3
        configuration.showsCursor = false
        let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        // Without a screen output ScreenCaptureKit logs every dropped video frame.
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        queue.sync {
            converter = nil
            outputFormat = format
        }
        lock.withLock {
            self.stream = stream
            self.onSamples = onSamples
        }
        try await stream.startCapture()
        Self.logger.info("capturing audio for \(format.sampleRate) Hz, \(format.channels) channels")
    }

    public func stop() async {
        let stream = lock.withLock { () -> SCStream? in
            defer {
                self.stream = nil
                self.onSamples = nil
            }
            return self.stream
        }
        try? await stream?.stopCapture()
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, let outputFormat else { return }
        guard let handler = lock.withLock({ onSamples }) else { return }
        do {
            try sampleBuffer.withAudioBufferList { bufferList, _ in
                guard let description = sampleBuffer.formatDescription?.audioStreamBasicDescription,
                      let inputFormat = AVAudioFormat(streamDescription: [description]),
                      let input = AVAudioPCMBuffer(pcmFormat: inputFormat, bufferListNoCopy: bufferList.unsafePointer) else { return }
                if converter?.inputFormat != inputFormat {
                    converter = PcmConverter(input: inputFormat, output: outputFormat)
                }
                if let bytes = converter?.convert(input), !bytes.isEmpty {
                    handler(bytes)
                }
            }
        } catch {
            Self.logger.debug("unreadable audio buffer: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Self.logger.error("audio capture stopped: \(error.localizedDescription, privacy: .public)")
    }
}

/// Converts captured audio buffers to interleaved 16-bit PCM at the client's rate, keeping resampler state between buffers.
final class PcmConverter {
    let inputFormat: AVAudioFormat
    private let output: AVAudioFormat
    private let converter: AVAudioConverter

    static func outputFormat(_ format: AudioStreamFormat) -> AVAudioFormat? {
        guard (1...2).contains(format.channels), format.sampleRate > 0 else { return nil }
        return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(format.sampleRate), channels: AVAudioChannelCount(format.channels), interleaved: true)
    }

    init?(input: AVAudioFormat, output format: AudioStreamFormat) {
        guard let output = Self.outputFormat(format), let converter = AVAudioConverter(from: input, to: output) else { return nil }
        inputFormat = input
        self.output = output
        self.converter = converter
    }

    /// Returns the converted samples as little endian bytes.
    func convert(_ input: AVAudioPCMBuffer) -> [UInt8]? {
        let ratio = output.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(input.frameLength) * ratio).rounded(.up)) + 32
        guard let buffer = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else { return nil }
        nonisolated(unsafe) var supplied = false
        nonisolated(unsafe) let source = input
        var error: NSError?
        let status = converter.convert(to: buffer, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return source
        }
        guard status != .error, let data = buffer.int16ChannelData else { return nil }
        let byteCount = Int(buffer.frameLength) * Int(output.channelCount) * 2
        return data[0].withMemoryRebound(to: UInt8.self, capacity: byteCount) { Array(UnsafeBufferPointer(start: $0, count: byteCount)) }
    }
}
