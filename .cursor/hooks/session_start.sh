#!/usr/bin/env bash
# sessionStart: inject compact goal:next route (best-effort; verify:goal is authoritative).
set -eu
cat >/dev/null || true
cd "$(dirname "$0")/../.." 2>/dev/null || exit 0
node script/session_route.js --hook-json
