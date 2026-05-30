import Foundation

/// OpenAI billing dashboard endpoints.
///
/// These endpoints are used by the OpenAI web dashboard. They require a standard
/// `sk-...` API key sent as `Authorization: Bearer <key>`.
///
/// Note: OpenAI has been migrating their billing API. If an endpoint returns
/// 404 or 410, `OpenAIProvider` gracefully surfaces a "endpoint unavailable" error
/// rather than crashing — allowing us to update the URL without a forced upgrade.
enum OpenAIEndpoint {
    static let subscriptionURL = URL(string: "https://api.openai.com/v1/dashboard/billing/subscription")!

    static func usageURL(startDate: String, endDate: String) -> URL {
        var c = URLComponents(string: "https://api.openai.com/v1/dashboard/billing/usage")!
        c.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        return c.url!
    }

    static func headers(apiKey: String) -> [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "Accept":        "application/json",
            "Content-Type":  "application/json"
        ]
    }
}
