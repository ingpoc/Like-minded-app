#!/usr/bin/env bash
# Self-validate context-efficiency-audit skill surfaces + repo recurrence gates.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# scripts/ -> context-efficiency-audit/ -> skills/ -> .agents/ -> repo root
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$ROOT"

echo "## stale-context-grep"
bash "$SCRIPT_DIR/stale-context-grep.sh" "$ROOT"

echo
echo "## verify:ledger-progress"
npm run verify:ledger-progress

echo
echo "## goal:next (route smoke)"
npm run goal:next

echo
echo "context-efficiency-audit validate: ok"
