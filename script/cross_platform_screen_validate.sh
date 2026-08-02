#!/usr/bin/env bash
# iOS single-screen validation entrypoint with flock/lockf coordination.
#
# Agent hygiene (see docs/workflows/validation.md § Parallel screen validation):
#   - Wave 1: parallel Swift/ledger edits OK.
#   - Wave 2: sequential build + capture via this script only.
#   - iOS: explicit simulator UDID (not booted); 15–60s post-launch wait.
#   - Never bare pkill/open/simctl outside cross_platform_validation_lock.sh.
#
# Does not restart validation API or re-seed when :8787 is already healthy on validation-db.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/script/cross_platform_validation_lock.sh"
PORT="${PORT:-8787}"
BUNDLE_ID="${BUNDLE_ID:-com.gurusharan.likeminded}"
USER_TOKEN="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"
USER_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}"
IOS_CAPTURE_WAIT="${IOS_CAPTURE_WAIT:-15}"
SIMULATOR_ID="${SIMULATOR_ID:-}"
IOS_IDB_CTL="$ROOT/validation/idb_ctl.sh"
API_LOG="/tmp/likeminded-screen-validate-api.log"

SCREEN=""
PLATFORM=""
OUT_IOS="$ROOT/output/validation/ios-screens"

usage() {
  cat <<EOF
Usage: $0 --screen <ledger-id> --platform ios

Single-screen validation with flock coordination. Uses validation-gurusharan / Gurusharan Gupta.

  --screen <id>     Ledger id (e.g. 07-meet, meet, 02-meet-overview)
  --platform ios    iOS simulator capture only
Lock order: seed (only when API was down) → ios-sim → release.

Examples:
  $0 --screen 07-meet --platform ios
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --screen) SCREEN="$2"; shift 2 ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$SCREEN" && -n "$PLATFORM" ]] || { usage >&2; exit 2; }
[[ "$PLATFORM" == "ios" ]] || {
  echo "macOS native proof uses testing-ledger + bundled @Computer; this script accepts only --platform ios" >&2
  exit 2
}

api_healthy() {
  curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1
}

wait_for_api() {
  local deadline=$((SECONDS + 20))
  while (( SECONDS < deadline )); do
    if api_healthy; then
      return 0
    fi
    sleep 0.3
  done
  echo "validation API did not become healthy; log:" >&2
  cat "$API_LOG" >&2 || true
  return 1
}

ensure_validation_api() {
  if api_healthy; then
    echo "validation API healthy on :$PORT (validation-db) — not restarting or re-seeding"
    return 0
  fi

  echo "validation API down — acquiring api + seed locks" >&2
  "$LOCK" with_lock api bash -c "
    set -euo pipefail
    if curl -fsS 'http://127.0.0.1:${PORT}/health' >/dev/null 2>&1; then
      exit 0
    fi
    if lsof -ti :'${PORT}' >/dev/null 2>&1; then
      kill \"\$(lsof -ti :'${PORT}')\" >/dev/null 2>&1 || true
      sleep 1
    fi
    '$ROOT/script/run_validation_api.sh' >'$API_LOG' 2>&1 &
    echo \$! > /tmp/likeminded-validation-api.pid
    deadline=\$((SECONDS + 20))
    while (( SECONDS < deadline )); do
      if curl -fsS 'http://127.0.0.1:${PORT}/health' >/dev/null 2>&1; then
        exit 0
      fi
      sleep 0.3
    done
    echo 'API failed to start' >&2
    exit 1
  "

  "$LOCK" with_lock seed bash -c "cd '$ROOT' && npm run reset:validation-data"
}

