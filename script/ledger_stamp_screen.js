#!/usr/bin/env node
/**
 * Stamp last_tested_at + tested_source_hash on multiple controls after a screen Computer pass.
 *
 *   node script/ledger_stamp_screen.js --platform macos --screen meetOverview \
 *     --controls rsvp-sun-yes,rsvp-sun-no --method Computer-use \
 *     --evidence-prefix "Computer validation-gurusharan"
 */
const {
  findLedgerByScreenArg,
  loadScreenLedger,
  stampControlsLedger,
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
const controlsRaw = arg("--controls");
const method = arg("--method") || "Computer-use";
const evidencePrefix = arg("--evidence-prefix") || `${method}`;

if (!platform || (!file && !screen)) {
  console.error(
    "Usage: ledger_stamp_screen.js --platform ios|macos (--file NN.json | --screen meetOverview) [--controls id1,id2] [--method Computer-use] [--evidence-prefix TEXT]"
  );
  process.exit(2);
}

const ledger = file
  ? loadScreenLedger(platform, file)
  : findLedgerByScreenArg(platform, screen);

const controlIds = controlsRaw ? controlsRaw.split(",").map((s) => s.trim()).filter(Boolean) : [];
const stamped = stampControlsLedger(ledger, platform, controlIds, { method, evidencePrefix });
const synced = syncFlowsFromControls(ledger, platform);
persistLedger(ledger);

console.log(
  `stamped ${platform}/${ledger.logicalId || ledger.file}: ${stamped.join(", ")} source_hash=${getPlatformHash(ledger, platform)} flows_synced=${synced}`
);
