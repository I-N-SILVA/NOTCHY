import XCTest
@testable import NotchyLimit

/// Tests for `ClaudeUsageMapper` — raw DTO → unified domain snapshot.
final class ClaudeUsageMapperTests: XCTestCase {

    // Happy path: all three windows present.
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

    // Fractional-seconds timestamps (matches docs/samples/claude_usage.json) parse too.
    func test_snapshot_parsesFractionalSecondsReset() throws {
        let json = """
        { "five_hour": { "utilization": 10.0, "resets_at": "2026-05-14T18:30:00.000Z" } }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ClaudeUsageDTO.self, from: json)
        let snapshot = try ClaudeUsageMapper.snapshot(from: dto)
        XCTAssertNotNil(snapshot.primaryWindow.resetAt)
    }

    // Missing five_hour → decoding error.
    func test_snapshot_throwsWhenFiveHourMissing() throws {
        let json = """
        { "seven_day": { "utilization": 61.0, "resets_at": "2026-05-25T00:00:00Z" } }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ClaudeUsageDTO.self, from: json)
        XCTAssertThrowsError(try ClaudeUsageMapper.snapshot(from: dto)) { error in
            guard case ProviderError.decoding = error else {
                return XCTFail("Expected ProviderError.decoding, got \(error)")
            }
        }
    }

    // Null utilization on five_hour → decoding error.
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

    // Missing optional windows → secondaryWindow and tertiaryWindow are nil.
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

    // A present seven_day window with null utilization defaults to 0%.
    func test_snapshot_weeklyNullUtilizationDefaultsToZero() throws {
        let json = """
        {
          "five_hour": { "utilization": 10.0, "resets_at": null },
          "seven_day": { "resets_at": null }
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(ClaudeUsageDTO.self, from: json)
        let snapshot = try ClaudeUsageMapper.snapshot(from: dto)
        XCTAssertEqual(snapshot.secondaryWindow?.percentUsed, 0.0)
    }
}
