# Building Notchy Limit

## Requirements

- macOS 12 (Monterey) or newer
- Xcode 15+ with the macOS SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## One-line build

```bash
./scripts/build.sh
open build/NotchyLimit.app
```

The `build.sh` script will:

1. Run `xcodegen generate` to produce `NotchyLimit.xcodeproj` from `project.yml`.
2. Build with `xcodebuild` (Release config) using the local toolchain.
3. Copy the `.app` bundle to `build/`.

## Working in Xcode

```bash
xcodegen generate
open NotchyLimit.xcodeproj
```

Select the **NotchyLimit** scheme and ⌘R.

## Creating a DMG installer

```bash
./scripts/build.sh
./scripts/create_dmg.sh
# build/NotchyLimit-Installer.dmg
```

## Signing + Notarization (distribution)

You need an Apple Developer account. Once you have a Developer ID Application
certificate installed in Keychain and a stored notarytool credential, run:

```bash
export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
./scripts/sign_and_notarize.sh
```

This hard-runtime-signs the `.app`, signs the DMG, submits to Apple, waits,
and staples the ticket.

## Sharing a build (without notarization)

`scripts/build.sh` ad-hoc signs the app, which is enough to *run* it — but
ad-hoc signing is **not** notarization. The only way to make a download open
with zero friction for other people is to notarize it, and notarization
requires the paid Apple Developer Program ($99/yr). A free Apple ID can only
sign apps for your own machines, not for distribution.

So if you hand someone an un-notarized build, macOS quarantines their download
and may say **"NotchyLimit is damaged and can't be opened."** That's expected.
Tell the recipient to do **one** of the following (any one works):

1. Double-click `scripts/remove_quarantine.command`.
2. Run `xattr -dr com.apple.quarantine /Applications/NotchyLimit.app`.
3. Open the app (it gets blocked), then **System Settings → Privacy &
   Security → Open Anyway**. Older macOS: right-click → **Open** → **Open**.

The cleanest no-license alternative is to have them build from source (no
quarantine flag is applied to locally-built apps) — see the one-line build
above.

## Troubleshooting

- **`xcodegen: command not found`** — `brew install xcodegen`
- **"App is damaged" on first open** —
  - *Your own local build:* `scripts/build.sh` already ad-hoc signs and
    de-quarantines it; just `open build/NotchyLimit.app`.
  - *A build you downloaded/received:* see **Sharing a build** above
    (`remove_quarantine.command` or the `xattr` one-liner). For a frictionless
    download, notarize via `sign_and_notarize.sh` (needs a paid Apple Dev ID).
- **Cookie not validating** — see `docs/COOKIE_SETUP.md`.
