#!/usr/bin/env bash
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/SKILL.md"
test -f "$SKILL" || { echo "missing SKILL.md"; exit 1; }
for needle in "Query router" "Tier A" "ledger:open" "do not load" "Ledger before source"; do
  grep -q "$needle" "$SKILL" || { echo "SKILL missing: $needle"; exit 1; }
done
echo "requirements-gap-audit skill validate: ok"
