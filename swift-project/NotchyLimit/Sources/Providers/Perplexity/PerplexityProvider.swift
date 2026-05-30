import Foundation

// MARK: - Credential

/// Perplexity API key credential. Stored in Keychain — never in logs.
///
/// Perplexity's API (`api.perplexity.ai`) is OpenAI-compatible but exposes no
/// usage or billing read endpoint, so Notchy can only verify the key works and
/// surface a "Connected" status — not a spend/quota percentage.
public struct PerplexityCredential: Codable, Hashable {
    public var apiKey: String
    public var storedAt: Date
    public var lastValidatedAt: Date?

    public init(apiKey: String, storedAt: Date = Date(), lastValidatedAt: Date? = nil) {
        self.apiKey = apiKey
        self.storedAt = storedAt
        self.lastValidatedAt = lastValidatedAt
    }
}

// MARK: - Endpoint

/// Perplexity endpoints. There is no usage endpoint, so we validate the key
/// against `chat/completions` using a request that authenticates but generates
/// no completion (empty messages) — auth is evaluated before the body, so a
/// bad key 401s for free and a good key returns 400 without billing tokens.
enum PerplexityEndpoint {
    static let chatCompletionsURL = URL(string: "https://api.perplexity.ai/chat/completions")!

    static func headers(apiKey: String) -> [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "Accept":        "application/json",
            "Content-Type":  "application/json"
        ]
    }

    /// A body that authenticates without producing a billable completion.
    static let validationBody: Data = {
        let payload: [String: Any] = ["model": "sonar", "messages": []]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }()
}

// MARK: - Provider

/// Perplexity provider — connected-status only.
///
/// Auth: Perplexity API key (`pplx-…`) stored in Keychain.
/// `fetchUsage` returns a status-only snapshot because Perplexity has no
/// usage endpoint.
final class PerplexityProvider: UsageProvider {
    let id: ProviderId = .perplexity
    let displayName: String = "Perplexity"
    let requiresCookie: Bool = false
    let isAvailable: Bool = true

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func validateCredentials() async throws {
        try await probeKey()
    }

    func fetchUsage() async throws -> ServiceUsageSnapshot {
        try await probeKey()
        return .connected(providerId: .perplexity)
    }

    // MARK: - API

    /// Sends a zero-token validation request. Treats auth failures as
    /// `.unauthorized`; any non-auth response (incl. 400 from the empty body)
    /// means the key is valid and reachable.
    private func probeKey() async throws {
        let apiKey = try currentAPIKey()
        var request = URLRequest(
            url: PerplexityEndpoint.chatCompletionsURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "POST"
        for (k, v) in PerplexityEndpoint.headers(apiKey: apiKey) {
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.httpBody = PerplexityEndpoint.validationBody

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw ProviderError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.unknown("non-HTTP response")
        }
        switch http.statusCode {
        case 401, 403: throw ProviderError.unauthorized
        case 429:      throw ProviderError.rateLimited
        case 500...:   throw ProviderError.server(http.statusCode)
        // 200/400/422 etc. — key authenticated successfully.
        default:       return
        }
    }

    private func currentAPIKey() throws -> String {
        guard let cred: PerplexityCredential = AuthService.shared.loadCredential(for: .perplexity),
              !cred.apiKey.isEmpty else {
            throw ProviderError.missingCredentials
        }
        return cred.apiKey
    }
}
