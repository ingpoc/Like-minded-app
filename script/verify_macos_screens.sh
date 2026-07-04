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
  local deadline=$((SECONDS + 10))
  while (( SECONDS < deadline )); do
    window_id="$(python3 -c "
import Quartz
for w in Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID):
    o = w.get('kCGWindowOwnerName') or ''
    b = w.get('kCGWindowBounds', {})
    if o.startswith('Likeminded') and b.get('Width',0) > 400 and b.get('Height',0) > 300:
        print(w['kCGWindowNumber']); break
" 2>/dev/null)"
    if [[ -n "$window_id" ]]; then
      screencapture -x -l "$window_id" "$output_path"
      local size
      size=$(stat -f%z "$output_path" 2>/dev/null || echo 0)
      if (( size < 10000 )); then
        echo "Screenshot too small (${size}B) for $output_path — retrying" >&2
        rm -f "$output_path"
        sleep 0.5
        continue
      fi
      return 0
    fi
    sleep 0.5
  done
  echo "Likeminded app window not found for $output_path" >&2
  exit 1
}

mkdir -p "$OUT_DIR"
captured=0
failed=0
failed_screens=""
if lsof -ti :"${PORT:-8787}" >/dev/null 2>&1; then
  kill "$(lsof -ti :"${PORT:-8787}")" >/dev/null 2>&1 || true
  sleep 1
fi
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
  build >/tmp/likeminded-macos-build.log 2>&1 || {
  echo "BUILD FAILED — see /tmp/likeminded-macos-build.log" >&2
  tail -20 /tmp/likeminded-macos-build.log >&2
  exit 1
}

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
  if capture_likeminded_window "$OUT_DIR/$screen.png"; then
    captured=$((captured + 1))
  else
    failed=$((failed + 1))
    failed_screens="$failed_screens $screen"
  fi
done

(cd "$ROOT_DIR" && npm run remove:validation-data >/tmp/likeminded-validation-remove.log)
echo "macOS captures: $captured/${#screens[@]} succeeded, $failed failed"
if (( failed > 0 )); then
  echo "Failed screens:$failed_screens" >&2
  exit 1
fi
echo "Screenshots: $OUT_DIR"
