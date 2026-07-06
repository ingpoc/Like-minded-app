#!/usr/bin/env node
/**
 * Record runtime test result on one flow (primary status owner, schema v2).
 *
 *   npm run ledger:record-flow -- --platform macos --screen meet --flow rsvp-weekend \
 *     --result pass --evidence "CUA validation-gurusharan: RSVP toggles" --method CUA-click \
 *     --screenshot-ref output/validation/macos-screens/meetOverview.png
 */
const {
  findLedgerByScreenArg,
  loadScreenLedger,
  recordFlowLedger,
  flowSuccessCriteria
} = require("./ledger_hash");
const { validatePassTier } = require("./ledger_proof");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

const platform = arg("--platform");
const file = arg("--file");
const screen = arg("--screen");
const flowId = arg("--flow");
const result = arg("--result");
const evidence = arg("--evidence");
const method = arg("--method") || "manual";
const blocker = arg("--blocker");
const screenshotRef = arg("--screenshot-ref");
const noSync = process.argv.includes("--no-sync-controls");
const forceTier = process.argv.includes("--force-tier");

if (!platform || !flowId || !result) {
  console.error(
    "Usage: ledger_record_flow.js --platform ios|macos (--file NN.json | --screen meet) --flow FLOW_ID --result pass|fail|pending|blocked [--evidence TEXT] [--method CUA-click] [--screenshot-ref path] [--blocker TEXT] [--no-sync-controls] [--force-tier]"
  );
  process.exit(2);
}

const ledger = file
  ? loadScreenLedger(platform, file)
  : findLedgerByScreenArg(platform, screen);

const unified = ledger.unified || ledger.data;
const flow = (unified.flows || []).find((f) => f.id === flowId);
if (!flow) {
  console.error(`flow not found: ${flowId}`);
  process.exit(1);
}

const tierCheck = validatePassTier(flow, platform, method, result);
if (!tierCheck.ok && !forceTier && result === "pass") {
  console.error(`tier check failed: ${tierCheck.message}`);
  console.error(`required tier: ${tierCheck.tier}; use --force-tier to override`);
  process.exit(1);
}

const recorded = recordFlowLedger(ledger, platform, flowId, {
  result,
  evidence,
  method,
  blocker,
  screenshotRef,
  syncControls: !noSync,
  forceTier
});

console.log(
  `recorded ${platform}/${ledger.logicalId || ledger.file} flow=${flowId} -> ${result} tier=${recorded.proof?.tier || tierCheck.tier} criteria="${flowSuccessCriteria(recorded, platform)}"`
);
