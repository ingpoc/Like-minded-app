#!/usr/bin/env node
"use strict";

/**
 * Single fixer turn: claim next issue + compact fix card (~12 lines).
 *
 *   npm run testing:ledger-fix-run
 *   npm run testing:ledger-fix-run -- --platform ios
 *   npm run testing:ledger-fix-run -- --no-claim
 */
const { spawnSync } = require("node:child_process");
const path = require("node:path");
const { root } = require("./ledger_hash");

function arg(name, fallback = null) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const platformFilter = arg("--platform");
const noClaim = process.argv.includes("--no-claim");
const asJson = process.argv.includes("--json");

const fixArgs = ["script/testing_ledger_fix_next.js", "--json"];
if (platformFilter) fixArgs.push("--platform", platformFilter);
if (!noClaim) fixArgs.push("--claim");

const result = spawnSync("node", fixArgs, { cwd: root, encoding: "utf8" });
if (result.status !== 0) {
  process.stderr.write(result.stderr || "");
  process.exit(result.status ?? 1);
}

const raw = (result.stdout || "").trim();
if (!raw || raw.includes("no open fix targets")) {
  console.log(raw || "testing-ledger-fix-run: no open fix targets");
  process.exit(0);
}

if (asJson) {
  console.log(raw);
  process.exit(0);
}

let target;
try {
  target = JSON.parse(raw);
} catch {
  console.log(raw);
  process.exit(0);
}

const lockAcquire = `./script/testing_ledger_runtime_lock.sh --platform ${target.platform} acquire fixer`;
const lockRelease = `./script/testing_ledger_runtime_lock.sh --platform ${target.platform} release`;
const retest =
  target.retest_command ||
  `npm run testing:ledger-run -- --platform ${target.platform} --screen ${target.screen} --flow ${target.flow_id}`;
const markReady = target.id
  ? `npm run testing:ledger-fix-next -- --mark-retest-ready ${target.id}`
  : "queue issue: set retest_ready after fix";
const ownerRead = target.fix_owner ? `Read: ${target.fix_owner}` : `npm run ledger:screen -- --platform ${target.platform} --screen ${target.screen} --section source_files`;

const lines = [
  "# testing-ledger-fix-run",
  `source: ${target.source}${target.id ? ` | id: ${target.id}` : ""}`,
  `target: ${target.screen}/${target.flow_id} (${target.platform})`,
  `class: ${target.root_cause_class} | expected: ${target.expected}`,
  `observed: ${target.observed}`,
  ownerRead,
  `LOCK_ACQUIRE: ${lockAcquire}`,
  `LOCK_RELEASE: ${lockRelease} (before mark-retest-ready)`,
  `RETEST: ${retest}`,
  `MARK_READY: ${markReady}`,
  `SKIP: ledger:open, GOAL.md, PROGRESS.md, mockups/**, full @build-ios-app skill`
];

console.log(lines.join("\n"));
