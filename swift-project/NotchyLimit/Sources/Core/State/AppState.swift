import Foundation
import Combine
import SwiftUI

/// Single source of truth for UI state. Backed by `@Published` properties so
/// any SwiftUI view bound to it reacts instantly.
public final class AppState: ObservableObject {
    // Active provider snapshot
    @Published public var activeProviderId: ProviderId = .claude
    @Published public var latestSnapshot: ServiceUsageSnapshot?
    @Published public var authStatus: AuthStatus = .notConfigured
    @Published public var syncStatus: SyncStatus = .idle

    // UI state
    @Published public var notchState: NotchState = .compactIdle
    @Published public var showOnboarding: Bool = false
    @Published public var showSettings: Bool = false
    @Published public var showDiagnostics: Bool = false

    // Settings
    @Published public var pollIntervalSeconds: TimeInterval = 300
    @Published public var notificationsEnabled: Bool = true
    @Published public var thresholds: [Double] = [0.25, 0.5, 0.75, 0.9, 1.0]
    @Published public var launchAtLogin: Bool = false

    // Convenience accessors used by views
    public var sessionPercent: Double {
        latestSnapshot?.primaryWindow.percentUsed ?? 0
    }

    public var sessionStatus: UsageStatus {
        latestSnapshot?.primaryWindow.status ?? .unknown
    }

    public var sessionResetString: String? {
        latestSnapshot?.primaryWindow.timeToResetString()
    }

    public var isAtSessionLimit: Bool {
        sessionPercent >= 1.0
    }

    /// Compact reset countdown for the pill, e.g. "1h 12m".
    public var sessionResetShortString: String? {
        latestSnapshot?.primaryWindow.timeToResetShortString()
    }

    public init() {}
}
