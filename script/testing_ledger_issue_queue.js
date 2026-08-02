#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { root } = require("./ledger_hash");

const QUEUE_PATH = path.join(root, "validation", "testing-issue-queue.json");

function emptyQueue() {
  return {
    schema_version: 1,
    status: "append-only",
    issues: []
  };
}

function loadQueue() {
  if (!fs.existsSync(QUEUE_PATH)) return emptyQueue();
  try {
    const data = JSON.parse(fs.readFileSync(QUEUE_PATH, "utf8"));
    if (!Array.isArray(data.issues)) data.issues = [];
    data.schema_version = 1;
    return data;
  } catch {
    return emptyQueue();
  }
}

function saveQueue(queue) {
  fs.mkdirSync(path.dirname(QUEUE_PATH), { recursive: true });
  fs.writeFileSync(QUEUE_PATH, `${JSON.stringify(queue, null, 2)}\n`);
}

function issueId(screen, flowId, platform) {
  const stamp = new Date().toISOString().slice(0, 19).replace(/[-:T]/g, "");
  return `${screen}-${platform}-${flowId}-${stamp}`;
}

function appendIssue(issue) {
  const queue = loadQueue();
  queue.issues.push(issue);
  saveQueue(queue);
  return issue;
}

function findControl(screenData, platform, controlId) {
  return (screenData.controls?.[platform] || []).find((c) => c.id === controlId) || null;
}

function resolveFixOwner(screenData, platform, controlId, rootCauseClass) {
  if (rootCauseClass === "harness") {
    return platform === "ios"
      ? "script/testing_ledger_prove_ios.sh"
      : ".agents/skills/testing-ledger/SKILL.md + bundled @Computer";
  }
  const slice = screenData.platforms?.[platform] || {};
  const files = slice.source_files || [];
  if (!files.length) return null;

  const lower = (controlId || "").toLowerCase();
  const ranked = files.filter(Boolean);
  const match = ranked.find((f) => {
    const base = path.basename(f).toLowerCase();
    if (lower && base.includes(lower.replace(/-/g, ""))) return true;
    if (/privacy|terms|footer/.test(lower) && /terms|footer|privacy/i.test(f)) return true;
    if (/launch|screen|macscreen/.test(rootCauseClass) && /macscreens/i.test(f)) return true;
    return false;
  });
  return match || ranked[0];
}

function inferRootCauseClass(observed, blocker = "") {
  const text = `${observed} ${blocker}`.toLowerCase();
  if (/8787|health|seed|validation-db|api down|connection refused|dev-auth/.test(text)) {
    return "env";
  }
  if (/apple id|testflight|livekit|infra|blocked-infra|real-auth unavailable/.test(text)) {
    return "infra";
  }
  if (/harness|timeout|ax |accessibility|osascript|menu shortcut|overlay|coordinate/.test(text)) {
    return "harness";
  }
  return "app";
}

function retestCommand(platform, screen, flowId) {
  return `npm run testing:ledger-run -- --platform ${platform} --screen ${screen} --flow ${flowId}`;
}

function isOpenFixIssue(issue) {
  if (!issue || issue.retest_ready === true) return false;
  const status = String(issue.status || "open").toLowerCase();
  return status === "open" || status === "fixing";
}

function selectOpenFixIssue(queue, { platform = null, issueId = null } = {}) {
  const issues = (queue.issues || []).filter(isOpenFixIssue);
  if (issueId) {
    return issues.find((issue) => issue.id === issueId && (!platform || issue.platform === platform)) || null;
  }
  if (platform) return issues.find((issue) => issue.platform === platform) || null;
  return issues[0] || null;
}

function matchingRetestIssues(queue, { platform, screen, flowId }) {
  if (!platform || !screen || !flowId) return [];
  return (queue.issues || []).filter((issue) => {
    const status = String(issue.status || "").toLowerCase();
    return (
      issue.platform === platform &&
      issue.screen === screen &&
      issue.flow_id === flowId &&
      issue.retest_ready === true &&
      status !== "resolved"
    );
  });
}

function resolveMatchingRetestIssues(
  queue,
  target,
  { resolvedAt = new Date().toISOString(), resolution = "Successful retest" } = {}
) {
  const ids = new Set(matchingRetestIssues(queue, target).map((issue) => issue.id));
  for (const issue of queue.issues || []) {
    if (!ids.has(issue.id)) continue;
    issue.retest_ready = false;
    issue.status = "resolved";
    issue.resolved_at = resolvedAt;
    issue.resolution = resolution;
  }
  return [...ids];
}

module.exports = {
  QUEUE_PATH,
  loadQueue,
  saveQueue,
  appendIssue,
  issueId,
  findControl,
  resolveFixOwner,
  inferRootCauseClass,
  retestCommand,
  isOpenFixIssue,
  selectOpenFixIssue,
  matchingRetestIssues,
  resolveMatchingRetestIssues
};
