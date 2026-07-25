#!/usr/bin/env bash
# get-sha1.sh — print the SHA-1 / SHA-256 fingerprints you paste into the
# Firebase console (Project settings → your com.kalimat.app app → Add fingerprint)
# so Google Sign-In works.
#
# Usage:
#   bash get-sha1.sh                 # debug keystore (for testing) — the usual one
#   bash get-sha1.sh <keystore> <alias>   # a release/upload keystore
#
# The debug keystore is created automatically the first time you build/run an
# Android app on this machine. If the script says it's missing, run
# `flutter run` (or `flutter build apk --debug`) once, then run this again.
#
# Windows: run this from Git Bash, or use the keytool line below in PowerShell
# with  %USERPROFILE%\.android\debug.keystore .
set -euo pipefail

KEYSTORE="${1:-$HOME/.android/debug.keystore}"
ALIAS="${2:-androiddebugkey}"

# Debug keystore uses the well-known password "android". A release keystore
# will prompt you for its password instead.
if [ "$KEYSTORE" = "$HOME/.android/debug.keystore" ]; then
  STOREPASS_ARGS=(-storepass android -keypass android)
  KIND="debug (for testing)"
else
  STOREPASS_ARGS=()
  KIND="release/upload (for Play)"
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "✗ keytool not found. Install a JDK (it ships with Android Studio)." >&2
  exit 1
fi

if [ ! -f "$KEYSTORE" ]; then
  echo "✗ Keystore not found: $KEYSTORE" >&2
  echo "  The debug keystore appears after your first Android build." >&2
  echo "  Run 'flutter run' once, then re-run this script." >&2
  exit 1
fi

echo "→ Keystore: $KEYSTORE"
echo "→ Alias:    $ALIAS   [$KIND]"
echo

keytool -list -v -alias "$ALIAS" -keystore "$KEYSTORE" "${STOREPASS_ARGS[@]}" \
  | grep -E 'SHA1|SHA256' \
  || { echo "✗ Could not read fingerprints (wrong alias or password?)." >&2; exit 1; }

echo
echo "Copy the SHA1 line above → Firebase console → ⚙ Project settings →"
echo "the com.kalimat.app app → Add fingerprint → paste → Save."
echo "(Then re-download google-services.json if it prompts, and send it over.)"
