#!/usr/bin/env node
"use strict";

/**
 * Single tester turn: next target + merged run card (+ optional prove).
 *
 *   npm run testing:ledger-run
 *   npm run testing:ledger-run -- --platform ios
 *   npm run testing:ledger-run -- --platform macos --screen auth --flow auth-privacy-link
 *   npm run testing:ledger-run -- --platform ios --screen circle-detail --flow secondary-circle-selection --reprove
 *   npm run testing:ledger-run -- --card-only
 */
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const { root } = require("./ledger_hash");
const { pickNextFlow } = require("./testing_ledger_pick_next");
const {
  loadQueue,
  saveQueue,
  matchingRetestIssues,
  resolveMatchingRetestIssues
} = require("./testing_ledger_issue_queue");

function arg(name, fallback = null) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const platform = arg("--platform", "macos");
const screenArg = arg("--screen");
const flowArg = arg("--flow");
const cardOnly = process.argv.includes("--card-only");
const asJson = process.argv.includes("--json");
const reprove = process.argv.includes("--reprove");
const verbose = process.argv.includes("--verbose");
const targetRequested = Boolean(screenArg || flowArg);

if (reprove && (!screenArg || !flowArg)) {
  const hint =
    "rerun with both exact selectors: --screen <screen> --flow <flow> --reprove";
  if (asJson) {
    console.log(
      JSON.stringify({
        schema: "testing-ledger-run-error-v1",
        status: "invalid-usage",
        error: "--reprove requires both --screen and --flow",
        hint
      })
    );
  } else {
    console.error("Error: --reprove requires both --screen and --flow");
    console.error(`Hint: ${hint}`);
  }
  process.exit(2);
}

const requestedRetestIssues = matchingRetestIssues(loadQueue(), {
  platform,
  screen: screenArg,
  flowId: flowArg
});

const { candidates, next } = pickNextFlow(platform, {
  screen: screenArg,
  flowId: flowArg,
  includePass: reprove || requestedRetestIssues.length > 0
});

if (!next) {
  const message = targetRequested ? "requested target is not eligible for proof" : "no open flows";
  const hint =
    targetRequested && screenArg && flowArg
      ? `use --reprove only for an operator-requested fresh proof: npm run testing:ledger-run -- --platform ${platform} --screen ${screenArg} --flow ${flowArg} --reprove`
      : null;
  if (asJson) {
    console.log(
      JSON.stringify({
        schema: "testing-ledger-run-error-v1",
        status: targetRequested ? "ineligible" : "empty",
        platform,
        flow: null,
        message,
        hint
      })
    );
  } else {
    console.log(`testing-ledger-run: ${message} (${platform})`);
    if (hint) console.log(`Hint: ${hint}`);
  }
  process.exit(targetRequested ? 1 : 0);
}

const pkt = next.packet;
const selectedRetestIssues = matchingRetestIssues(loadQueue(), {
  platform,
  screen: next.screen,
  flowId: next.flow_id
});
const recordMethod = {
  capture: "screen-capture",
  "computer-use": "Computer-use",
  "api-persist": "api-persist",
  "real-auth": "real-auth",
  "real-livekit": "real-livekit"
}[pkt.proof_tier] || "Computer-use";
const proveCmd =
  platform === "ios"
    ? `npm run testing:ledger-prove-ios -- --screen ${next.screen} --flow ${next.flow_id}`
    : `@Computer: launch with npm run dev:macos:validation -- ${next.mac_screen || next.screen}; target <repo>/.build/macos/Build/Products/Debug/LikemindedMac.app by full path; execute ${next.screen}/${next.flow_id}; inspect fresh semantic state after every action`;
const recordCmd = `npm run ledger:record-flow -- --platform ${platform} --screen ${next.screen} --flow ${next.flow_id} --result pass --method ${recordMethod} --evidence "..."`;
const failCmd = `npm run testing:ledger-issue -- --screen ${next.screen} --flow ${next.flow_id} --platform ${platform} --observed "..."`;
const lockHint = platform === "macos"
  ? `./script/testing_ledger_runtime_lock.sh --platform macos lease-acquire computer-prove`
  : `./script/testing_ledger_runtime_lock.sh --platform ios try-acquire prove`;
const proofLog = path.join(
  root,
  "output",
  "validation",
  "testing-ledger",
  platform,
  `${next.screen}--${next.flow_id}.log`
);
const proofLogRelative = path.relative(root, proofLog);

const out = {
  schema: "testing-ledger-run-card-v1",
  platform,
  screen: next.screen,
  flow_id: next.flow_id,
  flow_name: next.flow_name,
  queue_result: next.result,
  selection_mode: reprove
    ? "operator-requested-reprove"
    : selectedRetestIssues.length
      ? "issue-retest"
      : "queue",
  proof_tier: pkt.proof_tier,
  mac_screen: next.mac_screen,
  open_remaining: candidates.length,
  preconditions: pkt.preconditions,
  success_signals: pkt.success_signals,
  mockup_ref: pkt.mockup_ref,
  baseline_screenshot: pkt.baseline_screenshot,
  proof_log: proofLogRelative,
  lock: lockHint,
  prove: proveCmd,
  record_pass: recordCmd,
  record_fail: failCmd,
  retest_issue_ids: selectedRetestIssues.map((issue) => issue.id),
  requires_manual_computer: platform === "macos"
};

