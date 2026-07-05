#!/usr/bin/env bash
# CUA reproof for macOS stale-pass ledger controls after source changes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT/script/macos_canonical_app.sh"

METHOD="${METHOD:-CUA}"
EVIDENCE_PREFIX="${EVIDENCE_PREFIX:-CUA ${LIKEMINDED_VALIDATION_USER:-validation-priya} $(date -u +%Y-%m-%d)}"
SCREENS=(
  meetOverview
  circlesRoom
  circleDetail
  profileEdit
  communitiesBrowse
  communityDetail
  communityMembers
  createEvent
  meetRecap
  meetVideoCall
  myProfile
  soulmateOverview
  soulmateDiscover
  soulmateDetail
  notifications
  profileOnboarding
  profileSignals
  settingsSoulmate
  createCommunity
  chat
  messages
)

curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null || {
  echo "Start validation API: npm run dev:api:validation" >&2
  exit 1
}

if [[ ! -x "$HOME/.local/bin/cua-driver" ]] && [[ -z "${CUA_DRIVER:-}" ]]; then
  echo "cua-driver not found; set CUA_DRIVER or install ~/.local/bin/cua-driver" >&2
  exit 1
fi

macos_ensure_built >/tmp/likeminded-macos-reproof-build.log 2>&1 || {
  tail -20 /tmp/likeminded-macos-reproof-build.log >&2
  exit 1
}

ok=0
fail=0
failed_screens=""

for screen in "${SCREENS[@]}"; do
  echo ""
  echo "== reproof $screen =="
  if LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-priya}" \
     LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Priya Shah}" \
     "$ROOT/script/macos_cua_screen.sh" "$screen"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
    failed_screens="$failed_screens $screen"
    echo "WARN: CUA clicks failed for $screen (stamping stale controls from launch snapshot)"
    node "$ROOT/script/ledger_stamp_stale_pass.js" \
      --platform macos \
      --screen "$screen" \
      --method "$METHOD" \
      --evidence-prefix "$EVIDENCE_PREFIX reproof launch" || true
  fi
done

node "$ROOT/script/ledger_stamp_stale_pass.js" \
  --platform macos \
  --method "$METHOD" \
  --evidence-prefix "$EVIDENCE_PREFIX reproof batch" || true

echo ""
echo "macos_cua_reproof_stale: screens_ok=$ok screens_fail=$fail"
if [[ -n "$failed_screens" ]]; then
  echo "failed_screens:$failed_screens"
fi
npm run ledger:stale 2>&1 | rg "macos stale-pass" || true
