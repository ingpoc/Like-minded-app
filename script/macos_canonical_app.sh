#!/usr/bin/env bash
# Single source of truth for the macOS validation app binary.
# One app only: .build/macos/.../LikemindedMac.app (window title "Likeminded").
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export MACOS_CANONICAL_APP="$ROOT/.build/macos/Build/Products/Debug/LikemindedMac.app"
export MACOS_CANONICAL_BUNDLE_ID="com.likeminded.mac"
export MACOS_CANONICAL_SCHEME="LikemindedMac"
export MACOS_CANONICAL_EXEC="LikemindedMac"
export MACOS_CUA_CACHE_DIR="${MACOS_CUA_CACHE_DIR:-$HOME/.cache/macos-cua}"

macos_clear_cua_cache() {
  rm -f "$MACOS_CUA_CACHE_DIR"/*.json 2>/dev/null || true
}

macos_kill_all() {
  # Terminate every running instance of com.likeminded.mac (any copy/path).
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

  macos_clear_cua_cache
}

macos_running_pids() {
  pgrep -x "$MACOS_CANONICAL_EXEC" 2>/dev/null || true
}

macos_assert_single_instance() {
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
  if [[ "${MACOS_FORCE_BUILD:-0}" == "1" ]] || [[ ! -x "$MACOS_CANONICAL_APP/Contents/MacOS/$MACOS_CANONICAL_EXEC" ]]; then
    macos_ensure_built
  fi
  macos_open_with_args "$@"
}

macos_open_with_args() {
  macos_kill_all
  open -F -n "$MACOS_CANONICAL_APP" --args "$@"
  macos_clear_cua_cache
}
