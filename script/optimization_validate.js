#!/usr/bin/env node
/**
 * Optimization registry — record claims, validate against Cursor session transcripts.
 *
 *   npm run optimization:status          # compact view for agents (low token)
 *   npm run optimization:status -- --full
 *   npm run optimization:compact       # collapse verbose blobs in place
 *   npm run optimization:record -- --id <slug> --claims "a;b;c"
 *   npm run optimization:validate [-- --id <slug>] [--sessions 10]
 */
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const lib = require("./lib/optimization_validate_lib");

const root = path.resolve(__dirname, "..");
const REGISTRY_PATH = path.join(root, "session", "optimization-registry.json");

function arg(name, fallback = null) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

function validateOptions() {
  return {
    mode: arg("--mode", "after"),
    sessionLimit: Number(arg("--sessions", "10")),
    minSessions: Number(arg("--min-sessions", "3")),
    minUserPrompts: Number(arg("--min-user-prompts", "5")),
    transcriptDir: arg("--transcript-dir")
  };
}

function record() {
  const id = arg("--id");
  if (!id) {
    console.error(
      'Usage: optimization:record -- --id <slug> --claims "a;b;c" [--session <uuid>] [--commit <sha>]'
    );
    process.exit(2);
  }
  const claims = (arg("--claims") || "")
    .split(";")
    .map((s) => s.trim())
    .filter(Boolean);
  const reg = lib.readRegistry(REGISTRY_PATH);
  const active = lib.activeEntry(reg);
  if (active) {
    console.error(
      `active optimization exists: ${active.id}. Validate+archive first (npm run optimization:validate -- --mode after).`
    );
    process.exit(1);
  }
  if (reg.optimizations.some((o) => o.id === id)) {
    console.error(`optimization id already exists: ${id}`);
    process.exit(1);
  }

  const failureSignals =
    (arg("--failure-signals") || "")
      .split(";")
      .map((s) => s.trim())
      .filter(Boolean) || lib.ROUTING_SIGNAL_PACK.failure_signals;
  const successSignals =
    (arg("--success-signals") || "")
      .split(";")
      .map((s) => s.trim())
      .filter(Boolean) || lib.ROUTING_SIGNAL_PACK.success_signals;

  const entry = {
    id,
    recorded_at: new Date().toISOString(),
    anchor_commit: null,
    branch: arg("--branch") || null,
    anchor_session_id: arg("--session") || null,
    merged_at: arg("--merged-at") || null,
    claims,
    changes: (arg("--changes") || "")
      .split(";")
      .map((s) => s.trim())
      .filter(Boolean),
    failure_signals: failureSignals.length ? failureSignals : lib.ROUTING_SIGNAL_PACK.failure_signals,
    success_signals: successSignals.length ? successSignals : lib.ROUTING_SIGNAL_PACK.success_signals,
    validated_at: null,
    validation_verdict: null,
    archived: false
  };

  const shapeErrors = lib.validateRecordShape(entry);
  if (shapeErrors.length) {
    for (const e of shapeErrors) console.error(`record invalid: ${e}`);
    process.exit(1);
  }

  let commit = arg("--commit");
  if (!commit) {
    try {
      commit = execFileSync("git", ["rev-parse", "--short", "HEAD"], {
        cwd: root,
        encoding: "utf8"
      }).trim();
    } catch {
      commit = null;
    }
  }
  entry.anchor_commit = commit;

  reg.optimizations.push(entry);
  lib.writeRegistry(REGISTRY_PATH, reg);
  console.log(`recorded optimization: ${id} → ${REGISTRY_PATH}`);
  if (!entry.anchor_session_id) {
    console.log("hint: pass --session <cursor-transcript-uuid> for precise after-window filtering");
  }
  return entry;
}

function printReport(opt, report) {
  console.log(`# Optimization validate — ${opt.id}`);
  console.log(`mode: ${report.mode}`);
  console.log(`verdict: ${report.verdict}`);
  console.log(`confidence: ${report.confidence}`);
  console.log(`reason: ${report.verdict_reason}`);
  console.log(`sessions_analyzed: ${report.sessions_analyzed}`);
  if (report.after_fail_rate != null) {
    console.log(`after_fail_rate: ${(report.after_fail_rate * 100).toFixed(0)}%`);
  }
  if (report.baseline_fail_rate != null) {
    console.log(`baseline_fail_rate: ${(report.baseline_fail_rate * 100).toFixed(0)}%`);
  }
  if (report.behavior_success_rate != null) {
    console.log(`behavior_success_rate: ${(report.behavior_success_rate * 100).toFixed(0)}%`);
  }
  console.log(`top_failures: ${lib.collapseValidationReport(report)?.top_failures || ""}`);
  console.log("musk_simplify:");
  for (const line of report.musk.simplify) console.log(`  - ${line}`);
  console.log("musk_fix:");
  for (const line of report.musk.fix) console.log(`  - ${line}`);
}

