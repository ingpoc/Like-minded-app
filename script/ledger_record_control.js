#!/usr/bin/env node
/**
 * Record runtime test result on one ledger control after native/manual proof.
 *
 *   node script/ledger_record_control.js \
 *     --platform macos --screen meetOverview \
 *     --control join-meetup --result pass \
 *     --evidence "<dated semantic observation>" \
 *     --method Computer-use
 */
const {
  findLedgerByScreenArg,
  loadScreenLedger,
  recordControlLedger,
  syncFlowsFromControls,
  persistLedger,
  getPlatformHash
} = require("./ledger_hash");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

const platform = arg("--platform");
const file = arg("--file");
const screen = arg("--screen");
const controlId = arg("--control");
const result = arg("--result");
const evidence = arg("--evidence");
const method = arg("--method") || "manual";

if (!platform || !controlId || !result) {
  console.error(
    "Usage: ledger_record_control.js --platform ios|macos (--file NN-name.json | --screen meetOverview) --control ID --result pass|fail|pending|blocked [--evidence TEXT] [--method Computer-use]"
  );
  process.exit(2);
}

const ledger = file
  ? loadScreenLedger(platform, file)
  : findLedgerByScreenArg(platform, screen);

recordControlLedger(ledger, platform, controlId, { result, evidence, method });
const synced = syncFlowsFromControls(ledger, platform);
persistLedger(ledger);

console.log(
  `recorded ${platform}/${ledger.logicalId || ledger.file} ${controlId} -> ${result} @ ${getPlatformHash(ledger, platform)} flows_synced=${synced}`
);
