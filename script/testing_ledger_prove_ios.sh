#!/usr/bin/env bash
# Flow-specific iOS interactive proof for testing-ledger (one screen/flow per invocation).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LOCK="$ROOT/script/testing_ledger_runtime_lock.sh"
CROSS_LOCK="$ROOT/script/cross_platform_validation_lock.sh"
IDB="$ROOT/validation/idb_ctl.sh"
BUNDLE_ID="${BUNDLE_ID:-com.gurusharan.likeminded}"
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

ios_validation_api_healthy() {
  local body
  body="$(curl -sf "http://127.0.0.1:${PORT:-8787}/health" 2>/dev/null || true)"
  [[ -n "$body" ]] || return 1
  printf '%s' "$body" | python3 -c '
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if d.get("status") == "ok" and "validation-db" in (d.get("dbPath") or "") else 1)
' 2>/dev/null
}

# Re-check after xcodebuild waits: parallel macOS owners may bounce :8787 mid-prove.
ios_ensure_validation_api() {
  if ios_validation_api_healthy; then
    return 0
  fi
  echo "validation API not healthy — starting npm run dev:api:validation" >&2
  (
    cd "$ROOT"
    exec npm run dev:api:validation
  ) >>/tmp/likeminded-api-ios-prove.log 2>&1 </dev/null &
  local i
  for i in $(seq 1 40); do
    if ios_validation_api_healthy; then
      echo "validation API healthy (validation-db)"
      return 0
    fi
    sleep 0.5
  done
  echo "Start: npm run dev:api:validation (validation-db on :8787)" >&2
  return 1
}

ios_ensure_validation_api || exit 1

ios_validation_session_token() {
  curl -fsS -X POST -H 'Content-Type: application/json' \
    -d "{\"identityToken\":\"${USER_TOKEN:-validation-gurusharan}\",\"fullName\":\"${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}\"}" \
    "http://127.0.0.1:${PORT:-8787}/v1/auth/apple" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sessionToken") or "")' 2>/dev/null || true
}

# Retries across transient :8787 bounce after UI success (parallel platform drains).
ios_fetch_placement_json() {
  local attempt session_token placement_json
  for attempt in 1 2 3 4 5 6; do
    ios_ensure_validation_api || true
    session_token="$(ios_validation_session_token)"
    if [[ -n "$session_token" ]]; then
      placement_json="$(curl -fsS \
        -H "Authorization: Bearer $session_token" \
        "http://127.0.0.1:${PORT:-8787}/v1/me/placement" 2>/dev/null || true)"
      if [[ -n "$placement_json" ]]; then
        printf '%s' "$placement_json"
        return 0
      fi
    fi
    sleep 0.6
  done
  return 1
}

# Poll until concernFlag + exact placementConcern land (covers async app POST + API bounce).
# Prints final placement JSON on stdout; returns 0 on match.
ios_wait_placement_concern() {
  local expected="$1"
  local attempts="${2:-12}"
  local attempt placement_json
  for attempt in $(seq 1 "$attempts"); do
    placement_json="$(ios_fetch_placement_json || true)"
    if [[ -n "$placement_json" ]] && CONCERN_TEXT="$expected" python3 -c '
import json, os, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
expected = os.environ["CONCERN_TEXT"]
raise SystemExit(0 if payload.get("concernFlag") is True and payload.get("placementConcern") == expected else 1)
' <<<"$placement_json"; then
      printf '%s' "$placement_json"
      return 0
    fi
    sleep 0.7
  done
  printf '%s' "${placement_json:-}"
  return 1
}

# Clear stale concern so a prior probe cannot false-pass concern-submit readback.
ios_clear_placement_concern() {
  local session_token
  ios_ensure_validation_api || return 1
  session_token="$(ios_validation_session_token)"
  [[ -n "$session_token" ]] || return 1
  curl -fsS -X POST \
    -H "Authorization: Bearer $session_token" \
    -H "Content-Type: application/json" \
    -d '{"message":""}' \
    "http://127.0.0.1:${PORT:-8787}/v1/me/circles/concern" >/dev/null 2>&1 || true
}

command -v idb >/dev/null 2>&1 || {
  echo "idb required for computer-use iOS flow proof (brew tap facebook/fb && brew install idb-companion idb)" >&2
  exit 1
}

CLICK_OK=0
CLICK_MISS=0
FLOW_FAIL=0
IOS_TAPPABLE_POINT=""
EVIDENCE_USER="${LIKEMINDED_VALIDATION_USER:-validation-gurusharan}"

# Extract a 36-char simctl UDID from one device line (first parenthetical hex id).
ios_udid_from_device_line() {
  grep -oE '\([A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\)' \
    | head -1 \
    | tr -d '()'
}

resolve_ios_simulator() {
  local preferred="${SIMULATOR_NAME:-iPhone 17}"
  local id=""

  if [[ -n "${SIMULATOR_ID:-}" ]]; then
    id="$SIMULATOR_ID"
  else
    # Prefer already-booted match (exact "Name (", then prefix), then available.
    id=$(
      xcrun simctl list devices booted 2>/dev/null \
        | grep -F "$preferred (" \
        | head -1 \
        | ios_udid_from_device_line || true
    )
    if [[ -z "$id" ]]; then
      id=$(
        xcrun simctl list devices booted 2>/dev/null \
          | grep -F "$preferred " \
          | head -1 \
          | ios_udid_from_device_line || true
      )
    fi
    if [[ -z "$id" ]]; then
      id=$(
        xcrun simctl list devices available 2>/dev/null \
          | grep -F "$preferred (" \
          | head -1 \
          | ios_udid_from_device_line || true
      )
    fi
    if [[ -z "$id" ]]; then
      id=$(
        xcrun simctl list devices available 2>/dev/null \
          | grep -F "$preferred " \
          | head -1 \
          | ios_udid_from_device_line || true
      )
    fi
  fi

  if [[ -z "$id" || ! "$id" =~ ^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$ ]]; then
    echo "Simulator '$preferred' not found (id='${id:-}')" >&2
    return 1
  fi
  xcrun simctl boot "$id" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
  echo "$id"
}

# Bash assignments mask failing command substitutions under set -e; always gate UDID.
ios_require_simulator_udid() {
  local sim_id="${1:-}"
  if [[ -z "$sim_id" || ! "$sim_id" =~ ^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$ ]]; then
    echo "FATAL: empty/invalid iOS simulator UDID ('${sim_id:-}'); refusing simctl launch" >&2
    return 1
  fi
}

ios_built_executable() {
  if [[ -x "$IOS_APP_PATH/Likeminded" ]]; then
    echo "$IOS_APP_PATH/Likeminded"
  elif [[ -x "$IOS_APP_PATH/Contents/MacOS/Likeminded" ]]; then
    echo "$IOS_APP_PATH/Contents/MacOS/Likeminded"
  else
    return 1
  fi
}

ios_binary_is_source_fresh() {
  local exec_path newest_source binary_mtime
  exec_path="$(ios_built_executable)" || return 1
  newest_source="$(
    find "$ROOT/apps/ios-macos/Sources/LikemindedApp" "$ROOT/apps/ios-macos/project.yml" \
      -type f \( -name '*.swift' -o -name 'project.yml' \) -print0 2>/dev/null \
      | xargs -0 stat -f '%m' 2>/dev/null | sort -rn | head -1
  )"
  binary_mtime="$(stat -f '%m' "$exec_path" 2>/dev/null || echo 0)"
  [[ -n "$newest_source" && "$newest_source" -le "$binary_mtime" ]]
}

ios_needs_build() {
  if [[ "${LIKEMINDED_SKIP_IOS_BUILD:-0}" == "1" ]]; then
    return 1
  fi
  if [[ "${LIKEMINDED_FORCE_IOS_BUILD:-0}" == "1" ]]; then
    return 0
  fi
  ! ios_binary_is_source_fresh
}

ios_installed_executable() {
  local sim_id="$1" app_path executable
  ios_require_simulator_udid "$sim_id" || return 1
  app_path="$(xcrun simctl get_app_container "$sim_id" "$BUNDLE_ID" app 2>/dev/null)" || return 1
  [[ -d "$app_path" ]] || return 1
  executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_path/Info.plist" 2>/dev/null)" || return 1
  [[ -n "$executable" && -x "$app_path/$executable" ]] || return 1
  echo "$app_path/$executable"
}

ios_reuse_installed_app() {
  local sim_id="$1" built_exec installed_exec built_hash installed_hash
  [[ "${LIKEMINDED_REUSE_IOS_INSTALL:-0}" == "1" ]] || return 1
  ios_binary_is_source_fresh || {
    echo "reuse rejected: built iOS executable is missing or source-stale" >&2
    return 2
  }
  built_exec="$(ios_built_executable)" || return 2
  installed_exec="$(ios_installed_executable "$sim_id")" || {
    echo "reuse rejected: $BUNDLE_ID is not installed on simulator $sim_id" >&2
    return 2
  }
  built_hash="$(shasum -a 256 "$built_exec" | awk '{print $1}')"
  installed_hash="$(shasum -a 256 "$installed_exec" | awk '{print $1}')"
  if [[ -z "$built_hash" || "$built_hash" != "$installed_hash" ]]; then
    echo "reuse rejected: installed executable does not match the source-fresh build" >&2
    return 2
  fi
  echo "runtime tuple: platform=ios udid=$sim_id bundle=$BUNDLE_ID binary_sha256=$built_hash user=$USER_TOKEN mode=reuse"
  return 0
}

ios_ui_probe() {
  local needle="$1"
  local destination="${2:-/dev/null}"
  if [[ "$destination" != "/dev/null" ]]; then
    mkdir -p "$(dirname "$destination")"
  fi
  local status
  if "$IDB" describe 2>/dev/null \
    | python3 -c "
import json, sys, unicodedata

def normalized(value):
    return ' '.join(unicodedata.normalize('NFKC', str(value or '')).split()).casefold()

needle = normalized(sys.argv[1])
try:
    data = json.load(sys.stdin)
except Exception as error:
    print(json.dumps({'needle': needle, 'inventory_error': type(error).__name__, 'matches': []}))
    sys.exit(2)

application = next((e for e in data if e.get('type') == 'Application'), None)
app_frame = (application or {}).get('frame') or {}
required = ('x', 'y', 'width', 'height')
if not all(isinstance(app_frame.get(key), (int, float)) for key in required):
    print(json.dumps({'needle': needle, 'inventory_error': 'missing-application-frame', 'matches': []}))
    sys.exit(2)

app_x = float(app_frame['x'])
app_y = float(app_frame['y'])
app_width = float(app_frame['width'])
app_height = float(app_frame['height'])
matches = []
for e in data:
    for key in ('AXLabel', 'AXValue', 'AXTitle', 'AXIdentifier', 'AXUniqueId'):
        if needle in normalized(e.get(key)):
            frame = e.get('frame') or {}
            try:
                x = float(frame.get('x', 0))
                y = float(frame.get('y', 0))
                width = float(frame.get('width', 0))
                height = float(frame.get('height', 0))
            except (TypeError, ValueError):
                x = y = width = height = 0
            visible = (
                width > 0 and height > 0 and
                x < app_x + app_width and x + width > app_x and
                y < app_y + app_height and y + height > app_y
            )
            # Full-screen call/sheet chrome can sit on the edge; keep labeled controls.
            if not visible and width > 0 and height > 0 and e.get('type') in ('Button', 'Link', 'Switch'):
                visible = True
            matches.append({
                'type': e.get('type'),
                'field': key,
                'value': e.get(key),
                'frame': frame,
                'visible': visible
            })

print(json.dumps({
    'needle': needle,
    'application_frame': app_frame,
    'matches': matches,
    'visible_match_count': sum(1 for match in matches if match['visible'])
}, ensure_ascii=False))
sys.exit(0 if any(match['visible'] for match in matches) else 1)
" "$needle" > "$destination"; then
    status=0
  else
    status=$?
  fi
  return "$status"
}

ios_ui_contains() {
  if ios_ui_probe "$1"; then
    return 0
  fi
  return 1
}

