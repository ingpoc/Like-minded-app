#!/usr/bin/env bash
# End-to-end iOS account-delete failure and recovery check. Requires Xcode,
# a booted simulator, IDB, and curl. API request logs contain token hashes only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BUNDLE_ID="${BUNDLE_ID:-com.gurusharan.likeminded}"
PORT=8797
API_URL="http://127.0.0.1:$PORT"
SIMULATOR_ID="${SIMULATOR_ID:-}"
TEST_USER="ios-delete-failure-check"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lm-delete-check.XXXXXX")"
DB_DIR="$TMP_DIR/db"
REQUEST_LOG="$TMP_DIR/requests.log"
API_LOG="$TMP_DIR/api.log"
API_PID=""
IDB_CTL="$ROOT/validation/idb_ctl.sh"

cleanup() {
  if [[ -n "$API_PID" ]] && kill -0 "$API_PID" >/dev/null 2>&1; then
    kill "$API_PID" >/dev/null 2>&1 || true
    wait "$API_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

command -v xcrun >/dev/null || { echo "xcrun is required" >&2; exit 1; }
IDB_AVAILABLE=0
command -v idb >/dev/null && IDB_AVAILABLE=1
IDB_TAP_AVAILABLE=0
if [[ "$IDB_AVAILABLE" == 1 ]] && [[ -d "$(xcode-select -p)/Library/PrivateFrameworks/SimulatorKit.framework" ]]; then
  IDB_TAP_AVAILABLE=1
fi
if [[ -z "$SIMULATOR_ID" ]]; then
  SIMULATOR_ID="$(xcrun simctl list devices booted | sed -nE 's/.*\(([A-F0-9-]{36})\) \(Booted\).*/\1/p' | head -1)"
fi
[[ -n "$SIMULATOR_ID" ]] || { echo "Boot an iOS simulator, then rerun this check" >&2; exit 1; }
IDB_UDID="$SIMULATOR_ID"; export IDB_UDID
if curl -fsS "$API_URL/health" >/dev/null 2>&1; then
  echo "Port $PORT is already occupied; refusing to stop an unowned API" >&2
  exit 1
fi

start_api() {
  local failure="$1"
  mkdir -p "$DB_DIR"
  (
    cd "$ROOT"
    PORT="$PORT" HOST=127.0.0.1 APPLE_AUTH_BYPASS=1 \
      NODE_ENV=test SESSION_SECRET=local-delete-test-session-secret \
      LIKEMINDED_DB_DIR="$DB_DIR" LIKEMINDED_TEST_FAIL_DELETE="$failure" \
      LIKEMINDED_TEST_REQUEST_LOG="$REQUEST_LOG" \
      exec node services/api/src/server.js
  ) >"$API_LOG" 2>&1 &
  API_PID=$!
  for _ in {1..80}; do
    kill -0 "$API_PID" >/dev/null 2>&1 || { echo "Test API exited early" >&2; cat "$API_LOG" >&2; return 1; }
    curl -fsS "$API_URL/health" >/dev/null 2>&1 && return 0
    sleep 0.25
  done
  echo "Test API did not become healthy" >&2
  cat "$API_LOG" >&2
  return 1
}

stop_api() {
  if [[ -n "$API_PID" ]] && kill -0 "$API_PID" >/dev/null 2>&1; then
    kill "$API_PID" >/dev/null 2>&1 || true
    wait "$API_PID" 2>/dev/null || true
  fi
  API_PID=""
}

tree() { "$IDB_CTL" describe > "$TMP_DIR/tree.json"; }
wait_for_text() {
  local expected="$1"
  for _ in {1..40}; do
    tree
    if python3 - "$TMP_DIR/tree.json" "$expected" <<'PY'
import json, sys
data=json.load(open(sys.argv[1]))
text='\n'.join(str(e.get('AXLabel') or '')+' '+str(e.get('AXValue') or '') for e in data)
sys.exit(0 if sys.argv[2] in text else 1)
PY
    then return 0; fi
    sleep 0.25
  done
  echo "Accessibility tree did not contain: $expected" >&2
  cat "$TMP_DIR/tree.json" >&2
  return 1
}
delete_count() { [[ -f "$REQUEST_LOG" ]] && rg -c '^DELETE /v1/me/account proof=false$' "$REQUEST_LOG" || echo 0; }

api_contract_fallback() {
  echo "IDB interaction unavailable; verifying API request counts and session fingerprints instead."
  if [[ "$IDB_AVAILABLE" == 1 ]]; then
    tree
    python3 - "$TMP_DIR/tree.json" <<'PY'
import json,sys
labels={str(e.get('AXLabel') or '') for e in json.load(open(sys.argv[1]))}
assert 'Delete account' in labels and 'Sign out' in labels, 'signed-in settings UI is absent'
PY
  fi
  [[ "$(delete_count)" == 0 ]] || { echo "DELETE was sent before confirmation" >&2; return 1; }
  APP_AUTH_HASH="$(sed -n 's/^TOKEN POST \/v1\/auth\/apple //p' "$REQUEST_LOG" | head -1)"
  [[ -n "$APP_AUTH_HASH" ]] || { echo "simulator did not authenticate with the local API" >&2; return 1; }
  API_URL="$API_URL" TEST_USER="$TEST_USER" REQUEST_LOG="$REQUEST_LOG" TOKEN_FILE="$TMP_DIR/session.token" node <<'NODE'
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
(async () => {
  const auth = await fetch(`${process.env.API_URL}/v1/auth/apple`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ identityToken: process.env.TEST_USER, fullName: "Delete Test" })
  });
  assert.equal(auth.status, 200);
  const token = (await auth.json()).sessionToken;
  fs.writeFileSync(process.env.TOKEN_FILE, token, { mode: 0o600 });
  const before = fs.existsSync(process.env.REQUEST_LOG) ? fs.readFileSync(process.env.REQUEST_LOG, "utf8") : "";
  assert.equal(before.split("\n").filter(line => line.startsWith("DELETE ")).length, 0);
  const failed = await fetch(`${process.env.API_URL}/v1/me/account`, { method: "DELETE", headers: { authorization: `Bearer ${token}` } });
  assert.equal(failed.status, 500);
  const profile = await fetch(`${process.env.API_URL}/v1/me/notifications`, { headers: { authorization: `Bearer ${token}` } });
  assert.equal(profile.status, 200);
  const fingerprint = crypto.createHash("sha256").update(token).digest("hex");
  const log = fs.readFileSync(process.env.REQUEST_LOG, "utf8");
  assert.match(log, new RegExp(`TOKEN POST /v1/auth/apple ${fingerprint}`));
  assert.match(log, new RegExp(`TOKEN GET /v1/me/notifications ${fingerprint}`));
  assert.equal(log.split("\n").filter(line => line === "DELETE /v1/me/account proof=false").length, 1);
})().catch(error => { console.error(error.message); process.exitCode = 1; });
NODE
  SIMCTL_CHILD_LIKEMINDED_API_BASE_URL="$API_URL" xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID" --likeminded-start-settings >/dev/null
  for _ in {1..40}; do
    grep -Fq "TOKEN GET /v1/me/notifications $APP_AUTH_HASH" "$REQUEST_LOG" && break
    sleep 0.25
  done
  grep -Fq "TOKEN GET /v1/me/notifications $APP_AUTH_HASH" "$REQUEST_LOG" || { echo "app's persisted session did not survive failed deletion" >&2; return 1; }
  stop_api
  start_api 0
  API_URL="$API_URL" REQUEST_LOG="$REQUEST_LOG" TOKEN_FILE="$TMP_DIR/session.token" node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
