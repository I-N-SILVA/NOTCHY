import SwiftUI
import AppKit

/// Five-step onboarding: Welcome → Provider → Cookie → Validate → Notifications.
struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .welcome
    @State private var cookieInput: String = ""
    @State private var validating: Bool = false
    @State private var validateError: String?

    enum Step: Int, CaseIterable { case welcome, provider, cookie, validate, notifications }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    RetroMascot(size: 32)
                    Text("Welcome to Notchy Limit")
                        .font(Theme.displayFont)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button("Skip") { dismiss() }
                        .buttonStyle(.borderless)
                        .foregroundColor(Theme.textSecondary)
                }
                progressDots
                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .provider: providerStep
                    case .cookie: cookieStep
                    case .validate: validateStep
                    case .notifications: notificationsStep
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                navButtons
            }
            .padding(20)
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { s in
                Circle()
                    .fill(s == step ? Theme.accentWarm : Theme.stroke)
                    .frame(width: 7, height: 7)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("See your Claude limits at a glance.")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("A tiny pill lives in your notch. Hover for details. Everything stays on your Mac.")
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textSecondary)
            }

            // Live preview of the compact pill so users know exactly what they'll see
            VStack(spacing: 8) {
                Text("This will live in your notch:")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 0) {
                    // Simulated notch hardware (black bar above)
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black)
                            .frame(width: 130, height: 22)
                            .overlay(
                                Text("camera")
                                    .font(.system(size: 7))
                                    .foregroundColor(Color.white.opacity(0.15))
                            )
                        // The pill preview extending below
                        OnboardingPillPreview()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Text("Hover it to expand. Click to pin.")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.stroke))
            )
        }
    }

    private var providerStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose a provider")
                .font(.title3.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
            ForEach(ProviderId.allCases, id: \.self) { p in
                HStack {
                    Text(p.displayName).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text(p.isAvailable ? "Available" : "Coming soon")
                        .font(Theme.captionFont)
                        .foregroundColor(p.isAvailable ? Theme.statusHealthy : Theme.textSecondary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
                .opacity(p.isAvailable ? 1 : 0.6)
            }
        }
    }

    private var cookieStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste your claude.ai cookie")
                .font(.title3.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
            Text("In claude.ai, open DevTools (⌘⌥I), go to Network, find the 'usage' request, and copy the full Cookie header.")
                .font(Theme.captionFont)
                .foregroundColor(Theme.textSecondary)
            SecureCookieEditor(text: $cookieInput)
                .frame(height: 110)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
            if let err = validateError {
                Text(err).font(Theme.captionFont).foregroundColor(Theme.statusCritical)
            }
        }
    }

    private var validateStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(validating ? "Validating cookie…" : "Cookie validated ✓")
                .font(.title3.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
            Text("We're checking that the cookie can reach the Claude usage endpoint.")
                .font(Theme.captionFont)
                .foregroundColor(Theme.textSecondary)
            if let err = validateError {
                Text(err).font(Theme.captionFont).foregroundColor(Theme.statusCritical)
            }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications")
                .font(.title3.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
            Toggle("Alert me at 25/50/75/90% usage", isOn: $appState.notificationsEnabled)
                .toggleStyle(.switch)
                .foregroundColor(Theme.textPrimary)
            Text("You can change this any time from Settings.")
                .font(Theme.captionFont)
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var navButtons: some View {
        HStack {
            if step != .welcome {
                Button("Back") { goBack() }.buttonStyle(.bordered)
            }
            Spacer()
            Button(primaryLabel) { goNext() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(step == .cookie && cookieInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var primaryLabel: String {
        switch step {
        case .welcome:        return "Get started"
        case .provider:       return "Continue"
        case .cookie:         return "Validate"
        case .validate:       return validating ? "…" : "Continue"
        case .notifications:  return "Finish"
        }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) { step = prev }
    }

    private func goNext() {
        switch step {
        case .cookie:
            startValidation()
        case .validate:
            if !validating && validateError == nil { step = .notifications }
        case .notifications:
            dismiss()
        default:
            if let next = Step(rawValue: step.rawValue + 1) { step = next }
        }
    }

    private func startValidation() {
        validateError = nil
        validating = true
        let credential = ClaudeCredential(cookie: cookieInput.trimmingCharacters(in: .whitespacesAndNewlines))
        if let err = AuthService.shared.saveClaudeCredential(credential) {
            validateError = err
            validating = false
            return
        }
        step = .validate
        Task {
            do {
                let provider = ProviderRegistry.shared.provider(for: .claude)!
                try await provider.validateCredentials()
                let snapshot = try await provider.fetchUsage()
                await MainActor.run {
                    appState.latestSnapshot = snapshot
                    appState.authStatus = .valid
                    (NSApp.delegate as? AppDelegate)?.coordinator?.onCredentialsSaved()
                    validating = false
                }
            } catch let err as ProviderError {
                await MainActor.run {
                    validateError = err.description
                    validating = false
                }
            } catch {
                await MainActor.run {
                    validateError = error.localizedDescription
                    validating = false
                }
            }
        }
    }
}

// MARK: - Secure cookie text editor

/// NSTextView wrapper that disables all macOS text-processing features
/// (autocorrect, spellcheck, data detection, smart quotes, link detection)
/// so the session cookie is never sent to Apple autocorrect services.
/// Also enforces a hard 65 536-character length cap.
private struct SecureCookieEditor: NSViewRepresentable {
    @Binding var text: String
    private static let maxLength = 65_536

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let tv = scrollView.documentView as? NSTextView else { return scrollView }
        tv.isAutomaticSpellingCorrectionEnabled  = false
        tv.isAutomaticDataDetectionEnabled       = false
        tv.isAutomaticLinkDetectionEnabled       = false
        tv.isAutomaticTextReplacementEnabled     = false
        tv.isAutomaticQuoteSubstitutionEnabled   = false
        tv.isAutomaticDashSubstitutionEnabled    = false
        tv.isContinuousSpellCheckingEnabled      = false
        tv.isGrammarCheckingEnabled              = false
        tv.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.textColor = NSColor.white.withAlphaComponent(0.88)
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView else { return }
        if tv.string != text { tv.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SecureCookieEditor
        init(_ parent: SecureCookieEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if tv.string.count > SecureCookieEditor.maxLength {
                tv.string = String(tv.string.prefix(SecureCookieEditor.maxLength))
            }
            parent.text = tv.string
        }
    }
}

// MARK: - Onboarding pill preview

/// Animated replica of the compact pill used in the welcome step.
/// Cycles through healthy → warning → critical to show mood-reactive colours.
private struct OnboardingPillPreview: View {
    @State private var demoPercent: Double = 0.42
    @State private var glowPulse = false
    private let demoValues: [Double] = [0.42, 0.71, 0.88, 0.42]
    @State private var demoIndex = 0

    var body: some View {
        let status: UsageStatus = demoPercent >= 0.9 ? .critical : demoPercent >= 0.7 ? .warning : .healthy
        let color = status.color

        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(color.opacity(glowPulse ? 0.32 : 0.12))
                    .frame(width: 12, height: 12)
                    .blur(radius: 3)
                Circle().fill(color).frame(width: 5, height: 5)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.75), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, CGFloat(demoPercent) * 80))
            }
            .frame(width: 80, height: 3)
            Text("\(Int((demoPercent * 100).rounded()))%")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.88))
                .frame(minWidth: 25, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(width: 220, height: 22)
        .background(NotchPillShape(topRadius: 0, bottomRadius: 12).fill(Color.black))
        .shadow(color: color.opacity(0.4), radius: 8, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            // Cycle through demo values every 2 s
            func cycle() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    demoIndex = (demoIndex + 1) % demoValues.count
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                        demoPercent = demoValues[demoIndex]
                    }
                    cycle()
                }
            }
            cycle()
        }
    }
}
