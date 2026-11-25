import Foundation
import Synchronization

/// Locks out a remote address after repeated failed logins, which slows down password guessing from the network.
public final class AuthenticationThrottle: Sendable {
    private struct Record {
        var failures: [Date] = []
        var lockedUntil: Date?
    }

    public let maximumFailures: Int
    public let window: TimeInterval
    public let lockoutDuration: TimeInterval
    private let records = Mutex<[String: Record]>([:])

    public init(maximumFailures: Int = 5, window: TimeInterval = 300, lockoutDuration: TimeInterval = 300) {
        self.maximumFailures = maximumFailures
        self.window = window
        self.lockoutDuration = lockoutDuration
    }

    public func isLockedOut(_ address: String, now: Date = Date()) -> Bool {
        records.withLock { records in
            guard let until = records[address]?.lockedUntil else { return false }
            if until > now { return true }
            records[address] = nil
            return false
        }
    }

    public func recordFailure(_ address: String, now: Date = Date()) {
        records.withLock { records in
            var record = records[address] ?? Record()
            record.failures = record.failures.filter { now.timeIntervalSince($0) < window } + [now]
            if record.failures.count >= maximumFailures {
                record.lockedUntil = now.addingTimeInterval(lockoutDuration)
                record.failures = []
            }
            records[address] = record
        }
    }

    public func recordSuccess(_ address: String) {
        _ = records.withLock { $0.removeValue(forKey: address) }
    }
}
