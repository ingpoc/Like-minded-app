#!/usr/bin/env bash
# Wave 2 — sequential ledger reproof after parallel code edits (sole :8787 + locks).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"
export LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}"

mac_stale="$(node script/ledger_stale_screens.js --platform macos --count)"
ios_stale="$(node script/ledger_stale_screens.js --platform ios --count)"

echo "Wave 2 reproof: macOS stale=$mac_stale iOS stale=$ios_stale" >&2

if (( mac_stale > 0 )); then
  npm run macos:validation-batch -- --stale-only --cua-only --keep-api
fi

if (( ios_stale > 0 )); then
  npm run verify:ios-screens -- --stale-only
fi

npm run ledger:stale
