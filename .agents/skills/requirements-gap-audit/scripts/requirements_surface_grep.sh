#!/usr/bin/env bash
# Compact ledger-first summary for gap audits. Not a substitute for npm run ledger:open.
set -eu

ROOT="${1:-.}"

echo "# Requirements gap — ledger first"
echo

if [[ -f "$ROOT/package.json" ]] && grep -q '"ledger:open"' "$ROOT/package.json" 2>/dev/null; then
  echo "## Open controls"
  (cd "$ROOT" && npm run -s ledger:open) || true
  echo
  echo "## Goal route"
  (cd "$ROOT" && npm run -s goal:next 2>/dev/null | head -12) || true
else
  echo "## Open controls (no ledger:open script)"
  rg '"result": "(fail|pending|blocked)"' "$ROOT/validation" -g'*.json' 2>/dev/null | head -40 || echo "(no validation tree)"
fi

echo
echo "## Mockup file count (paths live in ledger JSON)"
find "$ROOT/mockups" -maxdepth 2 -type f \( -name '*.png' -o -name '*.jpg' \) 2>/dev/null | wc -l | awk '{print "files: " $1}'
