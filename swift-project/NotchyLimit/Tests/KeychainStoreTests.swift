import XCTest
@testable import NotchyLimit

/// Round-trip tests for the Keychain wrapper. Each test uses a unique service
/// name so items never collide with the real app or with other tests.
final class KeychainStoreTests: XCTestCase {

    func test_roundTrip_writeReadDelete() {
        let store = KeychainStore(service: "com.notchylimit.tests.\(UUID().uuidString)")
        let payload = "test-payload-\(UUID().uuidString)".data(using: .utf8)!

        store.set(account: "roundtrip", data: payload)
        XCTAssertEqual(store.get(account: "roundtrip"), payload)

        XCTAssertTrue(store.delete(account: "roundtrip"))
        XCTAssertNil(store.get(account: "roundtrip"))
    }

    func test_get_missingAccountReturnsNil() {
        let store = KeychainStore(service: "com.notchylimit.tests.\(UUID().uuidString)")
        XCTAssertNil(store.get(account: "never-written"))
    }

    func test_set_overwritesExistingValue() {
        let store = KeychainStore(service: "com.notchylimit.tests.\(UUID().uuidString)")
        store.set(account: "k", data: Data([1, 2, 3]))
        store.set(account: "k", data: Data([4, 5, 6]))
        XCTAssertEqual(store.get(account: "k"), Data([4, 5, 6]))
        store.delete(account: "k")
    }

    func test_delete_missingAccountSucceeds() {
        let store = KeychainStore(service: "com.notchylimit.tests.\(UUID().uuidString)")
        // errSecItemNotFound is treated as a successful delete.
        XCTAssertTrue(store.delete(account: "never-written"))
    }
}
