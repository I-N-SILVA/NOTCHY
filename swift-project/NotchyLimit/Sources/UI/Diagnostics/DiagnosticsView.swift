import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Diagnostics")
                        .font(Theme.displayFont)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button("Close") { appState.showDiagnostics = false }.keyboardShortcut(.cancelAction)
                }

                row("Provider", appState.activeProviderId.displayName)
                row("Auth status", appState.authStatus.rawValue)
                row("Last sync", syncSummary)
                row("Session %", "\(Int((appState.sessionPercent * 100).rounded()))")
                row("Resets at", appState.latestSnapshot?.primaryWindow.resetAt?.description ?? "—")
                row("App version", Bundle.main.shortVersion)

                Spacer()
                Text("Cookies and credentials are never logged here.")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(20)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(Theme.captionFont).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private var syncSummary: String {
        switch appState.syncStatus {
        case .idle:           return "idle"
        case .syncing:        return "syncing…"
        case .ok(let at):     return "OK — \(at.description)"
        case .error(let e):   return "ERROR — \(e.description)"
        }
    }
}

private extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }
}
