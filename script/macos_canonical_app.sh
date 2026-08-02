#!/usr/bin/env bash
# Single source of truth for the macOS validation app binary.
# One app only: .build/macos/.../LikemindedMac.app (window title "Likeminded").
set -euo pipefail

_SCRIPT_SELF="${BASH_SOURCE[0]:-$0}"
ROOT="$(cd "$(dirname "$_SCRIPT_SELF")/.." && pwd)"
export MACOS_CANONICAL_APP="$ROOT/.build/macos/Build/Products/Debug/LikemindedMac.app"
export MACOS_CANONICAL_BUNDLE_ID="com.gurusharan.likeminded"
export MACOS_CANONICAL_SCHEME="LikemindedMac"
export MACOS_CANONICAL_EXEC="LikemindedMac"

macos_macos_app_lock_held_by_other() {
  local lock_dir="${LIKEMINDED_VALIDATION_LOCK_DIR:-/tmp/likeminded-validation-locks}"
  local holder_file="$lock_dir/macos-app.holder"
  [[ "${LIKEMINDED_HOLDS_MACOS_APP_LOCK:-0}" == "1" ]] && return 1
  [[ -f "$holder_file" ]] || return 1
  local holder_pid
  holder_pid="$(cat "$holder_file" 2>/dev/null || true)"
  [[ -n "$holder_pid" ]] && kill -0 "$holder_pid" 2>/dev/null
}

macos_kill_if_lock_holder() {
  if macos_macos_app_lock_held_by_other; then
    local holder_pid
    holder_pid="$(cat "${LIKEMINDED_VALIDATION_LOCK_DIR:-/tmp/likeminded-validation-locks}/macos-app.holder" 2>/dev/null || true)"
    echo "[macos_kill_if_lock_holder] macos-app lock held by pid $holder_pid; refusing kill" >&2
    return 0
  fi
  macos_kill_all
}

macos_kill_all() {
  if macos_macos_app_lock_held_by_other; then
    local holder_pid
    holder_pid="$(cat "${LIKEMINDED_VALIDATION_LOCK_DIR:-/tmp/likeminded-validation-locks}/macos-app.holder" 2>/dev/null || true)"
    echo "[macos_kill_all] macos-app lock held by pid $holder_pid; skipping kill" >&2
    return 0
  fi
  # Terminate every running instance of com.gurusharan.likeminded (any copy/path).
  python3 -c "
from AppKit import NSWorkspace, NSApplicationActivateIgnoringOtherApps
import time
bid = '$MACOS_CANONICAL_BUNDLE_ID'
ws = NSWorkspace.sharedWorkspace()
apps = [a for a in ws.runningApplications() if a.bundleIdentifier() == bid]
for app in apps:
    app.forceTerminate()
if apps:
    time.sleep(0.6)
" 2>/dev/null || true

  pkill -9 -x "$MACOS_CANONICAL_EXEC" 2>/dev/null || true
  pkill -9 -f "$MACOS_CANONICAL_APP/Contents/MacOS/$MACOS_CANONICAL_EXEC" 2>/dev/null || true

  local deadline=$((SECONDS + 6))
  while (( SECONDS < deadline )); do
    if ! pgrep -x "$MACOS_CANONICAL_EXEC" >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done
  if pgrep -x "$MACOS_CANONICAL_EXEC" >/dev/null 2>&1; then
    pkill -9 -x "$MACOS_CANONICAL_EXEC" 2>/dev/null || true
    sleep 0.3
  fi

}

macos_running_pids() {
  pgrep -x "$MACOS_CANONICAL_EXEC" 2>/dev/null || true
}

# Preserve this workspace's canonical app while terminating same-name binaries
# relaunched by another worktree during an active validation flow. Bundled
# Computer targets this canonical full path; foreign copies remain invalid.
macos_kill_stray_instances() {
  local quiet="${1:-0}"
  local canonical_bin="$MACOS_CANONICAL_APP/Contents/MacOS/$MACOS_CANONICAL_EXEC"
  local pid proc_path
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    proc_path="$(ps -p "$pid" -o command= 2>/dev/null | awk '{print $1}')"
    if [[ "$proc_path" != "$canonical_bin" ]]; then
      if [[ "$quiet" != "1" ]]; then
        echo "[macos_kill_stray_instances] terminating foreign app pid=$pid path=$proc_path" >&2
      fi
      kill -9 "$pid" 2>/dev/null || true
    fi
  done < <(macos_running_pids)
}

