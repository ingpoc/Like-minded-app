#!/usr/bin/env bash
# Single-screen validation entrypoint with flock/lockf coordination for parallel agents.
#
# Agent hygiene (see docs/workflows/validation.md § Parallel screen validation):
#   - Wave 1: parallel Swift/ledger edits OK.
#   - Wave 2: sequential build + capture via this script only.
#   - iOS: explicit simulator UDID (not booted); 15–60s post-launch wait.
#   - macOS: --mac-screen BEFORE other launch flags; re-applied after sign-in.
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
API_LOG="/tmp/likeminded-screen-validate-api.log"

SCREEN=""
PLATFORM=""
OUT_IOS="$ROOT/output/validation/ios-screens"
OUT_MACOS="$ROOT/output/validation/macos-screens"

usage() {
  cat <<EOF
Usage: $0 --screen <ledger-id> --platform ios|both

Single-screen validation with flock coordination. Uses validation-gurusharan / Gurusharan Gupta.

  --screen <id>     Ledger id (e.g. 07-meet, meet, 02-meet-overview)
  --platform ios    iOS simulator capture only
  --platform both   iOS capture + macOS capture when mac screen resolves from ledger

macOS --mac-screen mapping: read `validation/screens/*.json` `platforms.macos.source_files` parenthetical,
  e.g. "MacScreens.swift (meetOverview)" → --mac-screen meetOverview
  (same lookup as ./script/macos_audit_prepare.sh)

Lock order: seed (only when API was down) → ios-sim OR macos-app → macos-capture → release.

Examples:
  $0 --screen 07-meet --platform ios
  $0 --screen 02-meet-overview --platform both
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
[[ "$PLATFORM" == "ios" || "$PLATFORM" == "both" ]] || {
  echo "--platform must be ios or both" >&2
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

resolve_mac_screen() {
  local ledger_arg="$1"
  case "$ledger_arg" in
    03-profile-empty|profile-empty) echo "profileOnboarding"; return 0 ;;
    04-profile-populated|profile-populated) echo "myProfile"; return 0 ;;
    05-profile-concern|profile-concern) echo "myProfile"; return 0 ;;
  esac
  node - "$ledger_arg" <<'NODE'
const fs = require("fs");
const path = require("path");

const arg = process.argv[2];
const norm = (s) => String(s || "").toLowerCase().replace(/[^a-z0-9]/g, "");
const needle = norm(arg);

function hintFromData(data) {
  for (const source of data.source_files || []) {
    const m = String(source).match(/\(([^)]+)\)\s*$/);
    if (m) return m[1];
  }
  return null;
}

const screensDir = path.join(process.cwd(), "validation", "screens");
if (fs.existsSync(screensDir)) {
  for (const file of fs.readdirSync(screensDir).filter((f) => f.endsWith(".json"))) {
    const data = JSON.parse(fs.readFileSync(path.join(screensDir, file), "utf8"));
    const logical = norm(data.logical_screen_id || file.replace(/\.json$/, ""));
    const macLegacy = data.platforms?.macos?.ledger_legacy_id;
    if (logical === needle || norm(macLegacy) === needle || logical.includes(needle) || needle.includes(logical)) {
      const hint = hintFromData({ source_files: data.platforms?.macos?.source_files || [] });
      if (hint) {
        console.log(hint);
        process.exit(0);
      }
    }
  }
}

for (const sub of ["macos", "_legacy/macos"]) {
  const dir = path.join(process.cwd(), "validation", sub);
  if (!fs.existsSync(dir)) continue;
  const files = fs.readdirSync(dir).filter((f) => f.endsWith(".json"));
  for (const file of files) {
    const data = JSON.parse(fs.readFileSync(path.join(dir, file), "utf8"));
    const stem = norm(file.replace(/\.json$/, ""));
    if (stem.includes(needle) || needle.includes(stem.replace(/^\d+/, ""))) {
      const hint = hintFromData(data);
      if (hint) {
        console.log(hint);
        process.exit(0);
      }
    }
    for (const source of data.source_files || []) {
      const m = String(source).match(/\(([^)]+)\)\s*$/);
      if (m && norm(m[1]).includes(needle)) {
        console.log(m[1]);
        process.exit(0);
      }
    }
  }
}
process.exit(1);
NODE
}

