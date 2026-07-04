#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/apps/ios-macos"
APP_PATH="$ROOT_DIR/.build/macos/Build/Products/Debug/LikemindedMac.app"
SCREEN="${1:-meetOverview}"
USER_TOKEN="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"
USER_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}"
WINDOW_WIDTH="${LIKEMINDED_MAC_WINDOW_WIDTH:-1200}"
WINDOW_HEIGHT="${LIKEMINDED_MAC_WINDOW_HEIGHT:-760}"

if ! curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null 2>&1; then
  echo "Start the validation API first: npm run dev:api:validation" >&2
  exit 1
fi

(cd "$ROOT_DIR" && npm run reset:validation-data >/dev/null 2>&1)

if [[ ! -d "$APP_PATH" ]]; then
  (cd "$IOS_DIR" && xcodegen generate)
  xcodebuild \
    -project "$IOS_DIR/Likeminded.xcodeproj" \
    -scheme LikemindedMac \
    -destination 'platform=macOS' \
    -derivedDataPath "$ROOT_DIR/.build/macos" \
    build
fi

pkill -x LikemindedMac >/dev/null 2>&1 || true
open -F -n "$APP_PATH" --args \
  --likeminded-reset-auth-session \
  --likeminded-dev-auth-bypass \
  --likeminded-dev-auth-token "$USER_TOKEN" \
  --likeminded-dev-auth-name "$USER_NAME" \
  --mac-screen "$SCREEN"

sleep 2
osascript <<APPLESCRIPT >/dev/null 2>&1 || true
tell application "LikemindedMac" to activate
tell application "System Events"
  tell process "LikemindedMac"
    set frontmost to true
    if (count of windows) > 0 then
      set size of window 1 to {$WINDOW_WIDTH, $WINDOW_HEIGHT}
      set position of window 1 to {80, 80}
    end if
  end tell
end tell
APPLESCRIPT

echo "Launched LikemindedMac screen=$SCREEN user=$USER_TOKEN window=${WINDOW_WIDTH}x${WINDOW_HEIGHT}"
