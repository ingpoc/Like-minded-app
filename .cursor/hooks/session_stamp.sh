#!/usr/bin/env bash
# preCompact + sessionEnd: refresh session/work-bucket.json from dirty paths (best-effort).
set -eu
cat >/dev/null || true
cd "$(dirname "$0")/../.." 2>/dev/null || exit 0
node script/session_work_bucket.js --auto --trigger "${CURSOR_HOOK_EVENT:-cursor-hook}" >/dev/null 2>&1 || true
exit 0
