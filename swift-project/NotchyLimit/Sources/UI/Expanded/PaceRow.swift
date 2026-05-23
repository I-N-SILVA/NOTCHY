import SwiftUI

/// Simple pace indicator. Today this is a derived label off session pct.
/// Later it can compare today's usage to a rolling average.
struct PaceRow: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: paceIcon)
                .foregroundColor(paceColor)
            Text(paceLabel)
                .font(Theme.captionFont)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var paceLabel: String {
        if appState.isAtSessionLimit { return "Session blocked — awaiting reset." }
        switch appState.sessionStatus {
        case .critical: return "Heavy usage — consider pausing."
        case .warning:  return "Slightly above pace."
        case .healthy:  return "On track."
        case .unknown:  return "Waiting for first sync…"
        }
    }

    private var paceIcon: String {
        switch appState.sessionStatus {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning:  return "hare.fill"
        case .healthy:  return "tortoise.fill"
        case .unknown:  return "clock"
        }
    }

    private var paceColor: Color {
        appState.sessionStatus.color
    }
}
