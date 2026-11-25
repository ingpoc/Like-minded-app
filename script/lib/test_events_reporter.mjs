// node --test reporter that appends one JSONL row per finished test to output/observability/likeminded-tests.jsonl
// (see services/api/src/lib/events.js). Pair it with the spec reporter for human output.
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { createEventLog } = require("../../services/api/src/lib/events.js");

export default async function* testEventsReporter(source) {
  const events = createEventLog("likeminded-tests");
  const started = Date.now();
  let passed = 0;
  let failed = 0;
  for await (const { type, data } of source) {
    if (type !== "test:pass" && type !== "test:fail") continue;
    if (data.details?.type === "suite") continue;
    const ok = type === "test:pass";
    if (ok) passed += 1; else failed += 1;
    const error = data.details?.error;
    const cause = error?.cause;
    events.emit("test_case", {
      step: String(data.name).slice(0, 160),
      file: data.file ? data.file.replace(/^.*\/(services|script)\//, "$1/") : undefined,
      status: ok ? "ok" : "failed",
      duration_ms: data.details?.duration_ms,
      ...(ok ? {} : { error_type: String(cause?.code || cause?.name || error?.code || "test_failure").slice(0, 80) })
    });
  }
  events.emit("test_run", { status: failed ? "failed" : "ok", passed, failed, duration_ms: Date.now() - started });
  yield "";
}
