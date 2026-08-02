#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=macos_canonical_app.sh
source "$ROOT_DIR/script/macos_canonical_app.sh"

SCREEN_REQUEST="${1:-meetOverview}"
SCREEN="$SCREEN_REQUEST"
EXTRA_LAUNCH_ARGS=()
case "$SCREEN_REQUEST" in
  voice-session)
    SCREEN="profileOnboarding"
    ;;
  profileVoiceStepPanel)
    SCREEN="profileOnboarding"
    EXTRA_LAUNCH_ARGS+=(--likeminded-dev-profile-empty)
    ;;
esac
USER_TOKEN="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"
USER_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}"
WINDOW_WIDTH="${LIKEMINDED_MAC_WINDOW_WIDTH:-1200}"
WINDOW_HEIGHT="${LIKEMINDED_MAC_WINDOW_HEIGHT:-760}"

if ! curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null 2>&1; then
  echo "Start the validation API first: npm run dev:api:validation" >&2
  exit 1
fi

(cd "$ROOT_DIR" && npm run reset:validation-data >/dev/null 2>&1)

macos_launch \
  --likeminded-reset-auth-session \
  --likeminded-dev-auth-bypass \
  --likeminded-dev-auth-token "$USER_TOKEN" \
  --likeminded-dev-auth-name "$USER_NAME" \
  --mac-screen "$SCREEN" \
  "${EXTRA_LAUNCH_ARGS[@]}"

sleep 2

echo "Launched canonical $MACOS_CANONICAL_APP screen=$SCREEN_REQUEST route=$SCREEN user=$USER_TOKEN window=${WINDOW_WIDTH}x${WINDOW_HEIGHT}; continue with bundled @Computer"
