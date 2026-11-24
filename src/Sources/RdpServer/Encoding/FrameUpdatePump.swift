import Foundation

/// Encodes frames on a private queue and sends at most one batch at a time, always sending the newest frame.
final class FrameUpdatePump: @unchecked Sendable {
    typealias Sender = @Sendable (_ pdus: [[UInt8]], _ completion: @escaping @Sendable () -> Void) -> Void

    private let queue = DispatchQueue(label: "com.kwojcieszek.irdp.frame-pump", qos: .userInteractive)
    private let encoder: ScreenUpdateEncoder
    private let send: Sender
    // State below is only accessed on `queue`.
    private var pendingFrame: ScreenFrame?
    private var isSending = false
    private var isPaused = false
    private var isStopped = false
    private var fullRefreshRequested = true

    init(encoder: ScreenUpdateEncoder, send: @escaping Sender) {
        self.encoder = encoder
        self.send = send
    }

    func submit(_ frame: ScreenFrame) {
        queue.async {
            self.pendingFrame = frame
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

    func stop() {
        queue.async { self.isStopped = true }
    }

    private func processIfIdle() {
        guard !isSending, !isPaused, !isStopped, let frame = pendingFrame else { return }
        pendingFrame = nil
        let pdus = encoder.encode(frame, forceFullUpdate: fullRefreshRequested)
        fullRefreshRequested = false
        guard !pdus.isEmpty else { return }
        isSending = true
        send(pdus) { [weak self] in
            guard let self else { return }
            self.queue.async {
                self.isSending = false
                self.processIfIdle()
            }
        }
    }
}
