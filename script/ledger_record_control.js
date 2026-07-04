#!/usr/bin/env node
/**
 * Record runtime test result on one ledger control (after CUA/manual proof).
 *
 *   node script/ledger_record_control.js \
 *     --platform macos --screen meetOverview \
 *     --control join-meetup --result pass \
 *     --evidence "2026-07-04 CUA validation-priya: Join clicked" \
 *     --method CUA
 */
const {
  findLedgerByScreenArg,
  loadScreenLedger,
  recordControl,
  writeLedger,
  refreshScreenSourceHash
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
    "Usage: ledger_record_control.js --platform ios|macos (--file NN-name.json | --screen meetOverview) --control ID --result pass|fail|pending|blocked [--evidence TEXT] [--method CUA]"
  );
  process.exit(2);
}

const ledger = file
  ? loadScreenLedger(platform, file)
  : findLedgerByScreenArg(platform, screen);

refreshScreenSourceHash(ledger.data);
recordControl(ledger.data, controlId, { result, evidence, method });
writeLedger(ledger.abs, ledger.data);

console.log(`recorded ${platform}/${ledger.file} ${controlId} -> ${result} @ ${ledger.data.source_hash}`);
