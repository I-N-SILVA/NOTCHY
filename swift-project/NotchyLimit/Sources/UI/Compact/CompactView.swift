import SwiftUI

/// Compact island pill.
///
/// The panel that hosts this view is taller than what's visible: the top
/// `safeAreaInsets.top` points sit inside the physical notch hardware
/// (invisible — black fill blends with the camera housing).  Content is
/// pushed to the bottom of the view with a Spacer so it appears in the
/// visible 22 pt strip just below the notch.  The result looks like the
/// notch grew a thin glowing status strip — identical to the Dynamic Island.
struct CompactView: View {
    @ObservedObject var appState: AppState
    @State private var appeared   = false
    @State private var glowPulse  = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-height black fill — top portion invisible (inside notch).
            NotchPillShape(topRadius: 0, bottomRadius: 14)
                .fill(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Visible content strip (bottom 22 pt, below the notch edge).
            HStack(spacing: 7) {
                // Status dot with ambient pulse
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(glowPulse ? 0.32 : 0.12))
                        .frame(width: 12, height: 12)
                        .blur(radius: 3)
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                }

                // Animated progress bar
                CompactProgressBar(progress: appState.sessionPercent, color: statusColor)
                    .frame(height: 3)

                // Percentage — or reset countdown when the session is blocked
                if appState.isAtSessionLimit {
                    Text(appState.sessionResetShortString ?? "LIMIT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(minWidth: 40, alignment: .trailing)
                } else {
                    Text("\(Int((appState.sessionPercent * 100).rounded()))%")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.88))
                        .frame(minWidth: 25, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 22)
        }
        // Colour glow below the island echoes the current usage status.
        .shadow(color: statusColor.opacity(appeared ? 0.40 : 0), radius: 10, y: 5)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.22)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true).delay(0.6)) {
                glowPulse = true
            }
        }
        .help(appState.sessionResetString ?? "Notchy Limit")
    }

    private var statusColor: Color { appState.sessionStatus.color }
}