ios_capture_slug() {
  local ledger_id="$1"
  case "$ledger_id" in
    01-auth-gate|auth-gate) echo "auth-gate" ;;
    02-onboarding|onboarding) echo "onboarding" ;;
    03-profile-empty|profile-empty) echo "profile-empty" ;;
    04-profile-populated|profile-populated) echo "profile-populated" ;;
    05-profile-concern|profile-concern) echo "profile-concern" ;;
    06-voice-session-sheet|voice-session-sheet) echo "voice-session-sheet" ;;
    07-meet|meet) echo "meet" ;;
    08-past-meet-detail|past-meet-detail) echo "past-meet-detail" ;;
    09-group-video-call|group-video-call) echo "group-video-call" ;;
    10-circles|circles) echo "circles" ;;
    11-circle-detail|circle-detail) echo "circle-detail" ;;
    12-communities|communities) echo "communities" ;;
    13-community-detail|community-detail) echo "community-detail" ;;
    14-soulmate|soulmate) echo "soulmate" ;;
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
      printf '%s\n' "${common[@]}" --likeminded-force-onboarding
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
    06-voice-session-sheet|voice-session-sheet)
      printf '%s\n' "${common[@]}" --likeminded-start-profile --likeminded-start-voice-session
      ;;
    07-meet|meet)
      printf '%s\n' "${common[@]}"
      ;;
    08-past-meet-detail|past-meet-detail)
      printf '%s\n' "${common[@]}" --likeminded-start-past-meet-detail
      ;;
    09-group-video-call|group-video-call)
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
      printf '%s\n' "${common[@]}" --likeminded-start-communities
      ;;
    14-soulmate|soulmate)
      printf '%s\n' "${common[@]}" --likeminded-start-soulmate
      ;;
    15-soulmate-match-detail|soulmate-match-detail)
      printf '%s\n' "${common[@]}" --likeminded-start-soulmate --likeminded-start-soulmate-match-detail
      ;;
    16-chat|chat)
      printf '%s\n' "${common[@]}" --likeminded-start-chat
      ;;
    17-conversations|conversations)
      printf '%s\n' "${common[@]}" --likeminded-start-soulmate
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
      printf '%s\n' "${common[@]}" --likeminded-start-community-members --likeminded-community-id reflective-builders
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
  shift 3
  xcrun simctl launch --terminate-running-process "$sim_id" "$BUNDLE_ID" "$@" >/dev/null
  sleep "$wait"
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
    $(declare -f ios_sim_launch_and_capture)
    ios_sim_launch_and_capture \"\$SIMULATOR_ID\" $(printf '%q' "$outfile") \"\$CAPTURE_WAIT\" $(printf ' %q' "${args[@]}")
  "

  local size
  size=$(stat -f%z "$outfile" 2>/dev/null || echo 0)
  if (( size < 10000 )); then
    echo "WARN: $outfile is ${size}B — likely blank" >&2
    return 1
  fi
  echo "iOS captured $outfile (${size}B)"

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

macos_capture_window() {
  local output_path="$1"
  local window_id deadline=$((SECONDS + 12))
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
      if (( size >= 10000 )); then
        return 0
      fi
      rm -f "$output_path"
    fi
    sleep 0.5
  done
  echo "macOS window capture failed for $output_path" >&2
  return 1
}

macos_launch_screen() {
  local mac_screen="$1"
  # shellcheck source=macos_canonical_app.sh
  source "$ROOT/script/macos_canonical_app.sh"
  macos_open_with_args \
    --likeminded-reset-auth-session \
    --likeminded-dev-auth-bypass \
    --likeminded-dev-auth-token "$USER_TOKEN" \
    --likeminded-dev-auth-name "$USER_NAME" \
    --mac-screen "$mac_screen"
  sleep 5
  "$ROOT/script/macos_cua_focus_window.sh" >/dev/null || true
}

macos_launch_args_for_screen() {
  local ledger_id="$1"
  local mac_screen="$2"
  local common=(
    --likeminded-reset-auth-session
    --likeminded-dev-auth-bypass
    --likeminded-dev-auth-token "$USER_TOKEN"
    --likeminded-dev-auth-name "$USER_NAME"
  )

  case "$ledger_id" in
    03-profile-empty|profile-empty)
      printf '%s\n' "${common[@]}" --mac-screen "$mac_screen" --likeminded-dev-profile-empty
      ;;
    *)
      printf '%s\n' "${common[@]}" --mac-screen "$mac_screen"
      ;;
  esac
}

validate_macos_screen() {
  local mac_screen outfile
  if ! mac_screen="$(resolve_mac_screen "$SCREEN")"; then
    echo "macOS: no --mac-screen mapping for ledger '$SCREEN' (see validation/screens/*.json platforms.macos.source_files hints)" >&2
    return 1
  fi

  outfile="$OUT_MACOS/$mac_screen.png"
  mkdir -p "$OUT_MACOS"
  echo "macOS validate ledger=$SCREEN mac-screen=$mac_screen" >&2

  "$LOCK" with_lock xcodebuild-macos bash -c "
    set -euo pipefail
    # shellcheck source=macos_canonical_app.sh
    source '$ROOT/script/macos_canonical_app.sh'
    macos_ensure_built > /tmp/likeminded-macos-build-\$\$.log 2>&1
  "

  "$LOCK" with_lock macos-app bash -c "
    set -euo pipefail
    source '$ROOT/script/macos_canonical_app.sh'
    export LIKEMINDED_HOLDS_MACOS_APP_LOCK=1
    macos_launch_args=()
    while IFS= read -r arg; do
      macos_launch_args+=(\"\$arg\")
    done < <(macos_launch_args_for_screen '$SCREEN' '$mac_screen')
    macos_open_with_args \"\${macos_launch_args[@]}\"
    sleep 5
    '$ROOT/script/macos_cua_focus_window.sh' >/dev/null || true
  "
  "$LOCK" with_lock macos-capture bash -s <<EOS
set -euo pipefail
$(declare -f macos_capture_window)
macos_capture_window $(printf '%q' "$outfile")
EOS

  echo "macOS captured $outfile"

  if [[ "${LIKEMINDED_LEDGER_CLOSEOUT:-1}" != "0" ]]; then
    node "$ROOT/script/ledger_capture_closeout.js" \
      --platform macos \
      --screen "$SCREEN" \
      --mac-screen "$mac_screen" \
      --screenshot "$outfile" \
      --stamp auto \
      --method screen-capture || echo "WARN: macOS ledger closeout failed" >&2
  fi
}

ensure_validation_api

if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "both" ]]; then
  validate_ios_screen
fi

if [[ "$PLATFORM" == "both" ]]; then
  validate_macos_screen || echo "macOS capture skipped or failed for $SCREEN" >&2
fi

echo "done screen=$SCREEN platform=$PLATFORM"
