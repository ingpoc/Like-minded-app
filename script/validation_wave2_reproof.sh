#!/usr/bin/env bash
# Wave 2 — sequential ledger reproof after parallel code edits (sole :8787 + locks).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"
export LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}"

echo "Wave 2 reproof: macOS validation batch → iOS captures → ledger:stale" >&2
npm run macos:validation-batch
npm run verify:ios-screens
npm run ledger:stale
