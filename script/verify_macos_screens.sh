#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/apps/ios-macos"
PROJECT_FILE="$IOS_DIR/Likeminded.xcodeproj"
DERIVED_DATA="$ROOT_DIR/.build/macos"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/LikemindedMac.app"
OUT_DIR="$ROOT_DIR/output/validation/macos-screens"
API_LOG="/tmp/likeminded-validation-api.log"
api_pid=""

screens=(
  welcome
  meetOverview
  circlesRoom
  profileEdit
  chat
  communitiesBrowse
  communityDetail
  meetRecap
  myProfile
  soulmateOverview
  soulmateDiscover
  soulmateDetail
  communityMembers
  createEvent
  messages
  notifications
  profileOnboarding
  profileSignals
  circleDetail
  settingsSoulmate
)

cleanup() {
  pkill -x LikemindedMac >/dev/null 2>&1 || true
  if [[ -n "$api_pid" ]]; then
    kill "$api_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

wait_for_api() {
  local deadline=$((SECONDS + 10))
  while (( SECONDS < deadline )); do
    if curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  echo "validation API did not become healthy; log follows:" >&2
  cat "$API_LOG" >&2 || true
  exit 1
}

capture_likeminded_window() {
  local output_path="$1"
  local window_id
  window_id="$(python3 - <<'PY'
import Quartz

windows = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID,
)
for window in windows:
    owner = window.get("kCGWindowOwnerName") or ""
    bounds = window.get("kCGWindowBounds", {})
    if owner.startswith("Likeminded") and bounds.get("Width", 0) > 400 and bounds.get("Height", 0) > 300:
        print(window["kCGWindowNumber"])
        break
PY
)"
  if [[ -n "$window_id" ]]; then
    screencapture -x -l "$window_id" "$output_path"
  else
    screencapture -x -R80,80,1200,760 "$output_path"
  fi
}

mkdir -p "$OUT_DIR"
"$ROOT_DIR/script/run_validation_api.sh" >"$API_LOG" 2>&1 &
api_pid="$!"
wait_for_api
(cd "$ROOT_DIR" && npm run reset:validation-data >/tmp/likeminded-validation-seed.log)

(cd "$IOS_DIR" && xcodegen generate)
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme LikemindedMac \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build >/tmp/likeminded-macos-build.log

for screen in "${screens[@]}"; do
  pkill -x LikemindedMac >/dev/null 2>&1 || true
  open -F -n "$APP_PATH" --args --likeminded-reset-auth-session --likeminded-dev-auth-bypass --likeminded-dev-auth-token validation-priya --likeminded-dev-auth-name "Priya Shah" --mac-screen "$screen"
  sleep 3
  osascript <<'APPLESCRIPT' >/dev/null || true
with timeout of 3 seconds
  tell application "LikemindedMac" to activate
  delay 0.2
  tell application "System Events"
    tell process "LikemindedMac"
      set frontmost to true
      set size of window 1 to {1200, 760}
      set position of window 1 to {80, 80}
    end tell
  end tell
end timeout
APPLESCRIPT
  capture_likeminded_window "$OUT_DIR/$screen.png"
done

(cd "$ROOT_DIR" && npm run remove:validation-data >/tmp/likeminded-validation-remove.log)
echo "macOS screen captures written to $OUT_DIR"
