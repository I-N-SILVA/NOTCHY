# Notchy Cross-Platform Tray App — Port Plan

**Status:** Planning only. No code yet.
**Goal:** Bring Notchy's "AI usage at a glance" to **Windows and Linux** users via a
system-tray app, since the notch is Mac-only hardware.

---

## 1. The core problem

The current app is native **Swift / AppKit**, which only runs on macOS. Two things
are macOS-specific:

1. **The notch pill** — there is no notch on Windows/Linux, so this concept simply
   doesn't apply. The fallback is the **menu bar / system tray**, which we already
   support on Mac via `DisplayMode.menubar`.
2. **The runtime** — AppKit, `NSStatusItem`, `NSPopover`, and macOS Keychain have no
   Windows/Linux equivalent.

So a "non-Mac version" is effectively a **tray app**: a colored status icon + a small
popover panel showing each provider's usage. The notch is dropped; everything else
(providers, usage windows, status colors, notifications) carries over conceptually.

---

## 2. Recommended approach: Tauri

| Option | Bundle size | Tray support | Language | Verdict |
|---|---|---|---|---|
| **Tauri (Rust + web UI)** | ~3–10 MB | First-class (`tauri-plugin-tray`) | Rust core + TS/React UI | **Recommended** |
| Electron | ~80–150 MB | Good (`Tray`) | Node + web UI | Heavy; fine if team is JS-only |
| Native per-OS | smallest | best | C#/WinUI + GTK/Qt | 2× the work, 2× the bugs |

**Why Tauri:** tiny binaries, native tray on all three OSes, cross-platform secure
credential storage via `keyring` crate (Windows Credential Manager / libsecret /
macOS Keychain), and one shared UI codebase. It can also replace the macOS build
later if we ever want a single codebase — but that's **not** a goal of this plan.

---

## 3. What actually ports (and what doesn't)

The win here is that the provider logic is **pure HTTP + JSON mapping** — no AppKit.

### Ports cleanly (re-implement in Rust/TS, ~1:1 with Swift)
- `ProviderId`, `UsageWindow`, `UsageStatus`, `ServiceUsageSnapshot` domain types
- `UsageProvider` protocol → a Rust trait `UsageProvider`
- **Claude** (OAuth token + cookie fallback), **OpenAI** (billing endpoints),
  **Gemini** (connected-only), **Perplexity** (connected-only)
- Polling loop (`UsageService`/`UsageCoordinator`) → a Rust async task per provider
- Threshold notifications → `tauri-plugin-notification`

### Must be rebuilt platform-specifically
- **Notch pill UI** → dropped. Tray icon + popover only.
- **Keychain** → `keyring` crate (cross-platform).
- **`NSStatusItem` / `NSPopover`** → Tauri tray + a small always-on-top WebView window.
- **Claude OAuth file discovery** (`~/.claude/credentials.json`) → same path logic,
  but resolve home dir per-OS (`%USERPROFILE%` on Windows).
- **Launch at login** → `tauri-plugin-autostart`.

---

## 4. Proposed architecture

```
notchy-tray/                      # new repo or /cross-platform dir
├── src-tauri/                    # Rust core
│   ├── src/
│   │   ├── domain/               # ProviderId, UsageWindow, Snapshot (port of Swift)
│   │   ├── providers/            # claude.rs, openai.rs, gemini.rs, perplexity.rs
│   │   ├── auth.rs               # keyring-backed credential store
│   │   ├── coordinator.rs        # poll loop, emits snapshots to the UI
│   │   └── tray.rs               # icon rendering (color dot + %), menu
│   └── tauri.conf.json
└── src/                          # web UI (React + TS)
    ├── Popover.tsx               # the glass panel (reuse current design language)
    ├── ProviderRow.tsx           # dot + bar + % (or "Active" for status-only)
    └── Onboarding.tsx            # provider picker + API key input
```

**Data flow:** Rust coordinator polls providers → emits `snapshot` events over the
Tauri event bus → React UI re-renders the popover. The tray icon is redrawn in Rust
whenever the combined status changes.

---

## 5. Tray icon rendering note

macOS lets us put an attributed string ("● 42%") directly in the status item. Windows
and Linux trays generally accept **only an image**, not text. So on those platforms:

- Render the "dot + percentage" (or "dot + ON" for status-only) to a small PNG/ICO at
  runtime and set it as the tray icon, **or**
- Use a plain colored-dot icon and put the number in the tooltip + popover.

Decide during implementation; the colored-dot-only approach is the safe v1.

---

## 6. Phased rollout

1. **Phase 0 — spike (1–2 days):** Tauri app with a tray icon + empty popover on all
   three OSes. Prove the shell works.
2. **Phase 1 — domain + one provider:** Port domain types + OpenAI (cleanest real-usage
   provider). Show a real % in the popover.
3. **Phase 2 — all providers + auth:** Add Claude, Gemini, Perplexity + `keyring`
   credential storage + onboarding.
4. **Phase 3 — parity polish:** notifications, launch-at-login, status-only "Active"
   states, design pass to match the Mac glass aesthetic.
5. **Phase 4 — packaging:** `.msi`/`.exe` (Windows), `.AppImage`/`.deb` (Linux), code
   signing where applicable.

---

## 7. Open decisions (for later)

- **Shared core or parallel core?** Re-implementing providers in Rust means two
  sources of truth (Swift + Rust). Acceptable for now; revisit if drift becomes painful.
  A future option is to make the Rust core the single engine and have the Mac app call
  into it — but that's a much bigger architectural change.
- **Distribution channel** for Windows/Linux (direct download vs. winget/Flathub).
- Whether to keep the Mac app native or eventually fold it into the Tauri build.

---

## 8. Effort estimate

- Spike + one provider end-to-end: **~1 week**
- Full parity (all 4 providers, auth, notifications, packaging): **~3–4 weeks**

This is a **separate track** from the macOS app and should not block ongoing native work.