(async () => {
  const token = fs.readFileSync(process.env.TOKEN_FILE, "utf8");
  const deleted = await fetch(`${process.env.API_URL}/v1/me/account`, { method: "DELETE", headers: { authorization: `Bearer ${token}` } });
  assert.equal(deleted.status, 200);
  const stale = await fetch(`${process.env.API_URL}/v1/me/notifications`, { headers: { authorization: `Bearer ${token}` } });
  assert.equal(stale.status, 401);
})().catch(error => { console.error(error.message); process.exitCode = 1; });
NODE
  [[ "$(delete_count)" == 2 ]] || { echo "API fallback expected two proof-free DELETEs" >&2; return 1; }
  echo "PASS API fallback: zero requests before confirmation, one 500 without Apple proof, same session still valid, successful delete rejects that token."
}

start_api 500
PORT="$PORT" SIMULATOR_ID="$SIMULATOR_ID" "$ROOT/script/build_and_run.sh" build >/dev/null
SIMCTL_CHILD_LIKEMINDED_API_BASE_URL="$API_URL" xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID" \
  --likeminded-reset-auth-session --likeminded-dev-auth-bypass --likeminded-dev-auth-token "$TEST_USER" --likeminded-start-settings >/dev/null

if [[ "$IDB_TAP_AVAILABLE" != 1 ]]; then
  if [[ "$IDB_AVAILABLE" == 1 ]]; then
    wait_for_text "Delete account"
    wait_for_text "Sign out"
  fi
  api_contract_fallback
  exit 0
