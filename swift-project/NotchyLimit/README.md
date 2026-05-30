# Notchy Limit

> Your MacBook notch (or menu bar) — now showing your AI usage limits.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 12+](https://img.shields.io/badge/macOS-12.0%2B-blue)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)

Notchy Limit is a free, open-source macOS utility that turns your MacBook's notch (or menu bar) into a live AI usage monitor. A minimal pill blends with the notch. Hover to expand into a full panel — session %, weekly quota, time to reset, and threshold alerts. Runs 100% locally, zero telemetry.

Supports **Claude** (Claude Code / Claude.ai — real 5h + weekly), **Codex** (ChatGPT plan — real 5h + weekly), **Gemini** (Code Assist quota), **OpenAI** (API spend), **OpenRouter** (credits %), **DeepSeek** (balance), **ElevenLabs** (character %), and **Perplexity** (connected). Claude / Codex / Gemini need no key — Notchy reads your existing CLI login automatically.

---

## Features

- **Dynamic Island-style pill** — blends with the hardware notch, shows usage % + status glow
- **Menu bar mode** — also works on non-notch Macs as a `● 42%` status item
- **Adaptive display** — auto-picks notch or menu bar; or run both simultaneously
- **Mood-reactive mascot** — calm at 0–74%, worried at 75–89%, alarmed at 90%+
- **Arc progress ring** — circular indicator with colour-matched glow keyed to health status
- **One provider in the notch** — the retracted pill shows a single active provider (with its icon); switch which one from the expanded panel
- **Provider switcher** — tap chips in the expanded panel to choose the notch provider; the menu-bar popover lists them all at once
- **Outage badges** — reads provider status pages and flags active incidents
- **Hover to expand / click to pin** — full panel drops down; click anywhere outside to dismiss
- **Hero layout** — giant usage %, reset countdown, rolling counter animation on open
- **Session + weekly cards** (Claude) / monthly spend card (OpenAI)
- **In-app notifications** — banners at 25/50/75/90% (no system permission required)
- **5-minute auto-refresh** with exponential backoff on errors
- **MIT licensed** — build it, fork it, audit it

---

## Requirements

| | Minimum |
|---|---|
| macOS | 12.0 Monterey |
| Chip | Apple Silicon (arm64) |
| Xcode CLT | Any version with Swift 5.9+ |
| Xcode (full) | Optional — only for Mode B build |

> **Intel Mac:** Change `-target arm64-apple-macosx12.0` to `-target x86_64-apple-macosx12.0` in `scripts/build.sh`.

---

## Install

### Option A — Download the release (fastest)

1. Grab `NotchyLimit-Installer.dmg` from the [latest release](https://github.com/I-N-SILVA/NOTCHY/releases/latest).
2. Open the DMG and drag **NotchyLimit** to **Applications**.
3. **First launch (unsigned build):** the app isn't notarized yet, so macOS Gatekeeper blocks a normal double-click. Either:
   - **Right-click** the app → **Open** → **Open** in the dialog, **or**
   - run `xattr -dr com.apple.quarantine /Applications/NotchyLimit.app` then open it.
4. Notchy lives in the menu bar / notch — there's no Dock icon (it's a menu-bar agent).

> **Keychain prompt for Claude:** if you use Claude Code, Notchy reads its login token from your Keychain. macOS will ask once — click **Always Allow** so it can show your Claude usage.

### Option B — Build from source (no Xcode required)

```bash
xcode-select --install
git clone https://github.com/I-N-SILVA/NOTCHY.git
cd NOTCHY/swift-project/NotchyLimit
bash scripts/build.sh
open build/NotchyLimit.app
```

### Option C — With Xcode (for development)

```bash
brew install xcodegen
cd NOTCHY/swift-project/NotchyLimit
xcodegen generate
open NotchyLimit.xcodeproj   # then ⌘R
```

---

## First launch — connecting your providers

Claude, Codex, and Gemini need **no key** — Notchy reads the login the official CLI already stored. Everything else takes an API key you paste once (stored in your Keychain, only ever sent to that provider).

### Claude (no key — uses Claude Code / CLI)

If you use **Claude Code** or the Claude CLI, Notchy auto-detects it (from `~/.claude/credentials.json` or the `Claude Code-credentials` Keychain item) and shows your real **5-hour session + weekly** usage. macOS asks once to allow Keychain access — click **Always Allow**.

No CLI? Paste a claude.ai session cookie instead: open [claude.ai](https://claude.ai) → DevTools (`⌘⌥I`) → **Network** → refresh → find a `usage` request → copy the `Cookie` header → paste into onboarding.

### Codex (no key — uses your ChatGPT plan)

Install + sign in once: `npm i -g @openai/codex` then `codex login`. Notchy reads `~/.codex/auth.json` and shows your **5-hour + weekly** Codex usage.

### Gemini (no key — uses Gemini CLI)

Sign in with the `gemini` CLI (Code Assist). Notchy reads `~/.gemini/oauth_creds.json` and shows your remaining per-model quota. *(Google is retiring Code Assist for individuals on 2026-06-18 → Antigravity.)* Without the CLI, paste a Gemini API key for a "Connected" status.

### OpenAI

1. Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Create or copy an API key (`sk-...`)
3. Paste it into the OpenAI onboarding step → **Validate**

Notchy uses it to read your monthly billing usage vs. your configured hard spend limit. The key requires billing read access.

---

## Security

This section is explicit about what each credential is and what it can access. If you have concerns, read the relevant source files linked below — the codebase is small enough to audit in an afternoon.

### Claude — OAuth token (preferred)

| Property | Value |
|---|---|
| **What it is** | Short-lived OAuth access token |
| **Where it comes from** | `~/.claude/credentials.json` (written by Claude CLI) |
| **What it can do** | Same scope as your Claude CLI session |
| **Where it's sent** | `claude.ai` only |
| **Blast radius** | Low — token expires and is scoped |
| **Source** | [`ClaudeOAuthCredential.swift`](Sources/Providers/Claude/ClaudeOAuthCredential.swift) |

Available automatically if Claude CLI or the Claude desktop app is installed. No user action required.

### Claude — Session cookie (fallback)

| Property | Value |
|---|---|
| **What it is** | Full browser session cookie |
| **What it can do** | Complete account access — same as being logged in |
| **Where it's stored** | macOS Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) |
| **Where it's sent** | `claude.ai` only, for the single usage API request |
| **Blast radius** | High — treat it like a password |
| **Source** | [`ClaudeCredential.swift`](Sources/Providers/Claude/ClaudeCredential.swift), [`AuthService.swift`](Sources/Services/AuthService.swift) |

This is only used if the OAuth path is unavailable. If you're uncomfortable with this tradeoff, install the Claude CLI — it enables the OAuth path and the cookie is never read.

**Mitigations in place today:**
- Stored device-only in Keychain, never in UserDefaults or on disk
- Never logged to console — error paths sanitize messages before display
- App-bound Keychain ACL — other processes require user confirmation to read
- No auto-update mechanism that could deliver malicious updates
- No background services, no network calls beyond `claude.ai`
- Codebase is small (~50 files) — realistic to read every line

**Known limitations:**
- Binary is currently unsigned and unnotarized. Signing + notarization is on the roadmap before any auto-update or extension feature ships.
- No independent security audit has been conducted.

### OpenAI — API key

| Property | Value |
|---|---|
| **What it is** | Standard `sk-...` API key |
| **What it can do** | Billing read access |
| **Where it's stored** | macOS Keychain |
| **Where it's sent** | `api.openai.com` only |
| **Blast radius** | Low if scoped; create a key with billing read only |
| **Source** | [`OpenAICredential.swift`](Sources/Providers/OpenAI/OpenAICredential.swift) |

---

## Usage

| Action | Result |
|---|---|
| Hover over the notch pill | Expands to full panel |
| Click the pill | Pins panel open |
| Click outside the panel | Collapses to pill |
| Press Escape | Collapses to pill |
| Right-click the pill | Context menu: Refresh · Settings · Quit |
| Click menu bar icon | Opens usage popover |
| Settings → Display | Switch between notch / menu bar / both |

---

## Architecture

```
Sources/
├── App/                     @main entry + AppDelegate
├── Core/
│   ├── Domain/              ProviderId · UsageWindow · ServiceUsageSnapshot · Status
│   └── State/               AppState · NotchState
├── Providers/
│   ├── UsageProvider.swift  Protocol + ProviderRegistry
│   ├── Claude/              ClaudeProvider · ClaudeCredential · ClaudeOAuthCredential
│   │                        ClaudeEndpoint · ClaudeUsageDTO
│   ├── OpenAI/              OpenAIProvider · OpenAICredential · OpenAIEndpoint · OpenAIUsageDTO
│   └── Gemini/              Stub (coming soon)
├── Services/                UsageService · UsageCoordinator · NotificationService · AuthService
├── Platform/                KeychainStore · ScreenUtils · NotchDetector · DisplayMode
└── UI/
    ├── MenuBar/             MenuBarController (NSStatusItem + NSPopover)
    ├── NotchWindowController  NSPanel · hover timer · click-outside monitor
    ├── Compact/             CompactView · ConstellationView (multi-provider)
    ├── Expanded/            ExpandedPanelView · ProviderSwitcherRow · SessionCard
    │                        WeeklyCard · PaceRow · HeaderRow · ActionsRow · FooterRow
    ├── Onboarding/          Smart setup: auto-detects OAuth, routes per provider
    ├── Settings/            Providers · Display · Alerts · Advanced
    ├── Diagnostics/         Sync status · raw errors
    └── Theme/               Tokens · GlassBackground · NotchPillShape
                             RetroMascot · StatusRingView
```

### Auth resolution order (Claude)

```
1. ~/.claude/credentials.json   →  Bearer token  (OAuth, preferred)
2. macOS Keychain cookie        →  Cookie auth   (fallback)
3. Neither available            →  missingCredentials error → onboarding
```

### How the notch blend works

The panel anchors at `screen.frame.maxY` with height = `safeAreaInsets.top` (~37 pt, the hardware notch) + visible content height. The top portion sits inside the physical camera housing — black fill blends with hardware. Only the lower portion is visible, identical to iOS Dynamic Island.

### Multi-provider polling

Each enabled provider runs its own independent `Task` in `UsageService`. A slow or rate-limited provider doesn't block others. `AppState.snapshots: [ProviderId: ServiceUsageSnapshot]` holds all live data; the constellation pill and provider switcher read from it.

---

## Adding a provider

1. Create `Sources/Providers/YourProvider/YourProvider.swift`
2. Conform to `UsageProvider`:

```swift
protocol UsageProvider: AnyObject {
    var id: ProviderId { get }
    var isAvailable: Bool { get }
    func validateCredentials() async throws
    func fetchUsage() async throws -> ServiceUsageSnapshot
}
```

3. Register in `ProviderRegistry.bootstrap()`
4. Add credential handling in `AuthService` if needed
5. Add a case to `ProviderId` and mark `isAvailable = true`

The notch UI, polling loop, and notification system all consume `ServiceUsageSnapshot` — nothing else needs changing.

---

## Privacy

- Credentials stored in macOS **Keychain** — never in UserDefaults, never logged
- No telemetry, no analytics, no remote servers
- Network calls go only to `claude.ai` and `api.openai.com` (and whichever providers you configure)
- MIT licensed — read every line yourself

---

## Contributing

PRs welcome. Open issues:

- **Gemini provider** — stub is in place, needs a real implementation once Google exposes a quota endpoint
- **Intel build** — verify and document x86_64 target
- **Code signing + notarization** — prerequisite before any auto-update or browser extension

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## Disclaimer

This app uses an **undocumented** Claude endpoint. It is not affiliated with or endorsed by Anthropic. The endpoint may change without notice. Use at your own risk.

---

## License

[MIT](LICENSE)

---

_Built by [Ian Silva](https://github.com/I-N-SILVA)_
