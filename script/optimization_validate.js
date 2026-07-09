#!/usr/bin/env node
/**
 * Optimization registry — record claims, validate against Cursor session transcripts.
 *
 *   npm run optimization:status
 *   npm run optimization:record -- --id <slug> --claims "a;b;c" [--session <uuid>] [--commit <sha>]
 *   npm run optimization:validate [-- --id <slug>] [--sessions 10]
 */
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const REGISTRY_PATH = path.join(root, "session", "optimization-registry.json");
const TRANSCRIPT_ROOT = path.join(
  process.env.HOME || "",
  ".cursor/projects/Users-gurusharan-Documents-remote-claude-active-apps-Like-minded-app/agent-transcripts"
);

function readRegistry() {
  if (!fs.existsSync(REGISTRY_PATH)) {
    return { schema_version: 1, optimizations: [] };
  }
  return JSON.parse(fs.readFileSync(REGISTRY_PATH, "utf8"));
}

function writeRegistry(data) {
  fs.mkdirSync(path.dirname(REGISTRY_PATH), { recursive: true });
  fs.writeFileSync(REGISTRY_PATH, `${JSON.stringify(data, null, 2)}\n`);
}

function arg(name, fallback = null) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

function listTranscripts(limit = 10, anchorIso = null, mode = "after") {
  if (!fs.existsSync(TRANSCRIPT_ROOT)) return [];
  const anchorMs = anchorIso ? Date.parse(anchorIso) : 0;
  const items = [];
  for (const id of fs.readdirSync(TRANSCRIPT_ROOT)) {
    const file = path.join(TRANSCRIPT_ROOT, id, `${id}.jsonl`);
    if (!fs.existsSync(file)) continue;
    const stat = fs.statSync(file);
    if (anchorMs) {
      if (mode === "after" && stat.mtimeMs < anchorMs) continue;
      if (mode === "baseline" && stat.mtimeMs >= anchorMs) continue;
    }
    items.push({ id, file, mtimeMs: stat.mtimeMs });
  }
  items.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return items.slice(0, limit);
}

function extractSessionText(file) {
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const users = [];
  const assistants = [];
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const o = JSON.parse(line);
      let text = "";
      if (typeof o.message?.content === "string") text = o.message.content;
      else if (Array.isArray(o.message?.content)) {
        text = o.message.content
          .filter((c) => c.type === "text")
          .map((c) => c.text)
          .join("\n");
      }
      if (!text || text.includes("<user_info>")) continue;
      if (o.role === "user") users.push(text);
      if (o.role === "assistant") assistants.push(text);
    } catch {
      /* skip */
    }
  }
  return { users, assistants, combined: [...users, ...assistants].join("\n") };
}

function scoreSignals(text, signals) {
  const hits = [];
  for (const signal of signals || []) {
    if (text.toLowerCase().includes(signal.toLowerCase())) hits.push(signal);
  }
  return hits;
}

function validateOptimization(opt, sessionLimit) {
  const mode = arg("--mode", "after");
  const sessions = listTranscripts(sessionLimit, opt.recorded_at, mode);
  const failureHits = {};
  const successHits = {};
  const perSession = [];

  for (const session of sessions) {
    const { users, combined } = extractSessionText(session.file);
    const fails = scoreSignals(combined, opt.failure_signals);
    const wins = scoreSignals(combined, opt.success_signals);
    for (const f of fails) failureHits[f] = (failureHits[f] || 0) + 1;
    for (const w of wins) successHits[w] = (successHits[w] || 0) + 1;
    perSession.push({
      session_id: session.id,
      user_prompts: users.length,
      failure_hits: fails,
      success_hits: wins
    });
  }

  const failCount = Object.values(failureHits).reduce((n, v) => n + v, 0);
  const winCount = Object.values(successHits).reduce((n, v) => n + v, 0);
  let verdict = "partial";
  if (sessions.length === 0) verdict = "no_data";
  else if (mode === "baseline") {
    verdict = failCount > 0 ? "baseline_confirmed" : "baseline_unclear";
  } else if (failCount === 0 && winCount > 0) verdict = "helped";
  else if (failCount > winCount * 2) verdict = "not_helped";
  else if (failCount > 0 && winCount > 0) verdict = "partial";

  const simplify = [];
  const fix = [];
  if (verdict === "helped") {
    simplify.push("Collapse work bucket output to 5 lines if agents obey continue_command reliably");
    simplify.push("Remove forbidden_until_continue prose once grader shows zero GOAL/PROGRESS preloads in transcripts");
    simplify.push("Merge session:stamp into auto-stamp only — drop manual stamp from AGENTS.md if unused");
  } else if (verdict === "not_helped" || verdict === "partial") {
    if (failureHits["still nowhere near"] || failureHits["not yet migrated"]) {
      fix.push("Enforce proof_command in first_command chain before implementation turns");
    }
    if (failureHits["we just completed"] || failureHits["check what implementation"]) {
      fix.push("Stamp anchor_session_id on record; fail validate if work bucket empty at session start");
    }
    if (failureHits["placing into a circle is not"]) {
      fix.push("Inject work_decision lines into hook compact output, not only full goal:next");
    }
    if (failureHits["are you duplicating surfaces"]) {
      fix.push("Run another context-efficiency prune pass — competing owner resurfaced");
    }
    if (failCount > 0 && winCount === 0) {
      fix.push("Add verify:optimization script that fails CI if failure_signals dominate post-record sessions");
    }
  }

  return {
    optimization_id: opt.id,
    recorded_at: opt.recorded_at,
    mode,
    sessions_analyzed: sessions.length,
    verdict,
    failure_hits: failureHits,
    success_hits: successHits,
    per_session: perSession,
    musk: {
      question: "Did the optimization remove a part or add ceremony?",
      simplify: simplify.length ? simplify : ["Keep registry row; system is earning its keep"],
      fix: fix.length ? fix : ["No fix — gather more sessions or tighten failure_signals"]
    }
  };
}