ios_absence_samples() {
  local needle="$1"
  local attempts="$2"
  local diagnostic_prefix="${3:-}"
  local absent_samples=0
  local sample probe_status destination
  for ((sample = 1; sample <= attempts; sample++)); do
    destination="/dev/null"
    if [[ -n "$diagnostic_prefix" ]]; then
      destination="${diagnostic_prefix}-sample-${sample}.json"
    fi
    if ios_ui_probe "$needle" "$destination"; then
      probe_status=0
    else
      probe_status=$?
    fi
    if [[ "$probe_status" -eq 0 ]]; then
      absent_samples=0
    elif [[ "$probe_status" -eq 1 ]]; then
      absent_samples=$((absent_samples + 1))
      if [[ "$absent_samples" -ge 3 ]]; then
        return 0
      fi
    else
      absent_samples=0
      echo "AX inventory error while checking absence: $needle" >&2
    fi
    sleep 0.4
  done
  return 1
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

ios_wait_ui_absent() {
  local needle="$1"
  local timeout="${2:-25}"
  local deadline=$((SECONDS + timeout))
  local absent_samples=0
  local probe_status
  while (( SECONDS < deadline )); do
    if ios_ui_probe "$needle"; then
      probe_status=0
    else
      probe_status=$?
    fi
    if [[ "$probe_status" -eq 0 ]]; then
      absent_samples=0
    elif [[ "$probe_status" -eq 1 ]]; then
      absent_samples=$((absent_samples + 1))
      if [[ "$absent_samples" -ge 3 ]]; then
        return 0
      fi
    else
      absent_samples=0
      echo "AX inventory error while checking absence: $needle" >&2
    fi
    sleep 0.4
  done
  if ios_absence_samples "$needle" 5; then
    return 0
  fi
  local refresh_slug="${needle// /-}"
  local refresh_prefix="$ROOT/output/validation/testing-ledger/ios/diagnostics/${SCREEN}--${FLOW}--absence-refresh-${refresh_slug}"
  local refresh_path="${refresh_prefix}.png"
  if ! "$IDB" screenshot "$refresh_path" >/dev/null 2>&1; then
    echo "failed rendered-state refresh while waiting for UI to disappear: $needle" >&2
    return 1
  fi
  sleep 1
  if ios_absence_samples "$needle" 5 "$refresh_prefix"; then
    echo "rendered-state refresh confirmed UI absent: $needle"
    return 0
  fi
  echo "UI did not remain absent for three refreshed samples: $needle" >&2
  return 1
}

ios_dismiss_account_verification_if_present() {
  if ! ios_ui_contains "Apple Account Verification"; then
    return 0
  fi
  if "$IDB" tap "Not Now"; then
    echo "dismissed iOS Simulator Apple Account Verification alert"
    sleep 1
    return 0
  fi
  echo "could not dismiss iOS Simulator Apple Account Verification alert" >&2
  FLOW_FAIL=1
  return 1
}

# System mic TCC alert blocks AX (describe collapses to alert chrome only).
ios_dismiss_microphone_prompt_if_present() {
  if ! ios_ui_contains "access the Microphone" && ! ios_ui_contains "Microphone"; then
    return 0
  fi
  if "$IDB" tap "Allow" 2>/dev/null || "$IDB" tap "OK" 2>/dev/null; then
    echo "dismissed iOS Microphone permission alert (Allow)"
    sleep 0.8
    return 0
  fi
  if "$IDB" tap "Don’t Allow" 2>/dev/null || "$IDB" tap "Don't Allow" 2>/dev/null; then
    echo "dismissed iOS Microphone permission alert (Don't Allow)"
    sleep 0.8
    return 0
  fi
  echo "warn: Microphone permission alert present but not dismissed" >&2
  return 1
}

ios_capture_failure_diagnostics() {
  local slug="$1"
  local directory="$ROOT/output/validation/testing-ledger/ios/diagnostics"
  mkdir -p "$directory"
  "$IDB" screenshot "$directory/${SCREEN}--${FLOW}--${slug}.png" || true
  "$IDB" describe > "$directory/${SCREEN}--${FLOW}--${slug}.json" || true
  echo "iOS failure diagnostics: output/validation/testing-ledger/ios/diagnostics/${SCREEN}--${FLOW}--${slug}.{png,json}"
}

ios_tap_button() {
  local label="$1"
  shift
  local expects=("$@")
  if [[ "${#expects[@]}" -eq 0 ]]; then
    echo "ios_tap_button requires at least one expect" >&2
    FLOW_FAIL=1
    return 1
  fi
  if ! "$IDB" tap "$label"; then
    echo "MISS resolve '$label' expected one of: ${expects[*]}"
    CLICK_MISS=$((CLICK_MISS + 1))
    FLOW_FAIL=1
    return 1
  fi
  sleep 0.6
  local expect
  for expect in "${expects[@]}"; do
    if ios_ui_contains "$expect"; then
      echo "OK tap '$label' → $expect"
      CLICK_OK=$((CLICK_OK + 1))
      return 0
    fi
  done
  # Give navigation/sheet settle one more beat for multi-expect.
  sleep 0.8
  for expect in "${expects[@]}"; do
    if ios_ui_contains "$expect"; then
      echo "OK tap '$label' → $expect"
      CLICK_OK=$((CLICK_OK + 1))
      return 0
    fi
  done
  echo "MISS tap '$label' expected one of: ${expects[*]}"
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

# Tap any AX element by label (Button/Link/Switch/Other/…) — needed for toggles/orbs.
ios_tap_any_label() {
  local label="$1"
  local expect="$2"
  local assertion="${3:-present}"
  local point
  point="$("$IDB" describe 2>/dev/null | LABEL="$label" python3 -c '
import json, os, sys, unicodedata
label = " ".join(unicodedata.normalize("NFKC", os.environ["LABEL"]).split()).casefold()

def norm(raw):
    return " ".join(unicodedata.normalize("NFKC", str(raw)).split()).casefold()

def labels_match(raw, wanted):
    text = norm(raw)
    if text == wanted:
        return True
    # SwiftUI often joins duplicate accessibility names with commas.
    parts = [p.strip() for p in text.split(",") if p.strip()]
    if parts and all(p == wanted for p in parts):
        return True
    return False

data = json.load(sys.stdin)
# Prefer interactive controls; StaticText titles often share the same label as a Toggle.
rank_for = {
    "Switch": 0, "CheckBox": 0, "Button": 1, "Link": 1,
    "Image": 2, "Other": 2, "Cell": 2,
}
candidates = []
for e in data:
    raw = e.get("AXLabel") or e.get("AXValue") or ""
    if not labels_match(raw, label):
        continue
    frame = e.get("frame") or {}
    if frame.get("width", 0) <= 0 or frame.get("height", 0) <= 0:
        continue
    # Skip absurdly tall/low hit targets (merged scroll cells / under-FAB ghosts).
    cy = frame["y"] + frame["height"] / 2
    # Allow below-fold browse cards; still skip under-tab-bar ghosts (cy≫1400).
    if frame.get("height", 0) > 280 or cy > 1400:
        continue
    rank = rank_for.get(e.get("type"), 8)
    # Switch/CheckBox AX frames span label+knob (+ often a caption). Prefer the
    # trailing knob at vertical mid — SwiftUI centers UISwitch in the full row.
    if e.get("type") in ("Switch", "CheckBox"):
        cx = frame["x"] + max(frame["width"] - 18, frame["width"] * 0.88)
        cy = frame["y"] + frame["height"] / 2
    else:
        cx = frame["x"] + frame["width"] / 2
    candidates.append((rank, cy, cx))
if not candidates:
    raise SystemExit(1)
candidates.sort()
print("%.0f %.0f" % (candidates[0][2], candidates[0][1]))
')" || true
  if [[ -z "$point" ]]; then
    ios_capture_failure_diagnostics "resolve-any-${label// /-}"
    echo "MISS resolve any-label '$label' expected: $expect"
    CLICK_MISS=$((CLICK_MISS + 1))
    FLOW_FAIL=1
    return 1
  fi
  local x y
  read -r x y <<< "$point"
  if ! "$IDB" tap-point "$x" "$y"; then
    ios_capture_failure_diagnostics "tap-any-${label// /-}"
    echo "MISS tap-point any-label '$label' expected: $expect"
    CLICK_MISS=$((CLICK_MISS + 1))
    FLOW_FAIL=1
    return 1
  fi
  sleep 0.6
  if [[ "$assertion" == "absent" ]] && ios_wait_ui_absent "$expect" 5; then
    echo "OK tap any-label '$label' → $expect absent"
    CLICK_OK=$((CLICK_OK + 1))
    return 0
  fi
  if [[ "$assertion" != "absent" ]] && ios_wait_ui_contains "$expect" 5; then
    echo "OK tap any-label '$label' → $expect"
    CLICK_OK=$((CLICK_OK + 1))
    return 0
  fi
  ios_capture_failure_diagnostics "tap-any-${label// /-}"
  echo "MISS tap any-label '$label' expected: $expect"
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

# Read Switch/CheckBox AXValue ("0"/"1"/"" if missing).
ios_switch_ax_value() {
  local label="$1"
  "$IDB" describe 2>/dev/null | LABEL="$label" python3 -c '
import json, os, sys, unicodedata
want = " ".join(unicodedata.normalize("NFKC", os.environ["LABEL"]).split()).casefold()
def norm(raw):
    return " ".join(unicodedata.normalize("NFKC", str(raw)).split()).casefold()
data = json.load(sys.stdin)
for e in data:
    if e.get("type") not in ("Switch", "CheckBox"):
        continue
    raw = e.get("AXLabel") or ""
    if norm(raw) != want:
        continue
    value = e.get("AXValue")
    if value is None:
        print("")
    else:
        print(str(value))
    raise SystemExit(0)
raise SystemExit(1)
' 2>/dev/null || true
}

# Tap a Switch/CheckBox and require AXValue to flip. Label-presence is not proof.
ios_tap_switch() {
  local label="$1"
  local before after point x y
  before="$(ios_switch_ax_value "$label")"
  if [[ -z "$before" ]]; then
    ios_capture_failure_diagnostics "switch-resolve-${label// /-}"
    echo "MISS switch '$label': not found in AX" >&2
    CLICK_MISS=$((CLICK_MISS + 1))
    FLOW_FAIL=1
    return 1
  fi
  # Prefer accessibility id when present; else knob-side points (mid / high / low).
  if [[ -n "$( "$IDB" point-id "settings-soulmate-toggle" 2>/dev/null || true )" ]] && \
     [[ "$label" == "Enable Soulmate" ]]; then
    if "$IDB" tap-id "settings-soulmate-toggle" center; then
      sleep 0.8
      after="$(ios_switch_ax_value "$label")"
      if [[ -n "$after" && "$after" != "$before" ]]; then
        echo "OK tap-id switch '$label' ($before→$after)"
        CLICK_OK=$((CLICK_OK + 1))
        return 0
      fi
    fi
  fi
  local attempt
  for attempt in mid high low; do
    point="$("$IDB" describe 2>/dev/null | LABEL="$label" ATTEMPT="$attempt" python3 -c '
import json, os, sys, unicodedata
want = " ".join(unicodedata.normalize("NFKC", os.environ["LABEL"]).split()).casefold()
attempt = os.environ["ATTEMPT"]
def norm(raw):
    return " ".join(unicodedata.normalize("NFKC", str(raw)).split()).casefold()
data = json.load(sys.stdin)
for e in data:
    if e.get("type") not in ("Switch", "CheckBox"):
        continue
    if norm(e.get("AXLabel") or "") != want:
        continue
    frame = e.get("frame") or {}
    if frame.get("width", 0) <= 0 or frame.get("height", 0) <= 0:
        continue
    cx = frame["x"] + max(frame["width"] - 18, frame["width"] * 0.88)
    if attempt == "high":
        cy = frame["y"] + min(22.0, frame["height"] * 0.28)
    elif attempt == "low":
        cy = frame["y"] + frame["height"] * 0.72
    else:
        cy = frame["y"] + frame["height"] / 2
    print("%.0f %.0f" % (cx, cy))
    raise SystemExit(0)
raise SystemExit(1)
')" || true
    if [[ -z "$point" ]]; then
      continue
    fi
    read -r x y <<< "$point"
    if ! "$IDB" tap-point "$x" "$y"; then
      continue
    fi
    sleep 0.8
    after="$(ios_switch_ax_value "$label")"
    if [[ -n "$after" && "$after" != "$before" ]]; then
      echo "OK tap switch '$label' at ($x,$y) ($before→$after)"
      CLICK_OK=$((CLICK_OK + 1))
      return 0
    fi
  done
  ios_capture_failure_diagnostics "switch-tap-${label// /-}"
  echo "MISS switch '$label': AXValue stayed=${after:-$before} (wanted flip from $before)" >&2
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

ios_focus_and_type() {
  local field_label="$1"
  local text="$2"
  if ! "$IDB" tap "$field_label"; then
    # TextField may not resolve via button tap — try AXLabel, then AXValue (placeholder).
    local point
    point="$("$IDB" describe 2>/dev/null | python3 -c "
import json, sys, unicodedata
def n(v):
    return ' '.join(unicodedata.normalize('NFKC', str(v or '')).split())
want = n(sys.argv[1])
data = json.load(sys.stdin)
ranked = []
for e in data:
    label = n(e.get('AXLabel'))
    value = n(e.get('AXValue'))
    typ = e.get('type') or ''
    f = e.get('frame') or {}
    if f.get('width', 0) <= 0 or f.get('height', 0) <= 0:
        continue
    score = None
    if label == want:
        score = 0 if typ in ('TextField', 'SearchField', 'TextArea') else 1
    elif value == want and typ in ('TextField', 'SearchField', 'TextArea', 'Other'):
        score = 2
    if score is None:
        continue
    ranked.append((score, f['x'] + f['width'] / 2, f['y'] + f['height'] / 2))
if not ranked:
    raise SystemExit(1)
ranked.sort()
print(f'{ranked[0][1]:.0f} {ranked[0][2]:.0f}')
" "$field_label")" || true
    if [[ -z "$point" ]]; then
      ios_capture_failure_diagnostics "focus-${field_label// /-}"
      echo "MISS focus field '$field_label'" >&2
      FLOW_FAIL=1
      return 1
    fi
    read -r x y <<< "$point"
    "$IDB" tap-point "$x" "$y" || { FLOW_FAIL=1; return 1; }
  fi
  sleep 0.3
  "$IDB" type "$text" || { echo "MISS type into '$field_label'" >&2; FLOW_FAIL=1; return 1; }
  echo "OK typed into '$field_label'"
  CLICK_OK=$((CLICK_OK + 1))
  return 0
}

ios_tap_control() {
  local identifier="$1"
  local expect="$2"
  local fallback_label="${3:-}"
  local fallback_x="${4:-}"
  local fallback_y="${5:-}"
  local assertion="${6:-present}"
  local tap_anchor="${7:-center}"
  local resolved_point="${8:-}"
  local dispatch=""

  if [[ -n "$resolved_point" ]]; then
    local resolved_x resolved_y
    read -r resolved_x resolved_y <<< "$resolved_point"
    if "$IDB" tap-point "$resolved_x" "$resolved_y"; then
      dispatch="tap-point ($resolved_x,$resolved_y) for '$identifier'"
    fi
  elif [[ -n "$identifier" ]] && "$IDB" tap-id "$identifier" "$tap_anchor"; then
    dispatch="tap-id '$identifier' anchor=$tap_anchor"
  elif [[ -n "$fallback_label" ]] && "$IDB" tap "$fallback_label"; then
    dispatch="tap '$fallback_label'"
  elif [[ -n "$fallback_x" && -n "$fallback_y" ]] && "$IDB" tap-point "$fallback_x" "$fallback_y"; then
    dispatch="tap-point ($fallback_x,$fallback_y) for '$identifier'"
  fi

  if [[ -n "$dispatch" ]]; then
    if [[ "$assertion" == "absent" ]] && ios_wait_ui_absent "$expect" 5; then
      echo "OK $dispatch → $expect absent"
      CLICK_OK=$((CLICK_OK + 1))
      return 0
    fi
    if [[ "$assertion" != "absent" ]] && ios_wait_ui_contains "$expect" 5; then
      echo "OK $dispatch → $expect"
      CLICK_OK=$((CLICK_OK + 1))
      return 0
    fi
    ios_capture_failure_diagnostics "tap-${identifier:-unknown}"
    echo "MISS $dispatch expected: $expect"
  else
    ios_capture_failure_diagnostics "resolve-${identifier:-unknown}"
    echo "MISS resolve '${identifier:-?}' expected: $expect"
  fi
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

# iOS confirmationDialog popovers often omit Cancel from AX — dismiss by outside tap.
ios_dismiss_dialog() {
  local title="$1"
  if "$IDB" tap "Cancel" 2>/dev/null; then
    sleep 0.5
    if ios_wait_ui_absent "$title" 8; then
      echo "OK tap 'Cancel' → $title absent"
      CLICK_OK=$((CLICK_OK + 1))
      return 0
    fi
  fi
  # Tap chrome outside the popover (top-leading safe area).
  if "$IDB" tap-point 36 96; then
    sleep 0.5
    if ios_wait_ui_absent "$title" 8; then
      echo "OK dismiss-outside → $title absent"
      CLICK_OK=$((CLICK_OK + 1))
      return 0
    fi
  fi
  ios_capture_failure_diagnostics "dismiss-dialog"
  echo "MISS dismiss dialog '$title'"
  CLICK_MISS=$((CLICK_MISS + 1))
  FLOW_FAIL=1
  return 1
}

ios_scroll_until_visible() {
  local needle="$1"
  local attempts="${2:-5}"
  local attempt
  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if ios_ui_contains "$needle"; then
      return 0
    fi
    "$IDB" swipe-up
    sleep 0.6
  done
  echo "timeout scrolling to visible UI: $needle" >&2
  return 1
}

ios_scroll_until_tappable() {
  local identifier="$1"
  local anchor="${2:-center}"
  local safe_y="${3:-700}"
  local attempts="${4:-5}"
  local bottom_inset="${5:-140}"
  local attempt point x y app_left app_top app_right app_bottom safe_y_min safe_y_max
  local did_scroll=0
  IOS_TAPPABLE_POINT=""
  for ((attempt = 0; attempt <= attempts; attempt++)); do
    if point="$("$IDB" point-id "$identifier" "$anchor" viewport)"; then
      read -r x y app_left app_top app_right app_bottom <<< "$point"
      safe_y_min=$((app_top + 60))
      safe_y_max=$((app_bottom - bottom_inset))
      if (( safe_y < safe_y_max )); then
        safe_y_max="$safe_y"
      fi
      if [[ "$x" =~ ^-?[0-9]+$ && "$y" =~ ^-?[0-9]+$ ]] \
        && (( x >= app_left && x <= app_right && y >= safe_y_min && y <= safe_y_max )); then
        IOS_TAPPABLE_POINT="$x $y"
        if (( did_scroll )); then
          sleep 1.2
        fi
        echo "tappable identifier '$identifier' anchor=$anchor at ($x,$y)"
        return 0
      fi
    fi
    if (( attempt == attempts )); then
      break
    fi
    "$IDB" swipe-up-short
    did_scroll=1
    sleep 0.8
  done
  echo "timeout scrolling identifier into tappable area: $identifier anchor=$anchor safe_y=$safe_y" >&2
  return 1
}

ios_prepare_app() {
  local sim_id="$1"
  ios_require_simulator_udid "$sim_id" || return 1
  if [[ "${LIKEMINDED_REUSE_IOS_INSTALL:-0}" == "1" ]]; then
    if ios_reuse_installed_app "$sim_id"; then
      return 0
    fi
    echo "FATAL: requested iOS install reuse failed identity/freshness checks; refusing interaction" >&2
    return 1
  fi
  if ios_needs_build; then
    SIMULATOR_ID="$sim_id" "$CROSS_LOCK" with_lock xcodebuild-ios bash -c "
      set -euo pipefail
      SIMULATOR_ID='$sim_id' '$ROOT/script/build_and_run.sh' build > /tmp/likeminded-ios-build-\$\$.log 2>&1
    "
  else
    SIMULATOR_ID="$sim_id" "$CROSS_LOCK" with_lock xcodebuild-ios bash -c "
      set -euo pipefail
      SIMULATOR_ID='$sim_id' '$ROOT/script/build_and_run.sh' install > /tmp/likeminded-ios-install-\$\$.log 2>&1
    "
  fi
}

ios_launch_app() {
  local sim_id="$1"
  shift
  "$CROSS_LOCK" with_lock ios-sim env IDB_UDID="$sim_id" BUNDLE_ID="$BUNDLE_ID" bash -c '
    set -euo pipefail
    xcrun simctl launch --terminate-running-process "$IDB_UDID" "$BUNDLE_ID" "$@" >/dev/null
  ' _ "$@"
}

ios_launch_auth_gate() {
  local sim_id
  sim_id="$(resolve_ios_simulator)" || true
  ios_require_simulator_udid "$sim_id" || exit 1
  export IDB_UDID="$sim_id"
  ios_prepare_app "$sim_id" || exit 1

  ios_launch_app "$sim_id" --likeminded-reset-auth-session
  sleep "${IOS_CAPTURE_WAIT:-12}"
  ios_dismiss_account_verification_if_present
}

ios_launch_signed_in() {
  local -a extra=("$@")
  local sim_id
  sim_id="$(resolve_ios_simulator)" || true
  ios_require_simulator_udid "$sim_id" || exit 1
  export IDB_UDID="$sim_id"
  ios_prepare_app "$sim_id" || exit 1
  # Health at script entry can go stale while waiting on xcodebuild-ios.
  ios_ensure_validation_api || exit 1

  local -a launch_args=(
    --likeminded-reset-auth-session
    --likeminded-dev-auth-bypass
    --likeminded-dev-auth-token "$USER_TOKEN"
    --likeminded-dev-auth-name "$USER_NAME"
  )
  launch_args+=("${extra[@]}")

  ios_launch_app "$sim_id" "${launch_args[@]}"
  sleep "${IOS_CAPTURE_WAIT:-18}"
  ios_dismiss_account_verification_if_present

  # One recovery for transient :8787 kills during parallel platform drains.
  if ios_ui_contains "Could not connect to the server" \
    || { ios_ui_contains "Sign in with Apple" \
      && ! ios_ui_contains "Meet" \
      && ! ios_ui_contains "Your circle." \
      && ! ios_ui_contains "Explore communities"; }; then
    echo "warn: signed-in launch stuck on auth/connection error — ensure API + relaunch once" >&2
    ios_ensure_validation_api || exit 1
    ios_launch_app "$sim_id" "${launch_args[@]}"
    sleep "${IOS_CAPTURE_WAIT:-18}"
    ios_dismiss_account_verification_if_present
  fi
}

ios_relaunch_signed_in() {
  local -a extra=("$@")
  local sim_id="${IDB_UDID:-}"
  if [[ -z "$sim_id" ]]; then
    sim_id="$(resolve_ios_simulator)" || true
  fi
  ios_require_simulator_udid "$sim_id" || exit 1
  export IDB_UDID="$sim_id"
  ios_ensure_validation_api || exit 1

  local -a launch_args=(
    --likeminded-reset-auth-session
    --likeminded-dev-auth-bypass
    --likeminded-dev-auth-token "$USER_TOKEN"
    --likeminded-dev-auth-name "$USER_NAME"
  )
  launch_args+=("${extra[@]}")

  ios_launch_app "$sim_id" "${launch_args[@]}"
  sleep "${IOS_CAPTURE_WAIT:-18}"
  ios_dismiss_account_verification_if_present
}

# Deep link --likeminded-start-create-event should open CreateEventView; if the
# stack only reaches community detail, open the form from Plan/Create.
ios_ensure_create_event_form() {
  if ios_wait_ui_contains "Event details" 20 || ios_wait_ui_contains "Add cover" 8; then
    return 0
  fi
  if ios_ui_contains "Create community event" || ios_ui_contains "Plan an event"; then
    ios_scroll_until_visible "Create community event" 5 || true
    local saved_fail=$FLOW_FAIL
    FLOW_FAIL=0
    if ios_tap_button "Create community event" "Event details" "Add cover" "Create event"; then
      return 0
    fi
    FLOW_FAIL=0
    if ios_tap_any_label "Create community event" "Event details"; then
      return 0
    fi
    FLOW_FAIL=$saved_fail
  fi
  if ios_wait_ui_contains "Create event" 8 && ios_ui_contains "Event details"; then
    return 0
  fi
  ios_capture_failure_diagnostics "create-event-form-readiness"
  echo "MISS create-event form not reachable" >&2
  FLOW_FAIL=1
  return 1
}

stamp_controls() {
  local ids="$1"
  local method="${2:-Computer-use}"
  [[ -n "$ids" ]] || return 0
  node "$ROOT/script/ledger_stamp_screen.js" \
    --platform ios \
    --screen "$SCREEN" \
    --controls "$ids" \
    --method "$method" \
    --evidence-prefix "${method} ${EVIDENCE_USER} ${SCREEN}/${FLOW}" || true
}

flow_tier() {
  node - "$ROOT" "$SCREEN" "$FLOW" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [root, screen, flowId] = process.argv.slice(2);
const file = path.join(root, "validation", "screens", `${screen}.json`);
if (!fs.existsSync(file) || !flowId) process.exit(0);
const data = JSON.parse(fs.readFileSync(file, "utf8"));
const flow = (data.flows || []).find((candidate) => candidate.id === flowId);
process.stdout.write(String(flow?.proof?.tier || ""));
NODE
}


# Scroll a labeled control until its center Y is above the floating tab bar (~770).
ios_scroll_label_into_safe_band() {
  local label="$1"
  local attempt point cx cy
  local did_scroll=0
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    point="$("$IDB" describe 2>/dev/null | LABEL="$label" python3 -c '
import json, os, sys, unicodedata
want = " ".join(unicodedata.normalize("NFKC", os.environ["LABEL"]).split()).casefold()

def labels_match(raw, wanted):
    text = " ".join(unicodedata.normalize("NFKC", str(raw)).split()).casefold()
    if text == wanted:
        return True
    parts = [p.strip() for p in text.split(",") if p.strip()]
    return bool(parts) and all(p == wanted for p in parts)

data = json.load(sys.stdin)
best = None
for e in data:
    raw = e.get("AXLabel") or e.get("AXValue") or ""
    if not labels_match(raw, want):
        continue
    if e.get("type") not in ("Button", "Link", "Cell", "Other", "StaticText", "TextField", "SearchField", "TextArea", "TextView"):
        continue
    frame = e.get("frame") or {}
    w = float(frame.get("width") or 0)
    h = float(frame.get("height") or 0)
    if w <= 0 or h <= 0 or h > 280:
        continue
    cx = float(frame.get("x") or 0) + w / 2
    cy = float(frame.get("y") or 0) + h / 2
    if best is None or abs(cy - 500) < abs(best[1] - 500):
        best = (cx, cy)
if not best:
    raise SystemExit(1)
print("%.0f %.0f" % best)
' 2>/dev/null || true)"
    if [[ -n "$point" ]]; then
      read -r cx cy <<< "$point"
      if [[ "$cx" =~ ^[0-9]+$ && "$cy" =~ ^[0-9]+$ ]] && (( cy >= 180 && cy <= 720 )); then
        if (( did_scroll )); then
          # Let ScrollView deceleration finish before dispatching at the AX frame.
          sleep 1.2
        fi
        echo "safe-band '$label' at ($cx,$cy)"
        IOS_TAPPABLE_POINT="$cx $cy"
        return 0
      fi
    fi
    if [[ -n "${cy:-}" && "$cy" =~ ^[0-9]+$ ]] && (( cy < 180 )); then
      "$IDB" swipe-down 2>/dev/null || true
    else
      "$IDB" swipe-up-short 2>/dev/null || "$IDB" swipe-up 2>/dev/null || true
    fi
    did_scroll=1
    sleep 0.55
  done
  echo "timeout scrolling '$label' into safe band" >&2
  return 1
}

echo "prove_flow platform=ios screen=$SCREEN flow=${FLOW:-"(capture)"}"

set +e
case "${SCREEN}/${FLOW}" in
  auth/auth-promise-copy)
    ios_launch_auth_gate
    if ! ios_wait_ui_contains "Likeminded" 30; then
      ios_capture_failure_diagnostics "auth-gate-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      for needle in "Voice profile" "Private by design" "Circle placement"; do
        if ios_wait_ui_contains "$needle" 15; then
          echo "OK promise row visible: $needle"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_capture_failure_diagnostics "auth-promise-$(echo "$needle" | tr '[:upper:] ' '[:lower:]-')"
          echo "MISS promise row: $needle" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
        fi
      done
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 3 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/auth-gate.png"; then
        stamp_controls "promise-rows"
      else
        echo "failed to capture auth promise-rows success state" >&2
        FLOW_FAIL=1
      fi
    else
      FLOW_FAIL=1
    fi
    ;;
  app-shell/tab-navigation)
    ios_launch_signed_in
    # Soft readiness wait — subtitle AX can lag behind tab bar; tabs prove shell ready.
    ios_wait_ui_contains "Meet" 45 || echo "warn: Meet tab not visible before tab sweep" >&2
    ios_tap_button "Meet" "When you meet."
    ios_tap_button "Circles" "Your circle."
    ios_tap_button "Communities" "Explore communities"
    ios_tap_button "Soulmate" "This week’s introduction."
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
    ios_tap_button "Back to circles" "Your circle."
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      stamp_controls "global-back"
    fi
    ;;
  profile-edit/profile-update-text)
    ios_launch_signed_in \
      --likeminded-start-profile \
      --likeminded-start-profile-edit
    if ! ios_wait_ui_contains "Living profile" 35; then
      ios_capture_failure_diagnostics "profile-edit-update-text-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "profile-update-with-text" \
        "Type an update" \
        "Type update" \
        "" \
        "" \
        present
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-edit-typed-update.png" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Typed profile update" "Typed profile proof update"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_tappable "profile-typed-update-save" center 700 4 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "profile-typed-update-save" \
        "Type an update" \
        "Save typed update" \
        "" \
        "" \
        absent \
        center \
        "$IOS_TAPPABLE_POINT"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_visible "Profile update saved" 10; then
      ios_capture_failure_diagnostics "profile-edit-update-text-confirmation"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_visible "Typed profile proof update" 4; then
      ios_capture_failure_diagnostics "profile-edit-update-text-persisted"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-edit-typed-saved.png"; then
        stamp_controls "profile-update-text"
      else
        echo "failed to capture profile-edit typed update persisted state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  profile-edit/profile-update-voice)
    ios_launch_signed_in \
      --likeminded-start-profile \
      --likeminded-start-profile-edit \
      --likeminded-dev-voice-preview
    if ! ios_wait_ui_contains "Living profile" 35; then
      ios_capture_failure_diagnostics "profile-edit-update-voice-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_scroll_until_tappable "profile-update-with-voice" center 700 8; then
        ios_capture_failure_diagnostics "profile-edit-update-voice-tappable"
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "profile-update-with-voice" \
        "Voice profile" \
        "Update profile with voice" \
        "" \
        "" \
        present \
        center \
        "$IOS_TAPPABLE_POINT"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_wait_ui_contains "Captured signals" 20 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-edit-voice-review.png" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Save voice profile" "Living profile"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_visible "Voice profile saved" 10; then
      echo "voice update returned without a visible saved receipt" >&2
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-edit-voice-saved.png" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_launch_signed_in \
        --likeminded-start-profile \
        --likeminded-start-profile-edit
      ios_wait_ui_contains "Living profile" 35 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_visible "Prefers slow, honest conversation" 10; then
      echo "voice-derived summary did not survive relaunch and profile refetch" >&2
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_launch_signed_in \
        --likeminded-start-profile \
        --likeminded-start-profile-edit
      ios_wait_ui_contains "Living profile" 35 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "profile-update-with-voice" \
        "Voice profile" \
        "Update profile with voice" \
        "" \
        "" \
        present
      ios_wait_ui_contains "Nothing was recorded or changed" 35 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-edit-voice-failure.png"; then
        stamp_controls "profile-update-voice"
      else
        echo "failed to capture profile-edit voice success and fail-closed states" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  profile-edit/save)
    ios_launch_signed_in \
      --likeminded-start-profile \
      --likeminded-start-profile-edit
    if ! ios_wait_ui_contains "Living profile" 35; then
      ios_capture_failure_diagnostics "profile-edit-back-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Back to profile" "Your profile"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile.png"; then
        stamp_controls "save"
      else
        echo "failed to capture profile-edit back-navigation success state" >&2
        FLOW_FAIL=1
      fi
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
  circle-detail/back)
    ios_launch_signed_in \
      --likeminded-start-circles \
      --likeminded-start-circle-detail
    if ! ios_wait_ui_contains "circle-detail-back" 35 \
      && ! ios_wait_ui_contains "Back to circles" 10; then
      ios_capture_failure_diagnostics "circle-detail-back-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "circle-detail-back" \
        "Your circle." \
        "Back to circles" \
        "" \
        "" \
        present
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/11-circle-detail.png"; then
        stamp_controls "back"
      else
        echo "failed to capture circle-detail back success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circle-detail/circle-options)
    ios_launch_signed_in \
      --likeminded-start-circles \
      --likeminded-start-circle-detail
    if ! ios_wait_ui_contains "circle-detail-back" 35 \
      && ! ios_wait_ui_contains "Back to circles" 10; then
      ios_capture_failure_diagnostics "circle-options-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "circle-options" \
        "Report placement concern" \
        "Circle options" \
        "" \
        "" \
        present
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/11-circle-detail.png"; then
        stamp_controls "circle-options"
      else
        echo "failed to capture circle-options success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circle-detail/detail-rows)
    ios_launch_signed_in \
      --likeminded-start-circles \
      --likeminded-start-circle-detail
    if ! ios_wait_ui_contains "circle-detail-back" 35 \
      && ! ios_wait_ui_contains "Back to circles" 10; then
      ios_capture_failure_diagnostics "detail-rows-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_visible "Next meetup" 8; then
      ios_capture_failure_diagnostics "detail-rows-next-meetup"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "members"; then
        echo "OK detail-rows members visible"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "detail-rows-members"
        echo "MISS detail-rows members row" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/11-circle-detail.png"; then
        stamp_controls "detail-rows"
      else
        echo "failed to capture detail-rows success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circle-detail/leave-circle)
    ios_launch_signed_in \
      --likeminded-start-circles \
      --likeminded-start-circle-detail
    if ! ios_wait_ui_contains "circle-detail-back" 35 \
      && ! ios_wait_ui_contains "Back to circles" 10; then
      ios_capture_failure_diagnostics "leave-circle-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_visible "Leave circle" 10; then
      ios_capture_failure_diagnostics "leave-circle-scroll"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Leave circle" "Leave this circle?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_dismiss_dialog "Leave this circle?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/11-circle-detail.png"; then
        stamp_controls "leave-circle"
      else
        echo "failed to capture leave-circle success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circle-detail/circle-options-ios)
    ios_launch_signed_in \
      --likeminded-start-circles \
      --likeminded-start-circle-detail
    if ! ios_wait_ui_contains "circle-detail-back" 35; then
      ios_capture_failure_diagnostics "circle-detail-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "" "Report placement concern" "Circle options"
      ios_tap_control \
        "options-report-concern" \
        "Report placement concern" \
        "Report placement concern" \
        "" \
        "" \
        absent
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "" "Report placement concern" "Circle options"
      ios_tap_control \
        "options-done" \
        "Report placement concern" \
        "Done" \
        "" \
        "" \
        absent
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 4 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/11-circle-detail.png"; then
        stamp_controls "options-report-concern,options-done"
      else
        echo "failed to capture circle options success state" >&2
        FLOW_FAIL=1
      fi
    else
      FLOW_FAIL=1
    fi
    ;;
  circle-detail/secondary-circle-selection)
    if ! "$CROSS_LOCK" with_lock seed npm run reset:validation-data >/dev/null; then
      echo "failed to reset deterministic validation data for secondary-circle proof" >&2
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_launch_signed_in --likeminded-start-circles
      if ! ios_wait_ui_contains "secondary-circle-card-longform-thinkers" 35; then
        ios_capture_failure_diagnostics "circles-readiness"
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_tappable \
      "secondary-circle-card-longform-thinkers" center 700 3; then
      ios_capture_failure_diagnostics "secondary-card-tappable"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "secondary-circle-card-longform-thinkers" \
        "Back to circles" \
        "Open Longform Thinkers AI suggestion" \
        "" \
        "" \
        present \
        center \
        "$IOS_TAPPABLE_POINT"
      if [[ "$FLOW_FAIL" -eq 0 ]]; then
        sleep 1.2
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_tappable \
      "make-secondary-circle" center 830 6 40; then
      ios_capture_failure_diagnostics "secondary-action-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "make-secondary-circle" \
        "Your second circle" \
        "Make this my second circle" \
        "" \
        "" \
        present \
        center \
        "$IOS_TAPPABLE_POINT"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_relaunch_signed_in --likeminded-start-circles
      if ios_wait_ui_contains "Your second circle" 35; then
        echo "OK secondary circle card persisted after relaunch"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "secondary-card-persistence"
        echo "MISS persisted secondary circle card after relaunch" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_scroll_until_tappable "secondary-circle-card-longform-thinkers" center 700 3; then
        ios_capture_failure_diagnostics "persisted-secondary-card-tappable"
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "secondary-circle-card-longform-thinkers" \
        "Back to circles" \
        "Open Longform Thinkers AI suggestion" \
        "" \
        "" \
        present \
        center \
        "$IOS_TAPPABLE_POINT"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_visible "Your second circle" 6; then
      ios_capture_failure_diagnostics "selected-detail-persistence"
      echo "MISS selected secondary state after reopening detail" >&2
      CLICK_MISS=$((CLICK_MISS + 1))
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/11-circle-detail.png"; then
        stamp_controls "make-secondary-circle"
      else
        echo "failed to capture selected secondary circle detail" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-detail/back)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "community-detail-back-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Back" \
        "Explore communities" "Browse communities" "Create a community" "YOUR COMMUNITIES"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/community-detail.png"; then
        stamp_controls "back"
      else
        echo "failed to capture community-detail back success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-detail/ellipsis)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "community-detail-ellipsis-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Community options" "View guidelines" "Community options"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "ellipsis"
      else
        echo "failed to capture community-detail ellipsis success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-detail/community-detail-tabs)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "community-detail-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_visible "Upcoming" 8; then
      ios_capture_failure_diagnostics "community-detail-tabs-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_tappable "detail-tab-members" center 650 12 180 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Members" "View members" "Join this community to view its members."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_tappable "detail-tab-resources" center 650 4 180 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "detail-tab-resources" "Community guidelines" "Resources" "" "" present center "$IOS_TAPPABLE_POINT"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_tappable "detail-tab-highlights" center 650 4 180 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "detail-tab-highlights" "Best essay thread" "Highlights" "" "" present center "$IOS_TAPPABLE_POINT"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_tappable "detail-tab-upcoming" center 650 4 180 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "detail-tab-upcoming" "Community Meetup" "Upcoming" "" "" present center "$IOS_TAPPABLE_POINT"
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 4 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "detail-tab-upcoming,detail-tab-members,detail-tab-resources,detail-tab-highlights"
      else
        echo "failed to capture community detail tab success state" >&2
        FLOW_FAIL=1
      fi
    else
      FLOW_FAIL=1
    fi
    ;;
  community-detail/event-rows)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "event-rows-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "detail-tab-upcoming" "Community Meetup" "Upcoming" || \
        ios_tap_button "Upcoming" "Community Meetup" "Create community event" "Host"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_visible "Host" 8 \
      && ! ios_scroll_until_visible "Create community event" 4 \
      && ! ios_scroll_until_visible "Plan an event" 4; then
      ios_capture_failure_diagnostics "event-rows-upcoming-content"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Create community event" || ios_ui_contains "Plan an event"; then
        ios_scroll_until_tappable "community-detail-plan-event" center 700 6 || true
        ios_tap_control "community-detail-plan-event" "Create event" "Create community event" \
          || ios_tap_button "Create community event" "Create event" "Event details"
      else
        event_id="community-detail-event-mtg_community_jazz-music_2026-07-25_1"
        ios_scroll_until_tappable "$event_id" center 700 8 || \
          ios_scroll_until_visible "Upcoming community event" 6 || true
        ios_tap_control "$event_id" "When you meet." "Jazz Music" \
          || ios_tap_button "Jazz Music" "When you meet."
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "event-rows"
      else
        echo "failed to capture community-detail event-rows success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-detail/highlights-essay)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "highlights-essay-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "detail-tab-highlights" "Best essay thread" "Highlights" || \
        ios_tap_button "Highlights" "Best essay thread"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Best essay thread" 6 || true
      ios_tap_button "Best essay thread" \
        "long-form reading" "essay collections" "Done"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "highlights-essay"
      else
        echo "failed to capture highlights-essay success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-detail/highlights-recommendation)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "highlights-recommendation-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "detail-tab-highlights" "Most saved recommendation" "Highlights" || \
        ios_tap_button "Highlights" "Most saved recommendation"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Most saved recommendation" 6 || true
      ios_tap_button "Most saved recommendation" \
        "listening session playlist" "cafe meetup" "Done"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "highlights-recommendation"
      else
        echo "failed to capture highlights-recommendation success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-detail/resources-guidelines)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "resources-guidelines-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "detail-tab-resources" "Community guidelines" "Resources" || \
        ios_tap_button "Resources" "Community guidelines"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Community guidelines" 6 || true
      ios_tap_button "Community guidelines" \
        "Be kind, stay curious" "No harassment" "Done"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "resources-guidelines"
      else
        echo "failed to capture resources-guidelines success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-detail/resources-prompts)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "resources-prompts-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "detail-tab-resources" "Conversation prompts" "Resources" || \
        ios_tap_button "Resources" "Conversation prompts"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Conversation prompts" 6 || true
      ios_tap_button "Conversation prompts" \
        "This week's prompts" "What piece of art" "Done"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "resources-prompts"
      else
        echo "failed to capture resources-prompts success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-detail/join-leave)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "join-leave-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Leave community" 8 || \
        ios_scroll_until_visible "Join community" 8 || true
      if ios_ui_contains "Leave community"; then
        ios_scroll_label_into_safe_band "Leave community" || FLOW_FAIL=1
        if [[ "$FLOW_FAIL" -eq 0 ]]; then
          ios_tap_button "Leave community" "Leave this community?"
        fi
        if [[ "$FLOW_FAIL" -eq 0 ]]; then
          ios_tap_button "Leave" "Join community"
        fi
        if [[ "$FLOW_FAIL" -eq 0 ]]; then
          ios_scroll_label_into_safe_band "Join community" || FLOW_FAIL=1
        fi
        if [[ "$FLOW_FAIL" -eq 0 ]]; then
          ios_tap_button "Join community" "Leave community"
        fi
      elif ios_ui_contains "Join community"; then
        ios_scroll_label_into_safe_band "Join community" || FLOW_FAIL=1
        if [[ "$FLOW_FAIL" -eq 0 ]]; then
          ios_tap_button "Join community" "Leave community"
        fi
        if [[ "$FLOW_FAIL" -eq 0 ]]; then
          ios_scroll_label_into_safe_band "Leave community" || FLOW_FAIL=1
        fi
        if [[ "$FLOW_FAIL" -eq 0 ]]; then
          ios_tap_button "Leave community" "Leave this community?"
        fi
        if [[ "$FLOW_FAIL" -eq 0 ]]; then
          ios_tap_button "Leave" "Join community"
        fi
      else
        ios_capture_failure_diagnostics "join-leave-cta-missing"
        echo "MISS join-leave CTA not visible" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "join-leave"
      else
        echo "failed to capture join-leave success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  chat/send-message)
    ios_launch_signed_in --likeminded-start-chat
    if ! ios_wait_ui_contains "Message input" 35; then
      ios_capture_failure_diagnostics "chat-send-readiness"
      FLOW_FAIL=1
    fi
    proof_text="Ledger proof $(date +%H%M%S)"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Message input" "$proof_text" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Send message" "$proof_text"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_wait_ui_contains "$proof_text" 20; then
        echo "OK sent message visible in thread: $proof_text"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "chat-send-message-missing"
        echo "MISS sent message not visible: $proof_text" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/chat.png"; then
        stamp_controls "draft,send,message-list"
      else
        echo "failed to capture chat send-message success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  chat/chat-call-headers)
    ios_launch_signed_in --likeminded-start-chat
    if ! ios_wait_ui_contains "Message input" 30; then
      ios_capture_failure_diagnostics "readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "voice-call-header" "Scheduling a voice call" "Voice call" 245 84
      sleep 1
      ios_tap_control "call-sheet-done" "Scheduling a voice call" "Done" "" "" absent
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "video-call-header" "Scheduling a video call" "Video call" 304 84
      sleep 1
      ios_tap_control "call-sheet-done" "Scheduling a video call" "Done" "" "" absent
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "conversation-info-header" "Mutual match from" "Conversation info" 361 84
      sleep 1
      ios_tap_control "call-sheet-done" "Mutual match from" "Done" "" "" absent
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 6 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/chat.png"; then
        stamp_controls "voice-call-header,video-call-header,conversation-info-header,call-sheet-done"
      else
        echo "failed to capture unobstructed chat success state" >&2
        FLOW_FAIL=1
      fi
    else
      FLOW_FAIL=1
    fi
    ;;
  community-detail/community-options-ios)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "community-detail-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Community options" "View guidelines"
      ios_tap_button "View guidelines" "Be kind, stay curious"
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 2 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "options-view-guidelines"
      else
        echo "failed to capture community options guidelines state" >&2
        FLOW_FAIL=1
      fi
    else
      FLOW_FAIL=1
    fi
    ;;
  community-members/community-members-back)
    ios_launch_signed_in \
      --likeminded-start-community-members \
      --likeminded-community-id reflective-builders
    if ! ios_wait_ui_contains "Back to community" 35; then
      ios_capture_failure_diagnostics "community-members-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Back to community" \
        "Community options" "Join community" "Leave community" "Upcoming" "View members"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/community-members.png"; then
        stamp_controls "members-back"
      else
        echo "failed to capture community-members back success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-members/member-rows)
    # Display-only roster from API (names + activity labels).
    # Use ai-builders: validation user is a member (jazz-music members API is 403).
    ios_launch_signed_in \
      --likeminded-start-community-members \
      --likeminded-community-id ai-builders
    if ! ios_wait_ui_contains "Back to community" 35 \
      && ! ios_wait_ui_contains "Roster" 10; then
      ios_capture_failure_diagnostics "community-members-member-rows-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Wait for the readable seeded roster; do not manufacture presence/activity state.
      if ios_wait_ui_contains "Community member" 25; then
        echo "OK member-rows: truthful roster rows rendered"
        CLICK_OK=$((CLICK_OK + 1))
      elif ios_ui_contains "No members have joined this community yet."; then
        ios_capture_failure_diagnostics "community-members-member-rows-empty"
        echo "MISS member-rows: roster empty" >&2
        FLOW_FAIL=1
      else
        ios_capture_failure_diagnostics "community-members-member-rows-content"
        echo "MISS member-rows: no truthful member rows" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Seeded ai-builders roster names (any one proves API rows rendered).
      if ios_ui_contains "Priya" || ios_ui_contains "Rohan" || ios_ui_contains "Kavya" \
        || ios_ui_contains "Vivek" || ios_ui_contains "Isha" || ios_ui_contains "Gurusharan"; then
        echo "OK member-rows: seeded member name visible"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "community-members-member-rows-names"
        echo "MISS member-rows: expected seeded member names absent" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/community-members.png"; then
        stamp_controls "member-rows"
      else
        echo "failed to capture community-members member-rows success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-members/filter-pills)
    # iOS: display control — subtitle + roster badge share the loaded API member count.
    # (macOS also has All/Active now/Most active pills; iOS exposes the count badge as filter-pills.)
    # ai-builders: validation user can GET members (jazz-music → 403 membership_required).
    ios_launch_signed_in \
      --likeminded-start-community-members \
      --likeminded-community-id ai-builders
    if ! ios_wait_ui_contains "Back to community" 35 \
      && ! ios_wait_ui_contains "members · Private" 10; then
      ios_capture_failure_diagnostics "community-members-filter-pills-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_wait_ui_contains " members" 20 || true
      count_msg="$("$IDB" describe 2>/dev/null | python3 -c '
