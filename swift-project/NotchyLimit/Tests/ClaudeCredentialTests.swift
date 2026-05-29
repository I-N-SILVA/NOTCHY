import XCTest
@testable import NotchyLimit

/// Tests for `ClaudeCredential.orgIdFromCookie`. This is security-relevant:
/// the UUID validation prevents path injection when the org id is later
/// interpolated into the usage URL (see `ClaudeEndpoint.usage(orgId:)`).
final class ClaudeCredentialTests: XCTestCase {

    private let uuid = "11111111-1111-1111-1111-111111111111"

    func test_extractsValidOrgUUID() {
        let cred = ClaudeCredential(cookie: "sessionKey=abc; lastActiveOrg=\(uuid); foo=bar")
        XCTAssertEqual(cred.orgIdFromCookie, uuid)
    }

    func test_rejectsNonUUIDValue() {
        let cred = ClaudeCredential(cookie: "lastActiveOrg=not-a-uuid; x=y")
        XCTAssertNil(cred.orgIdFromCookie, "non-UUID values must be rejected to prevent path injection")
    }

    func test_nilWhenKeyAbsent() {
        let cred = ClaudeCredential(cookie: "sessionKey=abc; foo=bar")
        XCTAssertNil(cred.orgIdFromCookie)
    }

    func test_nilForEmptyCookie() {
        XCTAssertNil(ClaudeCredential(cookie: "").orgIdFromCookie)
    }

    func test_toleratesSurroundingWhitespace() {
        let cred = ClaudeCredential(cookie: "  foo=bar ;   lastActiveOrg=\(uuid)  ; baz=qux")
        XCTAssertEqual(cred.orgIdFromCookie, uuid)
    }

    func test_findsKeyWhenNotFirstSegment() {
        let cred = ClaudeCredential(cookie: "a=1; b=2; lastActiveOrg=\(uuid)")
        XCTAssertEqual(cred.orgIdFromCookie, uuid)
    }

    func test_doesNotMatchPrefixOfAnotherKey() {
        // A different key that merely contains the substring must not match.
        let cred = ClaudeCredential(cookie: "notlastActiveOrg=\(uuid)")
        XCTAssertNil(cred.orgIdFromCookie)
    }
}
