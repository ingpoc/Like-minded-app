/**
 * Shared optimization validation — transcript discovery, session anchor, behavioral scoring.
 */
const fs = require("node:fs");
const path = require("node:path");

const FORBIDDEN_READ_PATTERNS = [
  /GOAL\.md/i,
  /PROGRESS\.md/i,
  /ledger:open/i
];
const CONTINUE_PATTERNS = [/ledger:screen/i, /goal:next/i];

function readRegistry(registryPath) {
  if (!fs.existsSync(registryPath)) {
    return { schema_version: 1, optimizations: [] };
  }
  return JSON.parse(fs.readFileSync(registryPath, "utf8"));
}

function writeRegistry(registryPath, data) {
  fs.mkdirSync(path.dirname(registryPath), { recursive: true });
  fs.writeFileSync(registryPath, `${JSON.stringify(data, null, 2)}\n`);
}

function discoverTranscriptRoots(repoRoot, explicitDir = null) {
  if (explicitDir && fs.existsSync(explicitDir)) return [explicitDir];
  const envDir = process.env.CURSOR_TRANSCRIPT_ROOT;
  if (envDir && fs.existsSync(envDir)) return [envDir];

  const home = process.env.HOME || "";
  const projectsDir = path.join(home, ".cursor/projects");
  if (!fs.existsSync(projectsDir)) return [];

  const repoName = path.basename(repoRoot).toLowerCase();
  const roots = [];
  for (const entry of fs.readdirSync(projectsDir)) {
    const lower = entry.toLowerCase();
    if (!lower.includes("like-minded") && !lower.includes(repoName.replace(/-/g, ""))) continue;
    const candidate = path.join(projectsDir, entry, "agent-transcripts");
    if (fs.existsSync(candidate)) roots.push(candidate);
  }
  return roots;
}

function resolveTranscriptRoots(repoRoot, options = {}) {
  const roots = discoverTranscriptRoots(repoRoot, options.transcriptDir);
  return {
    roots,
    resolved: roots.length > 0,
    hint:
      roots.length === 0
        ? "Set CURSOR_TRANSCRIPT_ROOT or pass --transcript-dir <path> (operator Mac with Cursor transcripts)."
        : null
  };
}

function parseTimestampMs(text) {
  const m = text.match(/<timestamp>([^<]+)<\/timestamp>/);
  if (!m) return null;
  const ms = Date.parse(m[1]);
  return Number.isFinite(ms) ? ms : null;
}

function sessionFilePath(roots, sessionId) {
  for (const root of roots) {
    const file = path.join(root, sessionId, `${sessionId}.jsonl`);
    if (fs.existsSync(file)) return file;
  }
  return null;
}

function listAllTranscriptFiles(roots) {
  const byId = new Map();
  for (const root of roots) {
    if (!fs.existsSync(root)) continue;
    for (const id of fs.readdirSync(root)) {
      const file = path.join(root, id, `${id}.jsonl`);
      if (!fs.existsSync(file)) continue;
      const stat = fs.statSync(file);
      const prev = byId.get(id);
      if (!prev || stat.mtimeMs > prev.mtimeMs) {
        byId.set(id, { id, file, mtimeMs: stat.mtimeMs, root });
      }
    }
  }
  return [...byId.values()];
}

function listTranscripts(roots, options = {}) {
  const {
    limit = 10,
    anchorIso = null,
    mode = "after",
    anchorSessionId = null,
    sinceCommitDate = null
  } = options;

  let anchorMs = anchorIso ? Date.parse(anchorIso) : 0;
  if (anchorSessionId) {
    const anchorFile = sessionFilePath(roots, anchorSessionId);
    if (anchorFile) {
      const anchorStat = fs.statSync(anchorFile);
      anchorMs = Math.max(anchorMs, anchorStat.mtimeMs);
    }
  }
  if (sinceCommitDate) {
    anchorMs = Math.max(anchorMs, Date.parse(sinceCommitDate));
  }

  let items = listAllTranscriptFiles(roots);

  if (anchorMs) {
    if (mode === "after") {
      items = items.filter((s) => s.mtimeMs >= anchorMs && s.id !== anchorSessionId);
    } else if (mode === "baseline") {
      items = items.filter((s) => s.mtimeMs < anchorMs);
    }
  }

  items.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return items.slice(0, limit);
}

function messageText(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .filter((c) => c.type === "text")
    .map((c) => c.text || "")
    .join("\n");
}