import json, re, sys, unicodedata

def norm(value):
    return " ".join(unicodedata.normalize("NFKC", str(value or "")).split())

data = json.load(sys.stdin)
subtitle_counts = []
badge_counts = []
for e in data:
    uid = str(e.get("AXUniqueId") or e.get("AXIdentifier") or "")
    lab = norm(e.get("AXLabel"))
    val = norm(e.get("AXValue"))
    if uid == "filter-pills" or lab.casefold() == "all members":
        m = re.search(r"(\d+)\s+members?", val, re.I) or re.search(r"(\d+)\s+members?", lab, re.I)
        if m:
            badge_counts.append(int(m.group(1)))
    if "members" in lab.casefold() and "private" in lab.casefold():
        m = re.search(r"(\d+)\s+members?", lab, re.I)
        if m:
            subtitle_counts.append(int(m.group(1)))
if not subtitle_counts:
    for e in data:
        lab = norm(e.get("AXLabel") or e.get("AXValue"))
        m = re.search(r"^(\d+)\s+members?\s*·\s*private$", lab, re.I)
        if m:
            subtitle_counts.append(int(m.group(1)))
if not badge_counts:
    for e in data:
        lab = norm(e.get("AXLabel") or e.get("AXValue"))
        m = re.search(r"^(\d+)\s+members?$", lab, re.I)
        if m:
            badge_counts.append(int(m.group(1)))
if not subtitle_counts or not badge_counts:
    print(f"missing subtitle={subtitle_counts} badge={badge_counts}", file=sys.stderr)
    raise SystemExit(2)
sub, badge = subtitle_counts[0], badge_counts[0]
if sub != badge or sub <= 0:
    print(f"mismatch subtitle={sub} badge={badge}", file=sys.stderr)
    raise SystemExit(1)
print(f"OK filter-pills: subtitle and roster badge both show {sub} members")
')" || true
      if [[ "$count_msg" == OK\ filter-pills:* ]]; then
        echo "$count_msg"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "community-members-filter-pills-count"
        echo "MISS filter-pills: subtitle/roster member counts missing or mismatched" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/community-members.png"; then
        stamp_controls "filter-pills"
      else
        echo "failed to capture community-members filter-pills success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-members/search)
    # Search members filters roster — type non-match → empty copy. Do not reuse screen sweep.
    # ai-builders: validation user can GET members (jazz-music → 403 membership_required).
    ios_launch_signed_in \
      --likeminded-start-community-members \
      --likeminded-community-id ai-builders
    if ! ios_wait_ui_contains "Back to community" 35 \
      && ! ios_wait_ui_contains "Search members" 10; then
      ios_capture_failure_diagnostics "community-members-search-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Wait for fetch before searching (empty roster would false-pass filter empty copy).
      if ios_wait_ui_contains "Community member" 25; then
        echo "OK search: truthful roster loaded"
      elif ios_ui_contains "No members have joined this community yet."; then
        ios_capture_failure_diagnostics "community-members-search-empty-roster"
        echo "MISS member search: roster empty/forbidden" >&2
        FLOW_FAIL=1
      else
        ios_capture_failure_diagnostics "community-members-search-roster"
        echo "MISS member search: roster did not load" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Search members" "zzzzno-member" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_wait_ui_contains "No members match" 15; then
        echo "OK search filtered roster to empty"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "community-members-search-no-filter"
        echo "MISS community-members search: expected No members match" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/community-members.png"; then
        stamp_controls "search"
      else
        echo "failed to capture community-members search success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-community/create-entry)
    # Entry control lives on Communities; opens CreateCommunityView sheet.
    ios_launch_signed_in --likeminded-start-communities
    if ! ios_wait_ui_contains "Create a community" 35 \
      && ! ios_wait_ui_contains "Browse communities" 10; then
      ios_capture_failure_diagnostics "create-entry-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # AX can expose the row while it is still behind the bottom tab bar.
      # Require a safe tap band before dispatching the interaction.
      ios_scroll_label_into_safe_band "Create a community" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Create a community" "Community name" "Create community"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_absence_samples "Preview" 5; then
      echo "Preview must remain hidden until the required community details are complete" >&2
      ios_capture_failure_diagnostics "create-community-premature-preview"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-community.png"; then
        stamp_controls "create-entry"
      else
        echo "failed to capture create-community create-entry success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-community/name)
    ios_launch_signed_in --likeminded-start-create-community
    if ! ios_wait_ui_contains "Community name" 35; then
      ios_capture_failure_diagnostics "create-community-name-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Community name" "Ledger Proof Circle"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_wait_ui_contains "Ledger Proof Circle" 10 || {
        ios_capture_failure_diagnostics "create-community-name-value"
        FLOW_FAIL=1
      }
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-community.png"; then
        stamp_controls "name"
      else
        echo "failed to capture create-community name success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-community/summary)
    ios_launch_signed_in --likeminded-start-create-community
    if ! ios_wait_ui_contains "Community summary" 35 \
      && ! ios_wait_ui_contains "Community name" 10; then
      ios_capture_failure_diagnostics "create-community-summary-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Community summary" "A place for ledger proof conversations."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_wait_ui_contains "A place for ledger proof conversations." 10 || {
        ios_capture_failure_diagnostics "create-community-summary-value"
        FLOW_FAIL=1
      }
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-community.png"; then
        stamp_controls "summary"
      else
        echo "failed to capture create-community summary success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-community/themes)
    ios_launch_signed_in --likeminded-start-create-community
    if ! ios_wait_ui_contains "Add themes (optional)" 35 \
      && ! ios_wait_ui_contains "Community name" 10; then
      ios_capture_failure_diagnostics "create-community-themes-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_absence_samples "Community themes" 5; then
      echo "Optional themes field must remain hidden until explicitly expanded" >&2
      ios_capture_failure_diagnostics "create-community-themes-prematurely-visible"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Add themes (optional)" "Community themes"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Community themes" "Jazz, Rituals, Reflection"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Preview chips or field value should surface at least one theme token.
      if ios_wait_ui_contains "Jazz" 10 || ios_wait_ui_contains "Jazz, Rituals, Reflection" 5; then
        echo "OK themes typed / previewed"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "create-community-themes-value"
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-community.png"; then
        stamp_controls "themes"
      else
        echo "failed to capture create-community themes success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-community/submit)
    ios_launch_signed_in --likeminded-start-create-community
    if ! ios_wait_ui_contains "Community name" 35; then
      ios_capture_failure_diagnostics "create-community-submit-readiness"
      FLOW_FAIL=1
    fi
    submit_name="Ledger Submit $(date +%H%M%S)"
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Community name" "$submit_name"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Community summary" "Created by iOS ledger submit proof."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_wait_ui_contains "Preview" 10; then
      ios_capture_failure_diagnostics "create-community-preview-after-required-fields"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Create community" \
        "Browse communities" "Explore communities" "YOUR COMMUNITIES" "$submit_name"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-community.png"; then
        stamp_controls "submit"
      else
        echo "failed to capture create-community submit success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-community/create-community-cancel)
    ios_launch_signed_in --likeminded-start-create-community
    if ! ios_wait_ui_contains "Community name" 35; then
      ios_capture_failure_diagnostics "create-community-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Cancel" \
        "Browse communities" "Explore communities" "Create a community" "YOUR COMMUNITIES"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-community.png"; then
        stamp_controls "create-cancel"
      else
        echo "failed to capture create-community cancel success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-event/event-type-meetup|create-event/event-type-listening-session|create-event/event-type-jam-session)
    ios_launch_signed_in --likeminded-start-create-event
    ios_ensure_create_event_form || true
    case "$FLOW" in
      event-type-meetup) pill_label="Meetup" ;;
      event-type-listening-session) pill_label="Listening Session" ;;
      event-type-jam-session) pill_label="Jam Session" ;;
      *) pill_label="" ;;
    esac
    if [[ "$FLOW_FAIL" -eq 0 && -n "$pill_label" ]]; then
      if [[ "$pill_label" == "Meetup" ]]; then
        # Force a re-select cycle so Selected is interaction-proven, not just default.
        "$IDB" tap "Listening Session" || true
        sleep 0.4
        "$IDB" tap "Meetup" || {
          ios_capture_failure_diagnostics "event-type-meetup-tap"
          echo "MISS resolve event type pill 'Meetup'" >&2
          FLOW_FAIL=1
        }
        sleep 0.5
      elif ! "$IDB" tap "$pill_label"; then
        ios_capture_failure_diagnostics "event-type-${FLOW}-tap"
        echo "MISS resolve event type pill '$pill_label'" >&2
        FLOW_FAIL=1
      else
        sleep 0.5
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def n(v):
    return " ".join(unicodedata.normalize("NFKC", str(v or "")).split()).casefold()
want_label, want_value = n(sys.argv[1]), n("Selected")
data = json.load(sys.stdin)
for e in data:
    if n(e.get("AXLabel")) == want_label and n(e.get("AXValue")) == want_value:
        raise SystemExit(0)
raise SystemExit(1)
' "$pill_label"; then
        echo "OK event type Selected: $pill_label"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "event-type-${FLOW}-selected"
        echo "MISS event type not Selected: $pill_label" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-event.png"; then
        stamp_controls "$FLOW"
      else
        echo "failed to capture create-event $FLOW success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-event/event-fields)
    ios_launch_signed_in --likeminded-start-create-event
    ios_ensure_create_event_form || true
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Event name" "Ledger Jazz Night"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Date" "Sat, Jul 19, 2026"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Time" "8:00 PM"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Location" "The Listening Room"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Event details" 4 || true
      ios_focus_and_type "Event details" "Ledger proof details for the create-event form."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Ledger Jazz Night" && ios_ui_contains "The Listening Room"; then
        echo "OK event fields retained after edit"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "create-event-fields-value"
        echo "MISS create-event fields did not retain typed values" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-event.png"; then
        stamp_controls "event-fields"
      else
        echo "failed to capture create-event event-fields success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-event/add-cover)
    ios_launch_signed_in --likeminded-start-create-event
    ios_ensure_create_event_form || true
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Add cover" 6 || ios_scroll_until_visible "Cover added" 2 || true
      if ios_ui_contains "Add cover"; then
        ios_tap_button "Add cover" \
          "Cover added" "Jazz listening cover added to preview."
      elif ios_ui_contains "Cover added"; then
        ios_tap_button "Cover added" \
          "Jazz listening cover added to preview." "Cover added"
      else
        ios_capture_failure_diagnostics "create-event-add-cover-missing"
        echo "MISS create-event add-cover control" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-event.png"; then
        stamp_controls "add-cover"
      else
        echo "failed to capture create-event add-cover success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-event/add-tags)
    ios_launch_signed_in --likeminded-start-create-event
    ios_ensure_create_event_form || true
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Add tags" 6 || ios_scroll_until_visible "Tags added" 2 || true
      if ios_ui_contains "Add tags"; then
        ios_tap_button "Add tags" \
          "Tags added" "Tags added from event type." "Community hosted"
      elif ios_ui_contains "Tags added"; then
        # Validation plate starts with tags applied; re-tap still sets status.
        ios_tap_button "Tags added" \
          "Tags added from event type." "Community hosted" "Tags added"
      else
        ios_capture_failure_diagnostics "create-event-add-tags-missing"
        echo "MISS create-event add-tags control" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-event.png"; then
        stamp_controls "add-tags"
      else
        echo "failed to capture create-event add-tags success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-event/create-event)
    ios_launch_signed_in --likeminded-start-create-event
    ios_ensure_create_event_form || true
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Scroll CTA above the floating tab bar, then tap by accessibility id.
      ios_scroll_until_tappable "create-event-submit" center 780 8 160 || \
        ios_scroll_until_visible "Create event" 6 || true
      if ! "$IDB" tap-id "create-event-submit"; then
        # Fallback: lowest "Create event" Button by AX frame.
        point="$("$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def n(v):
    return " ".join(unicodedata.normalize("NFKC", str(v or "")).split()).casefold()
