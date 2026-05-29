import XCTest
@testable import NotchyLimit

/// Tests for `ProviderError`. The `description` for transport/unknown errors
/// deliberately omits the raw underlying message to avoid leaking request URLs
/// (which can contain the org id) or system paths into the UI — this guarantee
/// is asserted here so a regression can't silently reintroduce PII.
final class ProviderErrorTests: XCTestCase {

    func test_transport_redactsRawMessage() {
        let raw = "https://claude.ai/api/organizations/SECRET-ORG/usage timed out at /Users/me"
        let desc = ProviderError.transport(raw).description
        XCTAssertEqual(desc, "Network error — check your connection.")
        XCTAssertFalse(desc.contains("SECRET-ORG"))
        XCTAssertFalse(desc.contains("/Users/me"))
    }

    func test_unknown_redactsRawMessage() {
        let desc = ProviderError.unknown("/private/var/secret path").description
        XCTAssertEqual(desc, "An unexpected error occurred.")
        XCTAssertFalse(desc.contains("secret"))
    }

    func test_decoding_surfacesSchemaMessage() {
        XCTAssertEqual(ProviderError.decoding("missing five_hour").description,
                       "Response schema changed: missing five_hour")
    }

    func test_server_includesStatusCode() {
        XCTAssertEqual(ProviderError.server(503).description, "Server error (503)")
    }

    func test_fixedDescriptions() {
        XCTAssertEqual(ProviderError.missingCredentials.description, "Missing credentials")
        XCTAssertEqual(ProviderError.unauthorized.description, "Authentication expired")
        XCTAssertEqual(ProviderError.rateLimited.description, "Rate limited")
    }

    func test_isAuthIssue() {
        XCTAssertTrue(ProviderError.unauthorized.isAuthIssue)
        XCTAssertTrue(ProviderError.missingCredentials.isAuthIssue)
        XCTAssertFalse(ProviderError.rateLimited.isAuthIssue)
        XCTAssertFalse(ProviderError.transport("x").isAuthIssue)
        XCTAssertFalse(ProviderError.decoding("x").isAuthIssue)
        XCTAssertFalse(ProviderError.server(500).isAuthIssue)
        XCTAssertFalse(ProviderError.unknown("x").isAuthIssue)
    }
}
