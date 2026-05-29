import XCTest
@testable import NotchyLimit

/// Tests for the high-water-mark notification logic. Each test builds an
/// isolated `NotificationService` with an in-memory UserDefaults suite and a
/// capturing `emit` sink, so there is no shared global state and no real
/// banner window is ever created.
final class NotificationServiceTests: XCTestCase {

    private let thresholds: [Double] = [0.25, 0.5, 0.75, 0.9, 1.0]
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var fired: [(title: String, body: String)] = []
    private var service: NotificationService!

    override func setUp() {
        super.setUp()
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        fired = []
        service = makeService()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// A fresh service bound to the shared suite, recording into `self.fired`.
    private func makeService() -> NotificationService {
        NotificationService(defaults: defaults) { [weak self] title, body in
            self?.fired.append((title, body))
        }
    }

    private func snapshot(session: Double,
                          weekly: Double? = nil,
                          model: Double? = nil,
                          resetAt: Date? = nil) -> ServiceUsageSnapshot {
        ServiceUsageSnapshot(
            providerId: .claude,
            primaryWindow: UsageWindow(type: .session, percentUsed: session, resetAt: resetAt),
            secondaryWindow: weekly.map { UsageWindow(type: .weekly, percentUsed: $0, resetAt: resetAt) },
            tertiaryWindow: model.map { UsageWindow(type: .weeklyModel, percentUsed: $0, resetAt: resetAt) }
        )
    }

    private func mark() -> [String: Double] {
        defaults.dictionary(forKey: "com.notchylimit.NotificationService.highWaterMark") as? [String: Double] ?? [:]
    }

    // MARK: - high-water mark

    func test_skippedThresholds_recordsHighestOnly() {
        service.evaluate(snapshot: snapshot(session: 0.76), thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.75)
        XCTAssertEqual(fired.count, 1)
        XCTAssertTrue(fired[0].title.contains("75%"))
    }

    func test_repeatedEvaluate_doesNotReFire() {
        service.evaluate(snapshot: snapshot(session: 0.76), thresholds: thresholds, providerId: .claude)
        service.evaluate(snapshot: snapshot(session: 0.76), thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(fired.count, 1, "the same usage level must not re-fire")
    }

    func test_newHigherThreshold_fires() {
        service.evaluate(snapshot: snapshot(session: 0.76), thresholds: thresholds, providerId: .claude)
        service.evaluate(snapshot: snapshot(session: 0.92), thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.9)
        XCTAssertEqual(fired.count, 2)
        XCTAssertTrue(fired[1].title.contains("90%"))
    }

    func test_windowReset_clearsMarkAndFiresResetThenRefires() {
        service.evaluate(snapshot: snapshot(session: 0.76), thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.75)

        // Usage drops below the lowest threshold → window reset.
        service.evaluate(snapshot: snapshot(session: 0.05), thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0)
        XCTAssertTrue(fired.contains { $0.title.contains("session reset") },
                      "a reset notification should fire on window rollover")

        // Next rising edge fires fresh.
        service.evaluate(snapshot: snapshot(session: 0.76), thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.75)
    }

    // MARK: - multiple windows

    func test_multipleWindows_evaluatedIndependently() {
        service.evaluate(snapshot: snapshot(session: 0.8, weekly: 0.6, model: 0.3),
                         thresholds: [0.5, 0.75], providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.75)
        XCTAssertEqual(mark()["claude:weekly"], 0.5)
        XCTAssertNil(mark()["claude:model"], "0.3 is below the lowest threshold — no mark")
        XCTAssertEqual(fired.count, 2)
    }

    // MARK: - limit reached

    func test_limitReached_usesLimitTitleAndBody() {
        service.evaluate(snapshot: snapshot(session: 1.0), thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 1.0)
        XCTAssertTrue(fired[0].title.contains("limit reached"))
        XCTAssertEqual(fired[0].body, "Session limit reached.")
    }

    func test_body_formatsPercentWhenNoReset() {
        // Title reports the crossed threshold (75%); body reports actual usage (80%).
        service.evaluate(snapshot: snapshot(session: 0.8), thresholds: thresholds, providerId: .claude)
        XCTAssertTrue(fired[0].title.contains("75%"))
        XCTAssertEqual(fired[0].body, "80% of your session limit used.")
    }

    // MARK: - guards

    func test_emptyThresholds_firesNothing() {
        service.evaluate(snapshot: snapshot(session: 0.99), thresholds: [], providerId: .claude)
        XCTAssertTrue(fired.isEmpty)
    }

    func test_zeroUsageWindow_skipped() {
        service.evaluate(snapshot: snapshot(session: 0.0), thresholds: thresholds, providerId: .claude)
        XCTAssertTrue(fired.isEmpty)
        XCTAssertTrue(mark().isEmpty)
    }

    // MARK: - persistence

    func test_markPersistsAcrossInstances() {
        service.evaluate(snapshot: snapshot(session: 0.76), thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(fired.count, 1)

        // A new service over the same suite must load the saved mark and not re-fire.
        let reborn = makeService()
        let countBefore = fired.count
        reborn.evaluate(snapshot: snapshot(session: 0.76), thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(fired.count, countBefore, "persisted mark should suppress re-firing after restart")
    }

    // MARK: - direct send

    func test_send_emitsImmediately() {
        service.send(title: "Hi", body: "There")
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired[0].title, "Hi")
        XCTAssertEqual(fired[0].body, "There")
    }
}
