#!/usr/bin/env bash
# Capture iOS simulator screenshots for validation ledger / mockup compare.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/apps/ios-macos"
OUT_DIR="$ROOT_DIR/output/validation/ios-screens"
BUNDLE_ID="${BUNDLE_ID:-com.likeminded.app}"
API_LOG="/tmp/likeminded-ios-validation-api.log"
api_pid=""

common_args=(
  --likeminded-reset-auth-session
  --likeminded-dev-auth-bypass
  --likeminded-dev-auth-token validation-priya
  --likeminded-dev-auth-name "Priya Shah"
)

captures=(
  "auth-gate|--likeminded-reset-auth-session"
  "onboarding|${common_args[*]} --likeminded-start-profile"
  "meet|${common_args[*]}"
  "circles|${common_args[*]} --likeminded-start-circles"
  "communities|${common_args[*]} --likeminded-start-communities"
  "profile-populated|${common_args[*]} --likeminded-start-profile"
  "soulmate|${common_args[*]} --likeminded-start-soulmate"
)

cleanup() {
  if [[ -n "$api_pid" ]]; then
    kill "$api_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

wait_for_api() {
  local deadline=$((SECONDS + 15))
  while (( SECONDS < deadline )); do
    if curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.3
  done
  echo "validation API did not become healthy; log follows:" >&2
  cat "$API_LOG" >&2 || true
  exit 1
}

launch_and_capture() {
  local name="$1"
  shift
  local -a args=("$@")
  xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" "${args[@]}" >/dev/null
  sleep 4
  xcrun simctl io booted screenshot "$OUT_DIR/$name.png"
  local size
  size=$(stat -f%z "$OUT_DIR/$name.png" 2>/dev/null || echo 0)
  if (( size < 10000 )); then
    echo "WARN: $name.png is ${size}B — likely blank" >&2
    return 1
  fi
  echo "captured $name.png (${size}B)"
}

mkdir -p "$OUT_DIR"

if ! curl -fsS "http://127.0.0.1:${PORT:-8787}/health" >/dev/null 2>&1; then
  if lsof -ti :"${PORT:-8787}" >/dev/null 2>&1; then
    kill "$(lsof -ti :"${PORT:-8787}")" >/dev/null 2>&1 || true
    sleep 1
  fi
  "$ROOT_DIR/script/run_validation_api.sh" >"$API_LOG" 2>&1 &
  api_pid="$!"
  wait_for_api
fi

(cd "$ROOT_DIR" && npm run reset:validation-data >/tmp/likeminded-ios-validation-seed.log)

"$ROOT_DIR/script/build_and_run.sh" run >/tmp/likeminded-ios-build.log 2>&1 || {
  tail -20 /tmp/likeminded-ios-build.log >&2
  exit 1
}
sleep 2

captured=0
failed=0
for entry in "${captures[@]}"; do
  name="${entry%%|*}"
  args="${entry#*|}"
  # shellcheck disable=SC2206
  arg_array=($args)
  if launch_and_capture "$name" "${arg_array[@]}"; then
    captured=$((captured + 1))
  else
    failed=$((failed + 1))
  fi
done

echo "iOS captures: $captured/${#captures[@]} succeeded, $failed failed"
echo "Screenshots: $OUT_DIR"
