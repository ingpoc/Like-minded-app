#!/usr/bin/env bash
# Deterministic stale-context scan. Count-first; optional --detail.
# Also flags paired validation ledger desync and dirty-vs-goal mismatch hints.
set -eu

ROOT="${1:-.}"
DETAIL="${2:-}"
cd "$ROOT"

# Project-specific + cross-repo high-signal stale routes.
PATTERNS='Talk starts|tap Talk|MVP tabs `Talk`|The Talk surface|ReflectionPrototypeView|Phase [0-9]+ .*remains unchecked|replace MVP placement loop goal|generic next action|normal repo retrieval|broad repo discovery|ui-ux-patterns-research|app-design-language|Coming Soon placeholder|Coming soon\" placeholder|❌ missing|every macOS screen exercise real functionality|functional parity \(visual parity deferred\)|Manual proofs — \*\*iOS\*\* \(simulator/runtime|GUI automation unavailable|macOS GUI automation unavailable|## Next Decisions'
# script/ledger_progress.js intentionally embeds overclaim phrases as detectors — exclude it.
FILES="AGENTS.md PROGRESS.md goal.json goal.template.json DESIGN.md docs/references docs/workflows script/goal_next.js script/verify_goal_contract.js script/verify_ledger_progress.js script/phase_preflight.js package.json validation README.md apps"

total=0
echo "## stale_string_hits"
while IFS=: read -r file count; do
  if [[ -n "${file:-}" && "${count:-0}" -gt 0 ]]; then
    echo "$file: $count matches"
    total=$((total + count))
  fi
done < <(rg -c "$PATTERNS" $FILES 2>/dev/null | grep -v '^script/phase_preflight\.js:' || true)

echo "stale_string_total: $total"

if (( total > 0 )); then
  if [[ "$DETAIL" == "--detail" ]]; then
    echo
    rg -n "$PATTERNS" $FILES 2>/dev/null \
      | grep -v '^script/phase_preflight\.js:.*pattern:' \
      | grep -v ':.*- \[x\]' || true
  else
    echo "(pass --detail to list non-completed lines)"
  fi
fi

# Duplicate ledger surface: sibling .md next to validation JSON (JSON is sole control-status owner).
echo
echo "## ledger_desync"
desync=0
if [[ -d validation ]]; then
  while IFS= read -r -d '' md; do
    # Ignore README and non-ledger docs under validation/
    base="$(basename "$md")"
    [[ "$base" == "README.md" ]] && continue
    json="${md%.md}.json"
    if [[ -f "$json" ]]; then
      echo "desync: duplicate ledger $md (remove; owner is $json)"
      desync=$((desync + 1))
    fi
  done < <(find validation -name '*.md' -print0 2>/dev/null)
fi
echo "ledger_desync_total: $desync"

# Dirty path class vs goal.json goal text (hint only; cost_scan judges).
echo
echo "## dirty_vs_goal_hint"
if [[ -f goal.json ]] && command -v git >/dev/null 2>&1; then
  dirty="$(git status --short 2>/dev/null || true)"
  goal="$(rg -o '"goal":\s*"[^"]+"' goal.json 2>/dev/null | head -1 || true)"
  if [[ -n "$dirty" ]]; then
    dirty_macos=0
    dirty_phase_release=0
    echo "$dirty" | rg -q 'LikemindedMac|validation/macos|DoodleArt|doodle-art|mockups/macos|macos_cua' && dirty_macos=1 || true
    echo "$dirty" | rg -q 'render\.yaml|testflight|release/' && dirty_phase_release=1 || true
    goal_macos=0
    goal_phase9=0
    echo "$goal" | rg -qi 'macOS Visual Parity|validation/macos|macos ledger' && goal_macos=1 || true
    echo "$goal" | rg -qi 'Phase 9|TestFlight|Neon|Render' && goal_phase9=1 || true
    if (( dirty_macos == 1 && goal_macos == 0 )); then
      echo "hint: dirty macOS-track paths but goal.json does not name macOS Visual Parity / validation/macos"
    fi
    if (( dirty_phase_release == 1 && goal_phase9 == 0 && goal_macos == 1 )); then
      echo "hint: dirty release paths while goal is macOS track — confirm intentional"
    fi
    if (( dirty_macos == 0 && dirty_phase_release == 0 )); then
      echo "hint: none (no macOS-track or release-path dirty class detected)"
    elif (( dirty_macos == 1 && goal_macos == 1 )); then
      echo "hint: none (dirty macOS paths align with macOS-track goal)"
    fi
  else
    echo "hint: none (clean tree)"
  fi
else
  echo "hint: skipped (no goal.json or git)"
fi