function extractToolEvents(content) {
  if (!Array.isArray(content)) return [];
  const events = [];
  for (const part of content) {
    if (part.type !== "tool_use") continue;
    const name = part.name || "";
    const input = part.input || {};
    if (name === "Read" && input.path) {
      events.push({ kind: "read", path: String(input.path) });
    } else if (name === "Shell" && input.command) {
      events.push({ kind: "shell", command: String(input.command) });
    } else if (name === "Grep" && input.path) {
      events.push({ kind: "grep", path: String(input.path), pattern: input.pattern });
    } else if (name === "Glob") {
      events.push({ kind: "glob", pattern: input.glob_pattern || input.pattern || "" });
    }
  }
  return events;
}

function extractSessionData(file) {
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const users = [];
  const assistants = [];
  const toolEvents = [];
  let firstTimestampMs = null;

  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const o = JSON.parse(line);
      const text = messageText(o.message?.content);
      if (text.includes("<user_info>")) continue;

      if (o.role === "user") {
        if (!firstTimestampMs) {
          const ts = parseTimestampMs(text);
          if (ts) firstTimestampMs = ts;
        }
        users.push(text);
      }
      if (o.role === "assistant") {
        assistants.push(text);
        toolEvents.push(...extractToolEvents(o.message?.content));
      }
    } catch {
      /* skip malformed line */
    }
  }

  return {
    users,
    assistants,
    userText: users.join("\n"),
    assistantText: assistants.join("\n"),
    combined: [...users, ...assistants].join("\n"),
    toolEvents,
    firstTimestampMs
  };
}

function scoreSignals(text, signals) {
  const hits = [];
  const lower = text.toLowerCase();
  for (const signal of signals || []) {
    if (lower.includes(signal.toLowerCase())) hits.push(signal);
  }
  return hits;
}

function analyzeBehavior(toolEvents) {
  let continueIndex = -1;
  const violations = [];

  for (let i = 0; i < toolEvents.length; i++) {
    const ev = toolEvents[i];
    if (ev.kind === "shell" && CONTINUE_PATTERNS.some((re) => re.test(ev.command))) {
      continueIndex = i;
      break;
    }
  }

  const scanUntil = continueIndex >= 0 ? continueIndex : toolEvents.length;
  for (let i = 0; i < scanUntil; i++) {
    const ev = toolEvents[i];
    const target =
      ev.kind === "read"
        ? ev.path
        : ev.kind === "shell"
          ? ev.command
          : ev.kind === "grep"
            ? `${ev.path || ""} ${ev.pattern || ""}`
            : ev.pattern || "";
    if (FORBIDDEN_READ_PATTERNS.some((re) => re.test(target))) {
      violations.push({ index: i, event: ev });
    }
  }

  const ranLedgerScreen = toolEvents.some(
    (ev) => ev.kind === "shell" && /ledger:screen/i.test(ev.command)
  );
  const ranGoalNext = toolEvents.some(
    (ev) => ev.kind === "shell" && /goal:next/i.test(ev.command)
  );
  const mockupWalk = toolEvents.some(
    (ev) => ev.kind === "glob" && /mockup/i.test(ev.pattern || "")
  );

  return {
    early_forbidden_reads: violations.length,
    violations,
    ran_ledger_screen: ranLedgerScreen,
    ran_goal_next: ranGoalNext,
    mockup_directory_walk: mockupWalk,
    continue_command_seen: continueIndex >= 0
  };
}

function sessionFailRate(perSession) {
  if (!perSession.length) return 0;
  const failed = perSession.filter((s) => {
    if (s.user_failure_hits?.length) return true;
    if (s.failure_hits?.length) return true;
    if (s.behavioral?.early_forbidden_reads > 0) return true;
    if (s.behavioral?.mockup_directory_walk) return true;
    return false;
  }).length;
  return failed / perSession.length;
}

function sessionBehaviorSuccessRate(perSession) {
  if (!perSession.length) return 0;
  const scored = perSession.filter((s) => s.behavioral);
  if (!scored.length) return 0;
  const ok = scored.filter(
    (s) =>
      (s.behavioral.ran_ledger_screen || s.behavioral.ran_goal_next) &&
      s.behavioral.early_forbidden_reads === 0
  ).length;
  return ok / scored.length;
}

