#!/usr/bin/env node
"use strict";

/**
 * Single tester turn: next target + merged run card (+ optional prove).
 *
 *   npm run testing:ledger-run
 *   npm run testing:ledger-run -- --platform ios
 *   npm run testing:ledger-run -- --platform macos --screen auth --flow auth-privacy-link
 *   npm run testing:ledger-run -- --card-only
 */
const { spawnSync } = require("node:child_process");
const path = require("node:path");
const { root } = require("./ledger_hash");
const { pickNextFlow } = require("./testing_ledger_pick_next");

function arg(name, fallback = null) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const platform = arg("--platform", "macos");
const screenArg = arg("--screen");
const flowArg = arg("--flow");
const cardOnly = process.argv.includes("--card-only");
const asJson = process.argv.includes("--json");

const { candidates, next } = pickNextFlow(platform, {
  screen: screenArg,
  flowId: flowArg
});

if (!next) {
  if (asJson) {
    console.log(JSON.stringify({ platform, flow: null, message: "no open flows" }));
  } else {
    console.log(`testing-ledger-run: no open ${platform} flows`);
  }
  process.exit(0);
}

const pkt = next.packet;
const recordMethod = platform === "ios" ? "screenshot" : "CUA-click";
const proveCmd =
  platform === "ios"
    ? `npm run testing:ledger-prove-ios -- --screen ${next.screen} --flow ${next.flow_id}`
    : `npm run testing:ledger-prove -- --screen ${next.screen} --flow ${next.flow_id}`;
const recordCmd = `npm run ledger:record-flow -- --platform ${platform} --screen ${next.screen} --flow ${next.flow_id} --result pass --method ${recordMethod} --evidence "..."`;
const failCmd = `npm run testing:ledger-issue -- --screen ${next.screen} --flow ${next.flow_id} --platform ${platform} --observed "..."`;
const lockHint = `./script/testing_ledger_runtime_lock.sh --platform ${platform} try-acquire prove`;

const out = {
  schema: "testing-ledger-run-card-v1",
  platform,
  screen: next.screen,
  flow_id: next.flow_id,
  flow_name: next.flow_name,
  queue_result: next.result,
  proof_tier: pkt.proof_tier,
  mac_screen: next.mac_screen,
  open_remaining: candidates.length,
  preconditions: pkt.preconditions,
  success_signals: pkt.success_signals,
  mockup_ref: pkt.mockup_ref,
  baseline_screenshot: pkt.baseline_screenshot,
  lock: lockHint,
  prove: proveCmd,
  record_pass: recordCmd,
  record_fail: failCmd
};

if (asJson) {
  console.log(JSON.stringify(out, null, 2));
  process.exit(cardOnly ? 0 : runProve());
}

console.log("# testing-ledger-run");
console.log(`platform: ${platform} | target: ${next.screen}/${next.flow_id} (${next.result})`);
console.log(`tier: ${pkt.proof_tier} | open_queue: ${candidates.length}`);
console.log(`PRE: ${pkt.preconditions.join(" | ")}`);
console.log(`PASS: ${pkt.success_signals.join(" | ")}`);
console.log(`MOCKUP: ${pkt.mockup_ref || "(none)"} | BASELINE: ${pkt.baseline_screenshot || "(none)"}`);
console.log(`LOCK: ${lockHint} (prove script acquires on entry)`);
console.log(`PROVE: ${proveCmd}`);
console.log(`RECORD_PASS: ${recordCmd}`);
console.log(`ON_FAIL: ${failCmd}`);

if (cardOnly) {
  process.exit(0);
}

process.exit(runProve());

function runProve() {
  const script =
    platform === "ios"
      ? path.join(root, "script", "testing_ledger_prove_ios.sh")
      : path.join(root, "script", "testing_ledger_prove_flow.sh");
  const args = ["--screen", next.screen, "--flow", next.flow_id];
  const result = spawnSync(script, args, { cwd: root, stdio: "inherit" });
  return result.status ?? 1;
}
