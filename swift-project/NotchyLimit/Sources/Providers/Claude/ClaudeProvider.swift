import Foundation

/// Claude provider. Cookie-based auth against the internal
/// `/api/organizations/{org}/usage` endpoint.
final class ClaudeProvider: UsageProvider {
    let id: ProviderId = .claude
    let displayName: String = "Claude"
    let requiresCookie: Bool = true
    let isAvailable: Bool = true

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - UsageProvider

    func validateCredentials() async throws {
        _ = try await resolveOrgId()
    }

    func fetchUsage() async throws -> ServiceUsageSnapshot {
        let orgId = try await resolveOrgId()
        let url = ClaudeEndpoint.usage(orgId: orgId)
        let data = try await get(url: url)

        do {
            let dto = try JSONDecoder().decode(ClaudeUsageDTO.self, from: data)
            return try ClaudeUsageMapper.snapshot(from: dto)
        } catch let providerError as ProviderError {
            throw providerError
        } catch {
            throw ProviderError.decoding(error.localizedDescription)
        }
    }

    // MARK: - Internals

    private func currentCookie() throws -> String {
        guard let cred: ClaudeCredential = AuthService.shared.loadCredential(for: .claude),
              !cred.cookie.isEmpty else {
            throw ProviderError.missingCredentials
        }
        return cred.cookie
    }

    /// Pull org id from the cookie if it contains `lastActiveOrg=`, otherwise
    /// fall back to `/api/bootstrap`.
    private func resolveOrgId() async throws -> String {
        let cookie = try currentCookie()
        if let inCookie = ClaudeCredential(cookie: cookie).orgIdFromCookie {
            return inCookie
        }
        let data = try await get(url: ClaudeEndpoint.bootstrap)
        do {
            let dto = try JSONDecoder().decode(ClaudeBootstrapDTO.self, from: data)
            guard let orgId = dto.account?.lastActiveOrgId,
                  UUID(uuidString: orgId) != nil else {
                throw ProviderError.decoding("bootstrap missing or invalid lastActiveOrgId")
            }
            return orgId
        } catch let providerError as ProviderError {
            throw providerError
        } catch {
            throw ProviderError.decoding("bootstrap parse failed: \(error.localizedDescription)")
        }
    }

    private func get(url: URL) async throws -> Data {
        let cookie = try currentCookie()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        for (k, v) in ClaudeEndpoint.headers(cookie: cookie) {
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
        case 401, 403: throw ProviderError.unauthorized
        case 429:      throw ProviderError.rateLimited
        case 500...:   throw ProviderError.server(http.statusCode)
        default:       throw ProviderError.unknown("HTTP \(http.statusCode)")
        }
    }
}
