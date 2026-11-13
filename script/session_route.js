#!/usr/bin/env node
/**
 * Compact session route for Cursor sessionStart hook and humans.
 * Hook uses goal_next --compact only (minimal high-signal lines).
 */
const { execFileSync } = require("node:child_process");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function sessionBrief(compact) {
  const args = compact ? ["script/goal_next.js", "--compact"] : ["script/goal_next.js"];
  return execFileSync("node", args, { cwd: root, encoding: "utf8" }).trim();
}

function hookPayload() {
  const brief = sessionBrief(true);
  const context = `Work bucket first. Run first_command end-to-end; forbidden_until_continue applies until continue_command completes.\n${brief}`;
  return { additional_context: context, additionalContext: context };
}

if (process.argv.includes("--hook-json")) {
  process.stdout.write(`${JSON.stringify(hookPayload())}\n`);
} else {
  process.stdout.write(`${sessionBrief(false)}\n`);
}
