#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v swiftc >/dev/null 2>&1; then
  echo "SKIP Apple authorization lifecycle harness: swiftc is unavailable"
  exit 0
fi
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lm-apple-auth.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc "$ROOT/apps/ios-macos/Sources/Shared/AppleSignInSupport.swift" \
  "$ROOT/script/test_apple_authorization_lifecycle.swift" \
  -framework AuthenticationServices -framework Security -framework AppKit -o "$TMP_DIR/check"
"$TMP_DIR/check"