ios_capture_slug() {
  local ledger_id="$1"
  case "$ledger_id" in
    01-auth-gate|auth-gate) echo "auth-gate" ;;
    02-onboarding|onboarding) echo "onboarding" ;;
    03-profile-empty|profile-empty) echo "profile-empty" ;;
    04-profile-populated|profile-populated) echo "profile-populated" ;;
    05-profile-concern|profile-concern) echo "profile-concern" ;;
    06-voice-session-sheet|voice-session-sheet|voice-session) echo "voice-session-sheet" ;;
    profile-edit) echo "profile-edit" ;;
    profile-signals) echo "profile-signals" ;;
    07-meet|meet) echo "meet" ;;
    08-past-meet-detail|past-meet-detail|past-meet-recap) echo "past-meet-detail" ;;
    09-group-video-call|group-video-call) echo "group-video-call" ;;
    10-circles|circles) echo "circles" ;;
    11-circle-detail|circle-detail) echo "circle-detail" ;;
    12-communities|communities) echo "communities" ;;
    13-community-detail|community-detail) echo "community-detail" ;;
    14-soulmate|soulmate|soulmate-overview) echo "soulmate" ;;
    15-soulmate-match-detail|soulmate-match-detail) echo "soulmate-match-detail" ;;
    16-chat|chat) echo "chat" ;;
    17-conversations|conversations) echo "conversations" ;;
    18-soulmate-selection|soulmate-selection) echo "soulmate-selection" ;;
    19-notifications|notifications) echo "notifications" ;;
    20-settings|settings) echo "settings" ;;
    21-settings-privacy|settings-privacy) echo "settings-privacy" ;;
    22-settings-info|settings-info) echo "settings-info" ;;
    23-settings-support|settings-support) echo "settings-support" ;;
    24-create-community|create-community) echo "create-community" ;;
    25-community-members|community-members) echo "community-members" ;;
    26-create-event|create-event) echo "create-event" ;;
    *) echo "$ledger_id" ;;
  esac
}

ios_launch_args_for_screen() {
  local ledger_id="$1"
  local common=(
    --likeminded-reset-auth-session
    --likeminded-dev-auth-bypass
    --likeminded-dev-auth-token "$USER_TOKEN"
    --likeminded-dev-auth-name "$USER_NAME"
  )

  case "$ledger_id" in
    01-auth-gate|auth-gate)
      printf '%s\n' --likeminded-reset-auth-session
      ;;
    02-onboarding|onboarding)
      printf '%s\n' "${common[@]}" --likeminded-force-onboarding --likeminded-start-profile
      ;;
    03-profile-empty|profile-empty)
      printf '%s\n' "${common[@]}" --likeminded-start-profile
      ;;
    04-profile-populated|profile-populated)
      printf '%s\n' "${common[@]}" --likeminded-start-profile
      ;;
    05-profile-concern|profile-concern)
      printf '%s\n' "${common[@]}" --likeminded-start-profile
      ;;
    06-voice-session-sheet|voice-session-sheet|voice-session)
      printf '%s\n' "${common[@]}" --likeminded-start-profile --likeminded-start-voice-session --likeminded-dev-voice-preview
      ;;
    profile-edit)
      printf '%s\n' "${common[@]}" --likeminded-start-profile --likeminded-start-profile-edit
      ;;
    profile-signals)
      printf '%s\n' "${common[@]}" --likeminded-start-profile --likeminded-start-profile-signals
      ;;
    07-meet|meet)
      printf '%s\n' "${common[@]}"
      ;;
    08-past-meet-detail|past-meet-detail|past-meet-recap)
      printf '%s\n' "${common[@]}" --likeminded-start-past-meet-detail
      ;;
    09-group-video-call|group-video-call|video-call)
      printf '%s\n' "${common[@]}" --likeminded-start-video-call --likeminded-dev-meet-join
      ;;
    10-circles|circles)
      printf '%s\n' "${common[@]}" --likeminded-start-circles
      ;;
    11-circle-detail|circle-detail)
      printf '%s\n' "${common[@]}" --likeminded-start-circles --likeminded-start-circle-detail
      ;;
    12-communities|communities)
      printf '%s\n' "${common[@]}" --likeminded-start-communities
      ;;
    13-community-detail|community-detail)
      printf '%s\n' "${common[@]}" --likeminded-start-community-detail --likeminded-community-id jazz-music
      ;;
    14-soulmate|soulmate|soulmate-overview)
      printf '%s\n' "${common[@]}" --likeminded-start-soulmate
      ;;
    15-soulmate-match-detail|soulmate-match-detail)
      printf '%s\n' "${common[@]}" --likeminded-start-soulmate --likeminded-start-soulmate-match-detail
      ;;
    16-chat|chat)
      printf '%s\n' "${common[@]}" --likeminded-start-chat
      ;;
    17-conversations|conversations)
      printf '%s\n' "${common[@]}" --likeminded-start-conversations
      ;;
    18-soulmate-selection|soulmate-selection)
      printf '%s\n' "${common[@]}" --likeminded-start-soulmate-selection
      ;;
    19-notifications|notifications)
      printf '%s\n' "${common[@]}" --likeminded-start-notifications
      ;;
    20-settings|settings)
      printf '%s\n' "${common[@]}" --likeminded-start-settings
      ;;
    21-settings-privacy|settings-privacy)
      printf '%s\n' "${common[@]}" --likeminded-open-privacy-policy
      ;;
    22-settings-info|settings-info)
      printf '%s\n' "${common[@]}" --likeminded-start-settings-info
      ;;
    23-settings-support|settings-support)
      printf '%s\n' "${common[@]}" --likeminded-start-settings-support
      ;;
    24-create-community|create-community)
      printf '%s\n' "${common[@]}" --likeminded-start-create-community
      ;;
    25-community-members|community-members)
      printf '%s\n' "${common[@]}" --likeminded-start-community-members --likeminded-community-id ai-builders
      ;;
    26-create-event|create-event)
      printf '%s\n' "${common[@]}" --likeminded-start-create-event
      ;;
    *)
      printf '%s\n' "${common[@]}"
      ;;
  esac
}

