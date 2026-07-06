#!/usr/bin/env bash
# Flow-specific iOS interactive proof for testing-ledger (one screen/flow per invocation).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LOCK="$ROOT/script/testing_ledger_runtime_lock.sh"
CROSS_LOCK="$ROOT/script/cross_platform_validation_lock.sh"
IDB="$ROOT/validation/idb_ctl.sh"
BUNDLE_ID="${BUNDLE_ID:-com.likeminded.app}"
USER_TOKEN="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"
USER_NAME="${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}"
IOS_APP_PATH="$ROOT/.build/ios-simulator/Build/Products/Debug-iphonesimulator/Likeminded.app"

SCREEN=""
FLOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --screen) SCREEN="$2"; shift 2 ;;
    --flow) FLOW="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --screen <logical-id> [--flow <flow-id>]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SCREEN" ]]; then
  echo "Usage: $0 --screen <logical-id> [--flow <flow-id>]" >&2
  exit 2
fi

LOCK_FILE="/tmp/likeminded-testing-ledger-ios.lock"

release_lock() {
  local pid
  [[ -f "$LOCK_FILE" ]] || return 0
  read -r pid _ < "$LOCK_FILE" 2>/dev/null || true
  if [[ -n "$pid" && "$pid" == "$$" ]]; then
    rm -f "$LOCK_FILE"
  fi
}
trap release_lock EXIT INT TERM

lock_status="$("$LOCK" --platform ios status)"
if echo "$lock_status" | grep -q '^held '; then
  echo "runtime lock held — another agent owns ios runtime lane ($lock_status)" >&2
  exit 1
fi
echo "$$ prove" > "$LOCK_FILE"
echo "acquired platform=ios pid=$$ role=prove"

curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null || {
  echo "Start: npm run dev:api:validation" >&2
  exit 1
}

command -v idb >/dev/null 2>&1 || {
  echo "idb required for cua-click iOS flow proof (brew tap facebook/fb && brew install idb-companion idb)" >&2
  exit 1
}

CLICK_OK=0
CLICK_MISS=0
FLOW_FAIL=0
EVIDENCE_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"

resolve_ios_simulator() {
  if [[ -n "${SIMULATOR_ID:-}" ]]; then
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

ios_needs_build() {
  if [[ "${LIKEMINDED_SKIP_IOS_BUILD:-0}" == "1" ]]; then
    return 1
  fi
  if [[ "${LIKEMINDED_FORCE_IOS_BUILD:-0}" == "1" ]]; then
    return 0
  fi
  local exec_path
  if [[ -x "$IOS_APP_PATH/Likeminded" ]]; then
    exec_path="$IOS_APP_PATH/Likeminded"
  elif [[ -x "$IOS_APP_PATH/Contents/MacOS/Likeminded" ]]; then
    exec_path="$IOS_APP_PATH/Contents/MacOS/Likeminded"
  else
    return 0
  fi
  local newest_source binary_mtime
  newest_source="$(
    find "$ROOT/apps/ios-macos/Sources/LikemindedApp" "$ROOT/apps/ios-macos/project.yml" \
      -type f \( -name '*.swift' -o -name 'project.yml' \) -print0 2>/dev/null \
      | xargs -0 stat -f '%m' 2>/dev/null | sort -rn | head -1
  )"
  binary_mtime="$(stat -f '%m' "$exec_path" 2>/dev/null || echo 0)"
  [[ -n "$newest_source" && "$newest_source" -gt "$binary_mtime" ]]
}

ios_ui_contains() {
  local needle="$1"
  "$IDB" describe 2>/dev/null \
    | python3 -c "
import json, sys
needle = sys.argv[1]
data = json.load(sys.stdin)
for e in data:
    for key in ('AXLabel', 'AXValue', 'AXTitle', 'AXIdentifier'):
        val = e.get(key) or ''
        if needle in str(val):
            sys.exit(0)
sys.exit(1)
" "$needle"
}

ios_wait_ui_contains() {
  local needle="$1"
  local timeout="${2:-25}"
  local deadline=$((SECONDS + timeout))
  while (( SECONDS < deadline )); do
    if ios_ui_contains "$needle"; then
      return 0
    fi
    sleep 0.5
  done
  echo "timeout waiting for UI: $needle" >&2
  return 1
}

