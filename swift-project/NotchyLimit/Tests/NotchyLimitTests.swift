import XCTest
@testable import NotchyLimit

// MARK: - ClaudeUsageMapper Tests

final class ClaudeUsageMappingTests: XCTestCase {

    // 1. Happy path: all three windows present.
    func test_snapshot_parsesAllWindows() throws {
        let json = """
        {
          "five_hour":        { "utilization": 42.5, "resets_at": "2026-05-18T10:00:00Z" },
          "seven_day":        { "utilization": 61.0, "resets_at": "2026-05-25T00:00:00Z" },
          "seven_day_sonnet": { "utilization": 28.0, "resets_at": "2026-05-25T00:00:00Z" }
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ClaudeUsageDTO.self, from: json)
        let snapshot = try ClaudeUsageMapper.snapshot(from: dto)

        XCTAssertEqual(snapshot.providerId, .claude)
        XCTAssertEqual(snapshot.primaryWindow.percentUsed, 0.425, accuracy: 0.001)
        XCTAssertEqual(snapshot.secondaryWindow?.percentUsed, 0.610, accuracy: 0.001)
        XCTAssertEqual(snapshot.tertiaryWindow?.percentUsed, 0.280, accuracy: 0.001)
        XCTAssertNotNil(snapshot.primaryWindow.resetAt)
    }

    // 2. Missing five_hour → decoding error.
    func test_snapshot_throwsWhenFiveHourMissing() throws {
        let json = """
        {
          "seven_day": { "utilization": 61.0, "resets_at": "2026-05-25T00:00:00Z" }
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ClaudeUsageDTO.self, from: json)
        XCTAssertThrowsError(try ClaudeUsageMapper.snapshot(from: dto)) { error in
            guard case ProviderError.decoding = error else {
                return XCTFail("Expected ProviderError.decoding, got \(error)")
            }
        }
    }

    // 3. Null utilization on five_hour → decoding error.
    func test_snapshot_throwsWhenUtilizationNull() throws {
        let json = """
        { "five_hour": { "resets_at": "2026-05-18T10:00:00Z" } }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ClaudeUsageDTO.self, from: json)
        XCTAssertThrowsError(try ClaudeUsageMapper.snapshot(from: dto)) { error in
            guard case ProviderError.decoding = error else {
                return XCTFail("Expected ProviderError.decoding, got \(error)")
            }
        }
    }

    // 4. Missing optional windows → secondaryWindow and tertiaryWindow are nil.
    func test_snapshot_optionalWindowsAreNil() throws {
        let json = """
        { "five_hour": { "utilization": 10.0, "resets_at": null } }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ClaudeUsageDTO.self, from: json)
        let snapshot = try ClaudeUsageMapper.snapshot(from: dto)

        XCTAssertNil(snapshot.secondaryWindow)
        XCTAssertNil(snapshot.tertiaryWindow)
        XCTAssertNil(snapshot.primaryWindow.resetAt)
    }
}

// MARK: - OpenAIUsageMapper Tests

final class OpenAIUsageMappingTests: XCTestCase {

    private func sub(hard: Double, accessUntil: TimeInterval? = nil) -> OpenAISubscriptionDTO {
        OpenAISubscriptionDTO(hardLimitUSD: hard, softLimitUSD: hard * 0.8, accessUntil: accessUntil)
    }

    private func usage(cents: Double) -> OpenAIUsageDTO {
        OpenAIUsageDTO(totalUsageCents: cents)
    }

    // 7. Happy path: $60 spent against $120 hard limit = 50%.
    func test_openai_happyPath_fiftyPercent() throws {
        let snapshot = try OpenAIUsageMapper.snapshot(
            subscription: sub(hard: 120.0),
            usage: usage(cents: 6000)   // $60.00
        )
        XCTAssertEqual(snapshot.providerId, .openai)
        XCTAssertEqual(snapshot.primaryWindow.type, .monthly)
        XCTAssertEqual(snapshot.primaryWindow.percentUsed, 0.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.primaryWindow.usedAmount ?? 0, 60.0, accuracy: 0.01)
        XCTAssertEqual(snapshot.primaryWindow.limitAmount ?? 0, 120.0, accuracy: 0.01)
        XCTAssertNil(snapshot.secondaryWindow)
    }

    // 8. Zero hard limit → decoding error (avoid division by zero).
    func test_openai_zeroHardLimit_throws() {
        XCTAssertThrowsError(try OpenAIUsageMapper.snapshot(
            subscription: sub(hard: 0),
            usage: usage(cents: 100)
        )) { error in
            guard case ProviderError.decoding = error else {
                return XCTFail("Expected ProviderError.decoding, got \(error)")
            }
        }
    }

