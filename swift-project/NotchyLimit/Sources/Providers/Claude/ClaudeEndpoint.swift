import Foundation

/// Constants for talking to claude.ai's internal usage endpoints.
///
/// These endpoints are NOT public API. They may change without notice.
/// All headers below mirror what the official `claude.ai` web app sends.
enum ClaudeEndpoint {
    static let bootstrap   = URL(string: "https://claude.ai/api/bootstrap")!

    /// Claude Code / Max-plan usage for an OAuth token (`sk-ant-oat…`). Returns
    /// the same `five_hour` / `seven_day` / `seven_day_sonnet` shape as the
    /// claude.ai endpoint, so `ClaudeUsageMapper` parses it unchanged.
    static let oauthUsage  = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    /// Headers the Claude Code CLI sends for the OAuth usage endpoint.
    static func oauthUsageHeaders(token: String) -> [String: String] {
        [
            "Authorization":  "Bearer \(token)",
            "Accept":         "application/json",
            "Content-Type":   "application/json",
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent":     "claude-code/2.1.69"
        ]
    }

    static func usage(orgId: String) -> URL {
        // Use URLComponents so the path is percent-encoded by the system,
        // preventing orgId content from escaping the intended path segment.
        var c = URLComponents()
        c.scheme = "https"
        c.host   = "claude.ai"
        c.path   = "/api/organizations/\(orgId)/usage"
        guard let url = c.url else {
            preconditionFailure("orgId produced an unparseable URL — validate before calling usage(orgId:)")
        }
        return url
    }

    /// Headers the official site sends. We replicate them to avoid being
    /// detected as a bot and getting served HTML instead of JSON.
    static func headers(cookie: String) -> [String: String] {
        [
            "Cookie":       cookie,
            "Accept":       "*/*",
            "Content-Type": "application/json",
            "Origin":       "https://claude.ai",
            "Referer":      "https://claude.ai",
            "User-Agent":   "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
                            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ]
    }

    /// Headers for OAuth Bearer token auth (Claude CLI credential).
    /// Smaller blast radius than the session cookie — use this when available.
    static func bearerHeaders(token: String) -> [String: String] {
        [
            "Authorization": "Bearer \(token)",
            "Accept":        "application/json",
            "Content-Type":  "application/json",
            "Origin":        "https://claude.ai",
            "Referer":       "https://claude.ai",
            "User-Agent":    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
                             "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ]
    }
}
