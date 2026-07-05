#!/usr/bin/env node
/**
 * Compact session route for Cursor sessionStart hook and humans.
 * Reuses goal_next.js output — single routing brain.
 */
const { execFileSync } = require("node:child_process");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

const ROUTE_KEYS = new Set([
  "current_status:",
  "current_goal:",
  "dirty_work_required:",
  "active_track:",
  "ledger_progress_ok:",
  "first_command:",
  "session_lane:",
  "route_execute:",
  "route_forbid:",
  "after_dirty_resolved:",
  "open_tracks:",
  "ledger_ios:",
  "ledger_macos:"
]);

function sessionBrief() {
  const out = execFileSync("node", ["script/goal_next.js"], {
    cwd: root,
    encoding: "utf8"
  });
  return out
    .split("\n")
    .filter((line) => {
      const key = line.split(" ")[0];
      return ROUTE_KEYS.has(key);
    })
    .join("\n");
}

function hookPayload() {
  const brief = sessionBrief();
  const context = [
    "Likeminded session route (auto). Execute first_command end-to-end — no user prompt required.",
    brief,
    "Owners: validation JSON only. One screen → npm run ledger:screen. Lazy authoring: AGENTS.md § Context doctrine."
  ].join("\n");
  return { additional_context: context, additionalContext: context };
}

if (process.argv.includes("--hook-json")) {
  process.stdout.write(`${JSON.stringify(hookPayload())}\n`);
} else {
  process.stdout.write(`${sessionBrief()}\n`);
}
