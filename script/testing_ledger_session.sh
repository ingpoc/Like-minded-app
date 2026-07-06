#!/usr/bin/env bash
# testing-ledger session bookends — preflight once, then agent runs one flow loop.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<EOF
Usage: $0 preflight|next|record <screen> <flow-id> [evidence]

  preflight  API health + compact open count (run once per session)
  next       Print next open macOS flow (testing:ledger-next)
  record     Record pass after CUA (tier CUA-click)

Examples:
  $0 preflight
  $0 next
  $0 record app-shell tab-navigation "CUA validation-gurusharan: all tabs switch"
EOF
}

cmd="${1:-preflight}"
case "$cmd" in
  preflight)
    curl -fsS http://127.0.0.1:8787/health | head -c 200 || {
      echo "Start API: npm run dev:api:validation && npm run reset:validation-data" >&2
      exit 1
    }
    echo ""
    npm run ledger:brief 2>/dev/null | head -6
    ;;
  next)
    npm run testing:ledger-run -- --card-only
    ;;
  record)
    screen="${2:?screen}"
    flow="${3:?flow-id}"
    evidence="${4:-CUA validation-gurusharan pass}"
    npm run ledger:record-flow -- --platform macos --screen "$screen" --flow "$flow" \
      --result pass --method CUA-click --evidence "$evidence"
    npm run testing:ledger-next 2>/dev/null | head -8 || true
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
