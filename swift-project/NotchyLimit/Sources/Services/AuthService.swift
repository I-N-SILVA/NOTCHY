import Foundation

/// Provider-credential storage. Backed by macOS Keychain.
public final class AuthService {
    public static let shared = AuthService()
    private init() {}

    private let store = KeychainStore(service: "com.notchylimit.NotchyLimit")

    // MARK: - Generic

    public func hasCredential(for providerId: ProviderId) -> Bool {
        store.get(account: providerId.rawValue) != nil
    }

    public func hasAnyConfiguredProvider() -> Bool {
        ProviderId.allCases.contains { hasCredential(for: $0) }
    }

    public func clearCredential(for providerId: ProviderId) {
        store.delete(account: providerId.rawValue)
    }

    // MARK: - Claude

    /// Sanitizes, validates, then stores the credential.
    /// Returns a user-facing error string if validation fails, nil on success.
    @discardableResult
    public func saveClaudeCredential(_ credential: ClaudeCredential) -> String? {
        let trimmed = credential.cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Cookie cannot be empty."
        }
        guard trimmed.count >= 32 else {
            return "Cookie looks too short. Paste the full Cookie header from DevTools."
        }
        guard trimmed.count <= 65_536 else {
            return "That doesn't look right — it's too long. Copy only the Cookie header value."
        }
        // Cookies never belong in logs — sanitize before any storage.
        let sanitized = ClaudeCredential(
            cookie: trimmed,
            storedAt: credential.storedAt,
            lastValidatedAt: credential.lastValidatedAt
        )
        guard let data = try? JSONEncoder().encode(sanitized) else {
            return "Failed to encode credential."
        }
        store.set(account: ProviderId.claude.rawValue, data: data)
        return nil
    }

    /// Generic load. Returns the decoded credential of type `T` if present.
    public func loadCredential<T: Decodable>(for providerId: ProviderId) -> T? {
        guard let data = store.get(account: providerId.rawValue) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
