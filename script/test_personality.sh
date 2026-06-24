#!/usr/bin/env bash
# Quick smoke test for personality extraction + circle matching
# Run after API server is running: ./script/test_profile.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8787}"

declare -a TESTS=(
  "I love meeting new people and being around groups. I trust quickly and speak directly. I want adventure and new experiences."
  "I need time to trust people. I prefer deep one-on-one conversations about ideas. I think before speaking and avoid conflict."
  "I'm organized, steady, and prefer calm. I show up consistently for people I care about. Warm, gentle humor."
)

declare -a EXPECTED_CIRCLES=(
  "Bold Explorers"
  "Reflective Builders"
  "Grounded Nurturers"
)

echo "Testing personality extraction + circle matching..."
echo

PASS=0
FAIL=0

for i in "${!TESTS[@]}"; do
  result=$(curl -s -X POST "http://127.0.0.1:${PORT}/v1/discover" \
    -H "content-type: application/json" \
    -d "$(python3 -c "import sys,json; print(json.dumps({'interviewTranscript': sys.stdin.read()}))" <<< "${TESTS[$i]}")")
  
  circle=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['placement']['primaryCircle']['name'])" 2>/dev/null || echo "ERROR")
  
  if [[ "$circle" == "${EXPECTED_CIRCLES[$i]}" ]]; then
    echo "  PASS: Test $((i+1)) → $circle"
    ((PASS++))
  else
    echo "  FAIL: Test $((i+1)) → expected ${EXPECTED_CIRCLES[$i]}, got $circle"
    ((FAIL++))
  fi
done

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
