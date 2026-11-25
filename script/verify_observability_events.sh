#!/usr/bin/env bash
# OBS-01 acceptance: API, smoke and test runs write JSONL events that developer-observability collects.
# Writes events and the scoped collect under a temp dir; never touches the shared observability store.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
WORK="${OBS_VERIFY_DIR:-$(mktemp -d /tmp/likeminded-obs-verify.XXXXXX)}"
mkdir -p "$WORK"
export LIKEMINDED_EVENTS_FILE="$WORK/likeminded-events.jsonl"
export LIKEMINDED_RUN_ID="obs-verify-$(date +%s)"
rm -f "$LIKEMINDED_EVENTS_FILE"

npm run -s test:api > "$WORK/test-api.log" 2>&1 || { echo "FAIL test:api (see $WORK/test-api.log)" >&2; tail -20 "$WORK/test-api.log" >&2; exit 1; }
echo "PASS test:api (includes events.test.js)"
npm run -s smoke:mvp > "$WORK/smoke.log" 2>&1 || { echo "FAIL smoke:mvp (see $WORK/smoke.log)" >&2; exit 1; }
echo "PASS smoke:mvp"

node - "$LIKEMINDED_EVENTS_FILE" "$LIKEMINDED_RUN_ID" <<'NODE'
const fs = require("node:fs");
const [file, runId] = process.argv.slice(2);
const rows = fs.readFileSync(file, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l));
const count = (service, event) => rows.filter(r => r.service === service && r.event === event && r.session_id === runId).length;
const need = {
  "likeminded-api http_request": count("likeminded-api", "http_request"),
  "likeminded-api server_start": count("likeminded-api", "server_start"),
  "likeminded-smoke smoke_finish": rows.filter(r => r.event === "smoke_finish" && r.status === "ok" && r.session_id === runId).length,
  "likeminded-tests test_case": count("likeminded-tests", "test_case"),
  "likeminded-tests test_run": count("likeminded-tests", "test_run")
};
for (const [name, n] of Object.entries(need)) {
  if (!n) { console.error(`FAIL no ${name} rows for run ${runId}`); process.exit(1); }
  console.log(`PASS ${name}: ${n}`);
}
const unexpected = rows.filter(r => r.service === "likeminded-api" && r.error_type);
if (unexpected.length) { console.error(`FAIL ${unexpected.length} API rows marked as server errors`); process.exit(1); }
console.log(`PASS ${rows.length} rows, no server errors`);
NODE

COLLECT="${DEVELOPER_OBSERVABILITY_BIN:-$HOME/.agents/plugins/developer-observability/bin/developer-observability}"
if [[ ! -x "$COLLECT" ]]; then echo "SKIP collect: $COLLECT not installed"; exit 0; fi
"$COLLECT" collect --no-known --no-prune --source "jsonl:$LIKEMINDED_EVENTS_FILE:likeminded" --out "$WORK/collect" --json > "$WORK/collect.json"
node - "$WORK/collect.json" "$WORK/collect/findings.json" <<'NODE'
const fs = require("node:fs");
const [summaryPath, findingsPath] = process.argv.slice(2);
const summary = JSON.parse(fs.readFileSync(summaryPath, "utf8"));
const findings = JSON.parse(fs.readFileSync(findingsPath, "utf8"));
if (!summary.events) { console.error("FAIL collector read 0 events"); process.exit(1); }
const failures = (findings.findings || []).filter(f => f.owner_ref === "owner:likeminded" && f.kind === "failure");
console.log(`PASS collector read ${summary.events} events from ${summary.sources} sources (likeminded findings: ${(findings.findings || []).filter(f => f.owner_ref === "owner:likeminded").length}, failures: ${failures.length})`);
if (failures.length) { console.error("FAIL collector reports likeminded failures: " + failures.map(f => f.headline).join("; ")); process.exit(1); }
NODE
echo "PASS OBS-01 events collected (work dir $WORK)"