fi

for _ in {1..40}; do
  tree
  if python3 - "$TMP_DIR/tree.json" <<'PY'
import json,sys
labels={str(e.get('AXLabel') or '') for e in json.load(open(sys.argv[1]))}
sys.exit(0 if 'Delete account' in labels and 'Sign out' in labels else 1)
PY
  then break; fi
  "$IDB_CTL" swipe-up-short >/dev/null 2>&1 || true
  sleep 0.25
done
wait_for_text "Delete account"
"$IDB_CTL" tap "Delete account" >/dev/null
wait_for_text "Delete your account?"
python3 - "$TMP_DIR/tree.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
buttons=[e for e in data if e.get('type')=='Button' and e.get('AXLabel') in ('Cancel','Delete account')]
cancel=next((e for e in buttons if e.get('AXLabel')=='Cancel'),None)
delete=next((e for e in buttons if e.get('AXLabel')=='Delete account'),None)
assert cancel and delete, 'confirmation buttons missing from accessibility tree'
assert cancel['frame']['y'] < delete['frame']['y'], 'Cancel must appear before Delete account'
PY
"$IDB_CTL" screenshot "$TMP_DIR/delete-confirmation.png" >/dev/null
"$IDB_CTL" tap "Cancel" >/dev/null
sleep 0.5
[[ "$(delete_count)" == 0 ]] || { echo "Cancel sent a DELETE request" >&2; exit 1; }

"$IDB_CTL" tap "Delete account" >/dev/null
wait_for_text "Delete your account?"
"$IDB_CTL" tap "Delete account" >/dev/null
wait_for_text "Account not deleted"
python3 - "$TMP_DIR/tree.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
text='\n'.join(str(e.get('AXLabel') or '')+' '+str(e.get('AXValue') or '') for e in data)
assert 'Account not deleted' in text, 'failure alert title is missing'
assert "Your account wasn't deleted. Check your connection and try again." in text, 'plain failure alert text is missing'
PY
"$IDB_CTL" screenshot "$TMP_DIR/delete-failure-alert.png" >/dev/null
[[ "$(delete_count)" == 1 ]] || { echo "Confirmation did not send exactly one DELETE" >&2; exit 1; }
grep -Fq 'TOKEN POST /v1/auth/apple ' "$REQUEST_LOG"
AUTH_HASH="$(sed -n 's/^TOKEN POST \/v1\/auth\/apple //p' "$REQUEST_LOG" | head -1)"
[[ -n "$AUTH_HASH" ]]
"$IDB_CTL" tap "OK" >/dev/null
SIMCTL_CHILD_LIKEMINDED_API_BASE_URL="$API_URL" xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID" --likeminded-start-settings >/dev/null
wait_for_text "Sign out"
grep -Fq "TOKEN GET /v1/me/notifications $AUTH_HASH" "$REQUEST_LOG" || { echo "same session token did not work after failed deletion" >&2; exit 1; }

stop_api
start_api 0
SIMCTL_CHILD_LIKEMINDED_API_BASE_URL="$API_URL" xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID" --likeminded-start-settings >/dev/null
wait_for_text "Delete account"
"$IDB_CTL" tap "Delete account" >/dev/null
wait_for_text "Delete your account?"
"$IDB_CTL" tap "Delete account" >/dev/null
wait_for_text "Sign in with Apple"
[[ "$(delete_count)" == 2 ]] || { echo "Success case did not send its single DELETE" >&2; exit 1; }
echo "PASS iOS delete: Cancel sent none; confirm sent one DELETE without Apple proof; failure alert title/text and signed-in session verified; success signed out."
