# Changelog

All notable changes to Notchy Limit will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- "Session limit reached" notification fires at 100% usage (separate from the 90% warning)
- "Session reset" notification when quota rolls over so users know immediately when they can resume
- 100% added to default notification thresholds and visible in Settings
- Compact pill shows reset countdown (e.g. "1h 15m") when session is blocked, instead of "100%"
- `isAtLimit` and `timeToResetShortString()` helpers on `UsageWindow`

### Fixed
- `OnboardingView` crashed if the Claude provider was not registered; replaced force-unwrap with `guard let`
- `RetroMascot` blink and eye-scan animations accumulated parallel `DispatchQueue` chains across mood changes; replaced with cancellable `Task`-based loops via `.task(id: mood)`
- `SessionCard` counter animation stacked multiple simultaneous chains when usage updated rapidly; added epoch cancellation

## [0.1.0] - 2026-05-20

### Added
- Dynamic Island-style pill that blends with the MacBook hardware notch.
- Arc progress ring with colour-matched glow (green, amber, red).
- Hover to expand, click to pin, click outside or press Escape to dismiss.
- Expanded panel with session %, weekly quota, reset countdown, and rolling counter animation.
- Mood-reactive retro mascot: calm at 0-74%, worried at 75-89%, alarmed at 90%+.
- In-app threshold banners at 25, 50, 75, and 90% — no system permission required.
- 5-minute auto-refresh with exponential backoff on errors and manual refresh via context menu.
- Claude session cookie stored exclusively in the macOS Keychain.
- Provider abstraction (`UsageProvider` protocol) so additional providers slot in without UI changes.
- Gemini provider stub included for contributors.
- Right-click context menu with Refresh, Settings, Test notification, and Quit.
- Five-step onboarding with a live pill preview.
- Settings panel for notification thresholds, poll interval, and launch at login.
- Diagnostics panel showing sync status and auth state.

### Security
- Keychain items bound to the current application via `SecAccessCreate` — other processes
  require user confirmation to access the cookie.
- Credential accessibility set to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- `orgId` parsed from cookie validated as a UUID before use; URL built with `URLComponents`
  to prevent path injection.
- Cookie paste field uses a custom `NSTextView` wrapper with all autocorrect, spell-check,
  and data-detection features disabled.
- Error descriptions sanitized before surfacing in the UI — `URLError.localizedDescription`
  (which can include request URLs) is never forwarded to `DiagnosticsView`.
- Logging migrated from `NSLog` to `os.log` with `.public` privacy scoping.
