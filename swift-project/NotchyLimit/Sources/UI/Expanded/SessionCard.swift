import SwiftUI

/// Hero session card. Dominates the top of the expanded panel.
///
/// Left: StatusRingView arc showing session %.
/// Right: Giant percentage number (hero) + reset countdown + pace label.
/// Background tinted by status colour so the whole card "is" the status.
struct SessionCard: View {
    @ObservedObject var appState: AppState
    @State private var displayedPercent: Int = 0
    @State private var animationEpoch: Int = 0

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Ring + mascot composited as one widget.
            // The mascot face sits centered inside the arc ring —
            // the ring becomes its mood aura.
            ZStack {
                StatusRingView(
                    progress: appState.sessionPercent,
                    color: statusColor,
                    size: 72
                )
                RetroMascot(size: 32, usagePercent: appState.sessionPercent)
            }

            VStack(alignment: .leading, spacing: 3) {
                // Hero number — rolls to new value like a counter
                Text("\(displayedPercent)%")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .onAppear { animateTo(Int((appState.sessionPercent * 100).rounded())) }
                    .onChange(of: appState.sessionPercent) { newVal in
                        animateTo(Int((newVal * 100).rounded()))
                    }

                // Reset countdown — the thing people actually want to see
                if let reset = appState.sessionResetString {
                    Text(reset)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                }

                // Pace context
                Text(paceLabel)
                    .font(Theme.captionFont)
                    .foregroundColor(statusColor.opacity(0.75))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(statusColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(statusColor.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var statusColor: Color { appState.sessionStatus.color }

    /// Animate the displayed integer from its current value to `target`,
    /// stepping every ~16 ms so it feels like a rolling counter.
    /// The epoch check cancels any in-flight animation when a new value arrives.
    private func animateTo(_ target: Int) {
        let start    = displayedPercent
        let delta    = target - start
        guard delta != 0 else { return }
        let steps    = max(abs(delta), 1)
        let interval = min(0.6 / Double(steps), 0.04)
        var current  = start
        animationEpoch += 1
        let epoch    = animationEpoch
        func step() {
            guard current != target, animationEpoch == epoch else { return }
            current += delta > 0 ? 1 : -1
            displayedPercent = current
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) { step() }
        }
        step()
    }

    private var paceLabel: String {
        if appState.isAtSessionLimit { return "Session limit reached" }
        switch appState.sessionStatus {
        case .critical: return "Heavy usage — consider pausing"
        case .warning:  return "Approaching limit"
        case .healthy:  return "On track"
        case .unknown:  return "Waiting for first sync…"
        }
    }
}