if (asJson) {
  console.log(JSON.stringify(out, null, 2));
  process.exit(cardOnly ? 0 : runProve());
}

console.log("# testing-ledger-run");
console.log(`platform: ${platform} | target: ${next.screen}/${next.flow_id} (${next.result})`);
console.log(`selection: ${out.selection_mode}`);
console.log(`tier: ${pkt.proof_tier} | open_queue: ${candidates.length}`);
console.log(`PRE: ${pkt.preconditions.join(" | ")}`);
console.log(`PASS: ${pkt.success_signals.join(" | ")}`);
console.log(`MOCKUP: ${pkt.mockup_ref || "(none)"} | BASELINE: ${pkt.baseline_screenshot || "(none)"}`);
console.log(`PROOF_LOG: ${proofLogRelative}`);
console.log(`LOCK: ${lockHint}${platform === "macos" ? " (save token; release after the same-screen band)" : " (prove script acquires on entry)"}`);
console.log(`PROVE: ${proveCmd}`);
console.log(`RECORD_PASS: ${recordCmd}`);
console.log(`ON_FAIL: ${failCmd}`);

if (cardOnly) {
  process.exit(0);
}

process.exit(runProve());

function runProve() {
  if (platform === "macos") {
    console.log("macOS proof card ready: use @Computer, then run RECORD_PASS or ON_FAIL.");
    return 0;
  }
  const script =
    path.join(root, "script", "testing_ledger_prove_ios.sh");
  const args = ["--screen", next.screen, "--flow", next.flow_id];
  fs.mkdirSync(path.dirname(proofLog), { recursive: true });
  const startedAt = new Date().toISOString();
  const result = spawnSync(script, args, {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
    stdio: ["inherit", "pipe", "pipe"]
  });
  const stdout = result.stdout || "";
  const stderr = result.stderr || "";
  const rawStatus = result.status ?? 1;
  const honesty = interpretProveHonesty(stdout, rawStatus);
  const status = honesty.status;
  const endedAt = new Date().toISOString();
  const durationMs = Date.parse(endedAt) - Date.parse(startedAt);
  const proveSummary = status === 0 ? "pass" : "fail";
  fs.writeFileSync(
    proofLog,
    [
      `started_at=${startedAt}`,
      `platform=${platform} screen=${next.screen} flow=${next.flow_id}`,
      "[stdout]",
      stdout.trimEnd(),
      "[stderr]",
      stderr.trimEnd(),
      honesty.note ? `honesty=${honesty.note}` : null,
      `prove_summary=${proveSummary}`,
      `duration_ms=${durationMs}`,
      `exit_status=${status}`,
      `raw_exit_status=${rawStatus}`,
      `ended_at=${endedAt}`,
      ""
    ]
      .filter((line) => line != null)
      .join("\n")
  );
  if (verbose) {
    if (stdout) process.stdout.write(stdout);
    if (stderr) process.stderr.write(stderr);
  } else if (status !== 0) {
    const failureTail = conciseTail(`${stdout}\n${stderr}`, 24);
    if (failureTail) process.stderr.write(`[failure-tail]\n${failureTail}\n`);
    if (honesty.note) process.stderr.write(`[honesty] ${honesty.note}\n`);
    process.stderr.write(`Hint: inspect ${proofLogRelative}, then use the ON_FAIL command above\n`);
  }
  if (result.error) process.stderr.write(`prove spawn error: ${result.error.message}\n`);
  console.log(`PROVE_RESULT: ${proveSummary} duration_ms=${durationMs}`);
  console.log(`PROOF_LOG_WRITTEN: ${proofLogRelative}`);
  if (status === 0) {
    const resolved = resolveRetestIssues();
    if (resolved.length) console.log(`RETEST_ISSUES_RESOLVED: ${resolved.join(",")}`);
  }
  return status;
}

/** Fail closed: exit 0 without `prove_summary ok=N miss=0 flow_fail=0` is not a pass. */
function interpretProveHonesty(stdout, rawStatus) {
  const match = String(stdout || "").match(
    /prove_summary ok=(\d+) miss=(\d+) flow_fail=(\d+)/
  );
  if (!match) {
    return {
      status: 1,
      note:
        rawStatus === 0
          ? "rejected exit 0 without prove_summary line (false-pass guard)"
          : "missing prove_summary line"
    };
  }
  const miss = Number(match[2]);
  const flowFail = Number(match[3]);
  if (rawStatus !== 0) {
    return { status: rawStatus, note: null };
  }
  if (flowFail !== 0 || miss !== 0) {
    return {
      status: 1,
      note: `rejected exit 0 with prove_summary ok=${match[1]} miss=${miss} flow_fail=${flowFail}`
    };
  }
  return { status: 0, note: null };
}

function conciseTail(value, maxLines) {
  return String(value || "")
    .split(/\r?\n/)
    .filter((line) => line.trim())
    .slice(-maxLines)
    .join("\n");
}

function resolveRetestIssues() {
  const queue = loadQueue();
  const resolvedAt = new Date().toISOString();
  const ids = resolveMatchingRetestIssues(
    queue,
    { platform, screen: next.screen, flowId: next.flow_id },
    {
      resolvedAt,
      resolution: `Successful retest: ${platform} ${next.screen}/${next.flow_id} exited 0; ${proofLogRelative}`
    }
  );
  if (!ids.length) return [];
  saveQueue(queue);
  return ids;
}
