#!/usr/bin/env node
"use strict";

/**
 * Emit compact tester→fixer handoff packet; append to testing-issue-queue.json.
 *
 *   npm run testing:ledger-issue -- --screen auth --flow auth-privacy-link \
 *     --observed "sheet AX timeout"
 */
const { findLedgerByScreenArg } = require("./ledger_hash");
const { buildAgentPacket, findFlow } = require("./ledger_proof");
const {
  appendIssue,
  issueId,
  findControl,
  resolveFixOwner,
  inferRootCauseClass,
  retestCommand
} = require("./testing_ledger_issue_queue");

function arg(name, fallback = null) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const platform = arg("--platform", "macos");
const screen = arg("--screen");
const flowId = arg("--flow");
const observed = arg("--observed");
const controlIdArg = arg("--control");
const expectedArg = arg("--expected");
const rootCauseArg = arg("--root-cause-class");
const asJson = process.argv.includes("--json");
const noQueue = process.argv.includes("--no-queue");

if (!screen || !flowId || !observed) {
  console.error(
    "Usage: testing_ledger_issue_packet.js --screen <id> --flow <flow-id> --observed \"...\" [--platform macos|ios] [--control <id>] [--expected \"...\"] [--root-cause-class env|harness|app|infra] [--json] [--no-queue]"
  );
  process.exit(2);
}

const ledger = findLedgerByScreenArg(platform, screen);
const unified = ledger.unified || ledger.data;
const logicalId = ledger.logicalId || unified.logical_screen_id || screen;
const flow = findFlow(unified, flowId);

if (!flow) {
  console.error(`flow not found: ${logicalId}/${flowId}`);
  process.exit(1);
}

const packetBase = buildAgentPacket(unified, flow, platform, logicalId);
const controlIds = flow.control_ids?.[platform] || [];
const controlId = controlIdArg || controlIds[0] || null;
const control = controlId ? findControl(unified, platform, controlId) : null;
const validation = flow.validation?.[platform] || {};

const expected =
  expectedArg ||
  control?.expected ||
  packetBase.success_signals[0] ||
  packetBase.success_criteria;

const rootCauseClass =
  rootCauseArg && ["env", "harness", "app", "infra"].includes(rootCauseArg)
    ? rootCauseArg
    : inferRootCauseClass(observed, validation.blocker || "");

const fixOwner = resolveFixOwner(unified, platform, controlId, rootCauseClass);
const retest = retestCommand(platform, logicalId, flowId);

const packet = {
  schema: "testing-issue-packet-v1",
  id: issueId(logicalId, flowId, platform),
  platform,
  screen: logicalId,
  flow_id: flowId,
  control_id: controlId,
  expected,
  observed,
  root_cause_class: rootCauseClass,
  fix_owner: fixOwner,
  retest_command: retest,
  retest_ready: false,
  status: "open",
  created_at: new Date().toISOString()
};

if (!noQueue) {
  appendIssue(packet);
}

if (asJson) {
  process.stdout.write(`${JSON.stringify(packet, null, 2)}\n`);
  process.exit(0);
}

const lines = [
  `# testing-issue ${packet.id}`,
  `screen: ${packet.screen} | flow: ${packet.flow_id} | control: ${packet.control_id || "(flow)"}`,
  `platform: ${packet.platform} | class: ${packet.root_cause_class}`,
  `expected: ${packet.expected}`,
  `observed: ${packet.observed}`,
  `fix_owner: ${packet.fix_owner || "(resolve from ledger:screen source_files)"}`,
  `retest: ${retest}`,
  `retest_ready: ${packet.retest_ready}`,
  `fix_run: npm run testing:ledger-fix-run -- --platform ${platform}`,
  `record_pass: npm run ledger:record-flow -- --platform ${platform} --screen ${logicalId} --flow ${flowId} --result pass --method CUA-click --evidence "..."`,
  `record_fail: npm run ledger:record-flow -- --platform ${platform} --screen ${logicalId} --flow ${flowId} --result fail --method CUA-click --evidence "${observed}"`
];

console.log(lines.join("\n"));
