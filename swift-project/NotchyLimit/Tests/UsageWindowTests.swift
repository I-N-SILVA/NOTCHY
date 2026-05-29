import XCTest
@testable import NotchyLimit

/// Pure-logic tests for `UsageWindow` status classification and the
/// reset-countdown formatters. All time-dependent assertions inject a fixed
/// `now:` so they are deterministic.
final class UsageWindowTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func window(percent: Double, resetAt: Date? = nil) -> UsageWindow {
        UsageWindow(type: .session, percentUsed: percent, resetAt: resetAt, lastUpdated: now)
    }

    // MARK: - status thresholds

    func test_status_healthyBelowWarning() {
        XCTAssertEqual(window(percent: 0.0).status, .healthy)
        XCTAssertEqual(window(percent: 0.69).status, .healthy)
    }

    func test_status_warningBetween70And90() {
        XCTAssertEqual(window(percent: 0.70).status, .warning)
        XCTAssertEqual(window(percent: 0.89).status, .warning)
    }

    func test_status_criticalAtOrAbove90() {
        XCTAssertEqual(window(percent: 0.90).status, .critical)
        XCTAssertEqual(window(percent: 1.50).status, .critical)
    }

    // MARK: - isAtLimit

    func test_isAtLimit_boundary() {
        XCTAssertFalse(window(percent: 0.99).isAtLimit)
        XCTAssertTrue(window(percent: 1.0).isAtLimit)
        XCTAssertTrue(window(percent: 1.2).isAtLimit)
    }

    // MARK: - timeToResetShortString

    func test_shortString_nilWhenNoReset() {
        XCTAssertNil(window(percent: 0.5).timeToResetShortString(now: now))
    }

    func test_shortString_soonWhenPast() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(-60))
        XCTAssertEqual(w.timeToResetShortString(now: now), "soon")
    }

    func test_shortString_hoursAndMinutes() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(90 * 60))
        XCTAssertEqual(w.timeToResetShortString(now: now), "1h 30m")
    }

    func test_shortString_wholeHours() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(3600))
        XCTAssertEqual(w.timeToResetShortString(now: now), "1h")
    }

    func test_shortString_minutesOnly() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(30 * 60))
        XCTAssertEqual(w.timeToResetShortString(now: now), "30m")
    }

    func test_shortString_flooredToOneMinute() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(30))
        XCTAssertEqual(w.timeToResetShortString(now: now), "1m")
    }

    // MARK: - timeToResetString

    func test_longString_nilWhenNoReset() {
        XCTAssertNil(window(percent: 0.5).timeToResetString(now: now))
    }

    func test_longString_resettingWhenPast() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(-1))
        XCTAssertEqual(w.timeToResetString(now: now), "Resetting…")
    }

    func test_longString_hoursAndMinutes() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(90 * 60))
        XCTAssertEqual(w.timeToResetString(now: now), "Resets in 1h 30m")
    }

    func test_longString_daysAndHours() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(25 * 3600))
        XCTAssertEqual(w.timeToResetString(now: now), "Resets in 1d 1h")
    }

    func test_longString_wholeDays() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(48 * 3600))
        XCTAssertEqual(w.timeToResetString(now: now), "Resets in 2d")
    }

    func test_longString_minutesOnly() {
        let w = window(percent: 0.5, resetAt: now.addingTimeInterval(30 * 60))
        XCTAssertEqual(w.timeToResetString(now: now), "Resets in 30m")
    }
}
