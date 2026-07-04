#!/usr/bin/env bash
set -eu

ROOT="${1:-.}"
cd "$ROOT"

# Count-first: agent sees counts, not raw matches
PATTERNS='Talk starts|tap Talk|MVP tabs `Talk`|The Talk surface|ReflectionPrototypeView|Phase [0-9]+ .*remains unchecked|replace MVP placement loop goal|generic next action|normal repo retrieval|broad repo discovery|ui-ux-patterns-research|app-design-language'
FILES="AGENTS.md PROGRESS.md goal.json goal.template.json DESIGN.md docs/references docs/workflows script package.json"

total=0
while IFS=: read -r file count; do
  if (( count > 0 )); then
    echo "$file: $count matches"
    total=$((total + count))
  fi
done < <(rg -c "$PATTERNS" $FILES 2>/dev/null | grep -v '^script/phase_preflight\.js:' | sed 's/:0$//' || true)

echo "---"
echo "Total stale context hits: $total"

if (( total > 0 )); then
  echo "Run with --detail to see exact lines"
  if [[ "${2:-}" == "--detail" ]]; then
    echo
    rg -n "$PATTERNS" $FILES 2>/dev/null \
      | grep -v '^script/phase_preflight\.js:.*pattern:' \
      | grep -v ':.*- \[x\]' || true
  fi
fi
