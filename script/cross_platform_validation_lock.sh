#!/usr/bin/env bash
# flock coordination for parallel iOS/macOS validation workers.
# Uses flock(1) on Linux; BSD lockf(1) on macOS (same lock files under LOCK_DIR).
set -euo pipefail

LOCK_DIR="${LIKEMINDED_VALIDATION_LOCK_DIR:-/tmp/likeminded-validation-locks}"
WAIT_SECS="${LIKEMINDED_LOCK_WAIT_SECS:-600}"
SESSION_DIR="$LOCK_DIR/sessions"

VALID_RESOURCES=(
  api
  seed
  ios-sim
  macos-app
  macos-capture
  xcodebuild-ios
  xcodebuild-macos
)

usage() {
  cat <<EOF
Usage: cross_platform_validation_lock.sh <command> ...

Commands:
  with_lock <resource> <command...>   Run command while holding flock (waits up to ${WAIT_SECS}s)
  acquire <resource>                  Acquire lock in this shell (pair with release)
  release <resource>                  Release lock acquired by acquire in this shell
  list                                Show current lock holders

Resources: ${VALID_RESOURCES[*]}
Lock dir: $LOCK_DIR
EOF
}

mkdir -p "$LOCK_DIR" "$SESSION_DIR"

if command -v flock >/dev/null 2>&1; then
  LOCK_BACKEND="flock"
elif [[ "$(uname -s)" == "Darwin" ]] && command -v lockf >/dev/null 2>&1; then
  LOCK_BACKEND="lockf"
else
  echo "no flock/lockf available for validation locks" >&2
  exit 1
fi

is_valid_resource() {
  local want="$1"
  local r
  for r in "${VALID_RESOURCES[@]}"; do
    [[ "$r" == "$want" ]] && return 0
  done
  return 1
}

lock_path() {
  echo "$LOCK_DIR/$1.lock"
}

holder_path() {
  echo "$LOCK_DIR/$1.holder"
}

acquired_pid_file() {
  local session_id="${LIKEMINDED_LOCK_SESSION_ID:-$PPID}"
  echo "$SESSION_DIR/$session_id.$1"
}

require_resource() {
  local resource="$1"
  if ! is_valid_resource "$resource"; then
    echo "unknown resource: $resource (valid: ${VALID_RESOURCES[*]})" >&2
    exit 2
  fi
}

run_file_lock() {
  local lock_file="$1"
  shift
  case "$LOCK_BACKEND" in
    flock)
      (
        flock -w "$WAIT_SECS" 200 || exit 1
        "$@"
      ) 200>"$lock_file"
      ;;
    lockf)
      lockf -t "$WAIT_SECS" "$lock_file" "$@"
      ;;
  esac
}

start_holder() {
  local lock_file="$1"
  local holder_file="$2"
  case "$LOCK_BACKEND" in
    flock)
      (
        flock -w "$WAIT_SECS" 200 || exit 1
        echo $$ >"$holder_file"
        trap 'rm -f "$holder_file"' EXIT
        while true; do sleep 86400; done
      ) 200>"$lock_file" &
      ;;
    lockf)
      lockf -t "$WAIT_SECS" "$lock_file" sh -c 'echo $$ > "$1"; while true; do sleep 86400; done' _ "$holder_file" &
      ;;
  esac
}

with_lock() {
  local resource="$1"
  shift
  require_resource "$resource"
  if (($# == 0)); then
    echo "with_lock requires a command" >&2
    exit 2
  fi

  local lock_file start
  lock_file="$(lock_path "$resource")"
  start=$SECONDS
  echo "[likeminded-lock] waiting for '$resource' (up to ${WAIT_SECS}s) pid=$$" >&2

  run_file_lock "$lock_file" bash -c '
    resource="$1"
    start="$2"
    shift 2
    waited=$((SECONDS - start))
    if (( waited > 0 )); then
      echo "[likeminded-lock] acquired ${resource} after ${waited}s pid=$$" >&2
    else
      echo "[likeminded-lock] acquired ${resource} pid=$$" >&2
    fi
    exec "$@"
  ' _ "$resource" "$start" "$@"
}

acquire() {
  local resource="$1"
  require_resource "$resource"

  local lock_file holder_file pid_file bg start
  lock_file="$(lock_path "$resource")"
  holder_file="$(holder_path "$resource")"
  pid_file="$(acquired_pid_file "$resource")"

  if [[ -f "$pid_file" ]]; then
    echo "[likeminded-lock] already hold '$resource' in shell $$" >&2
    return 0
  fi

  start=$SECONDS
  echo "[likeminded-lock] waiting for '$resource' (acquire, up to ${WAIT_SECS}s) pid=$$" >&2

  start_holder "$lock_file" "$holder_file"
  bg=$!

  local deadline=$((SECONDS + WAIT_SECS))
  while (( SECONDS < deadline )); do
    if [[ -f "$holder_file" ]] && kill -0 "$bg" 2>/dev/null; then
      echo "$bg" >"$pid_file"
      echo "[likeminded-lock] acquired '$resource' after $((SECONDS - start))s holder=$bg" >&2
      return 0
    fi
    if ! kill -0 "$bg" 2>/dev/null; then
      echo "[likeminded-lock] failed to acquire '$resource'" >&2
      return 1
    fi
    sleep 0.1
  done

  kill "$bg" 2>/dev/null || true
  rm -f "$holder_file"
  echo "[likeminded-lock] TIMEOUT acquiring '$resource' after ${WAIT_SECS}s" >&2
  return 1
}

release() {
  local resource="$1"
  require_resource "$resource"

  local pid_file bg
  pid_file="$(acquired_pid_file "$resource")"
  if [[ ! -f "$pid_file" ]]; then
    echo "[likeminded-lock] no acquire for '$resource' in shell $$" >&2
    return 1
  fi

  bg="$(cat "$pid_file")"
  kill "$bg" 2>/dev/null || true
  rm -f "$pid_file" "$(holder_path "$resource")"
  echo "[likeminded-lock] released '$resource'" >&2
}

list_locks() {
  local resource holder
  for resource in "${VALID_RESOURCES[@]}"; do
    holder="$(holder_path "$resource")"
    if [[ -f "$holder" ]]; then
      echo "$resource: holder pid $(cat "$holder" 2>/dev/null || echo unknown)"
    else
      echo "$resource: free"
    fi
  done
}

cmd="${1:-}"
case "$cmd" in
  with_lock)
    shift
    with_lock "$@"
    ;;
  acquire)
    shift
    [[ $# -eq 1 ]] || { usage >&2; exit 2; }
    acquire "$1"
    ;;
  release)
    shift
    [[ $# -eq 1 ]] || { usage >&2; exit 2; }
    release "$1"
    ;;
  list)
    list_locks
    ;;
  -h|--help|help|"")
    usage
    [[ -n "$cmd" ]] || exit 0
    ;;
  *)
    echo "unknown command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