function status() {
  const reg = readRegistry();
  const pending = reg.optimizations.filter((o) => !o.validated_at);
  const latest = reg.optimizations[reg.optimizations.length - 1] || null;
  const needsAfterValidation =
    latest &&
    !latest.validated_at &&
    latest.baseline_validation?.verdict === "baseline_confirmed";
  return {
    registry: REGISTRY_PATH,
    pending_validation: pending,
    latest,
    needs_after_validation: Boolean(needsAfterValidation)
  };
}

function record() {
  const id = arg("--id");
  if (!id) {
    console.error("Usage: optimization:record -- --id <slug> --claims \"a;b;c\" [--session <uuid>] [--commit <sha>]");
    process.exit(2);
  }
  const claims = (arg("--claims") || "").split(";").map((s) => s.trim()).filter(Boolean);
  const reg = readRegistry();
  if (reg.optimizations.some((o) => o.id === id)) {
    console.error(`optimization id already exists: ${id}`);
    process.exit(1);
  }
  let commit = arg("--commit");
  if (!commit) {
    try {
      commit = execFileSync("git", ["rev-parse", "--short", "HEAD"], { cwd: root, encoding: "utf8" }).trim();
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
    claims,
    changes: (arg("--changes") || "").split(";").map((s) => s.trim()).filter(Boolean),
    failure_signals: (arg("--failure-signals") || "").split(";").map((s) => s.trim()).filter(Boolean),
    success_signals: (arg("--success-signals") || "").split(";").map((s) => s.trim()).filter(Boolean),
    validated_at: null,
    validation_verdict: null
  };
  reg.optimizations.push(entry);
  writeRegistry(reg);
  console.log(`recorded optimization: ${id} → ${REGISTRY_PATH}`);
  return entry;
}

function validate() {
  const reg = readRegistry();
  const mode = arg("--mode", "after");
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
  const limit = Number(arg("--sessions", "10"));
  const report = validateOptimization(opt, limit);
  if (mode === "baseline") {
    opt.baseline_validation = { ...report, validated_at: new Date().toISOString() };
  } else if (report.verdict === "no_data" && !force) {
    opt.last_validation_attempt = { ...report, attempted_at: new Date().toISOString() };
    console.error(
      "no post-fix sessions yet — validated_at unchanged. Re-run after more sessions or pass --force to stamp no_data."
    );
  } else {
    opt.validated_at = new Date().toISOString();
    opt.validation_verdict = report.verdict;
    opt.last_validation = report;
  }
  writeRegistry(reg);
  if (process.argv.includes("--json")) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    return;
  }
  console.log(`# Optimization validate — ${opt.id}`);
  console.log(`mode: ${report.mode}`);
  console.log(`verdict: ${report.verdict}`);
  console.log(`sessions_analyzed: ${report.sessions_analyzed}`);
  console.log(`failure_hits: ${JSON.stringify(report.failure_hits)}`);
  console.log(`success_hits: ${JSON.stringify(report.success_hits)}`);
  console.log("musk_simplify:");
  for (const line of report.musk.simplify) console.log(`  - ${line}`);
  console.log("musk_fix:");
  for (const line of report.musk.fix) console.log(`  - ${line}`);
}

const cmd = process.argv[2] || "status";
if (cmd === "status" || process.argv.includes("--status")) {
  const s = status();
  if (process.argv.includes("--json")) {
    process.stdout.write(`${JSON.stringify(s, null, 2)}\n`);
  } else {
    console.log(`registry: ${s.registry}`);
    console.log(`pending_validation: ${s.pending_validation.map((o) => o.id).join(", ") || "none"}`);
    if (s.latest) {
      const baseline = s.latest.baseline_validation?.verdict;
      console.log(
        `latest: ${s.latest.id} (after: ${s.latest.validated_at || "pending"}, baseline: ${baseline || "none"})`
      );
    }
    if (s.needs_after_validation) {
      console.log("action: run npm run optimization:validate -- --mode after --sessions 10");
    }
  }
} else if (cmd === "record" || process.argv.includes("--record")) {
  record();
} else if (cmd === "validate" || process.argv.includes("--validate")) {
  validate();
} else {
  validate();
}
