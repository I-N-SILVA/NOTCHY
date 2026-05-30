import Foundation

/// OpenAI provider. Uses the billing dashboard API to show monthly spend
/// as a percentage of the user's configured hard spending limit.
///
/// Auth: standard `sk-...` API key stored in Keychain.
/// Primary metric: `total_usage` (cents) / `hard_limit_usd` → percentage.
final class OpenAIProvider: UsageProvider {
    let id: ProviderId = .openai
    let displayName: String = "OpenAI"
    let requiresCookie: Bool = false
    let isAvailable: Bool = true

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - UsageProvider

    func validateCredentials() async throws {
        _ = try await fetchSubscription()
    }

    func fetchUsage() async throws -> ServiceUsageSnapshot {
        async let sub  = fetchSubscription()
        async let usage = fetchCurrentMonthUsage()
        return try await OpenAIUsageMapper.snapshot(subscription: sub, usage: usage)
    }

    // MARK: - API calls

    private func fetchSubscription() async throws -> OpenAISubscriptionDTO {
        let data = try await get(url: OpenAIEndpoint.subscriptionURL)
        do {
            return try JSONDecoder().decode(OpenAISubscriptionDTO.self, from: data)
        } catch {
            throw ProviderError.decoding("subscription parse: \(error.localizedDescription)")
        }
    }

    private func fetchCurrentMonthUsage() async throws -> OpenAIUsageDTO {
        let (start, end) = currentBillingWindow()
        let url = OpenAIEndpoint.usageURL(startDate: start, endDate: end)
        let data = try await get(url: url)
        do {
            return try JSONDecoder().decode(OpenAIUsageDTO.self, from: data)
        } catch {
            throw ProviderError.decoding("usage parse: \(error.localizedDescription)")
        }
    }

    // MARK: - HTTP

    private func get(url: URL) async throws -> Data {
        let apiKey = try currentAPIKey()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        for (k, v) in OpenAIEndpoint.headers(apiKey: apiKey) {
            request.setValue(v, forHTTPHeaderField: k)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProviderError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.unknown("non-HTTP response")
        }
        switch http.statusCode {
        case 200..<300:    return data
        case 401, 403:     throw ProviderError.unauthorized
        case 404, 410:     throw ProviderError.decoding("OpenAI billing endpoint unavailable — API may have changed")
        case 429:          throw ProviderError.rateLimited
        case 500...:       throw ProviderError.server(http.statusCode)
        default:           throw ProviderError.unknown("HTTP \(http.statusCode)")
        }
    }

    private func currentAPIKey() throws -> String {
        guard let cred: OpenAICredential = AuthService.shared.loadCredential(for: .openai),
              !cred.apiKey.isEmpty else {
            throw ProviderError.missingCredentials
        }
        return cred.apiKey
    }

    // MARK: - Date helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func currentBillingWindow() -> (start: String, end: String) {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        var comps = cal.dateComponents([.year, .month], from: now)
        let start = cal.date(from: comps)!
        comps.month! += 1
        let end = cal.date(from: comps)!
        return (
            OpenAIProvider.dateFormatter.string(from: start),
            OpenAIProvider.dateFormatter.string(from: end)
        )
    }
}
