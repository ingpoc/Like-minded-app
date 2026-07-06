#!/usr/bin/env bash
# Sequential iOS capture batch — thin wrapper over cross_platform_screen_validate.sh.
# Uses locks, explicit simulator UDID, build-only + deep-link launch (not build_and_run run).
#
# Prefer one screen: npm run validate:screen -- --screen <ledger-id> --platform ios
# Stale reproof: npm run verify:ios-screens -- --stale-only
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATE="$ROOT_DIR/script/cross_platform_screen_validate.sh"
STAMP_STALE=0

# Default batch (legacy smoke set + common parity screens). Override: verify_ios_screens.sh 07-meet 16-chat …
default_screens=(
  01-auth-gate
  02-onboarding
  04-profile-populated
  07-meet
  09-group-video-call
  10-circles
  12-communities
  14-soulmate
  16-chat
  18-soulmate-selection
  20-settings
  21-settings-privacy
  22-settings-info
  24-create-community
  26-create-event
)

usage() {
  cat <<EOF
Usage: $0 [options] [ledger-id ...]

Options:
  --stale-only   Capture only ledger screens with stale-pass controls; stamp hashes after capture
  -h, --help     Show this help

Default (no args): legacy smoke screen list.
EOF
}

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stale-only) STAMP_STALE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

if ((${#args[@]} > 0)); then
  screens=("${args[@]}")
elif (( STAMP_STALE == 1 )); then
  mapfile -t screens < <(node "$ROOT_DIR/script/ledger_stale_screens.js" --platform ios)
  if ((${#screens[@]} == 0)); then
    echo "iOS stale-pass: no screens to capture"
    exit 0
  fi
  echo "iOS stale-only capture: ${#screens[@]} screen(s)" >&2
else
  screens=("${default_screens[@]}")
fi

export LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"
export LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}"

LOCK="$ROOT_DIR/script/cross_platform_validation_lock.sh"
echo "== iOS batch: one build for ${#screens[@]} screen(s) ==" >&2
"$LOCK" with_lock xcodebuild-ios bash -c "
  set -euo pipefail
  '$ROOT_DIR/script/build_and_run.sh' build > /tmp/likeminded-ios-batch-build.log 2>&1
"
export LIKEMINDED_SKIP_IOS_BUILD=1

captured=0
failed=0
failed_screens=()

for screen in "${screens[@]}"; do
  echo "=== iOS capture: $screen ===" >&2
  if "$VALIDATE" --screen "$screen" --platform ios; then
    captured=$((captured + 1))
  else
    failed=$((failed + 1))
    failed_screens+=("$screen")
  fi
done

echo "iOS batch: $captured/${#screens[@]} succeeded, $failed failed"
if (( failed > 0 )); then
  echo "Failed: ${failed_screens[*]}" >&2
  exit 1
fi
echo "Screenshots: $ROOT_DIR/output/validation/ios-screens"

if (( STAMP_STALE == 1 )); then
  echo "== stamp stale iOS controls ==" >&2
  node "$ROOT_DIR/script/ledger_stamp_stale_pass.js" \
    --platform ios \
    --method screen-capture \
    --evidence-prefix "screen-capture ${LIKEMINDED_VALIDATION_USER} $(date -u +%Y-%m-%d) reproof"
fi