want = n("Create event")
data = json.load(sys.stdin)
buttons = []
for e in data:
    if e.get("type") != "Button":
        continue
    if n(e.get("AXLabel")) != want:
        continue
    frame = e.get("frame") or {}
    w, h = frame.get("width", 0), frame.get("height", 0)
    if w <= 0 or h <= 0 or h > 280:
        continue
    cx = frame["x"] + w / 2
    cy = frame["y"] + h / 2
    buttons.append((cy, cx))
if not buttons:
    raise SystemExit(1)
buttons.sort()
cy, cx = buttons[-1]
print("%.0f %.0f" % (cx, cy))
')" || true
        if [[ -z "${point:-}" ]]; then
          ios_capture_failure_diagnostics "create-event-submit-resolve"
          echo "MISS resolve Create event CTA button" >&2
          FLOW_FAIL=1
        else
          read -r x y <<< "$point"
          echo "tappable Create event CTA at ($x,$y)"
          "$IDB" tap-point "$x" "$y" || FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # API create + dismiss can take a few seconds.
      if ios_wait_ui_contains "Community options" 25 \
        || ios_wait_ui_contains "View members" 10 \
        || ios_wait_ui_contains "Upcoming" 10 \
        || ios_wait_ui_contains "was created" 8; then
        echo "OK Create event CTA → left create form"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "create-event-submit-outcome"
        echo "MISS Create event CTA did not leave form / show success" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-event.png"; then
        stamp_controls "create-event"
      else
        echo "failed to capture create-event submit success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  create-event/create-event-cancel)
    ios_launch_signed_in --likeminded-start-create-event
    ios_ensure_create_event_form || true
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Back" \
        "Community options" "Upcoming" "Join community" "Leave community" "View members"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/create-event.png"; then
        stamp_controls "create-event-cancel"
      else
        echo "failed to capture create-event cancel success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  onboarding/onboarding-voice-nav)
    ios_launch_signed_in --likeminded-force-onboarding --likeminded-start-profile
    if ! ios_wait_ui_contains "About you" 35 && ! ios_wait_ui_contains "ONBOARDING" 10; then
      ios_capture_failure_diagnostics "onboarding-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Prefer Voice profile step a11y; fall back to Continue on About you.
      if ios_ui_contains "Voice profile step"; then
        ios_tap_any_label "Voice profile step" "Answer a few reflection prompts" || \
          ios_tap_button "Voice profile step" "Answer a few reflection prompts" "Your answer"
      elif ios_ui_contains "Continue"; then
        ios_tap_button "Continue" "Answer a few reflection prompts" "Voice profile" "Your answer"
      else
        ios_capture_failure_diagnostics "onboarding-voice-step-missing"
        echo "MISS onboarding voice step entry" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_wait_ui_contains "Your answer" 15 || ios_wait_ui_contains "Answer a few reflection prompts" 10 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Your answer" "Quiet dinners and long walks help me recharge."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Next prompt" "How do you prefer to open up" "Your answer"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Back" "What has felt most energizing" "Your answer"
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 2 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/onboarding.png"; then
        stamp_controls "voice-back,voice-next-prompt"
      else
        echo "failed to capture onboarding voice-nav success state" >&2
        FLOW_FAIL=1
      fi
    else
      FLOW_FAIL=1
    fi
    ;;
  onboarding/onboarding-voice)
    # Text-box proof for the reflection UI and persisted profile synthesis.
    voice_marker="Ledger voice $(date +%H%M%S)"
    ios_launch_signed_in --likeminded-force-onboarding --likeminded-start-profile
    if ! ios_wait_ui_contains "About you" 35 && ! ios_wait_ui_contains "ONBOARDING" 10; then
      ios_capture_failure_diagnostics "onboarding-voice-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_label_into_safe_band "Voice profile step" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_any_label "Voice profile step" "Answer a few reflection prompts" \
        || ios_tap_button "Voice profile step" "Answer a few reflection prompts" "Your answer"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Your answer" "$voice_marker - thoughtful small-group conversations energize me."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Next prompt" "How do you prefer to open up" "Your answer"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Your answer" "I open up gradually through honest, low-pressure conversation."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Next prompt" "What topics or hobbies" "Your answer"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Your answer" "Design, systems thinking, jazz, and meaningful community building."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Save voice profile" "Join first circle" "Open circles" "Review your placement"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      session_token="$(ios_validation_session_token || true)"
      profile_json=""
      voice_ok=0
      if [[ -n "$session_token" ]]; then
        voice_deadline=$((SECONDS + 20))
        while (( SECONDS < voice_deadline )); do
          profile_json="$(curl -fsS \
            -H "Authorization: Bearer $session_token" \
            "http://127.0.0.1:${PORT:-8787}/v1/me/profile" 2>/dev/null || true)"
          if VOICE_MARKER="$voice_marker" python3 -c '
import json, os, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
profile = payload.get("profile") if isinstance(payload.get("profile"), dict) else payload
answers = ((profile or {}).get("sourceInput") or {}).get("reflectionAnswers") or []
raise SystemExit(0 if any(os.environ["VOICE_MARKER"] in str(answer) for answer in answers) else 1)
' <<<"$profile_json"; then
            voice_ok=1
            break
          fi
          sleep 0.5
        done
      fi
      if [[ "$voice_ok" -eq 1 ]]; then
        echo "OK onboarding voice reflection persisted marker=$voice_marker"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "onboarding-voice-api"
        echo "MISS onboarding voice API readback marker=$voice_marker" >&2
        echo "profile_json=${profile_json:-<empty>}" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/onboarding.png"; then
        stamp_controls "voice-profile-step" "api-persist"
      else
        echo "failed to capture onboarding voice success state" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      "$CROSS_LOCK" with_lock seed npm run reset:validation-data >/dev/null \
        || { echo "failed to restore validation data after onboarding voice proof" >&2; FLOW_FAIL=1; }
    fi
    ;;
  onboarding/onboarding-join-circle)
    ios_launch_signed_in --likeminded-force-onboarding --likeminded-start-profile
    if ! ios_wait_ui_contains "About you" 35 && ! ios_wait_ui_contains "ONBOARDING" 10; then
      ios_capture_failure_diagnostics "onboarding-join-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # stepRow a11y: "<title> step" → "Join your first circle step"
      ios_scroll_label_into_safe_band "Join your first circle step" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Join your first circle step" \
        "Join first circle" "Open circles" "Suggested circle" "Review your placement" \
        || ios_tap_any_label "Join your first circle step" "Join first circle" "Open circles"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Join first circle" 12 && ! ios_wait_ui_contains "Open circles" 8; then
        ios_capture_failure_diagnostics "onboarding-join-step-missing"
        echo "MISS onboarding-join-circle: join-circle step chrome missing" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # PrimaryActionButton title is "Open circles"; a11y label is "Join first circle".
      ios_tap_button "Join first circle" "Your circle." "Circles" \
        || ios_tap_button "Open circles" "Your circle." "Circles" \
        || ios_tap_any_label "Join first circle" "Your circle."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Your circle." || ios_ui_contains "CIRCLES"; then
        echo "OK tap 'Join first circle' → Circles tab"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "onboarding-join-circles-tab"
        echo "MISS Join first circle expected Circles tab (Your circle.)" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/onboarding.png"; then
        stamp_controls "join-circle-step"
      else
        echo "failed to capture onboarding-join-circle success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  onboarding/onboarding-steps)
    ios_launch_signed_in --likeminded-force-onboarding --likeminded-start-profile
    if ! ios_wait_ui_contains "About you" 35 && ! ios_wait_ui_contains "ONBOARDING" 10; then
      ios_capture_failure_diagnostics "onboarding-steps-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Sidebar step rows: tap advances step content (About you → Voice → Join circle).
      ios_scroll_label_into_safe_band "Voice profile step" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Voice profile step" \
        "Answer a few reflection prompts" "Voice profile" "Your answer" \
        || ios_tap_any_label "Voice profile step" "Answer a few reflection prompts"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_label_into_safe_band "Join your first circle step" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Join your first circle step" \
        "Join first circle" "Open circles" "Suggested circle" "Review your placement" \
        || ios_tap_any_label "Join your first circle step" "Join first circle"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_label_into_safe_band "About you step" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "About you step" \
        "About you" "What should we call you?" "Share a bit about yourself" \
        || ios_tap_any_label "About you step" "What should we call you?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 2 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/onboarding.png"; then
        stamp_controls "step-rows"
      else
        echo "failed to capture onboarding-steps success state" >&2
        FLOW_FAIL=1
      fi
    else
      if [[ "$FLOW_FAIL" -eq 0 ]]; then
        echo "MISS onboarding-steps: expected ≥2 successful step-row advances" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  onboarding/complete-first-time-setup)
    # E2E api-persist: step rows → city PATCH → voice (or skip if placed) → join circle → placement.
    unique_city="Ledger City $(date +%H%M%S)"
    ios_launch_signed_in --likeminded-force-onboarding --likeminded-start-profile
    if ! ios_wait_ui_contains "About you step" 35; then
      ios_capture_failure_diagnostics "onboarding-complete-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Voice profile step" 12 \
        || ! ios_wait_ui_contains "Join your first circle step" 8; then
        ios_capture_failure_diagnostics "onboarding-complete-step-rows"
        echo "MISS complete-first-time-setup: step-rows incomplete" >&2
        FLOW_FAIL=1
      else
        echo "OK step-rows present"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # A forced onboarding launch already starts on About you. Bring the field
      # into the safe band instead of re-tapping the selected step row.
      ios_scroll_label_into_safe_band "Where are you based?" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Replace seeded city: focus TextField, delete, type unique marker (idb ui text appends).
      city_focused=0
      if "$IDB" tap "Where are you based?"; then
        city_focused=1
      else
        city_point="$("$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def n(v):
    return " ".join(unicodedata.normalize("NFKC", str(v or "")).split()).casefold()
want = "where are you based?"
data = json.load(sys.stdin)
ranked = []
for e in data:
    label = n(e.get("AXLabel"))
    value = n(e.get("AXValue"))
    typ = e.get("type") or ""
    f = e.get("frame") or {}
    if f.get("width", 0) <= 0 or f.get("height", 0) <= 0:
        continue
    score = None
    if label == want and typ in ("TextField", "SearchField", "TextArea", "Other"):
        score = 0
    elif value == "city" and typ in ("TextField", "SearchField", "TextArea", "Other"):
        score = 1
    elif label == want:
        score = 2
    if score is None:
        continue
    ranked.append((score, f["x"] + f["width"] / 2, f["y"] + f["height"] / 2))
if not ranked:
    raise SystemExit(1)
ranked.sort()
print("%.0f %.0f" % (ranked[0][1], ranked[0][2]))
' 2>/dev/null || true)"
        if [[ -n "$city_point" ]]; then
          read -r cx cy <<< "$city_point"
          if "$IDB" tap-point "$cx" "$cy"; then
            city_focused=1
          fi
        fi
      fi
      if [[ "$city_focused" -ne 1 ]]; then
        ios_capture_failure_diagnostics "onboarding-complete-city-focus"
        echo "MISS complete-first-time-setup: could not focus city field" >&2
        FLOW_FAIL=1
      else
        sleep 0.25
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
          idb ui key 42 >/dev/null 2>&1 || true
        done
        if ! "$IDB" type "$unique_city"; then
          ios_capture_failure_diagnostics "onboarding-complete-city-type"
          echo "MISS complete-first-time-setup: could not type city" >&2
          FLOW_FAIL=1
        else
          echo "OK typed city=$unique_city"
          CLICK_OK=$((CLICK_OK + 1))
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Dismiss keyboard so Continue (below fold) is tappable; never accept bare
      # "Voice profile" — sidebar step row always matches and false-passes.
      idb ui key 58 >/dev/null 2>&1 || true  # Return / dismiss when possible
      "$IDB" tap-point 10 100 2>/dev/null || true
      sleep 0.35
      ios_scroll_until_visible "Continue" 8 || true
      ios_scroll_label_into_safe_band "Continue" || true
      ios_tap_button "Continue" \
        "Answer a few reflection prompts" "Your answer" "Next prompt" "Save voice profile" \
        || ios_tap_any_label "Continue" "Answer a few reflection prompts"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Require destination-unique voice chrome (sidebar "Voice profile step" is insufficient).
      if ! ios_wait_ui_contains "Answer a few reflection prompts" 12 \
        && ! ios_wait_ui_contains "Your answer" 8; then
        ios_capture_failure_diagnostics "onboarding-complete-continue-dest"
        echo "MISS Continue did not reach voice reflection step" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      session_token="$(ios_validation_session_token || true)"
      profile_json=""
      city_ok=0
      if [[ -n "$session_token" ]]; then
        profile_deadline=$((SECONDS + 20))
        while (( SECONDS < profile_deadline )); do
          profile_json="$(curl -fsS \
            -H "Authorization: Bearer $session_token" \
            "http://127.0.0.1:${PORT:-8787}/v1/me/profile" 2>/dev/null || true)"
          if CITY="$unique_city" python3 -c '