macos_start_stray_guard() {
  if [[ -n "${MACOS_STRAY_GUARD_PID:-}" ]] && kill -0 "$MACOS_STRAY_GUARD_PID" 2>/dev/null; then
    return 0
  fi
  macos_kill_stray_instances
  local owner_pid="${BASHPID:-$$}"
  (
    while kill -0 "$owner_pid" 2>/dev/null; do
      macos_kill_stray_instances 1
      sleep "${MACOS_STRAY_GUARD_INTERVAL:-0.1}"
    done
  ) </dev/null >/dev/null 2>&1 &
  MACOS_STRAY_GUARD_PID=$!
}

macos_stop_stray_guard() {
  local guard_pid="${MACOS_STRAY_GUARD_PID:-}"
  if [[ -n "$guard_pid" ]]; then
    kill "$guard_pid" 2>/dev/null || true
    wait "$guard_pid" 2>/dev/null || true
  fi
  unset MACOS_STRAY_GUARD_PID
}

macos_assert_single_instance() {
  macos_kill_stray_instances
  local -a pids=()
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && pids+=("$pid")
  done < <(macos_running_pids)

  if (( ${#pids[@]} == 0 )); then
    echo "LikemindedMac is not running (canonical: $MACOS_CANONICAL_APP)" >&2
    return 1
  fi
  if (( ${#pids[@]} > 1 )); then
    echo "Multiple LikemindedMac instances: ${pids[*]}" >&2
    echo "Run: source script/macos_canonical_app.sh && macos_kill_all" >&2
    return 1
  fi

  local pid="${pids[0]}"
  local proc_path canonical_bin
  proc_path="$(ps -p "$pid" -o command= 2>/dev/null | awk '{print $1}')"
  canonical_bin="$MACOS_CANONICAL_APP/Contents/MacOS/$MACOS_CANONICAL_EXEC"
  if [[ "$proc_path" != "$canonical_bin" ]]; then
    echo "Stray app instance: $proc_path" >&2
    echo "Expected canonical binary: $canonical_bin" >&2
    macos_kill_all
    return 1
  fi
  echo "$pid"
}

macos_needs_build() {
  if [[ "${LIKEMINDED_SKIP_MACOS_BUILD:-0}" == "1" ]]; then
    return 1
  fi
  if [[ "${MACOS_FORCE_BUILD:-0}" == "1" || "${LIKEMINDED_FORCE_MACOS_BUILD:-0}" == "1" ]]; then
    return 0
  fi
  local exec_path="$MACOS_CANONICAL_APP/Contents/MacOS/$MACOS_CANONICAL_EXEC"
  if [[ ! -x "$exec_path" ]]; then
    return 0
  fi
  local newest_source binary_mtime
  newest_source="$(
    find "$ROOT/apps/ios-macos/Sources/LikemindedMac" \
      "$ROOT/apps/ios-macos/Sources/Shared" \
      "$ROOT/apps/ios-macos/project.yml" \
      -type f \( -name '*.swift' -o -name 'project.yml' \) -print0 2>/dev/null \
      | xargs -0 stat -f '%m' 2>/dev/null | sort -rn | head -1
  )"
  binary_mtime="$(stat -f '%m' "$exec_path" 2>/dev/null || echo 0)"
  [[ -n "$newest_source" && "$newest_source" -gt "$binary_mtime" ]]
}

macos_ensure_built() {
  local ios_dir="$ROOT/apps/ios-macos"
  macos_kill_all
  (cd "$ios_dir" && xcodegen generate)
  xcodebuild \
    -project "$ios_dir/Likeminded.xcodeproj" \
    -scheme "$MACOS_CANONICAL_SCHEME" \
    -destination 'platform=macOS' \
    -derivedDataPath "$ROOT/.build/macos" \
    build
  if [[ ! -x "$MACOS_CANONICAL_APP/Contents/MacOS/$MACOS_CANONICAL_EXEC" ]]; then
    echo "Canonical macOS app missing after build: $MACOS_CANONICAL_APP" >&2
    exit 1
  fi
}

macos_launch() {
  # Usage: macos_launch --arg1 val1 ...
  macos_kill_all
  if macos_needs_build; then
    echo "[macos_launch] rebuilding stale/missing LikemindedMac (sources newer than binary)" >&2
    macos_ensure_built
  fi
  macos_open_with_args "$@"
}

macos_open_with_args() {
  macos_kill_all
  open -F -n "$MACOS_CANONICAL_APP" --args "$@"
}
