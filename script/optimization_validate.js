#!/usr/bin/env node
/**
 * Optimization registry — record claims, validate against Cursor session transcripts.
 *
 *   npm run optimization:status
 *   npm run optimization:record -- --id <slug> --claims "a;b;c" [--session <uuid>] [--commit <sha>]
 *   npm run optimization:validate [-- --id <slug>] [--sessions 10] [--min-sessions 3]
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

function resolveRoots() {
  const explicit = arg("--transcript-dir");
  const { roots, resolved, hint } = lib.resolveTranscriptRoots(root, { transcriptDir: explicit });
  if (!resolved) {
    console.error(`transcript root not found. ${hint}`);
    process.exit(1);
  }
  return roots;
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
      'Usage: optimization:record -- --id <slug> --claims "a;b;c" [--session <uuid>] [--commit <sha>] [--replace]'
    );
    process.exit(2);
  }
  const claims = (arg("--claims") || "")
    .split(";")
    .map((s) => s.trim())
    .filter(Boolean);
  const reg = lib.readRegistry(REGISTRY_PATH);
  const pending = reg.optimizations.filter((o) => !o.validated_at);
  if (pending.length && !process.argv.includes("--replace")) {
    console.error(
      `pending optimization exists: ${pending[0].id}. Validate first or pass --replace.`
    );
    process.exit(1);
  }
  if (reg.optimizations.some((o) => o.id === id)) {
    console.error(`optimization id already exists: ${id}`);
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
  const entry = {
    id,
    recorded_at: new Date().toISOString(),
    anchor_commit: commit,
    branch: arg("--branch") || null,
    anchor_session_id: arg("--session") || null,
    merged_at: arg("--merged-at") || null,
    claims,
    changes: (arg("--changes") || "")
      .split(";")
      .map((s) => s.trim())
      .filter(Boolean),
    failure_signals: (arg("--failure-signals") || "")
      .split(";")
      .map((s) => s.trim())
      .filter(Boolean),
    success_signals: (arg("--success-signals") || "")
      .split(";")
      .map((s) => s.trim())
      .filter(Boolean),
    validated_at: null,
    validation_verdict: null
  };
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
  console.log(`transcript_roots: ${report.transcript_roots.length}`);
  console.log(`sessions_analyzed: ${report.sessions_analyzed}`);
  console.log(`total_user_prompts: ${report.total_user_prompts}`);
  if (report.after_fail_rate != null) {
    console.log(`after_fail_rate: ${(report.after_fail_rate * 100).toFixed(0)}%`);
  }
  if (report.baseline_fail_rate != null) {
    console.log(`baseline_fail_rate: ${(report.baseline_fail_rate * 100).toFixed(0)}%`);
  }
  if (report.behavior_success_rate != null) {
    console.log(`behavior_success_rate: ${(report.behavior_success_rate * 100).toFixed(0)}%`);
  }
  console.log(`failure_hits (user): ${JSON.stringify(report.failure_hits)}`);
  console.log(`success_hits (assistant): ${JSON.stringify(report.success_hits)}`);
  console.log(`behavioral_hits: ${JSON.stringify(report.behavioral_hits)}`);
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
  const id =
    arg("--id") ||
    reg.optimizations.find((o) => !o.validated_at || (force && mode === "after"))?.id;
  const opt = reg.optimizations.find((o) => o.id === id);
  if (!opt) {
    console.error("no optimization to validate");
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
    opt.baseline_validation = { ...report, validated_at: new Date().toISOString() };
  } else if (inconclusive && !force) {
    opt.last_validation_attempt = { ...report, attempted_at: new Date().toISOString() };
    console.error(
      `${report.verdict}: ${report.verdict_reason}. validated_at unchanged. Re-run later or --force to stamp.`
    );
  } else {
    opt.validated_at = new Date().toISOString();
    opt.validation_verdict = report.verdict;
    opt.last_validation = report;
  }
  lib.writeRegistry(REGISTRY_PATH, reg);

  if (process.argv.includes("--json")) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    return;
  }
  printReport(opt, report);
}

const cmd = process.argv[2] || "status";
if (cmd === "status" || process.argv.includes("--status")) {
  const s = lib.status(REGISTRY_PATH);
  const roots = lib.resolveTranscriptRoots(root);
  if (process.argv.includes("--json")) {
    process.stdout.write(
      `${JSON.stringify({ ...s, transcript_roots: roots.roots, transcript_resolved: roots.resolved }, null, 2)}\n`
    );
  } else {
    console.log(`registry: ${s.registry}`);
    console.log(`transcript_roots: ${roots.roots.length} (${roots.resolved ? "resolved" : "missing"})`);
    if (roots.hint) console.log(`hint: ${roots.hint}`);
    console.log(`pending_validation: ${s.pending_validation.map((o) => o.id).join(", ") || "none"}`);
    if (s.latest) {
      const baseline = s.latest.baseline_validation?.verdict;
      console.log(
        `latest: ${s.latest.id} (after: ${s.latest.validated_at || "pending"}, baseline: ${baseline || "none"})`
      );
      if (s.latest.anchor_session_id) {
        console.log(`anchor_session_id: ${s.latest.anchor_session_id}`);
      }
    }
    if (s.needs_after_validation) {
      console.log("action: run npm run optimization:validate -- --mode after --sessions 10");
    }
    if (s.requires_user_confirm) {
      console.log("requires_user_confirm: yes — ask operator before after-mode validate");
    }
  }
} else if (cmd === "record" || process.argv.includes("--record")) {
  record();
} else if (cmd === "validate" || process.argv.includes("--validate")) {
  validate();
} else {
  validate();
}
