#!/usr/bin/env bash
# Test personality extraction + circle matching without the UI
# Usage: ./script/test_profile.sh "interview transcript here"
#        ./script/test_profile.sh --file path/to/transcript.txt
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8787}"

if [[ "${1:-}" == "--file" ]]; then
  TRANSCRIPT=$(cat "$2")
elif [[ -n "${1:-}" ]]; then
  TRANSCRIPT="$1"
else
  echo "Usage: $0 \"interview transcript\"" >&2
  echo "       $0 --file path/to/transcript.txt" >&2
  exit 1
fi

curl -s -X POST "http://127.0.0.1:${PORT}/v1/discover" \
  -H "content-type: application/json" \
  -d "$(python3 -c "import sys,json; print(json.dumps({'interviewTranscript': sys.stdin.read()}))" <<< "$TRANSCRIPT")" \
  | python3 -m json.tool
