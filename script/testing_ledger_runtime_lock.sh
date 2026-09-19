#!/usr/bin/env bash
# Platform-scoped session mutex: one runtime owner per platform (tester XOR fixer).
set -euo pipefail

PLATFORM="macos"
WAIT_SECS="${LIKEMINDED_TESTING_LEDGER_LOCK_WAIT:-600}"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

usage() {
  cat <<EOF
Usage: testing_ledger_runtime_lock.sh [--platform ios|macos] acquire|try-acquire|release|status [role]
       testing_ledger_runtime_lock.sh [--platform ios|macos] lease-acquire [role]
       testing_ledger_runtime_lock.sh [--platform ios|macos] lease-release <token>

  acquire [role]     Hold lock for this shell (wait up to LIKEMINDED_TESTING_LEDGER_LOCK_WAIT)
  try-acquire [role] Acquire or exit 1 immediately if another live pid holds the lock
  release            Release lock if held by this pid
  lease-acquire      Start a cross-command holder and print its release token
  lease-release      Release the live cross-command holder matching <token>
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
    acquire|try-acquire|release|status|lease-acquire|lease-release|lease-hold|-h|--help)
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
    awk 'NR==1 {print $1, $2, $3}' "$LOCK_FILE"
  fi
}

cmd_status() {
  local pid role _token
  read -r pid role _token < <(read_holder) || true
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
  echo "runtime lock held — another agent owns the ${PLATFORM} native proof lane ($(cmd_status))" >&2
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
    if ! pid_alive "$pid"; then
      rm -f "$LOCK_FILE"
      echo "released stale platform=$PLATFORM pid=$pid"
      return 0
    fi
    echo "lock held by pid $pid, not $$ (platform=$PLATFORM)" >&2
    exit 1
  fi
  rm -f "$LOCK_FILE"
  echo "released platform=$PLATFORM"
}

lease_cleanup() {
  local pid _role token
  read -r pid _role token < <(read_holder) || true
  if [[ "$pid" == "$$" && "$token" == "${LEASE_TOKEN:-}" ]]; then
    rm -f "$LOCK_FILE"
  fi
}

lease_terminate() {
  lease_cleanup
  exit 0
}

cmd_lease_hold() {
  local role="${1:-computer-prove}"
  local token="${2:-}"
  [[ -n "$token" ]] || exit 2
  LEASE_TOKEN="$token"
  export LEASE_TOKEN
  trap lease_cleanup EXIT
  trap lease_terminate INT TERM

  if ! (
    set -o noclobber
    printf '%s %s %s\n' "$$" "$role" "$token" > "$LOCK_FILE"
  ) 2>/dev/null; then
    exit 1
  fi

  while true; do
    sleep 1
  done
}

cmd_lease_acquire() {
  local role="${1:-computer-prove}"
  local pid _role _token
  read -r pid _role _token < <(read_holder) || true
  if [[ -n "$pid" ]] && pid_alive "$pid"; then
    echo "runtime lock held — another agent owns the ${PLATFORM} native proof lane ($(cmd_status))" >&2
    exit 1
  fi
  [[ -n "$pid" ]] && rm -f "$LOCK_FILE"

  local token holder_pid check_pid check_token _
  token="$(date +%s)-$$-${RANDOM}-${RANDOM}"
  nohup "$SELF" --platform "$PLATFORM" lease-hold "$role" "$token" \
    </dev/null >>"/tmp/likeminded-testing-ledger-${PLATFORM}-lease.log" 2>&1 &
  holder_pid=$!

  for _ in $(seq 1 40); do
    read -r check_pid _ check_token < <(read_holder) || true
    if [[ "$check_pid" == "$holder_pid" && "$check_token" == "$token" ]] && pid_alive "$holder_pid"; then
      echo "acquired platform=$PLATFORM pid=$holder_pid role=$role token=$token"
      return 0
    fi
    if ! pid_alive "$holder_pid"; then
      break
    fi
    sleep 0.05
  done

  kill "$holder_pid" 2>/dev/null || true
  echo "failed to establish cross-command lease platform=$PLATFORM" >&2
  exit 1
}

cmd_lease_release() {
  local supplied_token="${1:-}"
  local pid role token _
  [[ -n "$supplied_token" ]] || {
    echo "lease-release requires the token printed by lease-acquire" >&2
    exit 2
  }
  read -r pid role token < <(read_holder) || true
  if [[ -z "$pid" ]]; then
    echo "no lock held platform=$PLATFORM"
    return 0
  fi
  if [[ "$token" != "$supplied_token" ]]; then
    echo "lease token mismatch platform=$PLATFORM" >&2
    exit 1
  fi

  kill "$pid" 2>/dev/null || true
  for _ in $(seq 1 40); do
    if ! pid_alive "$pid"; then
      break
    fi
    sleep 0.05
  done
  if pid_alive "$pid"; then
    echo "lease holder did not exit platform=$PLATFORM pid=$pid" >&2
    exit 1
  fi
  read -r pid _ token < <(read_holder) || true
  if [[ "$token" == "$supplied_token" ]]; then
    rm -f "$LOCK_FILE"
  fi
  echo "released platform=$PLATFORM role=${role:-computer-prove}"
}

case "${1:-}" in
  acquire) cmd_acquire "${2:-session}" ;;
  try-acquire) cmd_try_acquire "${2:-session}" ;;
  release) cmd_release ;;
  lease-acquire) cmd_lease_acquire "${2:-computer-prove}" ;;
  lease-release) cmd_lease_release "${2:-}" ;;
  lease-hold) cmd_lease_hold "${2:-computer-prove}" "${3:-}" ;;
  status) cmd_status ;;
  -h|--help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
