import Darwin
import os

/// Collects per-frame timings of the update pipeline and logs a summary every few seconds.
struct FrameStatistics {
    private static let logger = Logger(subsystem: "com.kwojcieszek.irdp", category: "performance")
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private var windowStart = mach_absolute_time()
    private var frames = 0
    private var bytes = 0
    private var waitTotal = 0.0
    private var encodeTotal = 0.0
    private var sendTotal = 0.0
    private var endToEndMaximum = 0.0

    static func milliseconds(from start: UInt64, to end: UInt64) -> Double {
        guard end > start else { return 0 }
        return Double(end - start) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
    }

    /// Records one sent frame: display time, encode start, encode end and send completion (mach ticks).
    mutating func record(displayTime: UInt64, encodeStart: UInt64, encodeEnd: UInt64, sendEnd: UInt64, bytes: Int) {
        frames += 1
        self.bytes += bytes
        waitTotal += Self.milliseconds(from: displayTime, to: encodeStart)
        encodeTotal += Self.milliseconds(from: encodeStart, to: encodeEnd)
        sendTotal += Self.milliseconds(from: encodeEnd, to: sendEnd)
        endToEndMaximum = max(endToEndMaximum, Self.milliseconds(from: displayTime, to: sendEnd))
        let elapsed = Self.milliseconds(from: windowStart, to: sendEnd)
        guard elapsed >= 3000 else { return }
        let count = Double(frames)
        let summary = String(format: "%.1f fps, capture→encode %.1f ms, encode %.1f ms, send %.1f ms, max end-to-end %.1f ms, %.0f KiB/s",
                             count * 1000 / elapsed, waitTotal / count, encodeTotal / count, sendTotal / count, endToEndMaximum, Double(self.bytes) / 1024 * 1000 / elapsed)
        Self.logger.info("\(summary, privacy: .public)")
        self = FrameStatistics()
    }
}
