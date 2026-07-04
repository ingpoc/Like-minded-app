#!/usr/bin/env bash
set -eu

ROOT="${1:-.}"

# Structured summary, not raw dumps

echo "# Requirements Surface Summary"

echo
echo "## Route"
route=$(cd "$ROOT" && ./script/project_context.sh query --task "requirements gap audit" 2>/dev/null || true)
if [[ -n "$route" ]]; then
  echo "$route" | head -5
else
  echo "(no active route)"
fi

echo
echo "## Mockups"
mockup_count=$(find "$ROOT/mockups" -maxdepth 2 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) 2>/dev/null | wc -l | tr -d ' ')
echo "Mockup files: $mockup_count"

echo
echo "## Dead control signals"
dead_count=$(rg -c "coming soon|TODO|disabled|placeholder|stub|not implemented|fake|static|mock only|No .* yet|could not be loaded" "$ROOT" \
  -g'*.md' -g'*.swift' -g'*.js' -g'*.sh' -g'*.json' \
  -g'!node_modules' -g'!.build' -g'!output' 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')
echo "Dead control hits: $dead_count"
if (( dead_count > 0 )); then
  rg -c "coming soon|TODO|disabled|placeholder|stub|not implemented|fake|static|mock only|No .* yet|could not be loaded" "$ROOT" \
    -g'*.md' -g'*.swift' -g'*.js' -g'*.sh' -g'*.json' \
    -g'!node_modules' -g'!.build' -g'!output' 2>/dev/null | grep -v ':0$' | sort -t: -k2 -rn | head -10
fi

echo
echo "## Runtime proof"
proof_count=$(rg -c "runtime tap|manual proof|simulator|verify:macos-screens|verify:simulator-local|smoke:mvp|phase:preflight" "$ROOT/PROGRESS.md" "$ROOT/docs" "$ROOT/script" 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')
echo "Runtime proof hits: $proof_count"