ios_tap_button() {
  local label="$1"
  local expect="$2"
  if "$IDB" tap "$label" && sleep 0.6 && ios_ui_contains "$expect"; then
    echo "OK tap '$label' → $expect"
    CLICK_OK=$((CLICK_OK + 1))
    return 0
  fi
  echo "MISS tap '$label' expected: $expect"
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

ios_tap_control() {
  local expect="$2"
  local tapped=0
  if [[ -n "${1:-}" ]] && "$IDB" tap-id "$1" 2>/dev/null; then
    tapped=1
    sleep 0.8
    if ios_ui_contains "$expect"; then
      echo "OK tap-id '$1' → $expect"
      CLICK_OK=$((CLICK_OK + 1))
      return 0
    fi
    local retry_deadline=$((SECONDS + 4))
    while (( SECONDS < retry_deadline )); do
      if ios_ui_contains "$expect"; then
        echo "OK tap-id '$1' → $expect (delayed)"
        CLICK_OK=$((CLICK_OK + 1))
        return 0
      fi
      sleep 0.5
    done
  fi
  if [[ -n "${3:-}" ]]; then
    ios_tap_button "$3" "$expect"
    return $?
  fi
  echo "MISS tap-id '${1:-?}' expected: $expect"
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

ios_launch_signed_in() {
  local -a extra=("$@")
  local sim_id
  sim_id="$(resolve_ios_simulator)"
  export IDB_UDID="$sim_id"

  if ios_needs_build; then
    "$CROSS_LOCK" with_lock xcodebuild-ios bash -c "
      set -euo pipefail
      '$ROOT/script/build_and_run.sh' build > /tmp/likeminded-ios-build-\$\$.log 2>&1
    "
  else
    "$CROSS_LOCK" with_lock xcodebuild-ios bash -c "
      set -euo pipefail
      '$ROOT/script/build_and_run.sh' install > /tmp/likeminded-ios-install-\$\$.log 2>&1
    "
  fi

  local -a launch_args=(
    --likeminded-reset-auth-session
    --likeminded-dev-auth-bypass
    --likeminded-dev-auth-token "$USER_TOKEN"
    --likeminded-dev-auth-name "$USER_NAME"
  )
  launch_args+=("${extra[@]}")

  "$CROSS_LOCK" with_lock ios-sim bash -c "
    set -euo pipefail
    xcrun simctl launch --terminate-running-process '$sim_id' '$BUNDLE_ID' $(printf ' %q' "${launch_args[@]}") >/dev/null
  "
  sleep "${IOS_CAPTURE_WAIT:-18}"
}

stamp_controls() {
  local ids="$1"
  [[ -n "$ids" ]] || return 0
  node "$ROOT/script/ledger_stamp_screen.js" \
    --platform ios \
    --screen "$SCREEN" \
    --controls "$ids" \
    --method CUA-click \
    --evidence-prefix "CUA ${EVIDENCE_USER} ${SCREEN}/${FLOW}" || true
}

echo "prove_flow platform=ios screen=$SCREEN flow=${FLOW:-"(capture)"}"

set +e
case "${SCREEN}/${FLOW}" in
  app-shell/tab-navigation)
    ios_launch_signed_in
    # Soft readiness wait — subtitle AX can lag behind tab bar; tabs prove shell ready.
    ios_wait_ui_contains "Meet" 45 || echo "warn: Meet tab not visible before tab sweep" >&2
    ios_tap_button "Meet" "When you meet."
    ios_tap_button "Circles" "Your room."
    ios_tap_button "Communities" "Explore communities"
    ios_tap_button "Soulmate" "Discover"
    ios_tap_button "Profile" "Your profile"
    if [[ "$CLICK_MISS" -eq 0 && "$CLICK_OK" -ge 5 ]]; then
      FLOW_FAIL=0
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "tab-meet,tab-circles,tab-communities,tab-soulmate,tab-profile"
    fi
    ;;
  app-shell/global-back)
    ios_launch_signed_in \
      --likeminded-start-circles \
      --likeminded-start-circle-detail
    ios_wait_ui_contains "Back to circles" 30 || FLOW_FAIL=1
    ios_tap_button "Back to circles" "Your room."
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "global-back"
    fi
    ;;
  app-shell/title-action-messages)
    ios_launch_signed_in
    ios_wait_ui_contains "Meet" 30 || echo "warn: Meet tab not visible before title-messages" >&2
    ios_tap_button "Meet" "When you meet."
    ios_wait_ui_contains "title-messages" 30 \
      || ios_wait_ui_contains "Messages" 30 \
      || FLOW_FAIL=1
    ios_tap_control "title-messages" "Recent conversations." "Messages"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "title-messages"
    fi
    ;;
  app-shell/title-action-settings)
    ios_launch_signed_in
    ios_tap_button "Profile" "Your profile"
    ios_wait_ui_contains "title-settings" 25 \
      || ios_wait_ui_contains "Settings" 25 \
      || FLOW_FAIL=1
    ios_tap_control "title-settings" "Account" "Settings"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "title-settings"
    fi
    ;;
  *)
    "$ROOT/script/cross_platform_screen_validate.sh" --screen "$SCREEN" --platform ios
    ;;
esac

echo "prove_summary ok=$CLICK_OK miss=$CLICK_MISS flow_fail=$FLOW_FAIL"
set -e
case "${SCREEN}/${FLOW}" in
  app-shell/global-back|app-shell/tab-navigation|app-shell/title-action-messages|app-shell/title-action-settings)
    [[ "$FLOW_FAIL" -ne 0 ]] && exit 1
    ;;
esac