function computeVerdict(report, options = {}) {
  const {
    mode = "after",
    minSessions = 3,
    minUserPrompts = 5,
    baselinePerSession = null
  } = options;

  const { sessions_analyzed, per_session: perSession } = report;
  const totalUserPrompts = perSession.reduce((n, s) => n + s.user_prompts, 0);

  if (sessions_analyzed === 0) {
    return { verdict: "no_data", confidence: "none", reason: "no transcripts in window" };
  }

  if (mode === "baseline") {
    const failCount = Object.values(report.failure_hits).reduce((n, v) => n + v, 0);
    return {
      verdict: failCount > 0 ? "baseline_confirmed" : "baseline_unclear",
      confidence: sessions_analyzed >= minSessions ? "medium" : "low",
      reason: failCount > 0 ? "pre-fix failure signals present" : "no failure signals in baseline window"
    };
  }

  if (sessions_analyzed < minSessions || totalUserPrompts < minUserPrompts) {
    return {
      verdict: "insufficient_data",
      confidence: "low",
      reason: `need >=${minSessions} sessions and >=${minUserPrompts} user prompts (have ${sessions_analyzed}, ${totalUserPrompts})`
    };
  }

  const afterFailRate = sessionFailRate(perSession);
  const behaviorRate = sessionBehaviorSuccessRate(perSession);
  const baselineFailRate = baselinePerSession ? sessionFailRate(baselinePerSession) : null;

  let verdict = "partial";
  let confidence = "medium";
  let reason = "";

  if (baselineFailRate !== null) {
    const improved = afterFailRate < baselineFailRate * 0.5;
    if (improved && behaviorRate >= 0.4 && afterFailRate <= 0.25) {
      verdict = "helped";
      confidence = behaviorRate >= 0.6 ? "high" : "medium";
      reason = `after fail rate ${(afterFailRate * 100).toFixed(0)}% vs baseline ${(baselineFailRate * 100).toFixed(0)}%; behavior ${(behaviorRate * 100).toFixed(0)}%`;
    } else if (afterFailRate > baselineFailRate) {
      verdict = "not_helped";
      confidence = "medium";
      reason = `after fail rate ${(afterFailRate * 100).toFixed(0)}% worse than baseline ${(baselineFailRate * 100).toFixed(0)}%`;
    } else {
      verdict = "partial";
      reason = `after ${(afterFailRate * 100).toFixed(0)}% vs baseline ${(baselineFailRate * 100).toFixed(0)}%; behavior ${(behaviorRate * 100).toFixed(0)}%`;
    }
  } else {
    const failCount = Object.values(report.failure_hits).reduce((n, v) => n + v, 0);
    const winCount = Object.values(report.success_hits).reduce((n, v) => n + v, 0);
    if (failCount === 0 && winCount > 0 && behaviorRate >= 0.5) {
      verdict = "helped";
      confidence = "low";
      reason = "no baseline comparison; absolute pass with behavioral success";
    } else if (failCount > winCount * 2 || afterFailRate > 0.5) {
      verdict = "not_helped";
      reason = "failure signals dominate without baseline";
    } else {
      verdict = "partial";
      reason = "no baseline comparison; mixed signals";
    }
  }

  return { verdict, confidence, reason, after_fail_rate: afterFailRate, behavior_success_rate: behaviorRate, baseline_fail_rate: baselineFailRate };
}

