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
  if (/cua|harness|timeout|ax |accessibility|osascript|menu shortcut|overlay|coordinate/.test(text)) {
    return "harness";
  }
  return "app";
}

function retestCommand(platform, screen, flowId) {
  return `npm run testing:ledger-run -- --platform ${platform} --screen ${screen} --flow ${flowId}`;
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
  retestCommand
};
