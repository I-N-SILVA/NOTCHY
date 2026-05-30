import Foundation

// MARK: - Domain

/// Severity of a provider's current service status, mapped from statuspage.io's
/// `status.indicator` field.
public enum IncidentLevel: String, Codable, Hashable {
    case none
    case minor
    case major
    case critical
    case maintenance

    public init(indicator: String?) {
        switch indicator?.lowercased() {
        case "minor":       self = .minor
        case "major":       self = .major
        case "critical":    self = .critical
        case "maintenance": self = .maintenance
        default:            self = .none   // "none" or anything unexpected
        }
    }

    /// True when there's an active incident worth badging in the UI.
    public var isActive: Bool { self != .none }

    public var defaultSummary: String {
        switch self {
        case .none:        return "All systems operational"
        case .minor:       return "Minor service issue"
        case .major:       return "Major outage"
        case .critical:    return "Critical outage"
        case .maintenance: return "Under maintenance"
        }
    }
}

/// A point-in-time read of a provider's status page.
public struct ServiceIncident: Hashable, Codable {
    public let level: IncidentLevel
    public let summary: String
    public let checkedAt: Date

    public init(level: IncidentLevel, summary: String, checkedAt: Date = Date()) {
        self.level = level
        self.summary = summary
        self.checkedAt = checkedAt
    }
}

// MARK: - StatusPage client

/// Reads a statuspage.io-backed status page. The `/api/v2/status.json` shape is
/// shared across every statuspage.io instance (Anthropic, OpenAI, ElevenLabs, …).
final class StatusPageService {
    static let shared = StatusPageService()

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    private struct StatusPageDTO: Decodable {
        struct Status: Decodable {
            let indicator: String?
            let description: String?
        }
        let status: Status
    }

    /// Fetches the current status. Returns nil if the page is unreachable or the
    /// payload doesn't parse — callers treat nil as "no information", not an outage.
    func fetchIncident(baseURL: URL) async -> ServiceIncident? {
        let url = baseURL.appendingPathComponent("api/v2/status.json")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard
            let (data, response) = try? await session.data(for: request),
            let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
            let dto = try? JSONDecoder().decode(StatusPageDTO.self, from: data)
        else {
            return nil
        }

        let level = IncidentLevel(indicator: dto.status.indicator)
        let summary = dto.status.description?.isEmpty == false
            ? dto.status.description!
            : level.defaultSummary
        return ServiceIncident(level: level, summary: summary)
    }
}

// MARK: - Monitor

/// Polls the status pages of the enabled providers on a slow cadence and reports
/// incidents back via `onIncident`. Independent of auth — outages are public.
final class IncidentMonitor {
    static let shared = IncidentMonitor()
    private init() {}

    /// Called on the main actor whenever a provider's status is (re)read.
    var onIncident: ((ProviderId, ServiceIncident) -> Void)?

    private var task: Task<Void, Never>?
    private var providers: [ProviderId] = []
    private var interval: TimeInterval = 300

    func start(providers: [ProviderId], interval: TimeInterval = 300) {
        stop()
        self.providers = providers.filter { $0.statusPageBaseURL != nil }
        self.interval = max(120, interval)   // status pages don't need frequent polls
        guard !self.providers.isEmpty else { return }

        task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.pollOnce()
                try? await Task.sleep(nanoseconds: UInt64(self.interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func pollOnce() async {
        for provider in providers {
            guard let base = provider.statusPageBaseURL else { continue }
            guard let incident = await StatusPageService.shared.fetchIncident(baseURL: base) else { continue }
            await MainActor.run { [weak self] in
                self?.onIncident?(provider, incident)
            }
        }
    }
}