function validateOptimization(opt, roots, options = {}) {
  const mode = options.mode || "after";
  const sessionLimit = options.sessionLimit || 10;
  const minSessions = options.minSessions ?? 3;
  const minUserPrompts = options.minUserPrompts ?? 5;

  const sessions = listTranscripts(roots, {
    limit: sessionLimit,
    anchorIso: opt.recorded_at,
    mode,
    anchorSessionId: opt.anchor_session_id,
    sinceCommitDate: opt.merged_at || null
  });

  const failureHits = {};
  const successHits = {};
  const behavioralHits = {
    early_forbidden_reads: 0,
    ran_ledger_screen: 0,
    ran_goal_next: 0,
    mockup_directory_walk: 0
  };
  const perSession = [];

  for (const session of sessions) {
    const data = extractSessionData(session.file);
    const behavioral = analyzeBehavior(data.toolEvents);
    const userFails = scoreSignals(data.userText, opt.failure_signals);
    const assistantWins = scoreSignals(data.assistantText, opt.success_signals);
    const userWins = scoreSignals(data.userText, opt.success_signals);

    for (const f of userFails) failureHits[f] = (failureHits[f] || 0) + 1;
    for (const w of assistantWins) successHits[w] = (successHits[w] || 0) + 1;
    if (behavioral.early_forbidden_reads) behavioralHits.early_forbidden_reads += 1;
    if (behavioral.ran_ledger_screen) behavioralHits.ran_ledger_screen += 1;
    if (behavioral.ran_goal_next) behavioralHits.ran_goal_next += 1;
    if (behavioral.mockup_directory_walk) behavioralHits.mockup_directory_walk += 1;

    perSession.push({
      session_id: session.id,
      user_prompts: data.users.length,
      user_failure_hits: userFails,
      assistant_success_hits: assistantWins,
      user_success_hits: userWins,
      behavioral
    });
  }

  const report = {
    optimization_id: opt.id,
    recorded_at: opt.recorded_at,
    mode,
    transcript_roots: roots,
    sessions_analyzed: sessions.length,
    total_user_prompts: perSession.reduce((n, s) => n + s.user_prompts, 0),
    failure_hits: failureHits,
    success_hits: successHits,
    behavioral_hits: behavioralHits,
    per_session: perSession
  };

  let baselinePerSession = null;
  if (mode === "after" && opt.baseline_validation?.per_session) {
    baselinePerSession = opt.baseline_validation.per_session;
  }

  const verdictMeta = computeVerdict(report, {
    mode,
    minSessions,
    minUserPrompts,
    baselinePerSession
  });
  report.verdict = verdictMeta.verdict;
  report.confidence = verdictMeta.confidence;
  report.verdict_reason = verdictMeta.reason;
  report.after_fail_rate = verdictMeta.after_fail_rate;
  report.behavior_success_rate = verdictMeta.behavior_success_rate;
  report.baseline_fail_rate = verdictMeta.baseline_fail_rate;

  const simplify = [];
  const fix = [];
  if (report.verdict === "helped") {
    simplify.push("Collapse work bucket hook output once behavioral success rate stays >=60%");
    simplify.push("Remove manual session:stamp from AGENTS if auto-stamp covers all sessions");
    simplify.push("Archive registry row (archived: true) before recording next wave");
  } else if (report.verdict === "not_helped" || report.verdict === "partial") {
    if (behavioralHits.early_forbidden_reads > 0) {
      fix.push("forbidden_until_continue not obeyed — block Read GOAL/PROGRESS in hook or fail verify:optimization");
    }
    if (failureHits["we just completed"] || failureHits["check what implementation"]) {
      fix.push("Work bucket empty at session start — enforce session:stamp-auto + anchor_session_id on record");
    }
    if (failureHits["placing into a circle is not"]) {
      fix.push("Inject work_decision_* into compact session_route hook output");
    }
    if (behavioralHits.mockup_directory_walk > 0) {
      fix.push("Agents still glob mockups — strengthen forbidden_until_continue grader");
    }
    if (behavioralHits.ran_ledger_screen === 0 && behavioralHits.ran_goal_next === 0) {
      fix.push("continue_command not running — wire first_command earlier in session_route.js");
    }
    if (!fix.length) {
      fix.push("Gather more sessions or tighten failure_signals; check transcript root resolution");
    }
  }

  report.musk = {
    question: "Did the optimization remove a part or add ceremony?",
    simplify: simplify.length ? simplify : ["Keep registry row; system is earning its keep"],
    fix: fix.length ? fix : ["No fix — gather more sessions or tighten failure_signals"]
  };

  return report;
}

function status(registryPath) {
  const reg = readRegistry(registryPath);
  const pending = reg.optimizations.filter((o) => !o.validated_at);
  const latest = reg.optimizations[reg.optimizations.length - 1] || null;
  const needsAfterValidation =
    latest &&
    !latest.validated_at &&
    latest.baseline_validation?.verdict === "baseline_confirmed";
  return {
    registry: registryPath,
    pending_validation: pending,
    latest,
    needs_after_validation: Boolean(needsAfterValidation),
    requires_user_confirm: pending.length > 0
  };
}

module.exports = {
  REGISTRY_PATH_DEFAULT: path.join(path.resolve(__dirname, "../.."), "session", "optimization-registry.json"),
  readRegistry,
  writeRegistry,
  discoverTranscriptRoots,
  resolveTranscriptRoots,
  listTranscripts,
  extractSessionData,
  analyzeBehavior,
  validateOptimization,
  status,
  sessionFailRate,
  sessionBehaviorSuccessRate
};