    // 9. Nil hard limit → decoding error.
    func test_openai_nilHardLimit_throws() {
        let noLimit = OpenAISubscriptionDTO(hardLimitUSD: nil, softLimitUSD: nil, accessUntil: nil)
        XCTAssertThrowsError(try OpenAIUsageMapper.snapshot(
            subscription: noLimit,
            usage: usage(cents: 100)
        ))
    }

    // 10. Zero usage → 0% utilization.
    func test_openai_zeroUsage_zeroPercent() throws {
        let snapshot = try OpenAIUsageMapper.snapshot(
            subscription: sub(hard: 100.0),
            usage: usage(cents: 0)
        )
        XCTAssertEqual(snapshot.primaryWindow.percentUsed, 0.0, accuracy: 0.001)
    }

    // 11. Over-limit usage → percentUsed > 1.0 (not clamped — let UI decide).
    func test_openai_overLimit_exceedsOne() throws {
        let snapshot = try OpenAIUsageMapper.snapshot(
            subscription: sub(hard: 50.0),
            usage: usage(cents: 6000)   // $60 against $50 limit
        )
        XCTAssertGreaterThan(snapshot.primaryWindow.percentUsed, 1.0)
    }

    // 12. accessUntil present → resetAt is populated.
    func test_openai_accessUntil_populatesResetAt() throws {
        let future: TimeInterval = Date().timeIntervalSince1970 + 86400
        let snapshot = try OpenAIUsageMapper.snapshot(
            subscription: sub(hard: 100, accessUntil: future),
            usage: usage(cents: 1000)
        )
        XCTAssertNotNil(snapshot.primaryWindow.resetAt)
        XCTAssertEqual(
            snapshot.primaryWindow.resetAt!.timeIntervalSince1970,
            future,
            accuracy: 1.0
        )
    }

    // 13. Nil usage cents treated as 0 (API may omit it).
    func test_openai_nilUsageCents_treatedAsZero() throws {
        let noUsage = OpenAIUsageDTO(totalUsageCents: nil)
        let snapshot = try OpenAIUsageMapper.snapshot(
            subscription: sub(hard: 100),
            usage: noUsage
        )
        XCTAssertEqual(snapshot.primaryWindow.percentUsed, 0.0, accuracy: 0.001)
    }
}

// MARK: - ClaudeOAuthCredential Parsing Tests

final class ClaudeOAuthCredentialTests: XCTestCase {

    // 14. Standard claudeAiOauthToken field.
    func test_parse_claudeAiOauthToken_field() {
        let json = #"{"claudeAiOauthToken":"tok-abc123","expiresAt":9999999999999}"#.data(using: .utf8)!
        let cred = ClaudeOAuthCredential.parse(from: json)
        XCTAssertEqual(cred?.accessToken, "tok-abc123")
    }

    // 15. Falls back to accessToken field.
    func test_parse_accessToken_field() {
        let json = #"{"accessToken":"sk-ant-oauth01XYZ"}"#.data(using: .utf8)!
        let cred = ClaudeOAuthCredential.parse(from: json)
        XCTAssertEqual(cred?.accessToken, "sk-ant-oauth01XYZ")
    }

    // 16. Falls back to token field.
    func test_parse_token_field() {
        let json = #"{"token":"raw-token-value"}"#.data(using: .utf8)!
        let cred = ClaudeOAuthCredential.parse(from: json)
        XCTAssertEqual(cred?.accessToken, "raw-token-value")
    }

    // 17. Empty string token → nil.
    func test_parse_emptyToken_returnsNil() {
        let json = #"{"claudeAiOauthToken":""}"#.data(using: .utf8)!
        XCTAssertNil(ClaudeOAuthCredential.parse(from: json))
    }

    // 18. No token field → nil.
    func test_parse_missingToken_returnsNil() {
        let json = #"{"expiresAt":9999999999999}"#.data(using: .utf8)!
        XCTAssertNil(ClaudeOAuthCredential.parse(from: json))
    }

    // 19. Invalid JSON → nil.
    func test_parse_malformedJSON_returnsNil() {
        XCTAssertNil(ClaudeOAuthCredential.parse(from: Data("not json".utf8)))
    }

    // 20. Expiry as millisecond Unix timestamp (> 1e12).
    func test_parse_expiryMilliseconds() {
        // 9_999_999_999_000 ms = 9_999_999_999 s  (far future)
        let json = #"{"claudeAiOauthToken":"t","expiresAt":9999999999000}"#.data(using: .utf8)!
        let cred = ClaudeOAuthCredential.parse(from: json)
        XCTAssertNotNil(cred?.expiresAt)
        XCTAssertFalse(cred?.isLikelyExpired ?? true)
    }