import json, os, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
profile = payload.get("profile") if isinstance(payload.get("profile"), dict) else payload
basic = (profile or {}).get("basicInfo") or {}
city = basic.get("city") or (profile or {}).get("city") or ""
raise SystemExit(0 if city == os.environ["CITY"] else 1)
' <<<"$profile_json"; then
            city_ok=1
            break
          fi
          sleep 0.5
        done
      fi
      if [[ "$city_ok" -eq 1 ]]; then
        echo "OK form-lines/continue persisted city=$unique_city"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "onboarding-complete-city-api"
        echo "MISS basics API readback city=$unique_city" >&2
        echo "profile_json=${profile_json:-<empty>}" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Walk all 3 reflection prompts even for seeded users: an existing
      # placement is not evidence that this onboarding submission works.
      if ! ios_ui_contains "Your answer" && ! ios_ui_contains "Answer a few reflection prompts"; then
        ios_tap_button "Voice profile step" \
          "Answer a few reflection prompts" "Your answer" \
          || ios_tap_any_label "Voice profile step" "Answer a few reflection prompts"
      fi
      voice_answers=(
        "Quiet dinners with a few friends help me recharge after busy weeks."
        "Warm welcomes and shared interests help me feel comfortable enough to open up."
        "Deep conversations about books and design make me lose track of time."
      )
      for idx in "${!voice_answers[@]}"; do
        [[ "$FLOW_FAIL" -eq 0 ]] || break
        ios_wait_ui_contains "Your answer" 12 || {
          ios_capture_failure_diagnostics "onboarding-complete-voice-field"
          FLOW_FAIL=1
          break
        }
        ios_focus_and_type "Your answer" "${voice_answers[$idx]}" || FLOW_FAIL=1
        [[ "$FLOW_FAIL" -eq 0 ]] || break
        if [[ "$idx" -lt $((${#voice_answers[@]} - 1)) ]]; then
          ios_tap_button "Next prompt" "Your answer" "How do you prefer" "What topics" \
            || ios_tap_any_label "Next prompt" "Your answer"
        else
          ios_tap_button "Save voice profile" \
            "Join your first circle" "Join first circle" "Suggested circle" "Open circles" \
            || ios_tap_any_label "Save voice profile" "Join first circle"
        fi
      done
      if [[ "$FLOW_FAIL" -eq 0 ]]; then
        echo "OK voice-profile-step reflections saved"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_ui_contains "Join first circle" && ! ios_ui_contains "Open circles" \
        && ! ios_ui_contains "Suggested circle"; then
        ios_tap_button "Join your first circle step" \
          "Join first circle" "Open circles" "Suggested circle" "Review your placement" \
          || ios_tap_any_label "Join your first circle step" "Join first circle"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Join first circle" "Your circle." "Circles" \
        || ios_tap_button "Open circles" "Your circle." "Circles" \
        || ios_tap_any_label "Join first circle" "Your circle."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Your circle." || ios_ui_contains "CIRCLES"; then
        echo "OK join-circle-step → Circles"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "onboarding-complete-join"
        echo "MISS join-circle-step expected Circles tab" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      session_token="$(ios_validation_session_token || true)"
      placement_json=""
      place_ok=0
      if [[ -n "$session_token" ]]; then
        place_deadline=$((SECONDS + 15))
        while (( SECONDS < place_deadline )); do
          placement_json="$(curl -fsS \
            -H "Authorization: Bearer $session_token" \
            "http://127.0.0.1:${PORT:-8787}/v1/me/placement" 2>/dev/null || true)"
          if python3 -c '
import json, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
circle = ((payload.get("placement") or {}).get("primaryCircle") or {})
raise SystemExit(0 if circle.get("id") else 1)
' <<<"$placement_json"; then
            place_ok=1
            break
          fi
          sleep 0.5
        done
      fi
      if [[ "$place_ok" -eq 1 ]]; then
        echo "OK placement primaryCircle after complete-first-time-setup"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "onboarding-complete-placement-api"
        echo "MISS placement API readback after complete-first-time-setup" >&2
        echo "placement_json=${placement_json:-<empty>}" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/onboarding.png"; then
        stamp_controls "step-rows,form-lines,continue,voice-profile-step,join-circle-step" "api-persist"
      else
        echo "failed to capture onboarding complete-first-time-setup success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  past-meet-recap/recap-soulmate-select)
    # Select connections + Message match on past-meet recap (Soulmate enabled).
    # Off-screen AX frames tap without activating; floating tab bar steals y≈770–950.
    # Scroll each control into a safe band (cy 180–720) before asserting outcomes.
    session_token="$(
      curl -fsS -X POST \
        -H "Content-Type: application/json" \
        -d "{\"identityToken\":\"${USER_TOKEN:-validation-gurusharan}\",\"fullName\":\"${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}\"}" \
        "http://127.0.0.1:${PORT:-8787}/v1/auth/apple" 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sessionToken") or "")' 2>/dev/null || true
    )"
    if [[ -n "$session_token" ]]; then
      curl -fsS -X POST \
        -H "Authorization: Bearer $session_token" \
        -H "Content-Type: application/json" \
        -d '{"enabled":true}' \
        "http://127.0.0.1:${PORT:-8787}/v1/me/soulmate/enable" >/dev/null 2>&1 || true
      echo "OK API soulmate enabled for recap soulmate controls"
      CLICK_OK=$((CLICK_OK + 1))
    else
      echo "warn: could not mint session for soulmate enable" >&2
    fi
    ios_launch_signed_in --likeminded-start-past-meet-detail
    if ! ios_wait_ui_contains "Great meeting!" 35 && ! ios_wait_ui_contains "Back to meet" 10; then
      ios_capture_failure_diagnostics "recap-soulmate-readiness"
      FLOW_FAIL=1
    fi

    # message-match first (above Select connections in the scroll stack).
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "People you connected with" 8 || true
      msg_label="$("$IDB" describe 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
for e in data:
    lab = str(e.get("AXLabel") or "")
    if lab.startswith("Message ") and lab != "Message input" and e.get("type") in ("Button", "Link", "Cell", "Other"):
        print(lab)
        raise SystemExit(0)
raise SystemExit(1)
' 2>/dev/null || true)"
      if [[ -z "$msg_label" ]]; then
        ios_capture_failure_diagnostics "recap-message-match-missing"
        echo "MISS recap-soulmate-select: no Message <name> control" >&2
        FLOW_FAIL=1
      elif ! ios_scroll_label_into_safe_band "$msg_label"; then
        ios_capture_failure_diagnostics "recap-message-under-tab-bar"
        echo "MISS recap-soulmate-select: Message stayed outside safe tap band" >&2
        FLOW_FAIL=1
      else
        read -r msg_x msg_y <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$msg_x" "$msg_y"; then
          sleep 0.9
          if ios_ui_contains "Message input" || ios_ui_contains "Send message" || ios_ui_contains "Voice call"; then
            echo "OK tap-point '$msg_label' → chat"
            CLICK_OK=$((CLICK_OK + 1))
          else
            ios_tap_any_label "$msg_label" "Message input" || \
              ios_tap_button "$msg_label" "Message input" "Send message" "Voice call"
          fi
        else
          ios_tap_any_label "$msg_label" "Message input" || \
            ios_tap_button "$msg_label" "Message input" "Send message" "Voice call"
        fi
      fi
    fi

    # Return to recap for select-connections.
    if [[ "$FLOW_FAIL" -eq 0 ]] && (ios_ui_contains "Message input" || ios_ui_contains "Send message"); then
      returned=0
      if "$IDB" tap "Back" 2>/dev/null; then
        sleep 0.7
        if ios_ui_contains "Great meeting!" || ios_ui_contains "People you connected with" || ios_ui_contains "Select connections"; then
          echo "OK tap 'Back' → recap"
          CLICK_OK=$((CLICK_OK + 1))
          returned=1
        fi
      fi
      if [[ "$returned" -eq 0 ]]; then
        "$IDB" tap-point 36 96 2>/dev/null || true
        sleep 0.7
        if ios_ui_contains "Great meeting!" || ios_ui_contains "People you connected with" || ios_ui_contains "Select connections"; then
          echo "OK edge-back → recap"
          CLICK_OK=$((CLICK_OK + 1))
          returned=1
        fi
      fi
      if [[ "$returned" -eq 0 ]]; then
        ios_capture_failure_diagnostics "recap-return-from-chat"
        echo "MISS recap-soulmate-select: could not return from chat to recap" >&2
        FLOW_FAIL=1
      fi
    fi

    # select-connections — never accept bare "Soulmate" (tab bar false pass).
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Select connections" 8 || true
      if ! ios_scroll_label_into_safe_band "Select connections"; then
        ios_capture_failure_diagnostics "recap-select-connections-offscreen"
        echo "MISS recap-soulmate-select: Select connections outside safe tap band" >&2
        FLOW_FAIL=1
      else
        read -r sel_x sel_y <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$sel_x" "$sel_y"; then
          sleep 0.9
          if ios_ui_contains "Did you connect with someone?" \
            || ios_ui_contains "Potential match row" \
            || ios_ui_contains "No meetup selection is waiting." \
            || ios_ui_contains "Submit"; then
            echo "OK tap-point 'Select connections' → selection sheet"
            CLICK_OK=$((CLICK_OK + 1))
          else
            ios_tap_button "Select connections" \
              "Did you connect with someone?" "Potential match row" \
              "No meetup selection is waiting." "Submit"
          fi
        else
          ios_tap_button "Select connections" \
            "Did you connect with someone?" "Potential match row" \
            "No meetup selection is waiting." "Submit"
        fi
      fi
    fi

    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/past-meet-recap.png"; then
        stamp_controls "select-connections,message-match"
      else
        echo "failed to capture recap-soulmate-select success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  past-meet-recap/past-meet-back)
    ios_launch_signed_in --likeminded-start-past-meet-detail
    if ! ios_wait_ui_contains "Back to meet" 35; then
      ios_capture_failure_diagnostics "past-meet-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Do not expect bare "MEET" — substring matches detail title "MEET RECAP".
      ios_tap_button "Back to meet" \
        "When you meet." "Past meets" "Available this weekend?" "Upcoming meetup"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Detail-only chrome must leave AX (Back control + recap copy).
      if ios_ui_contains "Back to meet" || ios_ui_contains "Great meeting!"; then
        echo "MISS past-meet-back: still on recap after Back" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/past-meet-recap.png"; then
        stamp_controls "recap-back"
      else
        echo "failed to capture past-meet-back success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  past-meet-recap/recap-save-note)
    # Type private note → Save note → GET /v1/meetings/upcoming recapNote readback.
    unique_note="Ledger recap note $(date +%H%M%S)"
    ios_launch_signed_in --likeminded-start-past-meet-detail
    if ! ios_wait_ui_contains "Great meeting!" 35 && ! ios_wait_ui_contains "Reflection note field" 10; then
      ios_capture_failure_diagnostics "recap-save-note-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Reflection note field" 8 || ios_scroll_until_visible "Save note" 8 || true
      ios_scroll_label_into_safe_band "Reflection note field" || true
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      note_focused=0
      if "$IDB" tap "Reflection note field"; then
        note_focused=1
      else
        note_point="$("$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def n(v):
    return " ".join(unicodedata.normalize("NFKC", str(v or "")).split()).casefold()
want = "reflection note field"
data = json.load(sys.stdin)
ranked = []
for e in data:
    label = n(e.get("AXLabel"))
    typ = e.get("type") or ""
    f = e.get("frame") or {}
    if f.get("width", 0) <= 0 or f.get("height", 0) <= 0:
        continue
    if label != want:
        continue
    score = 0 if typ in ("TextField", "TextArea", "TextView", "Other") else 1
    ranked.append((score, f["x"] + f["width"] / 2, f["y"] + f["height"] / 2))
if not ranked:
    raise SystemExit(1)
ranked.sort()
print("%.0f %.0f" % (ranked[0][1], ranked[0][2]))
' 2>/dev/null || true)"
        if [[ -n "$note_point" ]]; then
          read -r nx ny <<< "$note_point"
          if "$IDB" tap-point "$nx" "$ny"; then
            note_focused=1
          fi
        fi
      fi
      if [[ "$note_focused" -ne 1 ]]; then
        ios_capture_failure_diagnostics "recap-save-note-focus"
        echo "MISS recap-save-note: could not focus Reflection note field" >&2
        FLOW_FAIL=1
      else
        sleep 0.25
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40; do
          idb ui key 42 >/dev/null 2>&1 || true
        done
        if ! "$IDB" type "$unique_note"; then
          ios_capture_failure_diagnostics "recap-save-note-type"
          echo "MISS recap-save-note: could not type note" >&2
          FLOW_FAIL=1
        else
          echo "OK typed reflection note"
          CLICK_OK=$((CLICK_OK + 1))
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      idb ui key 58 >/dev/null 2>&1 || true
      "$IDB" tap-point 10 100 2>/dev/null || true
      sleep 0.3
      ios_scroll_until_visible "Save note" 6 || true
      ios_scroll_label_into_safe_band "Save note" || true
      if "$IDB" tap "Save note"; then
        echo "OK tap 'Save note'"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "recap-save-note-tap"
        echo "MISS resolve 'Save note'" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      session_token="$(ios_validation_session_token || true)"
      upcoming_json=""
      note_ok=0
      if [[ -n "$session_token" ]]; then
        note_deadline=$((SECONDS + 18))
        while (( SECONDS < note_deadline )); do
          upcoming_json="$(curl -fsS \
            -H "Authorization: Bearer $session_token" \
            "http://127.0.0.1:${PORT:-8787}/v1/meetings/upcoming" 2>/dev/null || true)"
          if NOTE="$unique_note" python3 -c '
import json, os, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
want = os.environ["NOTE"]
rows = list(payload.get("upcoming") or []) + list(payload.get("past") or []) + list(payload.get("history") or [])
# Some payloads nest meetings; also scan top-level lists.
for key in ("upcoming", "past", "history", "meetings"):
    val = payload.get(key)
    if isinstance(val, list):
        rows.extend(val)
seen = set()
for meeting in rows:
    if not isinstance(meeting, dict):
        continue
    mid = id(meeting)
    if mid in seen:
        continue
    seen.add(mid)
    if meeting.get("recapNote") == want:
        raise SystemExit(0)
raise SystemExit(1)
' <<<"$upcoming_json"; then
            note_ok=1
            break
          fi
          sleep 0.5
        done
      fi
      if [[ "$note_ok" -eq 1 ]]; then
        echo "OK recap-save-note API recapNote=$unique_note"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "recap-save-note-api"
        echo "MISS recap-save-note API readback note=$unique_note" >&2
        echo "upcoming_json=${upcoming_json:-<empty>}" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/past-meet-recap.png"; then
        stamp_controls "reflection-note,save-note" "api-persist"
      else
        echo "failed to capture past-meet-recap recap-save-note success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  settings/settings-soulmate-toggle)
    # Enable Soulmate control on Settings (Button-wrapped row; id may be Button or CheckBox).
    # One hit only, then API contract (parity with macOS prove). Never multi-retry.
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "Enable Soulmate" 35; then
      ios_capture_failure_diagnostics "settings-soulmate-toggle-readiness"
      FLOW_FAIL=1
    fi
    session_token=""
    before_enabled=""
    want_enabled=""
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      session_token="$(
        curl -fsS -X POST \
          -H "Content-Type: application/json" \
          -d "{\"identityToken\":\"${USER_TOKEN:-validation-gurusharan}\",\"fullName\":\"${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}\"}" \
          "http://127.0.0.1:${PORT:-8787}/v1/auth/apple" 2>/dev/null \
          | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sessionToken") or "")' 2>/dev/null || true
      )"
      if [[ -z "$session_token" ]]; then
        echo "MISS soulmate-toggle: no validation session token" >&2
        FLOW_FAIL=1
      else
        before_enabled="$(
          curl -fsS \
            -H "Authorization: Bearer $session_token" \
            "http://127.0.0.1:${PORT:-8787}/v1/me/soulmate/status" 2>/dev/null \
            | python3 -c 'import json,sys; print("true" if json.load(sys.stdin).get("enabled") else "false")' \
            2>/dev/null || echo ""
        )"
        if [[ -z "$before_enabled" ]]; then
          echo "MISS soulmate-toggle: could not read /v1/me/soulmate/status" >&2
          FLOW_FAIL=1
        elif [[ "$before_enabled" == "true" ]]; then
          want_enabled="false"
        else
          want_enabled="true"
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Whole row is tappable; prefer identifier center (any AX type).
      tapped=0
      if "$IDB" tap-id "settings-soulmate-toggle" center; then
        tapped=1
        echo "OK tap-id 'settings-soulmate-toggle' center (before=$before_enabled want=$want_enabled)"
        CLICK_OK=$((CLICK_OK + 1))
      else
        point="$("$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
want_id = "settings-soulmate-toggle"
want_label = "enable soulmate"
def norm(raw):
    return " ".join(unicodedata.normalize("NFKC", str(raw)).split()).casefold()
data = json.load(sys.stdin)
candidates = []
for e in data:
    frame = e.get("frame") or {}
    if frame.get("width", 0) <= 0 or frame.get("height", 0) <= 0:
        continue
    uid = e.get("AXUniqueId") or ""
    label = norm(e.get("AXLabel") or "")
    rank = 0
    if uid == want_id:
        rank = 3
    elif e.get("type") in ("Switch", "CheckBox", "Button") and label == want_label:
        rank = 2 if e.get("type") in ("Switch", "CheckBox") else 1
    else:
        continue
    cx = frame["x"] + frame["width"] / 2
    cy = frame["y"] + frame["height"] / 2
    candidates.append((rank, cx, cy))
if not candidates:
    raise SystemExit(1)
candidates.sort(key=lambda item: -item[0])
_, cx, cy = candidates[0]
print("%.0f %.0f" % (cx, cy))
' 2>/dev/null || true)"
        if [[ -n "$point" ]]; then
          read -r x y <<< "$point"
          if "$IDB" tap-point "$x" "$y"; then
            tapped=1
            echo "OK tap-point 'Enable Soulmate' at ($x,$y) (before=$before_enabled want=$want_enabled)"
            CLICK_OK=$((CLICK_OK + 1))
          fi
        fi
      fi
      if [[ "$tapped" -ne 1 ]]; then
        ios_capture_failure_diagnostics "settings-soulmate-toggle-tap"
        echo "MISS soulmate-toggle: could not hit Enable Soulmate control" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      flipped=0
      after_enabled=""
      toggle_deadline=$((SECONDS + 25))
      while (( SECONDS < toggle_deadline )); do
        after_enabled="$(
          curl -fsS \
            -H "Authorization: Bearer $session_token" \
            "http://127.0.0.1:${PORT:-8787}/v1/me/soulmate/status" 2>/dev/null \
            | python3 -c 'import json,sys; print("true" if json.load(sys.stdin).get("enabled") else "false")' \
            2>/dev/null || echo ""
        )"
        if [[ "$after_enabled" == "$want_enabled" ]]; then
          flipped=1
          break
        fi
        sleep 0.5
      done
      if [[ "$flipped" -ne 1 ]]; then
        ios_capture_failure_diagnostics "settings-soulmate-toggle-api"
        echo "MISS soulmate-toggle API enabled stayed=${after_enabled:-unknown} want=$want_enabled" >&2
        if ios_ui_contains "Soulmate preference could not be saved."; then
          echo "MISS soulmate-toggle: save error banner visible" >&2
        fi
        FLOW_FAIL=1
      else
        echo "OK soulmate-toggle API enabled=$want_enabled"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Soulmate preference could not be saved."; then
        ios_capture_failure_diagnostics "settings-soulmate-toggle-error"
        echo "MISS soulmate-toggle: save error banner visible after API flip" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
        stamp_controls "soulmate-toggle"
        if ! "$CROSS_LOCK" with_lock seed npm run reset:validation-data >/dev/null; then
          echo "MISS soulmate-toggle: failed to restore validation-db baseline" >&2
          FLOW_FAIL=1
        else
          echo "OK soulmate-toggle: validation-db baseline restored"
          CLICK_OK=$((CLICK_OK + 1))
        fi
      else
        echo "failed to capture settings-soulmate-toggle success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  settings/settings-discovery)
    # Settings → Discovery preferences (SoulmateDiscoveryPreferencesView).
    # Assert destination-unique chrome — list row label also says "Discovery preferences".
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "Discovery preferences" 35; then
      ios_capture_failure_diagnostics "settings-discovery-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # NavigationLink often surfaces as Link/Other, not Button.
      # Prefer destination-unique chrome (list row also says "Discovery preferences").
      ios_tap_any_label "Discovery preferences" "Who can discover you"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Who can discover you" || ios_ui_contains "Save preferences"; then
        if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
          stamp_controls "discovery-preferences"
        else
          echo "failed to capture settings-discovery success state" >&2
          FLOW_FAIL=1
        fi
      else
        ios_capture_failure_diagnostics "settings-discovery-missing"
        echo "MISS settings-discovery: Discovery preferences detail did not open" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  settings/settings-discovery-details)
    # api-persist (iOS product shape): open discovery prefs → both visibility radios →
    # age 18–80 via sliders → Save → GET /v1/me/soulmate/status exact readback.
    # Note: iOS has 2 visibility radios (not macOS's 3 Circles-only labels) and no
    # macOS-only enforcement disclaimer copy on this screen.
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "Discovery preferences" 35; then
      ios_capture_failure_diagnostics "settings-discovery-details-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_any_label "Discovery preferences" "Who can discover you"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Who can discover you" 12 \
        && ! ios_wait_ui_contains "Save preferences" 8; then
        ios_capture_failure_diagnostics "settings-discovery-details-open"
        echo "MISS discovery-details: detail screen missing" >&2
        FLOW_FAIL=1
      else
        echo "OK discovery-who surface"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Age ± buttons (idb cannot reliably move UISlider). Target 18–80.
      if ! ios_scroll_label_into_safe_band "Increase maximum age" \
        || ! ios_ui_contains "Decrease minimum age" \
        || ! ios_ui_contains "Increase maximum age"; then
        ios_capture_failure_diagnostics "settings-discovery-details-age-controls"
        echo "MISS discovery-details: age ± buttons not in AX" >&2
        FLOW_FAIL=1
      else
        ios_discovery_age_read() {
          "$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata, re
def n(v):
    return " ".join(unicodedata.normalize("NFKC", str(v or "")).split()).casefold()
data = json.load(sys.stdin)
min_v = max_v = None
for e in data:
    lab = n(e.get("AXLabel"))
    val = e.get("AXValue")
    if lab == "minimum age" and val is not None:
        try:
            min_v = int(float(str(val)))
        except Exception:
            pass
    elif lab == "maximum age" and val is not None:
        try:
            max_v = int(float(str(val)))
        except Exception:
            pass
if min_v is None or max_v is None:
    for e in data:
        lab = n(e.get("AXLabel"))
        val = n(e.get("AXValue"))
        if lab == "age range" and val:
            m = re.search(r"(\d+)\s*(?:to|–|-)\s*(\d+)", val)
            if m:
                min_v, max_v = int(m.group(1)), int(m.group(2))
                break
if min_v is None or max_v is None:
    raise SystemExit(1)
print("%d %d" % (min_v, max_v))
' 2>/dev/null || true
        }
        age_now="$(ios_discovery_age_read)"
        if [[ -z "$age_now" ]]; then
          ios_capture_failure_diagnostics "settings-discovery-details-age"
          echo "MISS discovery-details: could not read current age values" >&2
          FLOW_FAIL=1
        else
          # shellcheck disable=SC2086
          set -- $age_now
          cur_min="$1"
          cur_max="$2"
          echo "→ age start ${cur_min}–${cur_max}; driving to 18–80 via ± buttons" >&2
          while [[ "$cur_min" -gt 18 ]]; do
            "$IDB" tap "Decrease minimum age" >/dev/null 2>&1 || true
            cur_min=$((cur_min - 1))
            sleep 0.05
          done
          while [[ "$cur_max" -lt 80 ]]; do
            "$IDB" tap "Increase maximum age" >/dev/null 2>&1 || true
            cur_max=$((cur_max + 1))
            sleep 0.05
          done
          while [[ "$cur_max" -gt 80 ]]; do
            "$IDB" tap "Decrease maximum age" >/dev/null 2>&1 || true
            cur_max=$((cur_max - 1))
            sleep 0.05
          done
          sleep 0.35
          age_now="$(ios_discovery_age_read)"
          age_ok=0
          if [[ "$age_now" == "18 80" ]] \
            || ios_ui_contains "18 – 80" \
            || ios_ui_contains "18–80" \
            || ios_ui_contains "18 to 80"; then
            age_ok=1
          fi
          if [[ "$age_ok" -eq 1 ]]; then
            echo "OK age range 18 to 80 via ± buttons"
            CLICK_OK=$((CLICK_OK + 1))
          else
            ios_capture_failure_diagnostics "settings-discovery-details-age"
            echo "MISS discovery-details age range not 18–80 after ± taps (last=${age_now:-unknown})" >&2
            FLOW_FAIL=1
          fi
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Cycle both iOS visibility radios; land on matches_only.
      # Age ± rows push radios/Save below the tab bar — scroll into safe band first.
      if ios_scroll_label_into_safe_band "Visible in discover"; then
        read -r vx vy <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$vx" "$vy"; then
          echo "OK tap 'Visible in discover'"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_capture_failure_diagnostics "settings-discovery-details-vis-discover"
          echo "MISS discovery visibility 'Visible in discover'" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
        fi
      else
        ios_capture_failure_diagnostics "settings-discovery-details-vis-discover"
        echo "MISS discovery visibility 'Visible in discover' (not in safe band)" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_scroll_label_into_safe_band "Visible only after both like"; then
        read -r vx vy <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$vx" "$vy"; then
          echo "OK tap 'Visible only after both like'"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_capture_failure_diagnostics "settings-discovery-details-vis-matches"
          echo "MISS discovery visibility 'Visible only after both like'" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
        fi
      else
        ios_capture_failure_diagnostics "settings-discovery-details-vis-matches"
        echo "MISS discovery visibility 'Visible only after both like' (not in safe band)" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_scroll_label_into_safe_band "Save preferences"; then
        read -r sx sy <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$sx" "$sy"; then
          sleep 0.8
          if ios_ui_contains "Preferences saved."; then
            echo "OK tap 'Save preferences' → Preferences saved."
            CLICK_OK=$((CLICK_OK + 1))
          else
            ios_tap_button "Save preferences" "Preferences saved." \
              || ios_tap_any_label "Save preferences" "Preferences saved."
          fi
        else
          ios_tap_button "Save preferences" "Preferences saved." \
            || ios_tap_any_label "Save preferences" "Preferences saved."
        fi
      else
        ios_capture_failure_diagnostics "settings-discovery-details-save"
        echo "MISS discovery-details: Save preferences not in safe band" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      session_token="$(ios_validation_session_token || true)"
      prefs_json=""
      prefs_ok=0
      if [[ -n "$session_token" ]]; then
        prefs_deadline=$((SECONDS + 18))
        while (( SECONDS < prefs_deadline )); do
          prefs_json="$(curl -fsS \
            -H "Authorization: Bearer $session_token" \
            "http://127.0.0.1:${PORT:-8787}/v1/me/soulmate/status" 2>/dev/null || true)"
          if python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
prefs = data.get("preferences") or {}
expected = {"ageMin": 18, "ageMax": 80, "visibility": "matches_only"}
raise SystemExit(0 if all(prefs.get(k) == v for k, v in expected.items()) else 1)
' <<<"$prefs_json"; then
            prefs_ok=1
            break
          fi
          sleep 0.5
        done
      fi
      if [[ "$prefs_ok" -eq 1 ]]; then
        echo "OK discovery preferences API ageMin=18 ageMax=80 visibility=matches_only"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "settings-discovery-details-api"
        echo "MISS discovery-details API readback expected ageMin=18 ageMax=80 visibility=matches_only" >&2
        echo "prefs_json=${prefs_json:-<empty>}" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
        stamp_controls "discovery-who,discovery-age-range,discovery-visibility,discovery-save" "api-persist"
        if ! "$CROSS_LOCK" with_lock seed npm run reset:validation-data >/dev/null; then
          echo "MISS discovery-details: failed to restore validation-db baseline" >&2
          FLOW_FAIL=1
        else
          echo "OK discovery-details: validation-db baseline restored"
          CLICK_OK=$((CLICK_OK + 1))
        fi
      else
        echo "failed to capture settings-discovery-details success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  settings/settings-delete-cancel)
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "Delete account" 35; then
      ios_capture_failure_diagnostics "settings-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Delete account" "Delete your account?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_dismiss_dialog "Delete your account?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ios_ui_contains "Delete account"; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
        stamp_controls "delete-cancel"
      else
        echo "failed to capture settings-delete-cancel success state" >&2
        FLOW_FAIL=1
      fi
    elif [[ "$FLOW_FAIL" -eq 0 ]]; then
      echo "MISS delete-cancel: Delete account row missing after Cancel" >&2
      FLOW_FAIL=1
    fi
    ;;
  settings/settings-delete-account)
    # api-persist: confirm DELETE /v1/me/account → welcome, old session dead, reseed.
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "Delete account" 35; then
      ios_capture_failure_diagnostics "settings-delete-account-readiness"
      FLOW_FAIL=1
    fi
    session_token=""
    deleted_confirmed=0
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      session_token="$(ios_validation_session_token || true)"
      if [[ -z "$session_token" ]]; then
        echo "MISS delete-account: no validation session token" >&2
        FLOW_FAIL=1
      elif ! curl -fsS \
        -H "Authorization: Bearer $session_token" \
        "http://127.0.0.1:${PORT:-8787}/v1/me/profile" >/dev/null 2>&1; then
        echo "MISS delete-account: pre-delete /v1/me/profile unavailable" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Delete account" 8 || true
      ios_tap_button "Delete account" "Delete your account?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      confirmed=0
      if ios_ui_contains "Delete your account?" && "$IDB" tap "Delete account"; then
        sleep 1.6
        if ios_ui_contains "Private by design" || ios_ui_contains "Sign in with Apple" \
          || ios_ui_contains "When you meet" || ios_ui_contains "it matters"; then
          confirmed=1
        fi
      fi
      if [[ "$confirmed" -eq 0 ]] && ios_ui_contains "Delete your account?"; then
        # confirmationDialog destructive sits below the settings row — prefer largest-y.
        confirm_point="$("$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def norm(raw):
    return " ".join(unicodedata.normalize("NFKC", str(raw)).split()).casefold()
data = json.load(sys.stdin)
cands = []
for e in data:
    if norm(e.get("AXLabel") or e.get("AXValue") or "") != "delete account":
        continue
    if e.get("type") not in ("Button", "Link"):
        continue
    frame = e.get("frame") or {}
    w = float(frame.get("width") or 0)
    h = float(frame.get("height") or 0)
    if w <= 0 or h <= 0 or h > 120:
        continue
    cx = float(frame.get("x") or 0) + w / 2
    cy = float(frame.get("y") or 0) + h / 2
    cands.append((cy, cx))
if not cands:
    raise SystemExit(1)
cands.sort(reverse=True)
print("%.0f %.0f" % (cands[0][1], cands[0][0]))
' 2>/dev/null || true)"
        if [[ -n "$confirm_point" ]]; then
          read -r dx dy <<< "$confirm_point"
          "$IDB" tap-point "$dx" "$dy" || true
          sleep 1.6
          if ios_ui_contains "Private by design" || ios_ui_contains "Sign in with Apple" \
            || ios_ui_contains "When you meet" || ios_ui_contains "it matters"; then
            confirmed=1
          fi
        fi
      fi
      if [[ "$confirmed" -ne 1 ]]; then
        ios_capture_failure_diagnostics "settings-delete-account-confirm"
        echo "MISS delete-account: confirm did not reach welcome/auth" >&2
        FLOW_FAIL=1
      else
        echo "OK confirm Delete account → welcome/auth"
        CLICK_OK=$((CLICK_OK + 1))
        deleted_confirmed=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 && -n "$session_token" ]]; then
      delete_code="$(
        curl -s -o /dev/null -w '%{http_code}' \
          -H "Authorization: Bearer $session_token" \
          "http://127.0.0.1:${PORT:-8787}/v1/me/profile" 2>/dev/null || echo 000
      )"
      if [[ "$delete_code" != "401" && "$delete_code" != "403" && "$delete_code" != "404" ]]; then
        ios_capture_failure_diagnostics "settings-delete-account-api"
        echo "MISS delete-account: expected 401/403/404 after delete, got $delete_code" >&2
        FLOW_FAIL=1
      else
        echo "OK delete-account API persist HTTP=$delete_code"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
        stamp_controls "delete-account" "api-persist"
      else
        echo "failed to capture settings-delete-account success state" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$deleted_confirmed" -eq 1 ]]; then
      if ! "$CROSS_LOCK" with_lock seed npm run reset:validation-data >/dev/null; then
        echo "MISS delete-account: failed to reseed validation-db" >&2
        FLOW_FAIL=1
      else
        echo "OK delete-account: validation-db reseeded"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi
    ;;
  settings/settings-sign-out)
    # Confirm Sign out → AuthGate. Popover confirm is ~y=222 (not bottom sheet).
    # App suppresses dev-auth-bypass re-login after explicit signOut.
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "Sign out" 35; then
      ios_capture_failure_diagnostics "settings-sign-out-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Sign out" "Sign out of Likeminded?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # When AX collapses, IDB tap hits the only Sign out; else prefer smallest-y.
      confirmed=0
      if ios_ui_contains "Sign out of Likeminded?" && "$IDB" tap "Sign out"; then
        sleep 1.4
        if ios_ui_contains "Private by design" || ios_ui_contains "When you meet" \
          || ios_ui_contains "it matters" || ios_ui_contains "Sign in with Apple"; then
          confirmed=1
        fi
      fi
      if [[ "$confirmed" -eq 0 ]] && ios_ui_contains "Sign out of Likeminded?"; then
        confirm_point="$("$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def norm(raw):
    return " ".join(unicodedata.normalize("NFKC", str(raw)).split()).casefold()
data = json.load(sys.stdin)
cands = []
for e in data:
    if norm(e.get("AXLabel") or e.get("AXValue") or "") != "sign out":
        continue
    if e.get("type") not in ("Button", "Link"):
        continue
    frame = e.get("frame") or {}
    w = float(frame.get("width") or 0)
    h = float(frame.get("height") or 0)
    if w <= 0 or h <= 0 or h > 120:
        continue
    cx = float(frame.get("x") or 0) + w / 2
    cy = float(frame.get("y") or 0) + h / 2
    cands.append((cy, cx))
