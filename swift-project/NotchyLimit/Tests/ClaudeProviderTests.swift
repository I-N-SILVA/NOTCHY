import XCTest
@testable import NotchyLimit

/// Tests for `ClaudeProvider`'s HTTP status-code → `ProviderError` mapping and
/// the org-id resolution (cookie short-circuit vs. /api/bootstrap fallback).
///
/// The provider is constructed with a stubbed `URLSession` (MockURLProtocol)
/// and an isolated `AuthService` seeded with a cookie, so no real network or
/// keychain item is touched.
final class ClaudeProviderTests: XCTestCase {

    private let orgId = "11111111-1111-1111-1111-111111111111"

    private let usageJSON = """
    { "five_hour": { "utilization": 42.5, "resets_at": "2026-05-18T10:00:00Z" } }
    """.data(using: .utf8)!

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// An AuthService seeded with a cookie. When `includeOrg` is true the cookie
    /// carries `lastActiveOrg`, so the provider resolves the org id without a
    /// bootstrap round-trip.
    private func makeAuth(includeOrg: Bool) -> AuthService {
        let auth = AuthService(store: KeychainStore(service: "com.notchylimit.tests.\(UUID().uuidString)"))
        let base = "sessionKey=" + String(repeating: "x", count: 64)
        let cookie = includeOrg ? "\(base); lastActiveOrg=\(orgId)" : base
        auth.saveClaudeCredential(ClaudeCredential(cookie: cookie))
        return auth
    }

    private func makeProvider(includeOrg: Bool = true) -> ClaudeProvider {
        ClaudeProvider(session: MockURLProtocol.makeSession(), auth: makeAuth(includeOrg: includeOrg))
    }

    private func assertThrows(_ expected: ProviderError,
                              _ body: () async throws -> Void) async {
        do {
            try await body()
            XCTFail("expected \(expected) to be thrown")
        } catch let error as ProviderError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("expected ProviderError, got \(error)")
        }
    }

    // MARK: - success

    func test_fetchUsage_success_parsesSnapshot() async throws {
        MockURLProtocol.requestHandler = { request in
            (MockURLProtocol.response(request.url!, 200), self.usageJSON)
        }
        let snapshot = try await makeProvider().fetchUsage()
        XCTAssertEqual(snapshot.providerId, .claude)
        XCTAssertEqual(snapshot.primaryWindow.percentUsed, 0.425, accuracy: 0.001)
    }

    // MARK: - status-code mapping

    func test_fetchUsage_401_unauthorized() async {
        MockURLProtocol.requestHandler = { (MockURLProtocol.response($0.url!, 401), Data()) }
        await assertThrows(.unauthorized) { _ = try await self.makeProvider().fetchUsage() }
    }

    func test_fetchUsage_403_unauthorized() async {
        MockURLProtocol.requestHandler = { (MockURLProtocol.response($0.url!, 403), Data()) }
        await assertThrows(.unauthorized) { _ = try await self.makeProvider().fetchUsage() }
    }

    func test_fetchUsage_429_rateLimited() async {
        MockURLProtocol.requestHandler = { (MockURLProtocol.response($0.url!, 429), Data()) }
        await assertThrows(.rateLimited) { _ = try await self.makeProvider().fetchUsage() }
    }

    func test_fetchUsage_500_server() async {
        MockURLProtocol.requestHandler = { (MockURLProtocol.response($0.url!, 503), Data()) }
        await assertThrows(.server(503)) { _ = try await self.makeProvider().fetchUsage() }
    }

    func test_fetchUsage_unexpectedStatus_unknown() async {
        MockURLProtocol.requestHandler = { (MockURLProtocol.response($0.url!, 418), Data()) }
        await assertThrows(.unknown("HTTP 418")) { _ = try await self.makeProvider().fetchUsage() }
    }

    func test_fetchUsage_transportFailure() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await makeProvider().fetchUsage()
            XCTFail("expected a transport error")
        } catch let error as ProviderError {
            guard case .transport = error else { return XCTFail("expected .transport, got \(error)") }
        } catch {
            XCTFail("expected ProviderError, got \(error)")
        }
    }

    // MARK: - decoding

    func test_fetchUsage_malformedBody_decoding() async {
        MockURLProtocol.requestHandler = { ((MockURLProtocol.response($0.url!, 200)), Data("not json".utf8)) }
        do {
            _ = try await makeProvider().fetchUsage()
            XCTFail("expected a decoding error")
        } catch let error as ProviderError {
            guard case .decoding = error else { return XCTFail("expected .decoding, got \(error)") }
        } catch {
            XCTFail("expected ProviderError, got \(error)")
        }
    }

    // MARK: - missing credentials

    func test_fetchUsage_noCookie_missingCredentials() async {
        // Auth with no stored credential.
        let auth = AuthService(store: KeychainStore(service: "com.notchylimit.tests.\(UUID().uuidString)"))
        let provider = ClaudeProvider(session: MockURLProtocol.makeSession(), auth: auth)
        await assertThrows(.missingCredentials) { _ = try await provider.fetchUsage() }
    }

    // MARK: - org-id resolution via bootstrap

    func test_fetchUsage_resolvesOrgViaBootstrapWhenNotInCookie() async throws {
        MockURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            if path.contains("/api/bootstrap") {
                let body = #"{ "account": { "lastActiveOrgId": "\#(self.orgId)" } }"#.data(using: .utf8)!
                return (MockURLProtocol.response(request.url!, 200), body)
            }
            return (MockURLProtocol.response(request.url!, 200), self.usageJSON)
        }
        let snapshot = try await makeProvider(includeOrg: false).fetchUsage()
        XCTAssertEqual(snapshot.primaryWindow.percentUsed, 0.425, accuracy: 0.001)
    }

    func test_fetchUsage_bootstrapInvalidOrgId_decoding() async {
        MockURLProtocol.requestHandler = { request in
            // Non-UUID org id must be rejected (path-injection guard).
            let body = #"{ "account": { "lastActiveOrgId": "../../etc" } }"#.data(using: .utf8)!
            return (MockURLProtocol.response(request.url!, 200), body)
        }
        do {
            _ = try await makeProvider(includeOrg: false).fetchUsage()
            XCTFail("expected a decoding error for invalid org id")
        } catch let error as ProviderError {
            guard case .decoding = error else { return XCTFail("expected .decoding, got \(error)") }
        } catch {
            XCTFail("expected ProviderError, got \(error)")
        }
    }
}