    // 21. Expiry as second Unix timestamp.
    func test_parse_expirySeconds() {
        let future = Date().timeIntervalSince1970 + 3600
        let json = "{\"claudeAiOauthToken\":\"t\",\"expiresAt\":\(future)}".data(using: .utf8)!
        let cred = ClaudeOAuthCredential.parse(from: json)
        XCTAssertFalse(cred?.isLikelyExpired ?? true, "Token expires in 1 hour, should not be expired")
    }

    // 22. Expired token → isLikelyExpired is true.
    func test_parse_expiredToken_isLikelyExpired() {
        let past = Date().timeIntervalSince1970 - 3600
        let json = "{\"claudeAiOauthToken\":\"t\",\"expiresAt\":\(past)}".data(using: .utf8)!
        let cred = ClaudeOAuthCredential.parse(from: json)
        XCTAssertTrue(cred?.isLikelyExpired ?? false)
    }

    // 23. ISO-8601 expiry string.
    func test_parse_expiryISO8601String() {
        let json = #"{"claudeAiOauthToken":"t","expiresAt":"2099-01-01T00:00:00Z"}"#.data(using: .utf8)!
        let cred = ClaudeOAuthCredential.parse(from: json)
        XCTAssertNotNil(cred?.expiresAt)
        XCTAssertFalse(cred?.isLikelyExpired ?? true)
    }

    // 24. No expiresAt → expiresAt is nil, isLikelyExpired is false (assume valid).
    func test_parse_noExpiry_notExpired() {
        let json = #"{"claudeAiOauthToken":"t"}"#.data(using: .utf8)!
        let cred = ClaudeOAuthCredential.parse(from: json)
        XCTAssertNil(cred?.expiresAt)
        XCTAssertFalse(cred?.isLikelyExpired ?? true)
    }
}

// MARK: - NotificationService high-water mark tests

final class NotificationServiceEvaluateTests: XCTestCase {

    private let defaultsKey = "com.notchylimit.NotificationService.highWaterMark"
    private let thresholds: [Double] = [0.25, 0.5, 0.75, 0.9]

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private func snapshot(percent: Double) -> ServiceUsageSnapshot {
        ServiceUsageSnapshot(
            providerId: .claude,
            primaryWindow: UsageWindow(type: .session, percentUsed: percent,
                                       lastUpdated: Date()),
            secondaryWindow: nil,
            tertiaryWindow: nil,
            capturedAt: Date()
        )
    }

    private func mark() -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Double] ?? [:]
    }

    // 5a. Skipping thresholds: jumping from 0% to 76% records the 75% mark.
    func test_skippedThresholds_recordsHighestOnly() {
        let service = NotificationService.shared
        service.evaluate(snapshot: snapshot(percent: 0.76),
                         thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.75,
                       "mark should be 0.75 — the highest crossed threshold")
    }

    // 5b. Repeated polls at the same usage level fire nothing extra.
    func test_repeatedEvaluate_doesNotReFire() {
        let service = NotificationService.shared
        service.evaluate(snapshot: snapshot(percent: 0.76),
                         thresholds: thresholds, providerId: .claude)
        let markAfterFirst = mark()
        service.evaluate(snapshot: snapshot(percent: 0.76),
                         thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark(), markAfterFirst,
                       "mark must not change on a second evaluate at the same usage")
    }

    // 5c. Crossing a higher threshold on a later poll fires once more.
    func test_newHigher_threshold_fires() {
        let service = NotificationService.shared
        service.evaluate(snapshot: snapshot(percent: 0.76),
                         thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.75)
        service.evaluate(snapshot: snapshot(percent: 0.92),
                         thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.9,
                       "mark should advance to 0.9 when usage crosses 90%")
    }

    // 5d. Window reset: usage drops below the lowest threshold → mark clears.
    func test_windowReset_clearsMark() {
        let service = NotificationService.shared
        service.evaluate(snapshot: snapshot(percent: 0.76),
                         thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.75)
        service.evaluate(snapshot: snapshot(percent: 0.05),
                         thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0,
                       "mark should clear to 0 when usage drops below lowest threshold")
        service.evaluate(snapshot: snapshot(percent: 0.76),
                         thresholds: thresholds, providerId: .claude)
        XCTAssertEqual(mark()["claude:session"], 0.75,
                       "mark should advance again after window reset")
    }

    // 6. KeychainStore round-trip: write → read → delete.
    func test_keychainStore_roundTrip() {
        let store = KeychainStore(service: "com.notchylimit.tests.\(UUID().uuidString)")
        let payload = "test-payload-\(UUID().uuidString)".data(using: .utf8)!
        store.set(account: "roundtrip", data: payload)
        let read = store.get(account: "roundtrip")
        XCTAssertEqual(read, payload)
        let deleted = store.delete(account: "roundtrip")
        XCTAssertTrue(deleted)
        XCTAssertNil(store.get(account: "roundtrip"))
    }
}
