#!/usr/bin/env bash
# Platform-scoped session mutex: one runtime owner per platform (tester XOR fixer).
set -euo pipefail

PLATFORM="macos"
WAIT_SECS="${LIKEMINDED_TESTING_LEDGER_LOCK_WAIT:-600}"

usage() {
  cat <<EOF
Usage: testing_ledger_runtime_lock.sh [--platform ios|macos] acquire|try-acquire|release|status [role]

  acquire [role]     Hold lock for this shell (wait up to LIKEMINDED_TESTING_LEDGER_LOCK_WAIT)
  try-acquire [role] Acquire or exit 1 immediately if another live pid holds the lock
  release            Release lock if held by this pid
  status             free | held pid=N role=R | stale pid=N

Lock files (one owner per platform):
  macos → /tmp/likeminded-testing-ledger-macos.lock
  ios   → /tmp/likeminded-testing-ledger-ios.lock

Shared serial resources (both platforms): cross_platform_validation_lock.sh (seed, xcodebuild)
Optional pre-check macOS: pgrep -x LikemindedMac
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    acquire|try-acquire|release|status|-h|--help)
      break
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$PLATFORM" in
  ios|macos) ;;
  *)
    echo "--platform must be ios or macos (got: $PLATFORM)" >&2
    exit 2
    ;;
esac

LOCK_FILE="/tmp/likeminded-testing-ledger-${PLATFORM}.lock"

pid_alive() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

read_holder() {
  if [[ -f "$LOCK_FILE" ]]; then
    awk 'NR==1 {print $1, $2}' "$LOCK_FILE"
  fi
}

cmd_status() {
  local pid role
  read -r pid role < <(read_holder) || true
  if [[ -z "$pid" ]]; then
    echo "free platform=$PLATFORM"
    return 0
  fi
  if pid_alive "$pid"; then
    echo "held platform=$PLATFORM pid=$pid role=${role:-session}"
    return 0
  fi
  echo "stale platform=$PLATFORM pid=$pid"
}

try_claim_lock() {
  local role="${1:-session}"
  local pid _existing
  read -r pid _existing < <(read_holder) || true
  if [[ -n "$pid" ]] && pid_alive "$pid"; then
    return 1
  fi
  [[ -n "$pid" ]] && rm -f "$LOCK_FILE"
  if echo "$$ $role" > "$LOCK_FILE" 2>/dev/null; then
    local check_pid
    read -r check_pid _ < <(read_holder) || true
    if [[ "$check_pid" == "$$" ]]; then
      echo "acquired platform=$PLATFORM pid=$$ role=$role"
      return 0
    fi
  fi
  return 1
}

cmd_acquire() {
  local role="${1:-session}"
  local deadline=$((SECONDS + WAIT_SECS))
  while (( SECONDS < deadline )); do
    if try_claim_lock "$role"; then
      return 0
    fi
    sleep 1
  done
  echo "timeout acquiring testing-ledger runtime lock ($(cmd_status))" >&2
  exit 1
}

cmd_try_acquire() {
  local role="${1:-session}"
  if try_claim_lock "$role"; then
    return 0
  fi
  echo "runtime lock held — another agent owns ${PLATFORM} CUA lane ($(cmd_status))" >&2
  exit 1
}

cmd_release() {
  local pid
  read -r pid _ < <(read_holder) || true
  if [[ -z "$pid" ]]; then
    echo "no lock held platform=$PLATFORM"
    return 0
  fi
  if [[ "$pid" != "$$" ]]; then
    echo "lock held by pid $pid, not $$ (platform=$PLATFORM)" >&2
    exit 1
  fi
  rm -f "$LOCK_FILE"
  echo "released platform=$PLATFORM"
}

case "${1:-}" in
  acquire) cmd_acquire "${2:-session}" ;;
  try-acquire) cmd_try_acquire "${2:-session}" ;;
  release) cmd_release ;;
  status) cmd_status ;;
  -h|--help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
