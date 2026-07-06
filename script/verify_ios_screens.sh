#!/usr/bin/env bash
# Sequential iOS capture batch — thin wrapper over cross_platform_screen_validate.sh.
# Uses locks, explicit simulator UDID, build-only + deep-link launch (not build_and_run run).
#
# Prefer one screen: npm run validate:screen -- --screen <ledger-id> --platform ios
# Full gap audit: npm run ledger:open then validate:screen per open row.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATE="$ROOT_DIR/script/cross_platform_screen_validate.sh"

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

if [[ $# -gt 0 ]]; then
  screens=("$@")
else
  screens=("${default_screens[@]}")
fi

export LIKEMINDED_VALIDATION_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"
export LIKEMINDED_VALIDATION_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}"

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
