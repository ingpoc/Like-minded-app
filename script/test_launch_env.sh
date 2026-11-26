#!/usr/bin/env bash
# Isolated launch-contract test: fake xcrun/open/curl/node and inspect only
# their URLs/arguments. No simulator, API socket, app, or secrets are used.
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lm-launch-env.XXXXXX")"
trap 'if [[ -n "${TEST_NODE_PID:-}" ]]; then kill "$TEST_NODE_PID" >/dev/null 2>&1 || true; fi; rm -rf "$TMP_ROOT"' EXIT
TEST_ROOT="$TMP_ROOT/repo"
BIN="$TMP_ROOT/bin"
LOG="$TMP_ROOT/record.log"
mkdir -p "$TEST_ROOT/script" "$TEST_ROOT/apps/ios-macos" "$TEST_ROOT/services/api/src" "$TEST_ROOT/output" "$BIN"
cp "$SOURCE_ROOT/script/run_api.sh" "$SOURCE_ROOT/script/verify_local_product_loop.sh" \
   "$SOURCE_ROOT/script/verify_simulator_local.sh" "$SOURCE_ROOT/script/build_and_run.sh" \
   "$SOURCE_ROOT/script/macos_canonical_app.sh" "$TEST_ROOT/script/"
printf 'PORT=8796\nAPPLE_AUTH_BYPASS=0\nLIKEMINDED_DB_DIR=/tmp/unisolated-test-override\nEXAMPLE_SETTING=local\n' > "$TEST_ROOT/.env.local"
touch "$TEST_ROOT/apps/ios-macos/project.yml" "$TEST_ROOT/services/api/src/server.js"

cat > "$BIN/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$TEST_LAUNCH_LOG"
[[ -s "$TEST_NODE_PID_FILE" ]] || exit 7
printf '{"ok":true,"walletAuth":true}\n'
EOF
cat > "$BIN/xcrun" <<'EOF'
#!/usr/bin/env bash
printf 'xcrun env=%s argv=%s\n' "${SIMCTL_CHILD_LIKEMINDED_API_BASE_URL:-}" "$*" >> "$TEST_LAUNCH_LOG"
if [[ "$*" == "simctl list devices available" ]]; then
  printf 'iPhone 17 (TESTSIM)\n'
  exit 0
fi
if [[ "$*" == *"screenshot"* ]]; then
  last="${!#}"
  dd if=/dev/zero of="$last" bs=1024 count=12 2>/dev/null
fi
printf 'launched\n'
EOF
cat > "$BIN/open" <<'EOF'
#!/usr/bin/env bash
printf 'open %s\n' "$*" >> "$TEST_LAUNCH_LOG"
if [[ "$*" == *"--args"* ]]; then touch "$TEST_OPEN_MARKER"; fi
EOF
cat > "$BIN/node" <<'EOF'
#!/usr/bin/env bash
[[ "${APPLE_AUTH_BYPASS:-}" == 1 ]] || { printf 'node-env-check failed-bypass\n' >> "$TEST_LAUNCH_LOG"; exit 3; }
case "${LIKEMINDED_DB_DIR:-}" in
  */output/validation/*) ;;
  *) printf 'node-env-check failed-store\n' >> "$TEST_LAUNCH_LOG"; exit 4 ;;
esac
printf 'node PORT=%s argv=%s\n' "${PORT:-}" "$*" >> "$TEST_LAUNCH_LOG"
printf '%s\n' "$$" > "$TEST_NODE_PID_FILE"
exec /bin/sleep 60
EOF
cat > "$BIN/npm" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == "run verify:simulator-local" ]]; then
  PORT="$PORT" LIKEMINDED_API_OWNER=parent bash "$TEST_REPO/script/verify_simulator_local.sh"
  kill -0 "$(cat "$TEST_NODE_PID_FILE")"
  curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null
  printf 'parent-api-healthy-after-helper\n' >> "$TEST_LAUNCH_LOG"
  exit 0
fi
exit 2
EOF
cat > "$BIN/xcodegen" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$BIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$BIN/lsof" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat > "$BIN/python3" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$BIN/pkill" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
if [[ -f "$TEST_OPEN_MARKER" ]]; then printf '4242\n'; exit 0; fi
exit 1
EOF
cat > "$BIN/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$BIN"/*

export TEST_LAUNCH_LOG="$LOG" TEST_REPO="$TEST_ROOT"
export TEST_NODE_PID_FILE="$TMP_ROOT/node.pid"
export TEST_OPEN_MARKER="$TMP_ROOT/app-opened"
export PATH="$BIN:$PATH"
export PORT=8795 SIMULATOR_ID=TESTSIM LIKEMINDED_HOLDS_MACOS_APP_LOCK=1
bash "$TEST_ROOT/script/verify_local_product_loop.sh" > "$TMP_ROOT/output.log" 2>&1 &
TEST_RUN_PID=$!
for _ in {1..100}; do
  [[ -s "$TEST_NODE_PID_FILE" ]] && break
  /bin/sleep 0.05
done
if [[ ! -s "$TEST_NODE_PID_FILE" ]]; then
  cat "$TMP_ROOT/output.log" >&2
  cat "$LOG" >&2
  exit 1
fi
TEST_NODE_PID="$(cat "$TEST_NODE_PID_FILE")"
if ! wait "$TEST_RUN_PID"; then
  cat "$TMP_ROOT/output.log" >&2
  cat "$LOG" >&2
  exit 1
fi

grep -Fq 'node PORT=8795 argv=' "$LOG"
grep -Fq 'curl -fsS http://127.0.0.1:8795/health' "$LOG"
grep -Fq 'parent-api-healthy-after-helper' "$LOG"
grep -Fq -- '--env LIKEMINDED_API_BASE_URL=http://127.0.0.1:8795' "$LOG"
launch_count="$(rg -c 'xcrun env=http://127.0.0.1:8795 argv=simctl launch' "$LOG" || true)"
[[ "$launch_count" -ge 3 ]]
if rg -q 'http://127\.0\.0\.1:(8787|8765|8788|53366|53367)' "$LOG"; then
  echo "A protected legacy port appeared in recorded launches" >&2
  exit 1
fi
echo "PASS: port 8795 reached API startup, health, nested and direct simulator launches, and macOS open; parent API stayed healthy."