resolve_ios_simulator() {
  if [[ -n "$SIMULATOR_ID" ]]; then
    echo "$SIMULATOR_ID"
    return 0
  fi
  local preferred="${SIMULATOR_NAME:-iPhone 17}"
  local id
  id=$(xcrun simctl list devices available 2>/dev/null | grep -F "$preferred " | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')
  if [[ -z "$id" ]]; then
    echo "Simulator '$preferred' not found" >&2
    return 1
  fi
  xcrun simctl boot "$id" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
  echo "$id"
}

IOS_APP_PATH="$ROOT/.build/ios-simulator/Build/Products/Debug-iphonesimulator/Likeminded.app"
IOS_SOURCE_ROOT="$ROOT/apps/ios-macos"

ios_app_exec() {
  if [[ -x "$IOS_APP_PATH/Likeminded" ]]; then
    echo "$IOS_APP_PATH/Likeminded"
  elif [[ -x "$IOS_APP_PATH/Contents/MacOS/Likeminded" ]]; then
    echo "$IOS_APP_PATH/Contents/MacOS/Likeminded"
  fi
}

ios_needs_build() {
  if [[ "${LIKEMINDED_SKIP_IOS_BUILD:-0}" == "1" ]]; then
    return 1
  fi
  if [[ "${LIKEMINDED_FORCE_IOS_BUILD:-0}" == "1" ]]; then
    return 0
  fi
  local exec_path
  exec_path="$(ios_app_exec || true)"
  if [[ -z "$exec_path" ]]; then
    return 0
  fi
  local newest_source binary_mtime
  newest_source="$(
    find "$IOS_SOURCE_ROOT/Sources/LikemindedApp" "$IOS_SOURCE_ROOT/project.yml" \
      -type f \( -name '*.swift' -o -name 'project.yml' \) -print0 2>/dev/null \
      | xargs -0 stat -f '%m' 2>/dev/null | sort -rn | head -1
  )"
  binary_mtime="$(stat -f '%m' "$exec_path" 2>/dev/null || echo 0)"
  if [[ -n "$newest_source" && "$newest_source" -gt "$binary_mtime" ]]; then
    return 0
  fi
  return 1
}

ios_capture_wait_for_screen() {
  local ledger_id="$1"
  local wait="${IOS_CAPTURE_WAIT:-15}"
  case "$ledger_id" in
    16-chat|chat)
      if (( wait < 30 )); then
        wait=30
      fi
      ;;
  esac
  echo "$wait"
}

