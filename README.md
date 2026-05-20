# NOTCHY

> Your MacBook notch, now showing your Claude AI usage limits live.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](swift-project/NotchyLimit/LICENSE)
[![macOS 12+](https://img.shields.io/badge/macOS-12.0%2B-blue)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)
[![GitHub stars](https://img.shields.io/github/stars/I-N-SILVA/NOTCHY?style=social)](https://github.com/I-N-SILVA/NOTCHY/stargazers)
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4)](https://github.com/sponsors/I-N-SILVA)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/iamnsilva)

<p align="center">
  <img src="assets/demo.gif" alt="NOTCHY running on a MacBook Pro" width="680" />
</p>

NOTCHY is a free, open-source macOS utility that turns the MacBook hardware notch into a real-time Claude usage monitor. A minimal pill blends with the notch and shows your session percentage at a glance. Hover to expand into a full panel with session usage, weekly quota, time until reset, and threshold alerts. Everything runs locally with zero telemetry.

---

## Why NOTCHY?

- **The notch is wasted real estate.** Apple uses it for the camera. macOS uses it for nothing. NOTCHY puts your most-checked number there.
- **Claude limit anxiety is real.** Stop refreshing `claude.ai/settings/usage`. The percentage is always on screen.
- **No tab, no Electron, no 400MB.** It's a native Swift app under 10MB. Hover-to-expand like Dynamic Island.
- **Local-first, zero telemetry.** Talks to `claude.ai` only. Cookie lives in Keychain. Read every line yourself.
- **Free forever.** MIT licensed. No paywalls, no upsells, no account.

---

## What it looks like

**Compact pill** sits inside the notch like a Dynamic Island element. A colour-coded glow shows your health at a glance.

**Expanded panel** drops down on hover or click. Shows your session percentage large, a rolling counter animation, session and weekly cards, and a mood-reactive retro mascot (calm, worried, then alarmed).

**Notifications** fire as in-app banners at 25, 50, 75, and 90% usage. No system permission required.

---

## Features

- Dynamic Island-style pill that blends with the physical hardware notch
- Arc progress ring with colour-matched glow (green, amber, red)
- Mood-reactive retro mascot, calm at 0-74%, worried at 75-89%, alarmed at 90%+
- Hover to expand, click to pin, click anywhere outside to dismiss
- Hero layout with giant usage %, reset countdown, and rolling counter on open
- Session card (5-hour window) and weekly card (7-day quota)
- In-app banners at 25, 50, 75, and 90% with no system permission required
- Right-click context menu with Refresh, Settings, Test notification, and Quit
- 5-minute auto-refresh with exponential backoff on errors
- Cookie stored in macOS Keychain, never in UserDefaults, never logged
- Local-first: talks only to `claude.ai`, zero telemetry
- Provider-extensible with a clean `UsageProvider` protocol (Gemini stub included)
- MIT licensed, read every line yourself

---

## Requirements

| | Minimum |
|---|---|
| macOS | 12.0 Monterey |
| Chip | Apple Silicon (arm64) |
| Xcode CLT | Any version with Swift 5.9+ |
| Xcode (full) | Optional, only needed for Mode B |

> **Intel Mac:** Change `-target arm64-apple-macosx12.0` to `-target x86_64-apple-macosx12.0` in `scripts/build.sh`.

---

## Install

### Option A: Build from source (no Xcode required)

```bash
# Install Xcode Command Line Tools (one-time)
xcode-select --install

# Clone
git clone https://github.com/I-N-SILVA/NOTCHY.git
cd NOTCHY/swift-project/NotchyLimit

# Build
bash scripts/build.sh

# Run
open build/NotchyLimit.app
```

The script compiles with `swiftc`, assembles the `.app` bundle, generates the `.icns` icon from included PNGs, and strips the quarantine attribute. No full Xcode install, no code signing, no Apple developer account required.

### Option B: With Xcode (for development)

```bash
brew install xcodegen
cd NOTCHY/swift-project/NotchyLimit
xcodegen generate
open NotchyLimit.xcodeproj   # then press Cmd+R
```

---

## First launch: getting your session token

Notchy reads Claude's internal usage endpoint using your session cookie. The process takes about 30 seconds.

1. Open [claude.ai](https://claude.ai) and log in
2. Open DevTools with `Cmd + Option + I`, then click the Network tab
3. Refresh the page and find a request named `usage`
4. Under Request Headers, copy the entire `Cookie` value
5. Paste it into Notchy's onboarding screen and click Validate

The cookie is stored in the macOS **Keychain**, never on disk, never logged.

> **Note:** This uses an undocumented Claude endpoint that may change. If it breaks, open an [Issue](https://github.com/I-N-SILVA/NOTCHY/issues).

Full setup guide with screenshots: [docs/COOKIE_SETUP.md](swift-project/NotchyLimit/docs/COOKIE_SETUP.md)

---

## Usage

| Action | Result |
|---|---|
| Hover over the notch pill | Expands to full panel |
| Click the pill | Pins panel open |
| Click outside the panel | Collapses to pill |
| Press Escape | Collapses to pill |
| Right-click the pill | Context menu with Refresh, Settings, Quit |

---

## Architecture

```
swift-project/NotchyLimit/Sources/
├── App/                   @main entry + AppDelegate
├── Core/
│   ├── Domain/            ProviderId, UsageWindow, ServiceUsageSnapshot, Status
│   └── State/             AppState, NotchState
├── Providers/
│   ├── UsageProvider.swift   Protocol + ProviderRegistry
│   ├── Claude/            ClaudeProvider, ClaudeCredential, Endpoint, DTOs
│   └── Gemini/            Stub (coming soon)
├── Services/              UsageService, NotificationService, AuthService
├── Platform/              KeychainStore, ScreenUtils, NotchDetector
└── UI/
    ├── NotchWindowController  NSPanel, hover timer, click-outside monitor
    ├── Compact/           Pill view
    ├── Expanded/          Full panel (session card, weekly card, actions)
    ├── Onboarding/        5-step setup with live pill preview
    ├── Settings/          Notifications, launch at login, providers
    ├── Diagnostics/       Sync status, raw errors
    └── Theme/             Tokens, GlassBackground, NotchPillShape,
                           RetroMascot, StatusRingView
```

### How the notch blend works

The panel anchors at `screen.frame.maxY` (top of screen). Its height equals `safeAreaInsets.top` (the hardware notch, roughly 37pt on MBP 14/16") plus the visible content height. The top portion sits inside the physical camera housing where black blends with hardware. Only the lower portion is visible, identical to how iOS Dynamic Island works.

---

## Privacy

- Cookie stored in macOS **Keychain**, never in UserDefaults, never logged
- No telemetry, no analytics, no remote servers
- Network calls go only to `claude.ai` (and whichever providers you configure)
- MIT licensed, read every line yourself

---

## Contributing

PRs welcome. Good first issues:

- **Gemini provider** — stub is in place, needs a real implementation
- **ChatGPT provider** — OpenAI usage API integration
- **Intel build** — verify and document the x86_64 target
- **Sparkle auto-update** — add `Sparkle.framework` update checking
- **Cookie helper** — browser extension to auto-grab the cookie

See [CONTRIBUTING.md](swift-project/NotchyLimit/CONTRIBUTING.md) for guidelines.

---

## Disclaimer

This app uses an **undocumented** Claude endpoint. It is not affiliated with or endorsed by Anthropic. The endpoint may change without notice. Use at your own risk.

---

## Support the project

NOTCHY is built and maintained by one person, in the open, for free. If it saves you from refreshing `claude.ai` every ten minutes — or you just want to see the roadmap below ship faster — please consider supporting the work.

<p align="left">
  <a href="https://ko-fi.com/iamnsilva">
    <img src="https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Support on Ko-fi" />
  </a>
  &nbsp;
  <a href="https://github.com/sponsors/I-N-SILVA">
    <img src="https://img.shields.io/badge/GitHub-Sponsor-ea4aaa?style=for-the-badge&logo=github&logoColor=white" alt="Sponsor on GitHub" />
  </a>
</p>

Every dollar goes back into the project: new providers (ChatGPT, Gemini), Sparkle auto-update, a one-click cookie helper, and keeping everything free and open-source forever. See [SPONSORS.md](SPONSORS.md) for the full list of backers.

Not in a position to sponsor? **Star the repo** ⭐ — it's free and genuinely helps with discoverability.

---

## Community

- 🐛 [Report a bug](https://github.com/I-N-SILVA/NOTCHY/issues/new?template=bug_report.md)
- 💡 [Request a feature](https://github.com/I-N-SILVA/NOTCHY/issues/new?template=feature_request.md)
- 💬 [Discussions](https://github.com/I-N-SILVA/NOTCHY/discussions) — usage questions, ideas, show-and-tell
- 🐦 Follow [@iansilva](https://github.com/I-N-SILVA) for updates

---

## Star history

<a href="https://star-history.com/#I-N-SILVA/NOTCHY&Date">
  <img src="https://api.star-history.com/svg?repos=I-N-SILVA/NOTCHY&type=Date" alt="Star history chart" width="600" />
</a>

---

## License

[MIT](swift-project/NotchyLimit/LICENSE) — Copyright 2026 Ian Silva

---

*Built by [Ian Silva](https://github.com/I-N-SILVA). If NOTCHY makes your day a little easier, [buy me a coffee](https://ko-fi.com/iamnsilva) ☕*
