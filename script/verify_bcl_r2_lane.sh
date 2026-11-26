#!/usr/bin/env bash
# bcl round-2 lane verify: API suite on the pinned Node, then the installed Mac app must be built from this worktree's HEAD.
# Live UI acceptance (CUA screenshots in docs/triage/shots/*-fixed.png) is recorded separately per finding.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT_DIR/script/verify_node20.sh"
APP="${LIKEMINDED_INSTALLED_APP:-$HOME/Applications/Likeminded.app}"
STAMP="${APP%.app}.bcl-revision"  # written beside the bundle so the code signature stays intact
[[ -f "$STAMP" ]] || { echo "FAIL no install stamp at $STAMP (install via the signed Debug build)" >&2; exit 1; }
HEAD_SHA="$(git -C "$ROOT_DIR" rev-parse HEAD)"
GOT="$(cat "$STAMP")"
[[ "$GOT" == "$HEAD_SHA" ]] || { echo "FAIL installed app is $GOT, worktree HEAD is $HEAD_SHA" >&2; exit 1; }
echo "PASS installed Mac app built from $HEAD_SHA"
codesign --verify --deep "$APP" && echo "PASS codesign"
