import XCTest
import Combine
@testable import NotchyLimit

/// Tests for `UsageCoordinator` — the glue between `UsageService` publishers,
/// `AppState`, and `NotificationService`.
///
/// The coordinator is wired to an empty (isolated) `AuthService` so `start()`
/// does not kick off real polling, and to a capturing `NotificationService`.
/// Snapshots/errors are injected directly through `UsageService.shared`'s
/// publishers, which the coordinator subscribes to.
final class UsageCoordinatorTests: XCTestCase {

    private var coord: UsageCoordinator!
    private var appState: AppState!
    private var fired: [(title: String, body: String)] = []
    private var cancellables = Set<AnyCancellable>()
    private var notifSuite: String!

    override func setUp() {
        super.setUp()
        appState = AppState()
        fired = []
        notifSuite = "test.\(UUID().uuidString)"
        let notif = NotificationService(defaults: UserDefaults(suiteName: notifSuite)!) { [weak self] title, body in
            self?.fired.append((title, body))
        }
        let auth = AuthService(store: KeychainStore(service: "com.notchylimit.tests.\(UUID().uuidString)"))
        coord = UsageCoordinator(appState: appState, authService: auth,
                                 usageService: .shared, notifications: notif)
        coord.start()
    }

    override func tearDown() {
        coord.stop()
        cancellables.removeAll()
        UserDefaults.standard.removePersistentDomain(forName: notifSuite)
        super.tearDown()
    }

    private func makeSnapshot(session: Double) -> ServiceUsageSnapshot {
        ServiceUsageSnapshot(providerId: .claude,
                             primaryWindow: UsageWindow(type: .session, percentUsed: session))
    }

    func test_start_withoutCredentials_isNotConfigured() {
        XCTAssertEqual(appState.authStatus, .notConfigured)
    }

    func test_snapshot_updatesStateAndMarksValid() {
        let exp = expectation(description: "snapshot applied")
        exp.assertForOverFulfill = false
        appState.$latestSnapshot
            .compactMap { $0 }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        UsageService.shared.snapshotPublisher.send(makeSnapshot(session: 0.42))
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(appState.latestSnapshot?.primaryWindow.percentUsed ?? -1, 0.42, accuracy: 0.001)
        XCTAssertEqual(appState.authStatus, .valid)
        if case .ok = appState.syncStatus {} else { XCTFail("expected syncStatus .ok") }
    }

    func test_unauthorizedAfterValid_setsExpiredAndNotifiesOnce() {
        // Become valid first via a (sub-threshold) snapshot.
        let validExp = expectation(description: "valid")
        validExp.assertForOverFulfill = false
        appState.$authStatus.sink { if $0 == .valid { validExp.fulfill() } }.store(in: &cancellables)
        UsageService.shared.snapshotPublisher.send(makeSnapshot(session: 0.1))
        wait(for: [validExp], timeout: 2)

        // An auth failure flips valid → expired and notifies exactly once.
        let expiredExp = expectation(description: "expired")
        expiredExp.assertForOverFulfill = false
        appState.$authStatus.sink { if $0 == .expired { expiredExp.fulfill() } }.store(in: &cancellables)
        UsageService.shared.errorPublisher.send(.unauthorized)
        wait(for: [expiredExp], timeout: 2)

        XCTAssertEqual(appState.authStatus, .expired)
        XCTAssertEqual(fired.filter { $0.title.contains("cookie expired") }.count, 1,
                       "valid → expired should notify exactly once")
    }

    func test_missingCredentials_setsNotConfiguredWithoutNotifying() {
        let exp = expectation(description: "sync error")
        exp.assertForOverFulfill = false
        appState.$syncStatus.sink { if case .error = $0 { exp.fulfill() } }.store(in: &cancellables)

        UsageService.shared.errorPublisher.send(.missingCredentials)
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(appState.authStatus, .notConfigured)
        XCTAssertTrue(fired.isEmpty, "missingCredentials must not produce a notification")
    }
}