function validate() {
  const reg = lib.readRegistry(REGISTRY_PATH);
  const opts = validateOptions();
  const mode = opts.mode;
  const force = process.argv.includes("--force");
  const active = lib.activeEntry(reg);
  const id = arg("--id") || active?.id;
  const idx = reg.optimizations.findIndex((o) => o.id === id);
  const opt = idx >= 0 ? reg.optimizations[idx] : null;
  if (!opt || opt.archived) {
    console.error("no active optimization to validate");
    process.exit(1);
  }
  if (opt.validated_at && mode === "after" && !force) {
    console.error(
      `optimization already validated (${opt.validation_verdict}). Use --force to re-run after-mode.`
    );
    process.exit(1);
  }

  const roots = lib.resolveTranscriptRoots(root, { transcriptDir: opts.transcriptDir }).roots;
  if (!roots.length) {
    const hint = lib.resolveTranscriptRoots(root).hint;
    console.error(`transcript root not found. ${hint}`);
    process.exit(1);
  }

  const report = lib.validateOptimization(opt, roots, opts);
  const inconclusive = ["no_data", "insufficient_data"].includes(report.verdict);

  if (mode === "baseline") {
    reg.optimizations[idx] = {
      ...lib.slimActiveEntry(opt),
      baseline_validation: lib.collapseValidationReport({
        ...report,
        validated_at: new Date().toISOString()
      })
    };
  } else if (inconclusive && !force) {
    reg.optimizations[idx] = {
      ...lib.slimActiveEntry(opt),
      last_validation_attempt: lib.collapseValidationReport({
        ...report,
        attempted_at: new Date().toISOString()
      })
    };
    console.error(
      `${report.verdict}: ${report.verdict_reason}. validated_at unchanged. Re-run later or --force to stamp.`
    );
  } else {
    const archived = lib.archiveEntry(
      { ...opt, validated_at: new Date().toISOString(), validation_verdict: report.verdict },
      report
    );
    reg.optimizations[idx] = archived;
    console.log(`archived: ${opt.id} (verdict=${report.verdict}) — registry row collapsed`);
  }
  lib.writeRegistry(REGISTRY_PATH, reg);

  if (process.argv.includes("--json")) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    return;
  }
  printReport(opt, report);
}

function printCompactStatus() {
  const compact = lib.compactStatus(REGISTRY_PATH);
  const roots = lib.resolveTranscriptRoots(root);
  console.log(`doctrine: ${compact.doctrine}`);
  console.log(`transcript_roots: ${roots.roots.length} (${roots.resolved ? "resolved" : "missing"})`);
  if (compact.active) {
    console.log(`active: ${compact.active.id} (validated: ${compact.active.validated_at || "pending"})`);
    console.log(`claims: ${compact.active.claims.length}`);
    if (compact.active.baseline_validation?.verdict) {
      console.log(`baseline: ${compact.active.baseline_validation.verdict}`);
    }
    if (compact.requires_user_confirm) {
      console.log("requires_user_confirm: yes");
      console.log("action: npm run optimization:validate -- --mode after --sessions 10");
    }
  } else {
    console.log("active: none — safe to record next wave");
  }
  if (compact.archived.length) {
    console.log(`archived (${compact.archived.length}):`);
    for (const row of compact.archived) {
      console.log(`  - ${row.id}: ${row.verdict} @ ${row.validated_at || "?"}`);
    }
  }
}

const cmd = process.argv[2] || "status";
if (cmd === "status" || process.argv.includes("--status")) {
  if (process.argv.includes("--full")) {
    const s = lib.status(REGISTRY_PATH);
    const roots = lib.resolveTranscriptRoots(root);
    if (process.argv.includes("--json")) {
      process.stdout.write(
        `${JSON.stringify({ ...s, transcript_roots: roots.roots, transcript_resolved: roots.resolved }, null, 2)}\n`
      );
    } else {
      console.log(JSON.stringify(lib.readRegistry(REGISTRY_PATH), null, 2));
    }
  } else if (process.argv.includes("--json")) {
    process.stdout.write(
      `${JSON.stringify({ ...lib.compactStatus(REGISTRY_PATH), transcript: lib.resolveTranscriptRoots(root) }, null, 2)}\n`
    );
  } else {
    printCompactStatus();
  }
} else if (cmd === "compact") {
  lib.compactRegistry(REGISTRY_PATH);
  console.log("registry compacted in place");
} else if (cmd === "record" || process.argv.includes("--record")) {
  record();
} else if (cmd === "validate" || process.argv.includes("--validate")) {
  validate();
} else {
  validate();
}
