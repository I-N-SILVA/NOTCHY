import Foundation

/// OpenAI API key credential. Stored in Keychain — never in logs or UserDefaults.
///
/// The API key is used with OpenAI's billing dashboard endpoints to derive
/// monthly spend as a percentage of the user's configured hard limit.
public struct OpenAICredential: Codable, Hashable {
    public var apiKey: String
    public var storedAt: Date
    public var lastValidatedAt: Date?

    public init(apiKey: String, storedAt: Date = Date(), lastValidatedAt: Date? = nil) {
        self.apiKey = apiKey
        self.storedAt = storedAt
        self.lastValidatedAt = lastValidatedAt
    }
}
