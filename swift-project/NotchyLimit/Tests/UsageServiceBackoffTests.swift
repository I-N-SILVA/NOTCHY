import XCTest
@testable import NotchyLimit

/// Tests for the (extracted, pure) backoff math in `UsageService`.
final class UsageServiceBackoffTests: XCTestCase {

    func test_noErrors_returnsBaseInterval() {
        XCTAssertEqual(UsageService.backoffInterval(consecutiveErrors: 0, intervalSeconds: 300), 300)
    }

    func test_doublesPerConsecutiveError() {
        XCTAssertEqual(UsageService.backoffInterval(consecutiveErrors: 1, intervalSeconds: 300), 600)
        XCTAssertEqual(UsageService.backoffInterval(consecutiveErrors: 2, intervalSeconds: 300), 1200)
        XCTAssertEqual(UsageService.backoffInterval(consecutiveErrors: 3, intervalSeconds: 300), 2400)
    }

    func test_clampsToOneHourCeiling() {
        // 300 * 2^4 = 4800 → clamped to 3600.
        XCTAssertEqual(UsageService.backoffInterval(consecutiveErrors: 4, intervalSeconds: 300), 3600)
    }

    func test_exponentCappedAtSix() {
        // Both should use exponent 6 → 60 * 64 = 3840 → clamped to 3600.
        XCTAssertEqual(UsageService.backoffInterval(consecutiveErrors: 6, intervalSeconds: 60), 3600)
        XCTAssertEqual(UsageService.backoffInterval(consecutiveErrors: 99, intervalSeconds: 60), 3600)
    }

    func test_rateLimitBackoffSteps() {
        // 300s base: ceil(log2(300/300 + 1)) = ceil(log2(2)) = 1
        XCTAssertEqual(UsageService.rateLimitBackoffSteps(intervalSeconds: 300), 1)
        // 150s base: ceil(log2(2 + 1)) = ceil(1.585) = 2
        XCTAssertEqual(UsageService.rateLimitBackoffSteps(intervalSeconds: 150), 2)
        // 60s base: ceil(log2(5 + 1)) = ceil(2.585) = 3
        XCTAssertEqual(UsageService.rateLimitBackoffSteps(intervalSeconds: 60), 3)
    }

    func test_rateLimitFloor_yieldsAtLeast300s() {
        // The computed steps, fed back into backoffInterval, must wait >= 300s.
        for base: TimeInterval in [60, 150, 300] {
            let steps = UsageService.rateLimitBackoffSteps(intervalSeconds: base)
            let wait = UsageService.backoffInterval(consecutiveErrors: steps, intervalSeconds: base)
            XCTAssertGreaterThanOrEqual(wait, 300, "base \(base) must floor to >= 300s")
        }
    }
}
