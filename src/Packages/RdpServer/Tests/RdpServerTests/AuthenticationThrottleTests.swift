import Foundation
import Testing
@testable import RdpServer

struct AuthenticationThrottleTests {
    @Test func locksOutAfterRepeatedFailures() {
        let throttle = AuthenticationThrottle(maximumFailures: 3, window: 60, lockoutDuration: 120)
        let start = Date(timeIntervalSince1970: 1000)
        for offset in 0..<2 { throttle.recordFailure("10.0.0.5", now: start.addingTimeInterval(Double(offset))) }
        #expect(!throttle.isLockedOut("10.0.0.5", now: start.addingTimeInterval(3)))
        throttle.recordFailure("10.0.0.5", now: start.addingTimeInterval(3))
        #expect(throttle.isLockedOut("10.0.0.5", now: start.addingTimeInterval(4)))
        #expect(!throttle.isLockedOut("10.0.0.6", now: start.addingTimeInterval(4)), "other addresses are not affected")
        #expect(!throttle.isLockedOut("10.0.0.5", now: start.addingTimeInterval(200)), "the lockout expires")
    }

    @Test func forgetsOldFailuresAndResetsOnSuccess() {
        let throttle = AuthenticationThrottle(maximumFailures: 2, window: 10, lockoutDuration: 60)
        let start = Date(timeIntervalSince1970: 0)
        throttle.recordFailure("a", now: start)
        throttle.recordFailure("a", now: start.addingTimeInterval(30))
        #expect(!throttle.isLockedOut("a", now: start.addingTimeInterval(31)))
        throttle.recordSuccess("a")
        throttle.recordFailure("a", now: start.addingTimeInterval(32))
        #expect(!throttle.isLockedOut("a", now: start.addingTimeInterval(33)))
    }
}
