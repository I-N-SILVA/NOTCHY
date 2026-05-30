import Foundation

/// Which authentication mechanism is active for Claude.
/// Used in diagnostics and onboarding hints only — never persisted,
/// since the active tier is resolved at runtime on every fetch.
public enum ClaudeAuthTier: String {
    /// OAuth token from `~/.claude/credentials.json` (Claude CLI / desktop app).
    /// Scoped + short-lived. Preferred because blast radius is much smaller
    /// than the full session cookie.
    case oauth
    /// Full browser session cookie pasted by the user.
    /// Grants full account access — use only when OAuth is unavailable.
    case cookie
}

/// Credential bundle for Claude. Stores the browser session cookie as a fallback.
/// When `~/.claude/credentials.json` is present the cookie may never be used —
/// see `ClaudeOAuthCredential` and `ClaudeAuthTier`.
///
/// We store the entire cookie string (not just `sessionKey=...`) because
/// `claude.ai`'s usage endpoint also reads `lastActiveOrg` and other
/// hardening cookies. Treat this value as a secret — it is keychain-only.
public struct ClaudeCredential: Codable, Hashable {
    public var cookie: String
    public var storedAt: Date
    public var lastValidatedAt: Date?

    public init(cookie: String, storedAt: Date = Date(), lastValidatedAt: Date? = nil) {
        self.cookie = cookie
        self.storedAt = storedAt
        self.lastValidatedAt = lastValidatedAt
    }

    /// Extract `lastActiveOrg` value from the cookie string if present.
    ///
    /// Returns nil if the value is absent or is not a valid UUID.
    /// Rejecting non-UUID values prevents path injection when the result
    /// is interpolated into a URL in `ClaudeEndpoint.usage(orgId:)`.
    public var orgIdFromCookie: String? {
        for part in cookie.split(separator: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("lastActiveOrg=") {
                let value = String(trimmed.dropFirst("lastActiveOrg=".count))
                guard UUID(uuidString: value) != nil else { return nil }
                return value
            }
        }
        return nil
    }
}
