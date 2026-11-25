import CoreMedia
import CoreVideo
import Foundation
import os
import RdpServer
import ScreenCaptureKit

/// Captures a display with ScreenCaptureKit and delivers BGRA frames.
public final class ScreenCaptureFrameSource: NSObject, FrameSource, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    public enum CaptureError: Error, CustomStringConvertible {
        case displayNotFound(UInt32)

        public var description: String {
            switch self {
            case .displayNotFound(let id): "display \(id) is not available for capture"
            }
        }
    }

    private static let logger = Logger(subsystem: "com.kwojcieszek.irdp", category: "capture")

    public let desktopSize: DesktopSize
    private let displayID: UInt32
    private let framesPerSecond: Int
    private let queue = DispatchQueue(label: "com.kwojcieszek.irdp.capture", qos: .userInteractive)
    private let lock = NSLock()
    // Guarded by `lock`.
    private var stream: SCStream?
    private var onFrame: (@Sendable (ScreenFrame) -> Void)?

    public init(displayID: UInt32, desktopSize: DesktopSize, framesPerSecond: Int) {
        self.displayID = displayID
        self.desktopSize = desktopSize
        self.framesPerSecond = min(max(framesPerSecond, 1), 60)
    }

    public func start(onFrame: @escaping @Sendable (ScreenFrame) -> Void) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound(displayID)
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = desktopSize.width
        configuration.height = desktopSize.height
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(framesPerSecond))
        configuration.showsCursor = false
        configuration.queueDepth = 4
        configuration.colorSpaceName = CGColorSpace.sRGB
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        lock.withLock {
            self.stream = stream
            self.onFrame = onFrame
        }
        try await stream.startCapture()
        Self.logger.info("capturing display \(self.displayID) at \(self.desktopSize.width)x\(self.desktopSize.height)")
    }

    public func stop() async {
        let stream = lock.withLock { () -> SCStream? in
            defer {
                self.stream = nil
                self.onFrame = nil
            }
            return self.stream
        }
        try? await stream?.stopCapture()
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let displayTime = (attachments.first?[.displayTime] as? UInt64) ?? mach_absolute_time()
        guard let frame = Self.makeFrame(from: pixelBuffer, displayTime: displayTime) else { return }
        let handler = lock.withLock { onFrame }
        handler?(frame)
    }

    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Self.logger.error("capture stopped: \(error.localizedDescription, privacy: .public)")
    }

    static func makeFrame(from pixelBuffer: CVPixelBuffer, displayTime: UInt64) -> ScreenFrame? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let sourceStride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rowLength = width * 4
        let pixels = [UInt8](unsafeUninitializedCapacity: rowLength * height) { buffer, count in
            guard let destination = buffer.baseAddress else { return }
            for row in 0..<height {
                memcpy(destination + row * rowLength, base + row * sourceStride, rowLength)
            }
            count = rowLength * height
        }
        return ScreenFrame(width: width, height: height, bytesPerRow: rowLength, pixels: pixels, displayTime: displayTime)
    }
}
