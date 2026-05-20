import Foundation
import Combine

/// Owns the polling loop. Single-instance, holds no UI state.
/// Snapshots/errors are emitted via publishers consumed by `UsageCoordinator`.
///
/// Failure backoff: consecutive errors double the wait (capped at 1 hour).
/// A 429 rate-limit forces a minimum 5-minute backoff regardless of interval.
public final class UsageService {
    public static let shared = UsageService()
    private init() {}

    public let snapshotPublisher = PassthroughSubject<ServiceUsageSnapshot, Never>()
    public let errorPublisher    = PassthroughSubject<ProviderError, Never>()

    private var pollTask: Task<Void, Never>?
    private(set) var intervalSeconds: TimeInterval = 300
    private(set) var activeProviderId: ProviderId = .claude

    private var consecutiveErrors: Int = 0

    public func start(providerId: ProviderId, interval: TimeInterval) {
        stop()
        activeProviderId = providerId
        intervalSeconds = max(60, interval)
        consecutiveErrors = 0
        pollTask = Task { [weak self] in
            guard let self = self else { return }
            await self.fetchOnce()
            while !Task.isCancelled {
                let wait = self.backoffInterval()
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                if Task.isCancelled { break }
                await self.fetchOnce()
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func refreshNow() {
        Task { await fetchOnce() }
    }

    public func updateInterval(_ seconds: TimeInterval) {
        intervalSeconds = max(60, seconds)
        start(providerId: activeProviderId, interval: intervalSeconds)
    }

    // MARK: - Backoff

    /// Returns the next wait interval, doubling on consecutive errors (cap: 3600s).
    /// Rate-limit (429) forces at least 300s regardless of the configured interval.
    private func backoffInterval() -> TimeInterval {
        guard consecutiveErrors > 0 else { return intervalSeconds }
        let backoff = intervalSeconds * pow(2.0, Double(min(consecutiveErrors, 6)))
        return min(backoff, 3600)
    }

    // MARK: - Fetch

    private func fetchOnce() async {
        guard let provider = ProviderRegistry.shared.provider(for: activeProviderId) else {
            await publish(error: .unknown("No provider registered for \(activeProviderId.rawValue)"))
            return
        }
        do {
            let snapshot = try await provider.fetchUsage()
            consecutiveErrors = 0
            await publish(snapshot: snapshot)
        } catch let error as ProviderError {
            consecutiveErrors += 1
            if case .rateLimited = error {
                // Ensure backoff is at least 300s on rate limit.
                consecutiveErrors = max(consecutiveErrors, Int(ceil(log2(300 / intervalSeconds + 1))))
            }
            await publish(error: error)
        } catch {
            consecutiveErrors += 1
            // localizedDescription may contain system paths or request URLs — discard it.
            await publish(error: .unknown("unexpected"))
        }
    }

    @MainActor
    private func publish(snapshot: ServiceUsageSnapshot) {
        snapshotPublisher.send(snapshot)
    }

    @MainActor
    private func publish(error: ProviderError) {
        errorPublisher.send(error)
    }
}
