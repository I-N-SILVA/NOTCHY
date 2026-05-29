import XCTest
@testable import NotchyLimit

/// Tests for `ServiceUsageSnapshot.combinedStatus` — the worst-status-wins
/// rollup that drives the top-level pill color.
final class ServiceUsageSnapshotTests: XCTestCase {

    private func win(_ percent: Double, type: UsageWindowType = .session) -> UsageWindow {
        UsageWindow(type: type, percentUsed: percent)
    }

    func test_allHealthy_isHealthy() {
        let snap = ServiceUsageSnapshot(
            providerId: .claude,
            primaryWindow: win(0.1),
            secondaryWindow: win(0.2, type: .weekly),
            tertiaryWindow: win(0.3, type: .weeklyModel)
        )
        XCTAssertEqual(snap.combinedStatus, .healthy)
    }

    func test_primaryWarning_isWarning() {
        let snap = ServiceUsageSnapshot(providerId: .claude, primaryWindow: win(0.75))
        XCTAssertEqual(snap.combinedStatus, .warning)
    }

    func test_secondaryCritical_beatsWarning() {
        let snap = ServiceUsageSnapshot(
            providerId: .claude,
            primaryWindow: win(0.75),
            secondaryWindow: win(0.95, type: .weekly)
        )
        XCTAssertEqual(snap.combinedStatus, .critical)
    }

    func test_tertiaryWarning_only() {
        let snap = ServiceUsageSnapshot(
            providerId: .claude,
            primaryWindow: win(0.1),
            tertiaryWindow: win(0.8, type: .weeklyModel)
        )
        XCTAssertEqual(snap.combinedStatus, .warning)
    }

    func test_nilOptionalWindows_defaultHealthy() {
        // Primary healthy, the missing windows must not push status up.
        let snap = ServiceUsageSnapshot(providerId: .claude, primaryWindow: win(0.5))
        XCTAssertEqual(snap.combinedStatus, .healthy)
    }
}