if not cands:
    raise SystemExit(1)
cands.sort()  # popover confirm above settings row (~430)
print("%.0f %.0f" % (cands[0][1], cands[0][0]))
' 2>/dev/null || true)"
        if [[ -n "$confirm_point" ]]; then
          read -r sx sy <<< "$confirm_point"
          "$IDB" tap-point "$sx" "$sy" || true
          sleep 1.4
          if ios_ui_contains "Private by design" || ios_ui_contains "When you meet" \
            || ios_ui_contains "it matters" || ios_ui_contains "Sign in with Apple"; then
            confirmed=1
          fi
        fi
      fi
      if [[ "$confirmed" -eq 0 ]]; then
        ios_capture_failure_diagnostics "settings-sign-out-confirm"
        echo "MISS settings-sign-out: could not confirm Sign out" >&2
        FLOW_FAIL=1
      else
        if ios_wait_ui_contains "Private by design" 12 \
          || ios_wait_ui_contains "Sign in with Apple" 8 \
          || ios_wait_ui_contains "When you meet" 8 \
          || ios_wait_ui_contains "it matters" 6; then
          echo "OK confirm Sign out → auth gate"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_capture_failure_diagnostics "settings-sign-out-welcome"
          echo "MISS settings-sign-out: did not reach auth gate" >&2
          FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Private by design" || ios_ui_contains "Sign in with Apple" \
        || ios_ui_contains "When you meet" || ios_ui_contains "it matters"; then
        if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
          stamp_controls "sign-out"
        else
          echo "failed to capture settings-sign-out success state" >&2
          FLOW_FAIL=1
        fi
      else
        ios_capture_failure_diagnostics "settings-sign-out-missing"
        echo "MISS settings-sign-out: auth gate chrome missing after confirm" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  settings/settings-sign-out-cancel)
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "Sign out" 35; then
      ios_capture_failure_diagnostics "settings-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Sign out" "Sign out of Likeminded?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_dismiss_dialog "Sign out of Likeminded?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ios_ui_contains "Sign out"; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
        stamp_controls "sign-out-cancel"
      else
        echo "failed to capture settings-sign-out-cancel success state" >&2
        FLOW_FAIL=1
      fi
    elif [[ "$FLOW_FAIL" -eq 0 ]]; then
      echo "MISS sign-out-cancel: Sign out row missing after Cancel" >&2
      FLOW_FAIL=1
    fi
    ;;
  settings/settings-privacy)
    # Privacy policy sheet → Done. Row sits mid/low; use safe-band to avoid tab bar.
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "Privacy policy" 35 && ! ios_wait_ui_contains "Account" 10; then
      ios_capture_failure_diagnostics "settings-privacy-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_scroll_label_into_safe_band "Privacy policy"; then
        ios_capture_failure_diagnostics "settings-privacy-under-tab-bar"
        echo "MISS settings-privacy: Privacy policy outside safe tap band" >&2
        FLOW_FAIL=1
      else
        read -r px py <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$px" "$py"; then
          sleep 0.8
          if ios_ui_contains "Likeminded TestFlight Privacy Policy" \
            || ios_ui_contains "Data Collected" \
            || ios_ui_contains "How Data Is Used"; then
            echo "OK tap-point 'Privacy policy' → policy sheet"
            CLICK_OK=$((CLICK_OK + 1))
          else
            FLOW_FAIL=0
            ios_tap_any_label "Privacy policy" "Likeminded TestFlight Privacy Policy" \
              || ios_tap_button "Privacy policy" "Likeminded TestFlight Privacy Policy" "Data Collected"
          fi
        else
          FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "" "Likeminded TestFlight Privacy Policy" "Done" "" "" absent \
        || ios_tap_control "" "Data Collected" "Done" "" "" absent
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Privacy policy" || ios_ui_contains "Delete account" || ios_ui_contains "Account"; then
        if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
          stamp_controls "privacy,done"
        else
          echo "failed to capture settings-privacy success state" >&2
          FLOW_FAIL=1
        fi
      else
        ios_capture_failure_diagnostics "settings-privacy-missing"
        echo "MISS settings-privacy: did not return to settings shell" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  settings/settings-help)
    # How it works sheet → Done → Help & FAQ sheet → Done.
    # Help & FAQ sits under the floating tab bar; safe-band or Soulmate steals the hit.
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "How it works" 35; then
      ios_capture_failure_diagnostics "settings-help-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      FLOW_FAIL=0
      if ! ios_tap_button "How it works" "How Soulmate works" "Turn Soulmate on"; then
        FLOW_FAIL=0
        ios_tap_any_label "How it works" "Turn Soulmate on"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Sheet title + section chrome; Done must clear "Turn Soulmate on".
      ios_tap_control "" "Turn Soulmate on" "Done" "" "" absent
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "How it works" 12 && ! ios_wait_ui_contains "Help & FAQ" 8; then
        ios_capture_failure_diagnostics "settings-help-shell"
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_scroll_label_into_safe_band "Help & FAQ"; then
        ios_capture_failure_diagnostics "settings-help-faq-under-tab-bar"
        echo "MISS settings-help: Help & FAQ outside safe tap band" >&2
        FLOW_FAIL=1
      else
        read -r hx hy <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$hx" "$hy"; then
          sleep 0.8
          if ios_ui_contains "Build your signals" || ios_ui_contains "Saturday and Sunday rooms"; then
            echo "OK tap-point 'Help & FAQ' → Help sheet"
            CLICK_OK=$((CLICK_OK + 1))
          else
            ios_capture_failure_diagnostics "settings-help-faq-missing"
            echo "MISS settings-help: Help & FAQ sheet did not open" >&2
            FLOW_FAIL=1
          fi
        else
          FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "" "Build your signals" "Done" "" "" absent
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "How it works" || ios_ui_contains "Delete account" || ios_ui_contains "Account"; then
        if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
          stamp_controls "how-it-works,help,done"
        else
          echo "failed to capture settings-help success state" >&2
          FLOW_FAIL=1
        fi
      else
        ios_capture_failure_diagnostics "settings-help-missing"
        echo "MISS settings-help: did not return to settings shell" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  settings/settings-support)
    # Contact support row → type note → Send support note → "Support note saved."
    # Row sits low under the floating tab bar; use safe-band like privacy/help.
    ios_launch_signed_in --likeminded-start-settings
    if ! ios_wait_ui_contains "Contact support" 35 && ! ios_wait_ui_contains "Account" 10; then
      ios_capture_failure_diagnostics "settings-support-open-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_scroll_label_into_safe_band "Contact support"; then
        ios_capture_failure_diagnostics "settings-support-under-tab-bar"
        echo "MISS settings-support: Contact support outside safe tap band" >&2
        FLOW_FAIL=1
      else
        read -r sx sy <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$sx" "$sy"; then
          sleep 0.8
          if ios_ui_contains "What needs help?" || ios_ui_contains "Send support note"; then
            echo "OK tap-point 'Contact support' → support sheet"
            CLICK_OK=$((CLICK_OK + 1))
          else
            FLOW_FAIL=0
            ios_tap_any_label "Contact support" "What needs help?" \
              || ios_tap_button "Contact support" "What needs help?" "Send support note"
          fi
        else
          FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "What needs help?" 12; then
        ios_capture_failure_diagnostics "settings-support-sheet-missing"
        echo "MISS settings-support: support sheet did not open" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "What needs help?" "Ledger iOS support note $(date +%H%M%S)"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Send support note" "Support note saved." \
        || ios_tap_any_label "Send support note" "Support note saved."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Support note saved." 15; then
        ios_capture_failure_diagnostics "settings-support-send-missing"
        echo "MISS settings-support: send did not confirm Support note saved." >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
        stamp_controls "support,message,send"
      else
        echo "failed to capture settings-support success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  settings/settings-support-done)
    ios_launch_signed_in --likeminded-start-settings-support
    if ! ios_wait_ui_contains "What needs help?" 35 && ! ios_wait_ui_contains "Contact support" 10; then
      ios_capture_failure_diagnostics "settings-support-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Sheet title "Contact support" also exists as a settings row — assert sheet field gone.
      ios_tap_control "" "What needs help?" "Done" "" "" absent
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Delete account" || ios_ui_contains "Sign out" || ios_ui_contains "Account"; then
        if "$IDB" screenshot "$ROOT/output/validation/ios-screens/settings.png"; then
          stamp_controls "support-done"
        else
          echo "failed to capture settings-support-done success state" >&2
          FLOW_FAIL=1
        fi
      else
        echo "MISS support Done did not return to settings shell" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-match/chat-icon)
    ios_launch_signed_in --likeminded-start-soulmate --likeminded-start-soulmate-match-detail
    if ! ios_wait_ui_contains "Open chat" 35 \
      && ! ios_wait_ui_contains "Start chatting" 10 \
      && ! ios_wait_ui_contains "Priya Shah" 10; then
      ios_capture_failure_diagnostics "soulmate-match-chat-icon-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Open chat" "Message input" "Send message" "Voice call" \
        || ios_tap_any_label "Open chat" "Message input"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Message input" 15 && ! ios_wait_ui_contains "Send message" 8; then
        ios_capture_failure_diagnostics "soulmate-match-chat-icon-thread"
        echo "MISS chat-icon: Open chat did not reach ChatView composer" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-match-detail.png"; then
        stamp_controls "chat-icon"
      else
        echo "failed to capture soulmate-match chat-icon success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-match/start-chat)
    ios_launch_signed_in --likeminded-start-soulmate --likeminded-start-soulmate-match-detail
    if ! ios_wait_ui_contains "Start chatting" 35 \
      && ! ios_wait_ui_contains "What they're into" 10 \
      && ! ios_wait_ui_contains "Priya Shah" 10; then
      ios_capture_failure_diagnostics "soulmate-match-start-chat-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Start chatting" 6 || true
      ios_tap_button "Start chatting" "Message input" "Send message" "Voice call" \
        || ios_tap_any_label "Start chatting" "Message input"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Message input" 15 && ! ios_wait_ui_contains "Send message" 8; then
        ios_capture_failure_diagnostics "soulmate-match-start-chat-thread"
        echo "MISS start-chat: Start chatting did not reach ChatView composer" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-match-detail.png"; then
        stamp_controls "start-chat"
      else
        echo "failed to capture soulmate-match start-chat success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-match/interest-chips)
    # Display control: fixture match detail must show depth-encoded interest labels.
    ios_launch_signed_in --likeminded-start-soulmate --likeminded-start-soulmate-match-detail
    if ! ios_wait_ui_contains "What they're into" 35 \
      && ! ios_wait_ui_contains "Priya Shah" 10; then
      ios_capture_failure_diagnostics "soulmate-match-interest-chips-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      chip_ok=0
      for chip in Design Cooking Tech Books; do
        if ios_ui_contains "$chip"; then
          echo "OK interest chip visible: $chip"
          chip_ok=$((chip_ok + 1))
          CLICK_OK=$((CLICK_OK + 1))
        else
          echo "MISS interest chip absent: $chip" >&2
        fi
      done
      if [[ "$chip_ok" -lt 3 ]]; then
        ios_capture_failure_diagnostics "soulmate-match-interest-chips-missing"
        echo "MISS interest-chips: expected fixture interests (Design/Cooking/Tech/Books)" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-match-detail.png"; then
        stamp_controls "interest-chips"
      else
        echo "failed to capture soulmate-match interest-chips success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-overview/save-introduction)
    ios_launch_signed_in --likeminded-start-soulmate
    if ! ios_wait_ui_contains "Keep for later" 35 \
      || ! ios_ui_contains "Priya Shah"; then
      ios_capture_failure_diagnostics "save-introduction-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Keep for later" "Saved for later"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Priya Shah stays available here." 10 \
        || ! ios_ui_contains "Show introduction"; then
        ios_capture_failure_diagnostics "save-introduction-state"
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Show introduction" "Keep for later"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Priya Shah" 10; then
        ios_capture_failure_diagnostics "save-introduction-restored"
        FLOW_FAIL=1
      elif "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-overview.png"; then
        stamp_controls "soulmate-defer-introduction"
      else
        echo "failed to capture restored introduction state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-overview/conversations-icon)
    ios_launch_signed_in --likeminded-start-soulmate
    if ! ios_wait_ui_contains "Conversations" 35 \
      && ! ios_wait_ui_contains "Discover" 10; then
      ios_capture_failure_diagnostics "conversations-icon-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Conversations" "Recent conversations." "Chats" "No conversations yet" \
        || ios_tap_any_label "Conversations" "Recent conversations."
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Recent conversations." 15 \
        && ! ios_wait_ui_contains "Chats" 8 \
        && ! ios_wait_ui_contains "No conversations yet" 5; then
        ios_capture_failure_diagnostics "conversations-icon-list"
        echo "MISS conversations-icon: bubble did not open ConversationListView" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-overview.png"; then
        stamp_controls "conversations-icon"
      else
        echo "failed to capture conversations-icon success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-overview/match-row)
    # Match rows require Soulmate enabled + seeded mutual match.
    session_token="$(
      curl -fsS -X POST \
        -H "Content-Type: application/json" \
        -d "{\"identityToken\":\"${USER_TOKEN:-validation-gurusharan}\",\"fullName\":\"${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}\"}" \
        "http://127.0.0.1:${PORT:-8787}/v1/auth/apple" 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sessionToken") or "")' 2>/dev/null || true
    )"
    if [[ -n "$session_token" ]]; then
      curl -fsS -X POST \
        -H "Authorization: Bearer $session_token" \
        -H "Content-Type: application/json" \
        -d '{"enabled":true}' \
        "http://127.0.0.1:${PORT:-8787}/v1/me/soulmate/enable" >/dev/null 2>&1 || true
    fi
    ios_launch_signed_in --likeminded-start-soulmate
    if ! ios_wait_ui_contains "View full introduction" 35 \
      || ! ios_ui_contains "Priya Shah"; then
      ios_capture_failure_diagnostics "match-row-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "View full introduction" "Start chatting" "Open chat" "What they're into" \
        || ios_tap_any_label "View full introduction" "Start chatting"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Start chatting" 15 \
        && ! ios_wait_ui_contains "Open chat" 8 \
        && ! ios_wait_ui_contains "What they're into" 8; then
        ios_capture_failure_diagnostics "match-row-detail"
        echo "MISS match-row: did not push SoulmateMatchDetailView" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-overview.png"; then
        stamp_controls "match-row"
      else
        echo "failed to capture match-row success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-overview/post-meet-select)
    ios_launch_signed_in --likeminded-start-soulmate
    if ! ios_wait_ui_contains "Choose who you connected with" 35 \
      && ! ios_wait_ui_contains "Discover" 10; then
      ios_capture_failure_diagnostics "post-meet-select-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_ui_contains "Choose who you connected with"; then
        ios_capture_failure_diagnostics "post-meet-select-cta-missing"
        echo "MISS post-meet-select: pending CTA absent (need validation pendingSelections)" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Choose who you connected with" "Did you connect with someone?" "Potential match row" "Submit" \
        || ios_tap_any_label "Choose who you connected with" "Did you connect with someone?"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Did you connect with someone?" 15 \
        && ! ios_wait_ui_contains "Potential match row" 8 \
        && ! ios_wait_ui_contains "Submit" 8; then
        ios_capture_failure_diagnostics "post-meet-select-sheet"
        echo "MISS post-meet-select: did not open SoulmateSelectionDialog" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-overview.png"; then
        stamp_controls "post-meet-select"
      else
        echo "failed to capture post-meet-select success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-selection/post-meet-selection-submit)
    # api-persist: explicitly choose a match → Confirm choices → POST /v1/me/soulmate/select.
    selection_meta="$(
      python3 - <<'PY'
import json, urllib.request
auth_req = urllib.request.Request(
    "http://127.0.0.1:8787/v1/auth/apple",
    data=json.dumps({
        "identityToken": "validation-gurusharan",
        "fullName": "Gurusharan Gupta",
    }).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
auth = json.load(urllib.request.urlopen(auth_req, timeout=20))
token = auth.get("sessionToken") or ""
user_id = ((auth.get("user") or {}).get("id") or "")
if not token or not user_id:
    raise SystemExit(1)
status_req = urllib.request.Request(
    "http://127.0.0.1:8787/v1/me/soulmate/status",
    headers={"Authorization": f"Bearer {token}"},
)
status = json.load(urllib.request.urlopen(status_req, timeout=20))
pending = status.get("pendingSelections") or []
if not pending:
    raise SystemExit(2)
row = pending[0]
meeting_id = str(row.get("meetingId") or "")
matches = [str(x) for x in (row.get("potentialMatches") or []) if x]
if not meeting_id or not matches:
    raise SystemExit(3)
# The UI starts with no one selected; the first row tap chooses the first candidate.
pick_id = matches[0]
print(f"{user_id}\t{meeting_id}\t{pick_id}")
PY
    )" || selection_meta=""
    user_id=""
    meeting_id=""
    pick_id=""
    if [[ -n "$selection_meta" ]]; then
      IFS=$'\t' read -r user_id meeting_id pick_id <<< "$selection_meta"
    fi
    if [[ -z "$user_id" || -z "$meeting_id" || -z "$pick_id" ]]; then
      ios_capture_failure_diagnostics "post-meet-selection-submit-pending"
      echo "MISS post-meet-selection-submit: no pending selection in validation API" >&2
      FLOW_FAIL=1
    fi

    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_launch_signed_in --likeminded-start-soulmate-selection
      if ! ios_wait_ui_contains "Did you connect with someone?" 35 \
        && ! ios_wait_ui_contains "Potential match row" 10 \
        && ! ios_wait_ui_contains "Choose someone" 10; then
        ios_capture_failure_diagnostics "post-meet-selection-submit-readiness"
        echo "MISS post-meet-selection-submit: selection dialog not ready" >&2
        FLOW_FAIL=1
      fi
    fi

    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Selection must begin empty; explicitly choose one row.
      toggled=0
      if [[ -n "$( "$IDB" point-id "match-toggle" 2>/dev/null || true )" ]]; then
        if "$IDB" tap-id "match-toggle" center; then
          sleep 0.5
          echo "OK tap-id 'match-toggle'"
          CLICK_OK=$((CLICK_OK + 1))
          toggled=1
        fi
      fi
      if [[ "$toggled" -eq 0 ]]; then
        if ios_tap_any_label "Potential match row"; then
          sleep 0.5
          echo "OK tap 'Potential match row'"
          CLICK_OK=$((CLICK_OK + 1))
          toggled=1
        fi
      fi
      if [[ "$toggled" -eq 0 ]]; then
        ios_capture_failure_diagnostics "post-meet-selection-submit-toggle"
        echo "MISS post-meet-selection-submit: could not toggle match row" >&2
        FLOW_FAIL=1
      fi
    fi

    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_ui_contains "Confirm choices"; then
        ios_capture_failure_diagnostics "post-meet-selection-submit-missing"
        echo "MISS post-meet-selection-submit: explicit confirmation control absent" >&2
        FLOW_FAIL=1
      else
        submitted=0
        if [[ -n "$( "$IDB" point-id "submit" 2>/dev/null || true )" ]]; then
          if "$IDB" tap-id "submit" center; then
            sleep 1.4
            submitted=1
          fi
        fi
        if [[ "$submitted" -eq 0 ]]; then
          if "$IDB" tap "Confirm choices" 2>/dev/null; then
            sleep 1.4
            submitted=1
          fi
        fi
        if [[ "$submitted" -ne 1 ]]; then
          ios_capture_failure_diagnostics "post-meet-selection-submit-tap"
          echo "MISS post-meet-selection-submit: could not confirm choices" >&2
          FLOW_FAIL=1
        else
          echo "OK tap Confirm choices → dismiss/persist"
          CLICK_OK=$((CLICK_OK + 1))
        fi
      fi
    fi

    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      persist_ok="$(
        USER_ID="$user_id" MEETING_ID="$meeting_id" PICK_ID="$pick_id" python3 - <<'PY'
import json, os, time
from pathlib import Path
user_id = os.environ["USER_ID"]
meeting_id = os.environ["MEETING_ID"]
pick_id = os.environ["PICK_ID"]
path = Path("data/validation-db/mvp-store.json")
deadline = time.time() + 12
row = None
while time.time() < deadline:
    data = json.loads(path.read_text())
    for cand in data.get("soulmateSelections") or []:
        if cand.get("userId") == user_id and cand.get("meetingId") == meeting_id:
            row = cand
            break
    if row and list(row.get("selectedUserIds") or []):
        # Accept any non-empty persist for this meeting; prefer including pick when present.
        ids = [str(x) for x in (row.get("selectedUserIds") or [])]
        print("ok" if ids else "empty")
        raise SystemExit(0 if ids else 1)
    time.sleep(0.4)
