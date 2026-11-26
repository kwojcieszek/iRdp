import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

/// Hardware H.264 encoder (VideoToolbox) tuned for low latency: real-time, no frame reordering, no frame delay.
/// Produces Annex B streams with SPS/PPS before every key frame. Not thread safe; use from one queue.
final class VideoToolboxH264Encoder {
    private final class OutputBox: @unchecked Sendable {
        var sample: CMSampleBuffer?
        var status: OSStatus = noErr
    }

    let width: Int
    let height: Int
    private var session: VTCompressionSession?
    private var nextTimestamp = CMTime.zero
    private var framesPerSecond: Int
    private static let startCode: [UInt8] = [0, 0, 0, 1]

    /// `width` and `height` are the encoded size and should be multiples of 16.
    init(width: Int, height: Int, bitRate: Int, framesPerSecond: Int) throws {
        self.framesPerSecond = framesPerSecond
        self.width = width
        self.height = height
        // Plain hardware real-time encoding. The low-latency rate control mode is not used: it produces long-term
        // reference frames that some RDP clients (Microsoft's decoder) do not handle, which showed up as gray areas.
        let specification: [CFString: Any] = [
            kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder: true,
        ]
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]
        var created: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil, width: Int32(width), height: Int32(height), codecType: kCMVideoCodecType_H264,
            encoderSpecification: specification as CFDictionary, imageBufferAttributes: attributes as CFDictionary,
            compressedDataAllocator: nil, outputCallback: nil, refcon: nil, compressionSessionOut: &created
        )
        guard status == noErr, let created else { throw H264EncoderError.sessionCreationFailed(status) }
        session = created
        let properties: [CFString: Any] = [
            kVTCompressionPropertyKey_RealTime: true,
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_Main_AutoLevel,
            kVTCompressionPropertyKey_H264EntropyMode: kVTH264EntropyMode_CABAC,
            kVTCompressionPropertyKey_AllowFrameReordering: false,
            kVTCompressionPropertyKey_AverageBitRate: bitRate,
            kVTCompressionPropertyKey_ExpectedFrameRate: framesPerSecond,
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: 2,
            kVTCompressionPropertyKey_MaxFrameDelayCount: 0,
        ]
        for (key, value) in properties {
            VTSessionSetProperty(created, key: key, value: value as CFTypeRef)
        }
        VTCompressionSessionPrepareToEncodeFrames(created)
    }

    /// Changes the bit rate of the running session.
    func setBitRate(_ bitRate: Int, framesPerSecond: Int) {
        self.framesPerSecond = framesPerSecond
        guard let session else { return }
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitRate as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: framesPerSecond as CFNumber)
    }

    deinit {
        if let session { VTCompressionSessionInvalidate(session) }
    }

    /// Encodes a frame (smaller frames are padded with black) and waits for the output.
    func encode(_ frame: ScreenFrame, forceKeyFrame: Bool) throws -> [UInt8] {
        guard let session, let pool = VTCompressionSessionGetPixelBufferPool(session) else { throw H264EncoderError.noPixelBuffer }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard let pixelBuffer else { throw H264EncoderError.noPixelBuffer }
        copy(frame, into: pixelBuffer)

        let timestamp = nextTimestamp
        let duration = CMTime(value: 1, timescale: CMTimeScale(max(1, framesPerSecond)))
        nextTimestamp = CMTimeAdd(timestamp, duration)
        let box = OutputBox()
        let options: CFDictionary? = forceKeyFrame ? [kVTEncodeFrameOptionKey_ForceKeyFrame: true] as CFDictionary : nil
        let status = VTCompressionSessionEncodeFrame(session, imageBuffer: pixelBuffer, presentationTimeStamp: timestamp, duration: duration, frameProperties: options, infoFlagsOut: nil) { status, _, sample in
            box.status = status
            box.sample = sample
        }
        guard status == noErr else { throw H264EncoderError.encodingFailed(status) }
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: timestamp)
        guard box.status == noErr, let sample = box.sample else { throw H264EncoderError.encodingFailed(box.status) }
        return try Self.annexB(from: sample)
    }

    private func copy(_ frame: ScreenFrame, into pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rows = min(frame.height, height)
        let rowLength = min(frame.width, width) * 4
        frame.pixels.withUnsafeBytes { source in
            guard let sourceBase = source.baseAddress else { return }
            for row in 0..<rows {
                let destination = base + row * stride
                memcpy(destination, sourceBase + row * frame.bytesPerRow, rowLength)
                if rowLength < stride { memset(destination + rowLength, 0, stride - rowLength) }
            }
        }
        if rows < height { memset(base + rows * stride, 0, (height - rows) * stride) }
    }

    static func annexB(from sample: CMSampleBuffer) throws -> [UInt8] {
        var output: [UInt8] = []
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[CFString: Any]]
        let isKeyFrame = !((attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false)
        if isKeyFrame, let format = CMSampleBufferGetFormatDescription(sample) {
            var count = 0
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil, parameterSetCountOut: &count, nalUnitHeaderLengthOut: nil)
            for index in 0..<count {
                var pointer: UnsafePointer<UInt8>?
                var size = 0
                if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: index, parameterSetPointerOut: &pointer, parameterSetSizeOut: &size, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil) == noErr, let pointer {
                    output += startCode
                    output += UnsafeBufferPointer(start: pointer, count: size)
                }
            }
        }
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sample) else { throw H264EncoderError.invalidSample }
        let totalLength = CMBlockBufferGetDataLength(dataBuffer)
        guard totalLength > 0 else { throw H264EncoderError.invalidSample }
        var bytes = [UInt8](repeating: 0, count: totalLength)
        let status = bytes.withUnsafeMutableBytes {
            CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: totalLength, destination: $0.baseAddress!)
        }
        guard status == noErr else { throw H264EncoderError.encodingFailed(status) }
        output.reserveCapacity(output.count + totalLength)
        var offset = 0
        while offset + 4 <= totalLength {
            let length = Int(bytes[offset]) << 24 | Int(bytes[offset + 1]) << 16 | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
            offset += 4
            guard length > 0, offset + length <= totalLength else { throw H264EncoderError.invalidSample }
            output += startCode
            output.append(contentsOf: bytes[offset..<(offset + length)])
            offset += length
        }
        guard offset == totalLength else { throw H264EncoderError.invalidSample }
        return output
    }
}
