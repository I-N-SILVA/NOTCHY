#!/usr/bin/env bash
# Double-click this file (or run it in Terminal) to let macOS open a downloaded,
# un-notarized build of Notchy Limit.
#
# Why this is needed: the app is ad-hoc signed but not notarized (notarization
# requires a paid Apple Developer account). macOS quarantines anything you
# download and refuses to open it — sometimes with "NotchyLimit is damaged".
# This script removes that quarantine flag. It does nothing else.

set -euo pipefail

echo "Notchy Limit — make a downloaded build openable"
echo "------------------------------------------------"

# Find the app: explicit arg, then /Applications, then common download spots.
APP="${1:-}"
if [ -z "$APP" ]; then
  for candidate in \
    "/Applications/NotchyLimit.app" \
    "$HOME/Applications/NotchyLimit.app" \
    "$HOME/Downloads/NotchyLimit.app" \
    "$HOME/Desktop/NotchyLimit.app"; do
    if [ -d "$candidate" ]; then APP="$candidate"; break; fi
  done
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo
  echo "Couldn't find NotchyLimit.app automatically."
  echo "Drag NotchyLimit.app onto this window, then press Return:"
  read -r APP
  # Strip surrounding quotes that Finder adds when you drag a path in.
  APP="${APP%\"}"; APP="${APP#\"}"
fi

if [ ! -d "$APP" ]; then
  echo "Still can't find an app at: $APP"
  echo "Move NotchyLimit.app to your Applications folder and run this again."
  exit 1
fi

echo "Clearing quarantine on: $APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "Done. You can now open Notchy Limit normally (double-click it)."
echo "If macOS still blocks it: right-click the app → Open → Open."
