import Foundation

/// Billing subscription — gives us the hard/soft spend limits.
struct OpenAISubscriptionDTO: Decodable {
    let hardLimitUSD: Double?
    let softLimitUSD: Double?
    let accessUntil: TimeInterval?   // unix timestamp — end of billing period

    enum CodingKeys: String, CodingKey {
        case hardLimitUSD  = "hard_limit_usd"
        case softLimitUSD  = "soft_limit_usd"
        case accessUntil   = "access_until"
    }
}

/// Monthly usage — gives us `total_usage` in **cents**.
struct OpenAIUsageDTO: Decodable {
    let totalUsageCents: Double?

    enum CodingKeys: String, CodingKey {
        case totalUsageCents = "total_usage"
    }
}

// MARK: - Mapper

enum OpenAIUsageMapper {
    static func snapshot(
        subscription: OpenAISubscriptionDTO,
        usage: OpenAIUsageDTO,
        capturedAt: Date = Date()
    ) throws -> ServiceUsageSnapshot {
        let hardLimit = subscription.hardLimitUSD ?? 0
        guard hardLimit > 0 else {
            throw ProviderError.decoding("hard_limit_usd is zero or missing")
        }

        let spentUSD   = (usage.totalUsageCents ?? 0) / 100.0
        let percentUsed = spentUSD / hardLimit

        // Billing period resets at `access_until` (end of current cycle)
        let resetAt: Date? = subscription.accessUntil.map { Date(timeIntervalSince1970: $0) }

        let monthly = UsageWindow(
            type: .monthly,
            percentUsed: percentUsed,
            usedAmount: spentUSD,
            limitAmount: hardLimit,
            resetAt: resetAt,
            lastUpdated: capturedAt
        )

        return ServiceUsageSnapshot(
            providerId: .openai,
            primaryWindow: monthly,
            capturedAt: capturedAt
        )
    }
}
