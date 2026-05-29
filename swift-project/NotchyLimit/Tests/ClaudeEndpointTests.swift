import XCTest
@testable import NotchyLimit

/// Tests for `ClaudeEndpoint` URL construction and headers.
final class ClaudeEndpointTests: XCTestCase {

    private let uuid = "11111111-1111-1111-1111-111111111111"

    func test_usageURL_isExact() {
        let url = ClaudeEndpoint.usage(orgId: uuid)
        XCTAssertEqual(url.absoluteString,
                       "https://claude.ai/api/organizations/\(uuid)/usage")
    }

    func test_usageURL_hostIsClaude() {
        XCTAssertEqual(ClaudeEndpoint.usage(orgId: uuid).host, "claude.ai")
    }

    func test_bootstrapURL_isExact() {
        XCTAssertEqual(ClaudeEndpoint.bootstrap.absoluteString,
                       "https://claude.ai/api/bootstrap")
    }

    func test_headers_carryCookieAndOrigin() {
        let headers = ClaudeEndpoint.headers(cookie: "sessionKey=secret")
        XCTAssertEqual(headers["Cookie"], "sessionKey=secret")
        XCTAssertEqual(headers["Origin"], "https://claude.ai")
        XCTAssertEqual(headers["Referer"], "https://claude.ai")
        XCTAssertNotNil(headers["User-Agent"])
        XCTAssertEqual(headers["Accept"], "*/*")
    }
}
