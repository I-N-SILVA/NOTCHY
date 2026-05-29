import XCTest
@testable import NotchyLimit

/// Tests for `AuthService.saveClaudeCredential` validation. Uses an isolated
/// keychain service name so it never touches the real app credential.
final class AuthServiceTests: XCTestCase {

    private var auth: AuthService!
    private var serviceName: String!

    override func setUp() {
        super.setUp()
        serviceName = "com.notchylimit.tests.\(UUID().uuidString)"
        auth = AuthService(store: KeychainStore(service: serviceName))
    }

    override func tearDown() {
        auth.clearCredential(for: .claude)
        super.tearDown()
    }

    func test_rejectsEmptyCookie() {
        XCTAssertEqual(auth.saveClaudeCredential(ClaudeCredential(cookie: "")),
                       "Cookie cannot be empty.")
    }

    func test_rejectsWhitespaceOnlyCookie() {
        XCTAssertEqual(auth.saveClaudeCredential(ClaudeCredential(cookie: "   \n\t ")),
                       "Cookie cannot be empty.")
    }

    func test_rejectsTooShortCookie() {
        let short = String(repeating: "a", count: 31)
        XCTAssertNotNil(auth.saveClaudeCredential(ClaudeCredential(cookie: short)))
        XCTAssertFalse(auth.hasCredential(for: .claude), "a rejected cookie must not be stored")
    }

    func test_acceptsBoundaryLength32() {
        let cookie = String(repeating: "a", count: 32)
        XCTAssertNil(auth.saveClaudeCredential(ClaudeCredential(cookie: cookie)))
        XCTAssertTrue(auth.hasCredential(for: .claude))
    }

    func test_rejectsTooLongCookie() {
        let long = String(repeating: "a", count: 65_537)
        XCTAssertNotNil(auth.saveClaudeCredential(ClaudeCredential(cookie: long)))
    }

    func test_validCookie_storesAndRoundTrips() {
        let cookie = "sessionKey=" + String(repeating: "x", count: 64)
        XCTAssertNil(auth.saveClaudeCredential(ClaudeCredential(cookie: cookie)))
        XCTAssertTrue(auth.hasCredential(for: .claude))

        let loaded: ClaudeCredential? = auth.loadCredential(for: .claude)
        XCTAssertEqual(loaded?.cookie, cookie)
    }

    func test_trimsSurroundingWhitespaceBeforeStoring() {
        let cookie = "sessionKey=" + String(repeating: "x", count: 64)
        XCTAssertNil(auth.saveClaudeCredential(ClaudeCredential(cookie: "  \(cookie)  ")))
        let loaded: ClaudeCredential? = auth.loadCredential(for: .claude)
        XCTAssertEqual(loaded?.cookie, cookie, "stored cookie should be trimmed")
    }

    func test_clearRemovesCredential() {
        let cookie = "sessionKey=" + String(repeating: "x", count: 64)
        auth.saveClaudeCredential(ClaudeCredential(cookie: cookie))
        XCTAssertTrue(auth.hasCredential(for: .claude))
        auth.clearCredential(for: .claude)
        XCTAssertFalse(auth.hasCredential(for: .claude))
    }
}
