import Foundation

// MARK: - Credential

/// ElevenLabs API key credential. Stored in Keychain — never in logs.
public struct ElevenLabsCredential: Codable, Hashable {
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

/// ElevenLabs subscription endpoint. `GET /v1/user/subscription` returns the
/// character usage and limit for the current billing period — a real usage %.
/// Auth uses the `xi-api-key` header (not Bearer).
enum ElevenLabsEndpoint {
    static let subscriptionURL = URL(string: "https://api.elevenlabs.io/v1/user/subscription")!

    static func headers(apiKey: String) -> [String: String] {
        [
            "xi-api-key": apiKey,
            "Accept":     "application/json"
        ]
    }
}

// MARK: - DTO + Mapper

struct ElevenLabsSubscriptionDTO: Decodable {
    let characterCount: Int?
    let characterLimit: Int?
    let nextResetUnix: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case characterCount = "character_count"
        case characterLimit = "character_limit"
        case nextResetUnix  = "next_character_count_reset_unix"
    }
}

enum ElevenLabsUsageMapper {
    static func snapshot(_ dto: ElevenLabsSubscriptionDTO, capturedAt: Date = Date()) throws -> ServiceUsageSnapshot {
        let limit = Double(dto.characterLimit ?? 0)
        guard limit > 0 else {
            throw ProviderError.decoding("character_limit is zero or missing")
        }
        let used = Double(dto.characterCount ?? 0)
        let resetAt = dto.nextResetUnix.map { Date(timeIntervalSince1970: $0) }

        let window = UsageWindow(
            type: .monthly,
            percentUsed: used / limit,
            usedAmount: used,
            limitAmount: limit,
            resetAt: resetAt,
            lastUpdated: capturedAt
        )
        return ServiceUsageSnapshot(
            providerId: .elevenlabs,
            primaryWindow: window,
            capturedAt: capturedAt
        )
    }
}

// MARK: - Provider

/// ElevenLabs provider. Shows characters used vs. the monthly character limit.
final class ElevenLabsProvider: UsageProvider {
    let id: ProviderId = .elevenlabs
    let displayName: String = "ElevenLabs"
    let requiresCookie: Bool = false
    let isAvailable: Bool = true

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func validateCredentials() async throws {
        _ = try await fetchSubscription()
    }

    func fetchUsage() async throws -> ServiceUsageSnapshot {
        let dto = try await fetchSubscription()
        return try ElevenLabsUsageMapper.snapshot(dto)
    }

    private func fetchSubscription() async throws -> ElevenLabsSubscriptionDTO {
        let data = try await get(url: ElevenLabsEndpoint.subscriptionURL)
        do {
            return try JSONDecoder().decode(ElevenLabsSubscriptionDTO.self, from: data)
        } catch {
            throw ProviderError.decoding("subscription parse: \(error.localizedDescription)")
        }
    }

    private func get(url: URL) async throws -> Data {
        let apiKey = try currentAPIKey()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        for (k, v) in ElevenLabsEndpoint.headers(apiKey: apiKey) {
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
        case 200..<300: return data
        case 401, 403:  throw ProviderError.unauthorized
        case 429:       throw ProviderError.rateLimited
        case 500...:    throw ProviderError.server(http.statusCode)
        default:        throw ProviderError.unknown("HTTP \(http.statusCode)")
        }
    }

    private func currentAPIKey() throws -> String {
        guard let cred: ElevenLabsCredential = AuthService.shared.loadCredential(for: .elevenlabs),
              !cred.apiKey.isEmpty else {
            throw ProviderError.missingCredentials
        }
        return cred.apiKey
    }
}