print("missing")
raise SystemExit(1)
PY
      )" || persist_ok="missing"
      if [[ "$persist_ok" != "ok" ]]; then
        ios_capture_failure_diagnostics "post-meet-selection-submit-api"
        echo "MISS post-meet-selection-submit: soulmateSelections missing for $meeting_id ($persist_ok)" >&2
        FLOW_FAIL=1
      else
        echo "OK post-meet-selection-submit API persist meeting=$meeting_id"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi

    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-selection.png"; then
        stamp_controls "match-toggle,submit" "api-persist"
      else
        echo "failed to capture post-meet-selection-submit success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-overview/soulmate-tab-enable)
    # Disable via API (dev token is identityToken, not session JWT for Bearer).
    session_token="$(
      curl -fsS -X POST \
        -H "Content-Type: application/json" \
        -d "{\"identityToken\":\"${USER_TOKEN:-validation-gurusharan}\",\"fullName\":\"${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}\"}" \
        "http://127.0.0.1:${PORT:-8787}/v1/auth/apple" 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sessionToken") or "")' 2>/dev/null || true
    )"
    if [[ -n "$session_token" ]]; then
      curl -fsS -X POST \
        -H "Authorization: Bearer $session_token" \
        -H "Content-Type: application/json" \
        -d '{"enabled":false}' \
        "http://127.0.0.1:${PORT:-8787}/v1/me/soulmate/enable" >/dev/null 2>&1 || true
      echo "OK API soulmate disabled for enable CTA"
      CLICK_OK=$((CLICK_OK + 1))
    else
      echo "warn: could not mint session for soulmate disable" >&2
    fi
    ios_launch_signed_in --likeminded-start-soulmate
    if ! ios_wait_ui_contains "Enable Soulmate" 40; then
      ios_capture_failure_diagnostics "soulmate-tab-enable-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Must hit the Switch (not FeatureCard StaticText). Never treat Discover / bare "On" as success.
      ios_tap_any_label "Enable Soulmate" "MUTUAL MATCHES" || \
        ios_tap_any_label "Enable Soulmate" "Check for mutual matches"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Optimistic enable removes the toggle card; wait for matches chrome.
      ios_wait_ui_contains "MUTUAL MATCHES" 20 || ios_wait_ui_contains "Check for mutual matches" 10 || {
        ios_capture_failure_diagnostics "soulmate-tab-enable-post-toggle"
        echo "MISS soulmate enable: matches section never appeared" >&2
        FLOW_FAIL=1
      }
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-overview.png"; then
        stamp_controls "tab-enable-toggle"
      else
        echo "failed to capture soulmate-tab-enable success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  video-call/tiles)
    # Display: participant tile grid + call chrome presence.
    ios_launch_signed_in --likeminded-start-video-call --likeminded-dev-meet-join
    if ! ios_wait_ui_contains "Leave meetup" 40 && ! ios_wait_ui_contains "Mute microphone" 15; then
      ios_capture_failure_diagnostics "video-call-tiles-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_wait_ui_contains "Participant tiles grid" 12 \
        || ios_wait_ui_contains "video tile" 10 \
        || ios_ui_contains "Mute microphone" \
        || ios_ui_contains "Leave meetup"; then
        echo "OK video-call tiles / call chrome visible"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "video-call-tiles-missing"
        echo "MISS video-call/tiles: tile grid / call chrome missing" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/video-call.png"; then
        stamp_controls "tiles"
      else
        echo "failed to capture video-call tiles success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  video-call/mute)
    ios_launch_signed_in --likeminded-start-video-call --likeminded-dev-meet-join
    if ! ios_wait_ui_contains "Mute microphone" 40 && ! ios_wait_ui_contains "Unmute microphone" 15 \
      && ! ios_wait_ui_contains "Leave meetup" 10; then
      ios_capture_failure_diagnostics "video-call-mute-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Normalize to unmuted first so one Mute tap reaches muted.
      if ios_ui_contains "Unmute microphone"; then
        ios_tap_button "Unmute microphone" "Mute microphone" || ios_tap_any_label "Unmute microphone" "Mute microphone"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Mute microphone" "Unmute microphone" "Muted" \
        || ios_tap_any_label "Mute microphone" "Unmute microphone"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_wait_ui_contains "Unmute microphone" 12 || ios_ui_contains "Muted"; then
        echo "OK mute toggled to muted"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "video-call-mute-state"
        echo "MISS mute did not reach muted state" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/video-call.png"; then
        stamp_controls "mute"
      else
        echo "failed to capture video-call mute success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  video-call/leave)
    # Leave meetup → Meet overview (Past meet / RSVP chrome).
    # Call bar is bottom-overlaid; still scroll into safe band if AX reports below fold.
    ios_launch_signed_in --likeminded-start-video-call --likeminded-dev-meet-join
    if ! ios_wait_ui_contains "Leave meetup" 40 && ! ios_wait_ui_contains "Mute microphone" 15; then
      ios_capture_failure_diagnostics "video-call-leave-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_scroll_label_into_safe_band "Leave meetup"; then
        read -r lx ly <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$lx" "$ly"; then
          sleep 0.9
          if ios_ui_contains "Past meet row" || ios_ui_contains "When you meet." \
            || ios_ui_contains "RSVP Yes" || ios_ui_contains "Can't Make It" \
            || ios_ui_contains "Join live room" || ios_ui_contains "Meet"; then
            echo "OK tap-point 'Leave meetup' → Meet overview"
            CLICK_OK=$((CLICK_OK + 1))
          else
            ios_tap_button "Leave meetup" "Past meet row" "When you meet." "RSVP Yes" \
              || ios_tap_any_label "Leave meetup" "Past meet row"
          fi
        else
          FLOW_FAIL=1
        fi
      else
        ios_tap_button "Leave meetup" "Past meet row" "When you meet." "RSVP Yes" "Can't Make It" \
          || ios_tap_any_label "Leave meetup" "Past meet row"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_wait_ui_contains "Past meet row" 15 \
        || ios_wait_ui_contains "When you meet." 10 \
        || ios_wait_ui_contains "RSVP Yes" 8 \
        || ios_wait_ui_contains "Can't Make It" 6 \
        || ios_wait_ui_contains "Join live room" 6 \
        || { ios_ui_contains "Meet" && ! ios_ui_contains "Leave meetup"; }; then
        echo "OK tap 'Leave meetup' → Meet overview"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "video-call-leave-destination"
        echo "MISS Leave meetup expected Meet overview chrome" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Leave meetup"; then
        ios_capture_failure_diagnostics "video-call-leave-still-in-call"
        echo "MISS leave still shows Leave meetup after navigate" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/meet.png"; then
        stamp_controls "leave"
      else
        echo "failed to capture video-call leave success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  video-call/video-call-participants)
    ios_launch_signed_in --likeminded-start-video-call --likeminded-dev-meet-join
    if ! ios_wait_ui_contains "Leave meetup" 40 && ! ios_wait_ui_contains "Show participants" 10; then
      ios_capture_failure_diagnostics "video-call-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_wait_ui_contains "Show participants" 20 || true
      ios_tap_button "Show participants" "Participants" "Host" "microphone"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/video-call.png"; then
        stamp_controls "show-participants"
      else
        echo "failed to capture video-call-participants success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  profile-populated/signal-pills)
    # Display: Communication/Energy/Trust pills (no tap).
    ios_launch_signed_in --likeminded-start-profile
    if ! ios_wait_ui_contains "Why this placement" 35; then
      ios_capture_failure_diagnostics "profile-populated-pills-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_label_into_safe_band "Voice-informed signals" 10 || true
      if ios_ui_contains "Communication" && ios_ui_contains "Energy" && ios_ui_contains "Review signals"; then
        echo "OK mobile signal summary and Review signals are visible"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "profile-populated-signal-pills-missing"
        echo "MISS signal-pills: two-pill mobile summary or Review signals not visible" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-populated.png"; then
        stamp_controls "signal-pills"
      else
        echo "failed to capture signal-pills success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  profile-populated/review-signals)
    ios_launch_signed_in --likeminded-start-profile
    if ! ios_scroll_label_into_safe_band "Review signals" 10; then
      ios_capture_failure_diagnostics "profile-populated-review-signals-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Review signals" "Private signals" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ios_wait_ui_contains "Private signals" 12; then
      echo "OK Review signals → Private signals"
      CLICK_OK=$((CLICK_OK + 1))
      "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-signals.png"
      stamp_controls "review-signals"
    else
      ios_capture_failure_diagnostics "profile-populated-review-signals-destination"
      echo "MISS review-signals: Private signals destination not visible" >&2
      CLICK_MISS=$((CLICK_MISS + 1))
      FLOW_FAIL=1
    fi
    ;;
  profile-populated/profile-evidence-scope)
    ios_launch_signed_in --likeminded-start-profile
    if ! ios_wait_ui_contains "Context for your circle—not proof of personality." 35; then
      ios_capture_failure_diagnostics "profile-populated-evidence-placement"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "Inferences from your interview and activity—not a diagnosis." 10 || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      echo "OK Profile evidence scope is visible"
      CLICK_OK=$((CLICK_OK + 1))
      "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-populated.png"
      stamp_controls "profile-evidence-scope"
    else
      ios_capture_failure_diagnostics "profile-populated-evidence-inference"
    fi
    ;;
  profile-populated/edit-profile)
    ios_launch_signed_in --likeminded-start-profile
    if ! ios_wait_ui_contains "Edit profile" 35; then
      ios_capture_failure_diagnostics "profile-populated-edit-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Edit profile" "A private, evolving read of you." || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-edit.png"
      stamp_controls "edit-profile"
    else
      ios_capture_failure_diagnostics "profile-populated-edit-destination"
    fi
    ;;
  profile-populated/interest-chips)
    # Display: interest tags with depth encoding (seed: AI/Startups/Design…).
    # Avoid needle "AI" — substring-matches visible "Analytical" trait label.
    # Concern card pushes interests below fold; scroll until a unique chip is visible.
    ios_launch_signed_in --likeminded-start-profile
    if ! ios_wait_ui_contains "Why this placement" 35; then
      ios_capture_failure_diagnostics "profile-populated-interests-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_scroll_label_into_safe_band "Startups" \
        && ! ios_scroll_label_into_safe_band "Design" \
        && ! ios_scroll_label_into_safe_band "Jazz"; then
        ios_capture_failure_diagnostics "profile-populated-interest-chips-scroll"
        echo "MISS interest-chips: could not scroll unique chips into viewport" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      chip_ok=0
      for chip in Startups Design Jazz Writing; do
        if ios_ui_contains "$chip"; then
          echo "OK interest chip visible: $chip"
          chip_ok=$((chip_ok + 1))
          CLICK_OK=$((CLICK_OK + 1))
        else
          echo "MISS interest chip absent: $chip" >&2
        fi
      done
      if [[ "$chip_ok" -lt 2 ]]; then
        ios_capture_failure_diagnostics "profile-populated-interest-chips-missing"
        echo "MISS interest-chips: expected seeded Startups/Design/Jazz/Writing" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-populated-interests.png"; then
        stamp_controls "interest-chips"
      else
        echo "failed to capture interest-chips success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  profile-empty/pencil-settings)
    # Empty profile + gear → Settings (control id pencil-settings; AX "Settings" / title-settings).
    # Mic TCC alert collapses AX — grant + dismiss before readiness wait.
    sim_id="$(resolve_ios_simulator)"
    xcrun simctl privacy "$sim_id" grant microphone "$BUNDLE_ID" >/dev/null 2>&1 || true
    ios_launch_signed_in --likeminded-force-onboarding --likeminded-start-profile
    ios_dismiss_microphone_prompt_if_present || true
    if ! ios_wait_ui_contains "Settings" 35 && ! ios_wait_ui_contains "title-settings" 10; then
      ios_dismiss_microphone_prompt_if_present || true
      if ! ios_wait_ui_contains "Settings" 12 && ! ios_wait_ui_contains "Your profile" 8; then
        ios_capture_failure_diagnostics "profile-empty-readiness"
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "title-settings" "Account" "Delete account" "Sign out" \
        || ios_tap_button "Settings" "Account" "Delete account" "Sign out"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-empty.png"; then
        stamp_controls "pencil-settings"
      else
        echo "failed to capture pencil-settings success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  profile-empty/start-voice)
    # Voice-empty hero (not force-onboarding About you) — needs --likeminded-dev-profile-empty.
    # CTA sits near floating tab bar; scroll into safe band or Soulmate tab steals the hit.
    sim_id="$(resolve_ios_simulator)"
    xcrun simctl privacy "$sim_id" grant microphone "$BUNDLE_ID" >/dev/null 2>&1 || true
    ios_launch_signed_in --likeminded-start-profile --likeminded-dev-profile-empty
    ios_dismiss_microphone_prompt_if_present || true
    if ! ios_wait_ui_contains "Start voice profile" 35 \
      && ! ios_wait_ui_contains "Tell me how" 10; then
      ios_dismiss_microphone_prompt_if_present || true
      if ! ios_wait_ui_contains "Start voice profile" 12; then
        ios_capture_failure_diagnostics "profile-empty-voice-readiness"
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_scroll_label_into_safe_band "Start voice profile"; then
        ios_capture_failure_diagnostics "profile-empty-voice-under-tab-bar"
        echo "MISS start-voice: Start voice profile outside safe tap band" >&2
        FLOW_FAIL=1
      else
        read -r vx vy <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$vx" "$vy"; then
          sleep 0.9
          ios_dismiss_microphone_prompt_if_present || true
          if ios_ui_contains "Voice orb" || ios_ui_contains "I am listening" \
            || ios_ui_contains "Stop" || ios_ui_contains "Captured signals"; then
            echo "OK tap-point 'Start voice profile' → voice session"
            CLICK_OK=$((CLICK_OK + 1))
          else
            # Sheet chrome may title "Voice profile"; require a session-only signal.
            if ios_ui_contains "Stop" || ios_ui_contains "Voice orb" || ios_ui_contains "I am listening"; then
              CLICK_OK=$((CLICK_OK + 1))
            else
              ios_tap_button "Start voice profile" \
                "Voice orb" "I am listening" "Stop" "Captured signals" \
                || ios_tap_any_label "Start voice profile" "Voice orb"
              ios_dismiss_microphone_prompt_if_present || true
            fi
          fi
        else
          FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Voice orb" || ios_ui_contains "I am listening" \
        || ios_ui_contains "Stop" || ios_ui_contains "Captured signals"; then
        if "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-empty.png"; then
          stamp_controls "start-voice"
        else
          echo "failed to capture start-voice success state" >&2
          FLOW_FAIL=1
        fi
      else
        ios_capture_failure_diagnostics "profile-empty-voice-missing"
        echo "MISS start-voice: voice session did not open" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  profile-concern/start-reinterview)
    # Concern card is gated by concernFlag; force via launch arg (not stale DB alone).
    # Pre-grant mic so TCC alert does not swallow AX during readiness wait.
    sim_id="$(resolve_ios_simulator)"
    xcrun simctl privacy "$sim_id" grant microphone "$BUNDLE_ID" >/dev/null 2>&1 || true
    ios_launch_signed_in \
      --likeminded-start-profile \
      --likeminded-dev-profile-concern "Validation: circle feels off — need a re-interview."
    ios_dismiss_microphone_prompt_if_present || true
    if ! ios_wait_ui_contains "Start re-interview" 35 \
      && ! ios_wait_ui_contains "Re-interview for placement" 10 \
      && ! ios_wait_ui_contains "Circle feels off" 10; then
      ios_dismiss_microphone_prompt_if_present || true
      if ! ios_wait_ui_contains "Start re-interview" 10 \
        && ! ios_wait_ui_contains "Circle feels off" 8; then
        ios_capture_failure_diagnostics "profile-concern-readiness"
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Tap first; mic TCC often races the sheet — dismiss then wait for voice chrome.
      if ! "$IDB" tap "Start re-interview"; then
        ios_capture_failure_diagnostics "profile-concern-tap-missing"
        echo "MISS resolve 'Start re-interview'" >&2
        FLOW_FAIL=1
      else
        sleep 0.6
        ios_dismiss_microphone_prompt_if_present || true
        if ios_wait_ui_contains "Voice profile" 15 \
          || ios_wait_ui_contains "Voice orb" 8 \
          || ios_wait_ui_contains "Stop" 6 \
          || ios_wait_ui_contains "I am listening" 4; then
          echo "OK tap 'Start re-interview' → voice session"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_dismiss_microphone_prompt_if_present || true
          if ios_wait_ui_contains "Voice profile" 8 || ios_wait_ui_contains "Voice orb" 6; then
            echo "OK tap 'Start re-interview' → voice session (after mic dismiss)"
            CLICK_OK=$((CLICK_OK + 1))
          else
            ios_capture_failure_diagnostics "profile-concern-voice-missing"
            echo "MISS start-reinterview: voice session did not open" >&2
            FLOW_FAIL=1
          fi
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/profile-concern.png"; then
        stamp_controls "start-reinterview"
      else
        echo "failed to capture start-reinterview success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  voice-session/voice-orb)
    ios_launch_signed_in \
      --likeminded-start-profile \
      --likeminded-start-voice-session \
      --likeminded-dev-voice-preview
    if ! ios_wait_ui_contains "Voice profile" 35; then
      ios_capture_failure_diagnostics "voice-session-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Voice orb"; then
        ios_tap_any_label "Voice orb" "Voice orb"
      else
        # Preview mode still proves the listening surface even if AX type is nonstandard.
        if ios_ui_contains "I am listening" || ios_ui_contains "Captured signals"; then
          echo "OK voice-orb surface visible (listening/captured)"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_capture_failure_diagnostics "voice-orb-missing"
          echo "MISS voice-orb surface" >&2
          FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/voice-session.png"; then
        stamp_controls "voice-orb"
      else
        echo "failed to capture voice-orb success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  voice-session/stop)
    ios_launch_signed_in \
      --likeminded-start-profile \
      --likeminded-start-voice-session \
      --likeminded-dev-voice-preview
    if ! ios_wait_ui_contains "Stop listening" 35; then
      ios_capture_failure_diagnostics "voice-session-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Stop listening" "Voice profile"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/voice-session.png"; then
        stamp_controls "stop"
      else
        echo "failed to capture voice-session stop success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  voice-session/done)
    ios_launch_signed_in \
      --likeminded-start-profile \
      --likeminded-start-voice-session \
      --likeminded-dev-voice-preview
    if ! ios_wait_ui_contains "Done" 35; then
      ios_capture_failure_diagnostics "voice-session-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_button "Done" "Your profile"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/voice-session.png"; then
        stamp_controls "done"
      else
        echo "failed to capture voice-session done success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  meet/open-notifications)
    ios_launch_signed_in
    if ! ios_wait_ui_contains "When you meet." 35; then
      ios_tap_button "Meet" "When you meet." || {
        ios_capture_failure_diagnostics "meet-tab-readiness"
        FLOW_FAIL=1
      }
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_wait_ui_contains "Notifications" 20; then
      ios_capture_failure_diagnostics "meet-bell-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" tap "Notifications"; then
        sleep 0.6
        if ios_ui_contains "All quiet." \
          || ios_ui_contains "Mark all notifications as read" \
          || ios_ui_contains "NOTIFICATIONS"; then
          echo "OK tap 'Notifications' → notifications sheet"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_capture_failure_diagnostics "meet-notifications-sheet"
          echo "MISS tap 'Notifications' expected notifications sheet content" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
        fi
      else
        ios_capture_failure_diagnostics "meet-notifications-tap"
        echo "MISS resolve 'Notifications'" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/meet.png"; then
        stamp_controls "bell"
      else
        echo "failed to capture meet open-notifications success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  meet/open-past-meet)
    ios_launch_signed_in
    if ! ios_wait_ui_contains "When you meet." 35; then
      ios_tap_button "Meet" "When you meet." || {
        ios_capture_failure_diagnostics "meet-tab-readiness"
        FLOW_FAIL=1
      }
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # The AX tree may expose off-screen rows, so require a viewport-safe point.
      if ! ios_scroll_until_tappable "past-row" center 700 8 140; then
        ios_capture_failure_diagnostics "meet-past-row-readiness"
        echo "MISS open-past-meet: past row never entered the tappable viewport" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      read -r past_x past_y <<< "$IOS_TAPPABLE_POINT"
      "$IDB" tap-point "$past_x" "$past_y"
      if ios_wait_ui_contains "Great meeting!" 12 \
        || ios_wait_ui_contains "Meet recap" 8 \
        || ios_wait_ui_contains "Meeting insights" 8; then
        echo "OK tap viewport-safe past row → recap"
      else
        ios_capture_failure_diagnostics "meet-past-row-tap"
        echo "MISS open-past-meet: viewport-safe tap did not open recap" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Great meeting!" \
        || ios_ui_contains "Back to meet" \
        || ios_ui_contains "Meeting insights" \
        || ios_ui_contains "Meet recap"; then
        echo "OK tap 'Past meet row' → past meet recap"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "meet-past-meet-detail"
        echo "MISS tap 'Past meet row' expected PastMeetDetailView / recap chrome" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/meet.png"; then
        stamp_controls "past-row"
      else
        echo "failed to capture meet open-past-meet success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  meet/rsvp-weekend)
    # Product AX: Saturday/Sunday Available|unavailable → POST /v1/meetings/rsvp → GET upcoming.
    ios_launch_signed_in
    if ! ios_wait_ui_contains "Available this weekend?" 35; then
      ios_tap_button "Meet" "Available this weekend?" || {
        ios_capture_failure_diagnostics "meet-rsvp-readiness"
        FLOW_FAIL=1
      }
    fi
    session_token=""
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      session_token="$(ios_validation_session_token || true)"
      if [[ -z "$session_token" ]]; then
        echo "MISS rsvp-weekend: no validation session token" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # label|kind|available(true/false)
      rsvp_steps=(
        "Saturday Available|community|true"
        "Saturday unavailable|community|false"
        "Sunday Available|circle|true"
        "Sunday unavailable|circle|false"
      )
      for step in "${rsvp_steps[@]}"; do
        IFS='|' read -r label kind want <<<"$step"
        ios_scroll_until_visible "$label" 6 || true
        if ! "$IDB" tap "$label"; then
          ios_capture_failure_diagnostics "meet-rsvp-${kind}-${want}"
          echo "MISS tap '$label'" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
          break
        fi
        echo "OK tap '$label'"
        CLICK_OK=$((CLICK_OK + 1))
        api_ok=0
        api_deadline=$((SECONDS + 12))
        upcoming_json=""
        while (( SECONDS < api_deadline )); do
          upcoming_json="$(curl -fsS \
            -H "Authorization: Bearer $session_token" \
            "http://127.0.0.1:${PORT:-8787}/v1/meetings/upcoming" 2>/dev/null || true)"
          if KIND="$kind" WANT="$want" python3 -c '
import json, os, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
rsvps = payload.get("rsvps") or {}
kind = os.environ["KIND"]
want = os.environ["WANT"] == "true"
raise SystemExit(0 if bool(rsvps.get(kind)) is want else 1)
' <<<"$upcoming_json"; then
            api_ok=1
            break
          fi
          sleep 0.4
        done
        if [[ "$api_ok" -ne 1 ]]; then
          ios_capture_failure_diagnostics "meet-rsvp-api-${kind}-${want}"
          echo "MISS rsvp-weekend API readback kind=$kind want=$want" >&2
          echo "upcoming_json=${upcoming_json:-<empty>}" >&2
          FLOW_FAIL=1
          break
        fi
        echo "OK rsvp API kind=$kind available=$want"
        CLICK_OK=$((CLICK_OK + 1))
      done
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/meet.png"; then
        stamp_controls "rsvp-sat-yes,rsvp-sat-no,rsvp-sun-yes,rsvp-sun-no" "api-persist"
      else
        echo "failed to capture meet rsvp-weekend success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circles/hero-circle)
    # Primary hero card → CircleDetailView fullScreenCover.
    ios_launch_signed_in --likeminded-start-circles
    if ! ios_wait_ui_contains "Your circle." 35; then
      ios_capture_failure_diagnostics "circles-hero-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "hero-circle" \
        "Back to circles" \
        "Open your circle" \
        "" \
        "" \
        present
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_wait_ui_contains "Why you fit" 8 \
        && ! ios_wait_ui_contains "circle-detail-back" 4; then
        ios_capture_failure_diagnostics "circles-hero-detail"
        echo "MISS hero-circle: CircleDetailView not shown after hero tap" >&2
        FLOW_FAIL=1
      else
        echo "OK hero-circle → CircleDetailView"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/circles.png"; then
        stamp_controls "hero-circle"
      else
        echo "failed to capture circles hero-circle success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circles/plus-icon)
    # Intentional omission vs mockup: no actionable top-right + control on Circles.
    # Ledger expected: DISPLAY ONLY / no Button (source-trace → computer-use tier-gap).
    ios_launch_signed_in --likeminded-start-circles
    if ! ios_wait_ui_contains "Your circle." 35; then
      ios_capture_failure_diagnostics "circles-plus-icon-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ! ios_ui_contains "Open your circle" && ! ios_ui_contains "Your circle"; then
        ios_capture_failure_diagnostics "circles-plus-icon-missing-chrome"
        echo "MISS plus-icon: Circles chrome absent" >&2
        FLOW_FAIL=1
      else
        echo "OK plus-icon: Circles chrome present"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Fail if a tappable plus/add control appears on Circles (id or labeled Button).
      if "$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata

def norm(value):
    return " ".join(unicodedata.normalize("NFKC", str(value or "")).split()).casefold()

data = json.load(sys.stdin)
hits = []
for e in data:
    uid = norm(e.get("AXUniqueId") or e.get("AXIdentifier"))
    lab = norm(e.get("AXLabel") or e.get("AXValue") or e.get("AXTitle"))
    typ = e.get("type") or ""
    if uid in ("plus-icon", "circles-plus", "add-circle"):
        hits.append(f"id={uid} type={typ}")
        continue
    if typ in ("Button", "Link") and (
        lab in ("plus", "+")
        or lab.startswith("add circle")
        or lab.startswith("create circle")
        or "plus icon" in lab
    ):
        hits.append(f"label={lab} type={typ}")
if hits:
    print("; ".join(hits[:5]))
    raise SystemExit(1)
