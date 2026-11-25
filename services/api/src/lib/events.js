// Structured JSONL events for developer-observability.
// One line per event: { ts, service, event, session_id, version, ...fields }.
// Never pass request bodies, headers, tokens or personal data in fields.
//
// LIKEMINDED_EVENTS=0          turn events off
// LIKEMINDED_EVENTS_FILE=path  write here ("-" = stdout); default output/observability/<service>.jsonl,
//                              or stdout on Render (RENDER is set) so events land in the service log.
// LIKEMINDED_RUN_ID=id         shared session id for one smoke/test run (child processes inherit it)
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "../../../..");
const VERSION = (process.env.RENDER_GIT_COMMIT || process.env.LIKEMINDED_VERSION || require(path.join(ROOT, "package.json")).version || "unknown").slice(0, 40);

function defaultTarget(service) {
  if (process.env.LIKEMINDED_EVENTS_FILE) return process.env.LIKEMINDED_EVENTS_FILE;
  if (process.env.RENDER) return "-";
  return path.join(ROOT, "output", "observability", `${service}.jsonl`);
}

function createEventLog(service, options = {}) {
  const enabled = process.env.LIKEMINDED_EVENTS !== "0";
  const target = options.target || defaultTarget(service);
  const sessionId = process.env.LIKEMINDED_RUN_ID || `${service}-${process.pid}-${Date.now().toString(36)}`;
  let broken = false;

  if (enabled && target !== "-") {
    try { fs.mkdirSync(path.dirname(target), { recursive: true }); } catch {}
  }

  function emit(event, fields = {}) {
    if (!enabled || broken) return;
    try {
      const row = { ts: new Date().toISOString(), service, event, session_id: sessionId, version: VERSION, ...fields };
      const line = JSON.stringify(row) + "\n";
      if (target === "-") process.stdout.write(line);
      else fs.appendFileSync(target, line);
    } catch (error) {
      broken = true;
      process.stderr.write(`[${service}] event log disabled: ${error.code || error.message}\n`);
    }
  }

  return { emit, sessionId, target: enabled ? target : null };
}

function errorType(error) {
  if (!error) return undefined;
  return String(error.code || error.name || "Error").slice(0, 80);
}

module.exports = { createEventLog, errorType, VERSION };