ios_sim_launch_and_capture() {
  local sim_id="$1"
  local outfile="$2"
  local wait="$3"
  local idb_ctl="$4"
  shift 4
  xcrun simctl launch --terminate-running-process "$sim_id" "$BUNDLE_ID" "$@" >/dev/null
  sleep "$wait"

  account_verification_present() {
    IDB_UDID="$sim_id" "$idb_ctl" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata

def normalized(value):
    return " ".join(unicodedata.normalize("NFKC", str(value or "")).split())

data = json.load(sys.stdin)
needle = "Apple Account Verification"
raise SystemExit(0 if any(
    needle in normalized(element.get(key))
    for element in data
    for key in ("AXLabel", "label", "AXValue", "value")
) else 1)
'
  }

  if account_verification_present; then
    IDB_UDID="$sim_id" "$idb_ctl" tap "Not Now"
    sleep 1
    if account_verification_present; then
      echo "Apple Account Verification still obscures iOS capture" >&2
      return 1
    fi
    echo "dismissed iOS Simulator Apple Account Verification alert" >&2
  fi

  xcrun simctl io "$sim_id" screenshot "$outfile"
}

validate_ios_screen() {
  local slug outfile args=()
  slug="$(ios_capture_slug "$SCREEN")"
  outfile="$OUT_IOS/$slug.png"
  mkdir -p "$OUT_IOS"

  while IFS= read -r arg; do
    args+=("$arg")
  done < <(ios_launch_args_for_screen "$SCREEN")

  echo "iOS validate screen=$SCREEN slug=$slug args=${args[*]}" >&2

  local sim_id capture_wait
  sim_id="$(resolve_ios_simulator)"
  capture_wait="$(ios_capture_wait_for_screen "$SCREEN")"

  if ios_needs_build; then
    "$LOCK" with_lock xcodebuild-ios bash -c "
      set -euo pipefail
      '$ROOT/script/build_and_run.sh' build > /tmp/likeminded-ios-build-\$\$.log 2>&1
    "
  else
    if [[ "${LIKEMINDED_SKIP_IOS_BUILD:-0}" == "1" ]]; then
      echo "iOS build skipped (LIKEMINDED_SKIP_IOS_BUILD=1)" >&2
    else
      echo "iOS build skipped (fresh binary at $(ios_app_exec))" >&2
    fi
    "$LOCK" with_lock xcodebuild-ios bash -c "
      set -euo pipefail
      '$ROOT/script/build_and_run.sh' install > /tmp/likeminded-ios-install-\$\$.log 2>&1
    "
  fi

  "$LOCK" with_lock ios-sim bash -c "
    set -euo pipefail
    BUNDLE_ID='$(printf '%q' "$BUNDLE_ID")'
    SIMULATOR_ID='$(printf '%q' "$sim_id")'
    CAPTURE_WAIT='$(printf '%q' "$capture_wait")'
    IOS_IDB_CTL='$(printf '%q' "$IOS_IDB_CTL")'
    $(declare -f ios_sim_launch_and_capture)
    ios_sim_launch_and_capture \"\$SIMULATOR_ID\" $(printf '%q' "$outfile") \"\$CAPTURE_WAIT\" \"\$IOS_IDB_CTL\" $(printf ' %q' "${args[@]}")
  "

  local size
  size=$(stat -f%z "$outfile" 2>/dev/null || echo 0)
  if (( size < 10000 )); then
    echo "WARN: $outfile is ${size}B — likely blank" >&2
    return 1
  fi
  echo "iOS captured $outfile (${size}B)"

  # Logical ids that alias to a capture slug (e.g. past-meet-recap → past-meet-detail)
  # also get a fresh copy under the requested screen name so stale alias PNGs cannot mislead.
  if [[ "$SCREEN" != "$slug" ]]; then
    cp -f "$outfile" "$OUT_IOS/$SCREEN.png"
    echo "iOS mirrored $OUT_IOS/$SCREEN.png ← $slug.png" >&2
  fi

  if [[ "${LIKEMINDED_LEDGER_CLOSEOUT:-1}" != "0" ]]; then
    local closeout_args=(--platform ios --screen "$SCREEN" --screenshot "$outfile" --method screen-capture)
    if [[ "${LIKEMINDED_LEDGER_STALE_ONLY:-0}" == "1" ]]; then
      closeout_args+=(--stale-only --stamp none)
    else
      closeout_args+=(--stamp auto)
    fi
    node "$ROOT/script/ledger_capture_closeout.js" "${closeout_args[@]}" || echo "WARN: iOS ledger closeout failed" >&2
  fi
}

ensure_validation_api

validate_ios_screen

echo "done screen=$SCREEN platform=$PLATFORM"
