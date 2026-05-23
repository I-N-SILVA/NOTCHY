import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Settings")
                        .font(Theme.displayFont)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button("Done") { dismiss() }.keyboardShortcut(.return)
                }

                TabView {
                    providersTab.tabItem { Label("Providers", systemImage: "square.grid.2x2") }
                    notificationsTab.tabItem { Label("Notifications", systemImage: "bell") }
                    advancedTab.tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
                }
            }
            .padding(20)
        }
    }

    private var providersTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ProviderId.allCases, id: \.self) { p in
                HStack {
                    Text(p.displayName).foregroundColor(Theme.textPrimary)
                    Spacer()
                    if !p.isAvailable {
                        Text("Coming soon").font(Theme.captionFont).foregroundColor(Theme.textSecondary)
                    } else if AuthService.shared.hasCredential(for: p) {
                        Button("Replace cookie") { appState.showOnboarding = true }
                            .buttonStyle(.bordered)
                        Button("Remove") {
                            AuthService.shared.clearCredential(for: p)
                            appState.authStatus = .notConfigured
                            appState.latestSnapshot = nil
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(Theme.statusCritical)
                    } else {
                        Button("Set up") { appState.showOnboarding = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var notificationsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable threshold notifications", isOn: $appState.notificationsEnabled)
                .toggleStyle(.switch)
                .foregroundColor(Theme.textPrimary)
            Text("Thresholds (percent of session)")
                .font(Theme.captionFont)
                .foregroundColor(Theme.textSecondary)
            HStack(spacing: 8) {
                ForEach([0.25, 0.5, 0.75, 0.9, 1.0], id: \.self) { t in
                    let on = appState.thresholds.contains(t)
                    Button("\(Int(t * 100))%") {
                        if on { appState.thresholds.removeAll(where: { $0 == t }) }
                        else  { appState.thresholds.append(t) }
                    }
                    .buttonStyle(.bordered)
                    .tint(on ? Theme.accentWarm : Theme.textSecondary)
                }
            }
            Button("Send test notification") {
                NotificationService.shared.sendTest()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Poll every")
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Picker("Poll every", selection: $appState.pollIntervalSeconds) {
                    Text("1 min").tag(TimeInterval(60))
                    Text("5 min").tag(TimeInterval(300))
                    Text("15 min").tag(TimeInterval(900))
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            .onChange(of: appState.pollIntervalSeconds) { newValue in
                UsageService.shared.updateInterval(newValue)
            }

            if #available(macOS 13.0, *) {
                Toggle("Launch at login", isOn: $appState.launchAtLogin)
                    .toggleStyle(.switch)
                    .foregroundColor(Theme.textPrimary)
            }

            Button("Open Diagnostics") { appState.showDiagnostics = true }
                .buttonStyle(.bordered)

            Divider().background(Theme.stroke)

            Button("Quit Notchy Limit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .foregroundColor(Theme.statusCritical)

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
