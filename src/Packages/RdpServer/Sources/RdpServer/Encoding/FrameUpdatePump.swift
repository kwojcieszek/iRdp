import Darwin
import Foundation

/// Encodes frames on a private queue and keeps latency low: only the newest frame is encoded, one batch is
/// written at a time, and with frame acknowledgements at most `maximumFramesInFlight` batches (one screen update, possibly split into several frames) are unacknowledged.
final class FrameUpdatePump: @unchecked Sendable {
    typealias Sender = @Sendable (_ packets: [[UInt8]], _ completion: @escaping @Sendable () -> Void) -> Void

    static let maximumFramesInFlight = 2
    static let refinementDelay: DispatchTimeInterval = .milliseconds(250)
    /// Delay between the steps of one refinement once it has started.
    static let refinementContinuationDelay: DispatchTimeInterval = .milliseconds(5)

    private let queue = DispatchQueue(label: "com.irdp.frame-pump", qos: .userInteractive)
    private let send: Sender
    // Capture can outpace encoding. Retain just the latest submitted image while the queue is busy.
    private let submissionLock = NSLock()
    private var latestSubmission: ScreenFrame?
    // State below is only accessed on `queue`.
    private var encoder: any FrameEncoding
    private var pendingFrame: ScreenFrame?
    private var isSending = false
    private var isPaused = false
    private var isStopped = false
    private var fullRefreshRequested = true
    /// Unacknowledged frames of each batch in flight, oldest first.
    private var batchesInFlight: [Int] = []
    private var acknowledgementsSuspended = false
    private var refinementGeneration = 0
    private var statistics = FrameStatistics()

    init(encoder: any FrameEncoding, send: @escaping Sender) {
        self.encoder = encoder
        self.send = send
    }

    func submit(_ frame: ScreenFrame) {
        let needsDelivery = submissionLock.withLock {
            let wasEmpty = latestSubmission == nil
            latestSubmission = frame
            return wasEmpty
        }
        guard needsDelivery else { return }
        queue.async {
            self.pendingFrame = self.submissionLock.withLock {
                defer { self.latestSubmission = nil }
                return self.latestSubmission
            }
            self.refinementGeneration += 1
            self.processIfIdle()
        }
    }

    func requestFullRefresh() {
        queue.async {
            self.fullRefreshRequested = true
            if self.pendingFrame == nil { self.pendingFrame = self.encoder.lastFrame }
            self.processIfIdle()
        }
    }

    func setPaused(_ paused: Bool) {
        queue.async {
            self.isPaused = paused
            if !paused { self.requestFullRefresh() }
        }
    }

    /// Switches to another encoder (e.g. the graphics pipeline) and resends the last frame with it.
    func replaceEncoder(_ newEncoder: any FrameEncoding) {
        queue.async {
            let last = self.encoder.lastFrame
            self.encoder = newEncoder
            self.batchesInFlight = []
            self.fullRefreshRequested = true
            if self.pendingFrame == nil { self.pendingFrame = last }
            self.processIfIdle()
        }
    }

    /// Called for every graphics pipeline frame acknowledgement.
    func frameAcknowledged(suspended: Bool) {
        queue.async {
            self.acknowledgementsSuspended = suspended
            if suspended {
                self.batchesInFlight = []
            } else if !self.batchesInFlight.isEmpty {
                self.batchesInFlight[0] -= 1
                if self.batchesInFlight[0] <= 0 { self.batchesInFlight.removeFirst() }
            }
            self.processIfIdle()
            if self.pendingFrame == nil, !self.isSending { self.scheduleRefinement() }
        }
    }

    /// Applies new encoding parameters to the running session.
    func updateQuality(_ quality: StreamingQuality) {
        queue.async {
            self.encoder.apply(quality)
            self.scheduleRefinement()
        }
    }

    func stop() {
        queue.async { self.isStopped = true }
    }

    private var canSendFrame: Bool {
        !encoder.usesFrameAcknowledgements || acknowledgementsSuspended || batchesInFlight.count < Self.maximumFramesInFlight
    }

    private func processIfIdle() {
        guard !isSending, !isPaused, !isStopped, canSendFrame, let frame = pendingFrame else { return }
        pendingFrame = nil
        let encodeStart = mach_absolute_time()
        let packets = encoder.encode(frame, forceFullUpdate: fullRefreshRequested)
        let encodeEnd = mach_absolute_time()
        fullRefreshRequested = false
        guard !packets.isEmpty else { return }
        isSending = true
        if encoder.usesFrameAcknowledgements && !acknowledgementsSuspended { batchesInFlight.append(encoder.framesInLastBatch) }
        let byteCount = packets.reduce(0) { $0 + $1.count }
        let displayTime = frame.displayTime
        send(packets) { [weak self] in
            let sendEnd = mach_absolute_time()
            guard let self else { return }
            self.queue.async {
                self.statistics.record(displayTime: displayTime, encodeStart: encodeStart, encodeEnd: encodeEnd, sendEnd: sendEnd, bytes: byteCount)
                self.isSending = false
                self.processIfIdle()
                self.scheduleRefinement()
            }
        }
    }

    /// While the screen is still, asks the encoder to improve the image (e.g. lossless tiles over H.264).
    private func scheduleRefinement(continuing: Bool = false) {
        guard pendingFrame == nil else { return }
        refinementGeneration += 1
        let generation = refinementGeneration
        queue.asyncAfter(deadline: .now() + (continuing ? Self.refinementContinuationDelay : Self.refinementDelay)) {
            guard generation == self.refinementGeneration, self.pendingFrame == nil, !self.isSending, !self.isStopped, !self.isPaused, self.canSendFrame else { return }
            guard let packets = self.encoder.refinement(), !packets.isEmpty else { return }
            self.isSending = true
            if self.encoder.usesFrameAcknowledgements && !self.acknowledgementsSuspended { self.batchesInFlight.append(self.encoder.framesInLastBatch) }
            self.send(packets) { [weak self] in
                guard let self else { return }
                self.queue.async {
                    self.isSending = false
                    self.processIfIdle()
                    self.scheduleRefinement(continuing: true)
                }
            }
        }
    }
}
