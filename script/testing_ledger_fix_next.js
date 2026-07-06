#!/usr/bin/env node
"use strict";

/**
 * Next fix target for fix agents — queue first, then ledger fail evidence.
 * Never loads full ledger:open inventory.
 *
 *   npm run testing:ledger-fix-next
 *   npm run testing:ledger-fix-next -- --claim
 */
const { listScreenFiles, loadScreenFile, flowValidation } = require("./ledger_screens");
const { loadQueue, saveQueue, retestCommand } = require("./testing_ledger_issue_queue");

function arg(name, fallback = null) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const asJson = process.argv.includes("--json");
const claim = process.argv.includes("--claim");
const platformFilter = arg("--platform");

function isOpenIssue(issue) {
  if (!issue || issue.retest_ready === true) return false;
  const status = String(issue.status || "open").toLowerCase();
  return status === "open" || status === "fixing";
}

function pickFromQueue() {
  const queue = loadQueue();
  const issues = queue.issues.filter(isOpenIssue);
  if (platformFilter) {
    return issues.find((i) => i.platform === platformFilter) || null;
  }
  return issues[0] || null;
}

function pickFromLedgerFails() {
  const items = [];
  for (const file of listScreenFiles()) {
    const { data, logicalId } = loadScreenFile(file);
    for (const flow of data.flows || []) {
      for (const platform of ["ios", "macos"]) {
        if (platformFilter && platform !== platformFilter) continue;
        const v = flowValidation(flow, platform);
        if (String(v.result || "").toLowerCase() !== "fail") continue;
        const controlIds = flow.control_ids?.[platform] || [];
        items.push({
          schema: "testing-fix-target-v1",
          source: "ledger-fail",
          platform,
          screen: logicalId,
          flow_id: flow.id,
          control_id: controlIds[0] || null,
          expected: v.blocker || flow.name,
          observed: v.evidence || "ledger fail without evidence",
          root_cause_class: "app",
          fix_owner: data.platforms?.[platform]?.source_files?.[0] || null,
          retest_command: `npm run testing:ledger-run -- --platform ${platform} --screen ${logicalId} --flow ${flow.id}`,
          retest_ready: false,
          status: "open"
        });
      }
    }
  }
  items.sort((a, b) => a.screen.localeCompare(b.screen) || a.flow_id.localeCompare(b.flow_id));
  return items[0] || null;
}

function buildFixTarget(issue) {
  return {
    schema: "testing-fix-target-v1",
    source: "issue-queue",
    id: issue.id,
    platform: issue.platform,
    screen: issue.screen,
    flow_id: issue.flow_id,
    control_id: issue.control_id,
    expected: issue.expected,
    observed: issue.observed,
    root_cause_class: issue.root_cause_class,
    fix_owner: issue.fix_owner,
    retest_command: issue.retest_command,
    retest_ready: issue.retest_ready === true,
    status: issue.status || "open",
    commands: {
      runtime_lock_acquire: `./script/testing_ledger_runtime_lock.sh --platform ${issue.platform} acquire fix`,
      runtime_lock_release: `./script/testing_ledger_runtime_lock.sh --platform ${issue.platform} release`,
      read_owner: issue.fix_owner ? `Read ${issue.fix_owner} only` : `npm run ledger:screen -- --platform ${issue.platform} --screen ${issue.screen} --section source_files`,
      retest: `npm run testing:ledger-run -- --platform ${issue.platform} --screen ${issue.screen} --flow ${issue.flow_id}`,
      mark_retest_ready: `npm run testing:ledger-fix-next -- --mark-retest-ready ${issue.id}`,
      record_pass: `npm run ledger:record-flow -- --platform ${issue.platform} --screen ${issue.screen} --flow ${issue.flow_id} --result pass --method ${issue.platform === "ios" ? "screenshot" : "CUA-click"} --evidence "..."`
    }
  };
}

const markId = arg("--mark-retest-ready");
if (markId) {
  const queue = loadQueue();
  const issue = queue.issues.find((i) => i.id === markId);
  if (!issue) {
    console.error(`issue not found: ${markId}`);
    process.exit(1);
  }
  issue.retest_ready = true;
  issue.status = "retest_ready";
  issue.retest_ready_at = new Date().toISOString();
  saveQueue(queue);
  console.log(`marked retest_ready: ${markId}`);
  process.exit(0);
}

let issue = pickFromQueue();
if (issue && claim) {
  const queue = loadQueue();
  const idx = queue.issues.findIndex((i) => i.id === issue.id);
  if (idx >= 0) {
    queue.issues[idx].status = "fixing";
    queue.issues[idx].claimed_at = new Date().toISOString();
    saveQueue(queue);
    issue = queue.issues[idx];
  }
}

let target = issue ? buildFixTarget(issue) : pickFromLedgerFails();

if (!target) {
  if (asJson) {
    console.log(JSON.stringify({ target: null, message: "no open fix targets" }));
  } else {
    console.log("testing-ledger-fix-next: no open fix targets (queue empty, no ledger fails)");
  }
  process.exit(0);
}

if (asJson) {
  console.log(JSON.stringify(target, null, 2));
  process.exit(0);
}

const lockCmd = `./script/testing_ledger_runtime_lock.sh --platform ${target.platform}`;

console.log("# testing-ledger-fix-next");
console.log(`source: ${target.source}${target.id ? ` | id: ${target.id}` : ""}`);
console.log(`runtime_lock: ${lockCmd} acquire fixer (release before mark-retest-ready)`);
console.log(`target: ${target.screen}/${target.flow_id} (${target.platform})`);
console.log(`class: ${target.root_cause_class} | control: ${target.control_id || "(flow)"}`);
console.log(`expected: ${target.expected}`);
console.log(`observed: ${target.observed}`);
console.log(`fix_owner: ${target.fix_owner || "(ledger:screen source_files)"}`);
console.log(`retest: ${target.retest_command}`);
console.log(`retest_ready: ${target.retest_ready}`);
if (target.commands) {
  console.log(`after_fix: ${target.commands.mark_retest_ready || "set retest_ready on queue issue"}`);
}