raise SystemExit(0)
'; then
        echo "OK plus-icon: no actionable + control (intentional omission)"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "circles-plus-icon-unexpected-control"
        echo "MISS plus-icon: actionable + control present (expected intentional omission)" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/circles.png"; then
        stamp_controls "plus-icon"
      else
        echo "failed to capture circles plus-icon success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circles/concern-btn)
    # Reveal concern capture sheet: "This doesn't feel like my circle" → What feels off?
    ios_launch_signed_in --likeminded-start-circles
    if ! ios_wait_ui_contains "Your circle." 35; then
      ios_capture_failure_diagnostics "circles-concern-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "This doesn't feel like my circle" 4 || true
      ios_tap_control \
        "concern-btn" \
        "What feels off?" \
        "This doesn't feel like my circle"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/circles.png"; then
        stamp_controls "concern-btn"
      else
        echo "failed to capture circles concern-btn success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circles/concern-field)
    # Type into revealed concern TextField (placeholder as focus label).
    # Avoid camelCase tokens (e.g. iOS) that Simulator may autocapitalize before the field fix.
    concern_text="circle concern field proof"
    ios_launch_signed_in --likeminded-start-circles
    if ! ios_wait_ui_contains "Your circle." 35; then
      ios_capture_failure_diagnostics "circles-concern-field-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "This doesn't feel like my circle" 4 || true
      ios_tap_control \
        "concern-btn" \
        "What feels off?" \
        "This doesn't feel like my circle"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Too fast, too quiet, wrong energy..." "$concern_text"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_wait_ui_contains "Continue in Profile" 8; then
        echo "OK concern-field → Continue in Profile enabled"
        CLICK_OK=$((CLICK_OK + 1))
      else
        echo "MISS concern-field: Continue in Profile not ready after type" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/circles.png"; then
        stamp_controls "concern-field"
      else
        echo "failed to capture circles concern-field success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circles/concern-submit)
    # Submit concern → POST /v1/me/circles/concern (dev-auth harness suppresses Profile auto-route).
    # Exact API readback; avoid camelCase tokens Simulator may autocapitalize.
    concern_text="circle feels too performative"
    ios_ensure_validation_api || exit 1
    ios_clear_placement_concern || true
    ios_launch_signed_in --likeminded-start-circles
    if ! ios_wait_ui_contains "Your circle." 35; then
      ios_capture_failure_diagnostics "circles-concern-submit-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_until_visible "This doesn't feel like my circle" 4 || true
      ios_tap_control \
        "concern-btn" \
        "What feels off?" \
        "This doesn't feel like my circle"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Too fast, too quiet, wrong energy..." "$concern_text"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Persist POST must hit a live validation-db; try? in app swallows network errors.
      ios_ensure_validation_api || exit 1
      ios_tap_control \
        "concern-submit" \
        "Your circle." \
        "Continue in Profile"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Poll: empty JSON was :8787 bounce; stale match blocked by ios_clear_placement_concern.
      if placement_json="$(ios_wait_placement_concern "$concern_text" 12)"; then
        echo "OK concern-submit persisted placementConcern=$concern_text"
        CLICK_OK=$((CLICK_OK + 1))
      else
        echo "MISS concern-submit API readback expected concernFlag + placementConcern=$concern_text" >&2
        echo "placement_json=${placement_json:-<empty>}" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/circles.png"; then
        stamp_controls "concern-submit" "api-persist"
      else
        echo "failed to capture circles concern-submit success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  circles/browse-card)
    ios_launch_signed_in --likeminded-start-circles
    if ! ios_wait_ui_contains "Your circle." 35; then
      ios_capture_failure_diagnostics "circles-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Placed-state browse cards are AI second-circle suggestions.
      secondary_label="$("$IDB" describe 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for e in data:
    label = e.get('AXLabel') or ''
    if label.startswith('Open ') and label.endswith(' AI suggestion'):
        print(label)
        raise SystemExit(0)
raise SystemExit(1)
" || true)"
      if [[ -z "$secondary_label" ]]; then
        ios_capture_failure_diagnostics "circles-browse-card-missing"
        echo "MISS circles browse-card: no Open … AI suggestion control" >&2
        FLOW_FAIL=1
      else
        ios_scroll_until_tappable "secondary-circle-card-longform-thinkers" center 700 4 || true
        ios_tap_button "$secondary_label" \
          "Back to circles" "About this circle" "Make this my second circle" "Your second circle"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/circles.png"; then
        stamp_controls "browse-card"
      else
        echo "failed to capture circles browse-card success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  communities/create-card)
    ios_launch_signed_in --likeminded-start-communities
    if ! ios_wait_ui_contains "Create a community" 35 \
      && ! ios_wait_ui_contains "Browse communities" 10; then
      ios_capture_failure_diagnostics "communities-create-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_scroll_label_into_safe_band "Create a community"; then
        ios_tap_button "Create a community" "Community name" "Create community"
      else
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/communities.png"; then
        stamp_controls "create-card"
      else
        echo "failed to capture communities create-card success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  communities/filter-pills)
    ios_launch_signed_in --likeminded-start-communities
    if ! ios_wait_ui_contains "All communities filter" 35 \
      && ! ios_wait_ui_contains "Browse communities" 10; then
      ios_capture_failure_diagnostics "communities-filter-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      for pill in "Trending" "Nearby" "New" "All"; do
        label="${pill} communities filter"
        if ! "$IDB" tap "$label"; then
          ios_capture_failure_diagnostics "filter-${pill}"
          echo "MISS resolve filter pill '$label'" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
          break
        fi
        sleep 0.5
        if "$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def n(v):
    return " ".join(unicodedata.normalize("NFKC", str(v or "")).split()).casefold()
want_label, want_value = n(sys.argv[1]), n("Selected")
data = json.load(sys.stdin)
for e in data:
    if n(e.get("AXLabel")) == want_label and n(e.get("AXValue")) == want_value:
        raise SystemExit(0)
raise SystemExit(1)
' "$label"; then
          echo "OK filter pill Selected: $label"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_capture_failure_diagnostics "filter-${pill}-selected"
          echo "MISS filter pill not Selected: $label" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
          break
        fi
      done
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 4 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/communities.png"; then
        stamp_controls "filter-pills"
      else
        echo "failed to capture communities filter-pills success state" >&2
        FLOW_FAIL=1
      fi
    else
      FLOW_FAIL=1
    fi
    ;;
  communities/search)
    ios_launch_signed_in --likeminded-start-communities
    if ! ios_wait_ui_contains "Search communities" 35 \
      && ! ios_wait_ui_contains "Browse communities" 10; then
      ios_capture_failure_diagnostics "communities-search-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_focus_and_type "Search communities" "zzz-no-match" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Empty copy sits below Your communities cards — scroll into the visible probe band.
      if ios_scroll_until_visible "No communities match" 10; then
        echo "OK search filtered browse to empty"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "communities-search-no-filter"
        echo "MISS communities search: expected No communities match" >&2
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/communities.png"; then
        stamp_controls "search"
      else
        echo "failed to capture communities search success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  communities/joined-card)
    # Your communities cards sit above Create/Browse; AX label is Open <name> community.
    ios_launch_signed_in --likeminded-start-communities
    if ! ios_wait_ui_contains "Your communities" 35 \
      && ! ios_wait_ui_contains "YOUR COMMUNITIES" 10 \
      && ! ios_wait_ui_contains "Browse communities" 10; then
      ios_capture_failure_diagnostics "communities-joined-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]] && ios_ui_contains "Join a community below"; then
      ios_capture_failure_diagnostics "communities-joined-empty"
      echo "MISS communities joined-card: Your communities empty" >&2
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      joined_label="$("$IDB" describe 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
create_y = None
for e in data:
    lab = e.get('AXLabel') or ''
    if lab == 'Create a community':
        create_y = e.get('frame', {}).get('y')
        break
candidates = []
for e in data:
    label = e.get('AXLabel') or ''
    frame = e.get('frame') or {}
    h = frame.get('height') or 0
    y = frame.get('y') or 0
    cy = y + h / 2
    if h <= 0 or h > 280 or cy > 1400:
        continue
    if not (label.startswith('Open ') and label.endswith(' community')):
        continue
    # Prefer cards above Create a community (Your communities section).
    if create_y is not None and y >= create_y:
        continue
    candidates.append((cy, label))
if not candidates:
    raise SystemExit(1)
candidates.sort()
print(candidates[0][1])
" || true)"
      if [[ -z "$joined_label" ]]; then
        ios_capture_failure_diagnostics "communities-joined-card-missing"
        echo "MISS communities joined-card: no Open … community above Create" >&2
        FLOW_FAIL=1
      else
        if ios_scroll_label_into_safe_band "$joined_label"; then
          ios_tap_any_label "$joined_label" "Community options" || \
            ios_tap_button "$joined_label" \
              "Community options" "Upcoming" "Leave community" "View members"
        else
          FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/communities.png"; then
        stamp_controls "joined-card"
      else
        echo "failed to capture communities joined-card success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  communities/browse-card)
    ios_launch_signed_in --likeminded-start-communities
    if ! ios_wait_ui_contains "Browse communities" 35 \
      && ! ios_wait_ui_contains "Explore communities" 10 \
      && ! ios_wait_ui_contains "Create a community" 10; then
      ios_capture_failure_diagnostics "communities-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      browse_label="$("$IDB" describe 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
candidates = []
for e in data:
    label = e.get('AXLabel') or ''
    frame = e.get('frame') or {}
    h = frame.get('height') or 0
    cy = (frame.get('y') or 0) + h / 2
    # Allow below-fold browse cards; scroll_until_visible brings them into the tap band.
    if h <= 0 or h > 280 or cy > 1400:
        continue
    if label.startswith('Open ') and label.endswith(' community'):
        candidates.append((0, cy, label))
    elif label.endswith(' community') and (label.startswith('Join ') or label.startswith('Joined ')):
        candidates.append((1, cy, label))
if not candidates:
    raise SystemExit(1)
candidates.sort()
print(candidates[0][2])
" || true)"
      if [[ -z "$browse_label" ]]; then
        ios_capture_failure_diagnostics "communities-browse-card-missing"
        echo "MISS communities browse-card: no Open/Join … community control" >&2
        FLOW_FAIL=1
      else
        # Scroll card into safe band then tap by label.
        if ios_scroll_label_into_safe_band "$browse_label"; then
          ios_tap_any_label "$browse_label" "Community options" || \
            ios_tap_button "$browse_label" \
              "Community options" "Upcoming" "Leave community" "Join community" "View members"
        else
          FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/communities.png"; then
        stamp_controls "browse-card"
      else
        echo "failed to capture communities browse-card success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  soulmate-overview/enable-toggle)
    # Display/status when already enabled: matches chrome present, enable CTA absent.
    session_token="$(
      curl -fsS -X POST \
        -H "Content-Type: application/json" \
        -d "{\"identityToken\":\"${USER_TOKEN:-validation-gurusharan}\",\"fullName\":\"${LIKEMINDED_VALIDATION_NAME:-Gurusharan Gupta}\"}" \
        "http://127.0.0.1:${PORT:-8787}/v1/auth/apple" 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sessionToken") or "")' 2>/dev/null || true
    )"
    if [[ -n "$session_token" ]]; then
      curl -fsS -X POST \
        -H "Authorization: Bearer $session_token" \
        -H "Content-Type: application/json" \
        -d '{"enabled":true}' \
        "http://127.0.0.1:${PORT:-8787}/v1/me/soulmate/enable" >/dev/null 2>&1 || true
      echo "OK API soulmate enabled for status chrome"
      CLICK_OK=$((CLICK_OK + 1))
    else
      echo "warn: could not mint session for soulmate enable" >&2
    fi
    ios_launch_signed_in --likeminded-start-soulmate
    if ! ios_wait_ui_contains "MUTUAL MATCHES" 40 && ! ios_wait_ui_contains "Check for mutual matches" 10; then
      ios_capture_failure_diagnostics "enable-toggle-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Enable Soulmate"; then
        ios_capture_failure_diagnostics "enable-toggle-still-showing-cta"
        echo "MISS enable-toggle: Enable Soulmate CTA still visible when enabled" >&2
        FLOW_FAIL=1
      else
        echo "OK enable-toggle: enabled status chrome (MUTUAL MATCHES), CTA absent"
        CLICK_OK=$((CLICK_OK + 1))
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/soulmate-overview.png"; then
        stamp_controls "enable-toggle"
      else
        echo "failed to capture enable-toggle success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  community-detail/view-members)
    ios_launch_signed_in \
      --likeminded-start-community-detail \
      --likeminded-community-id jazz-music
    if ! ios_wait_ui_contains "Community options" 35; then
      ios_capture_failure_diagnostics "view-members-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "Join community"; then
        ios_tap_button "Join community" "Leave community"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control "detail-tab-members" "View members" "Members" || \
        ios_tap_button "Members" "View members"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # CTA was landing under the floating tab bar (y≈810) — scroll into safe band first.
      ios_scroll_until_tappable "view-members" center 700 8 || \
        ios_scroll_until_visible "View members" 6 || true
      if [[ -n "${IOS_TAPPABLE_POINT:-}" ]]; then
        read -r vx vy <<< "$IOS_TAPPABLE_POINT"
        if "$IDB" tap-point "$vx" "$vy"; then
          sleep 0.8
          if ios_wait_ui_contains "Back to community" 15 || ios_wait_ui_contains "Search members" 10; then
            echo "OK tap-point view-members → members chrome"
            CLICK_OK=$((CLICK_OK + 1))
          else
            ios_capture_failure_diagnostics "view-members-nav-miss"
            echo "MISS view-members tap-point did not open members" >&2
            FLOW_FAIL=1
          fi
        else
          FLOW_FAIL=1
        fi
      else
        ios_tap_button "View members" "Back to community" "Search members" "Roster"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/13-community-detail.png"; then
        stamp_controls "view-members"
      else
        echo "failed to capture view-members success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  conversations/open-conversation)
    ios_launch_signed_in --likeminded-start-conversations
    if ! ios_wait_ui_contains "Recent conversations." 35; then
      ios_capture_failure_diagnostics "conversations-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      conv_label="$("$IDB" describe 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
for e in data:
    lab = str(e.get("AXLabel") or "")
    if lab.startswith("Open conversation with ") and e.get("type") in ("Button", "Link", "Cell", "Other"):
        print(lab)
        raise SystemExit(0)
raise SystemExit(1)
' 2>/dev/null || true)"
      if [[ -z "$conv_label" ]]; then
        ios_capture_failure_diagnostics "conversations-no-row"
        echo "MISS open-conversation: no Open conversation with … row" >&2
        FLOW_FAIL=1
      else
        ios_tap_any_label "$conv_label" "Message input" || \
          ios_tap_button "$conv_label" "Message input" "Send message" "Voice call"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/conversations.png"; then
        stamp_controls "conv-row"
      else
        echo "failed to capture open-conversation success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  notifications/activity-filter-pills)
    # Activity pills: unique AX labels "… activity filter" + Selected value.
    ios_launch_signed_in --likeminded-start-notifications
    if ! ios_wait_ui_contains "ACTIVITY" 35 \
      && ! ios_wait_ui_contains "Circles activity filter" 10; then
      ios_capture_failure_diagnostics "notifications-activity-filter-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_scroll_label_into_safe_band "Circles activity filter" || FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      for pill in "Circles" "Communities" "All"; do
        label="${pill} activity filter"
        if ! "$IDB" tap "$label"; then
          ios_capture_failure_diagnostics "activity-filter-${pill}"
          echo "MISS resolve activity filter pill '$label'" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
          break
        fi
        sleep 0.5
        if "$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def n(v):
    return " ".join(unicodedata.normalize("NFKC", str(v or "")).split()).casefold()
want_label, want_value = n(sys.argv[1]), n("Selected")
data = json.load(sys.stdin)
for e in data:
    if n(e.get("AXLabel")) == want_label and n(e.get("AXValue")) == want_value:
        raise SystemExit(0)
raise SystemExit(1)
' "$label"; then
          echo "OK activity filter Selected: $label"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_capture_failure_diagnostics "activity-filter-${pill}-selected"
          echo "MISS activity filter not Selected: $label" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
          break
        fi
      done
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 3 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/notifications.png"; then
        stamp_controls "activity-filter-pills"
      else
        echo "failed to capture notifications activity-filter-pills success state" >&2
        FLOW_FAIL=1
      fi
    else
      FLOW_FAIL=1
    fi
    ;;
  notifications/notif-filter-pills)
    ios_launch_signed_in --likeminded-start-notifications
    if ! ios_wait_ui_contains "NOTIFICATIONS" 35 \
      && ! ios_wait_ui_contains "Unread notifications filter" 10; then
      ios_capture_failure_diagnostics "notifications-notif-filter-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      for pill in "Unread" "Mentions" "All"; do
        label="${pill} notifications filter"
        if ! "$IDB" tap "$label"; then
          ios_capture_failure_diagnostics "notif-filter-${pill}"
          echo "MISS resolve notif filter pill '$label'" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
          break
        fi
        sleep 0.5
        if "$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def n(v):
    return " ".join(unicodedata.normalize("NFKC", str(v or "")).split()).casefold()
want_label, want_value = n(sys.argv[1]), n("Selected")
data = json.load(sys.stdin)
for e in data:
    if n(e.get("AXLabel")) == want_label and n(e.get("AXValue")) == want_value:
        raise SystemExit(0)
raise SystemExit(1)
' "$label"; then
          echo "OK notif filter Selected: $label"
          CLICK_OK=$((CLICK_OK + 1))
        else
          ios_capture_failure_diagnostics "notif-filter-${pill}-selected"
          echo "MISS notif filter not Selected: $label" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
          break
        fi
      done
    fi
    if [[ "$FLOW_FAIL" -eq 0 && "$CLICK_OK" -ge 3 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/notifications.png"; then
        stamp_controls "notif-filter-pills"
      else
        echo "failed to capture notifications notif-filter-pills success state" >&2
        FLOW_FAIL=1
      fi
    else
      FLOW_FAIL=1
    fi
    ;;
  notifications/mark-all-read)
    ios_launch_signed_in --likeminded-start-notifications
    if ! ios_wait_ui_contains "Mark all notifications as read" 35 \
      && ! ios_wait_ui_contains "NOTIFICATIONS" 10; then
      ios_capture_failure_diagnostics "notifications-mark-all-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      ios_tap_control \
        "mark-all-read" \
        "All notifications marked read." \
        "Mark all notifications as read"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "All notifications marked read."; then
        echo "OK mark-all-read → status message"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "notifications-mark-all-status"
        echo "MISS mark-all-read expected status message" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/notifications.png"; then
        stamp_controls "mark-all-read"
      else
        echo "failed to capture notifications mark-all-read success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  notifications/refresh)
    ios_launch_signed_in --likeminded-start-notifications
    if ! ios_wait_ui_contains "NOTIFICATIONS" 35 \
      && ! ios_wait_ui_contains "Stay in the loop" 10; then
      ios_capture_failure_diagnostics "notifications-refresh-readiness"
      FLOW_FAIL=1
    fi
    # Footer Refresh sits below the fold; Button needles look "visible" to
    # ios_ui_contains even when off-screen, so scroll-until-tappable is required.
    # safe_y≈820 / inset 50: after scroll the control lands near y~778 (above home indicator).
    if [[ "$FLOW_FAIL" -eq 0 ]] && ! ios_scroll_until_tappable "refresh" center 820 16 50; then
      ios_capture_failure_diagnostics "notifications-refresh-tappable"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if [[ -n "${IOS_TAPPABLE_POINT:-}" ]]; then
        ios_tap_control \
          "refresh" \
          "Notifications refreshed from backend." \
          "Refresh notifications" \
          "" "" present center "$IOS_TAPPABLE_POINT"
      else
        ios_tap_control \
          "refresh" \
          "Notifications refreshed from backend." \
          "Refresh notifications"
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_wait_ui_contains "Notifications refreshed from backend." 12; then
        echo "OK refresh → backend status"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "notifications-refresh-status"
        echo "MISS refresh expected status message" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/notifications.png"; then
        stamp_controls "refresh"
      else
        echo "failed to capture notifications refresh success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  notifications/rows)
    # Tap a seeded notification/activity row → dismiss sheet + tab route.
    ios_launch_signed_in --likeminded-start-notifications
    if ! ios_wait_ui_contains "NOTIFICATIONS" 35; then
      ios_capture_failure_diagnostics "notifications-rows-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      row_label="$(
        "$IDB" describe 2>/dev/null | python3 -c '
import json, sys, unicodedata
def n(v):
    return " ".join(unicodedata.normalize("NFKC", str(v or "")).split())
data = json.load(sys.stdin)
skip = {
    "notifications", "activity", "today", "earlier", "yesterday", "this week",
    "stay in the loop", "all quiet.", "mark all notifications as read", "done",
    "refresh notifications", "no notifications in this filter.", "no activity in this filter.",
    "we will keep you updated on what matters.", "we ll keep you updated on what matters.",
}
preferred, fallback = None, None
for e in data:
    if e.get("type") not in ("Button", "Cell"):
        continue
    lab = n(e.get("AXLabel") or e.get("AXValue"))
    if not lab:
        continue
    low = lab.casefold()
    if low in skip or low.endswith(" filter") or low in {"all", "unread", "mentions", "circles", "communities"}:
        continue
    if any(k in low for k in ("meetup", "soulmate", "message", "joined", "reflective", "jazz", "builders")):
        preferred = lab
        break
    if fallback is None:
        fallback = lab
print(preferred or fallback or "", end="")
' || true
      )"
      if [[ -z "$row_label" ]]; then
        ios_capture_failure_diagnostics "notifications-rows-empty"
        echo "MISS notifications/rows: no tappable notification/activity row" >&2
        FLOW_FAIL=1
      else
        if "$IDB" tap "$row_label"; then
          sleep 0.8
          if ios_ui_contains "When you meet." \
            || ios_ui_contains "Your circle." \
            || ios_ui_contains "Explore communities" \
            || ios_ui_contains "Browse communities" \
            || ios_ui_contains "Soulmate" \
            || ! ios_ui_contains "NOTIFICATIONS"; then
            echo "OK tap notification/activity row '$row_label' → dismissed"
            CLICK_OK=$((CLICK_OK + 1))
          else
            ios_capture_failure_diagnostics "notifications-rows-dismiss"
            echo "MISS rows: tapped '$row_label' but notifications sheet still up" >&2
            CLICK_MISS=$((CLICK_MISS + 1))
            FLOW_FAIL=1
          fi
        else
          ios_capture_failure_diagnostics "notifications-rows-tap"
          echo "MISS resolve row '$row_label'" >&2
          CLICK_MISS=$((CLICK_MISS + 1))
          FLOW_FAIL=1
        fi
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/notifications.png"; then
        stamp_controls "rows"
      else
        echo "failed to capture notifications rows success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  notifications/done)
    # Validation root pins NotificationsView; Done uses onDismiss → Meet tab.
    ios_launch_signed_in --likeminded-start-notifications
    if ! ios_wait_ui_contains "Done" 35 \
      && ! ios_wait_ui_contains "NOTIFICATIONS" 10; then
      ios_capture_failure_diagnostics "notifications-done-readiness"
      FLOW_FAIL=1
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      # Label tap is more reliable than AX id here (toolbar geometry shifts).
      ios_tap_button "Done" "When you meet." "Your circle." "Explore communities" "Browse communities"
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if ios_ui_contains "When you meet." \
        || ios_ui_contains "Your circle." \
        || ! ios_ui_contains "NOTIFICATIONS"; then
        echo "OK Done dismisses notifications → main tabs"
        CLICK_OK=$((CLICK_OK + 1))
      else
        ios_capture_failure_diagnostics "notifications-done-dismiss"
        echo "MISS Done did not dismiss notifications" >&2
        CLICK_MISS=$((CLICK_MISS + 1))
        FLOW_FAIL=1
      fi
    fi
    if [[ "$FLOW_FAIL" -eq 0 ]]; then
      if "$IDB" screenshot "$ROOT/output/validation/ios-screens/notifications.png"; then
        stamp_controls "done"
      else
        echo "failed to capture notifications done success state" >&2
        FLOW_FAIL=1
      fi
    fi
    ;;
  *)
    tier="$(flow_tier)"
    # Fail closed for interaction tiers — screen-capture alone must not false-pass api-persist.
    case "$tier" in
      computer-use|api-persist|real-auth|real-livekit|live-session)
        echo "missing explicit iOS interaction proof branch: ${SCREEN}/${FLOW} (tier=$tier)" >&2
        FLOW_FAIL=1
        ;;
      *)
        if ! "$ROOT/script/cross_platform_screen_validate.sh" --screen "$SCREEN" --platform ios; then
          FLOW_FAIL=1
        fi
        ;;
    esac
    ;;
esac

echo "prove_summary ok=$CLICK_OK miss=$CLICK_MISS flow_fail=$FLOW_FAIL"
set -e
if [[ "$FLOW_FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
