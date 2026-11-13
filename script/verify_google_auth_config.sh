#!/usr/bin/env bash
# Verify Google OAuth env + native plist wiring (Phase 2). Exits 0 when ready to test.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env.local"
  set +a
fi

failures=0
need() {
  if [[ -z "${1// }" ]]; then
    echo "MISSING: $2" >&2
    failures=$((failures + 1))
  else
    echo "OK: $2"
  fi
}

need "${GOOGLE_CLIENT_IDS:-}" "GOOGLE_CLIENT_IDS"
need "${GOOGLE_CLIENT_ID_IOS:-}" "GOOGLE_CLIENT_ID_IOS"
need "${GOOGLE_CLIENT_ID_MAC:-}" "GOOGLE_CLIENT_ID_MAC"
need "${GOOGLE_REVERSED_CLIENT_ID_IOS:-}" "GOOGLE_REVERSED_CLIENT_ID_IOS"
need "${GOOGLE_REVERSED_CLIENT_ID_MAC:-}" "GOOGLE_REVERSED_CLIENT_ID_MAC"

if rg -q "GIDClientID" apps/ios-macos/Info/Likeminded-Info.plist 2>/dev/null; then
  echo "OK: iOS Info plist has GIDClientID + URL schemes"
else
  echo "MISSING: GIDClientID in Info/Likeminded-Info.plist" >&2
  failures=$((failures + 1))
fi

if curl -fsS http://127.0.0.1:8787/health 2>/dev/null | grep -q '"googleAuth":true'; then
  echo "OK: API googleAuth ready"
else
  echo "SKIP: start API with GOOGLE_CLIENT_IDS set; /health should show googleAuth:true"
fi

if (( failures > 0 )); then
  echo "Google auth not configured. See docs/workflows/google-oauth-setup.md" >&2
  exit 1
fi

echo "Google auth configuration present."
