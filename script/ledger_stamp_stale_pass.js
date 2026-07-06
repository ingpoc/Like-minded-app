#!/usr/bin/env node
/**
 * Re-stamp stale-pass controls and flows after CUA/screen-capture reproof (schema v2).
 *
 *   npm run ledger:stamp-stale -- --platform ios --method screen-capture
 *   npm run ledger:stamp-stale -- --platform macos --screen meetOverview --method CUA
 */
const {
  findLedgerByScreenArg,
  stampStaleLedger,
  syncFlowsFromControls,
  persistLedger,
  getPlatformHash,
  isoNow
} = require("./ledger_hash");
const { listScreenFiles, loadScreenFile } = require("./ledger_screens");
const { logicalIdFromScreenArg } = require("./ios_screen_stamp_map");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

const platform = arg("--platform") || "macos";
const screen = arg("--screen");
const method = arg("--method") || "CUA";
const evidencePrefix = arg("--evidence-prefix") || `${method} ${isoNow()}`;

let screens = [];
if (screen) {
  screens = [logicalIdFromScreenArg(screen)];
} else {
  screens = listScreenFiles().map((f) => loadScreenFile(f).logicalId);
}

let stampedControls = 0;
let stampedFlows = 0;

for (const logicalId of screens) {
  let ledger;
  try {
    ledger = findLedgerByScreenArg(platform, logicalId);
  } catch {
    continue;
  }
  const result = stampStaleLedger(ledger, platform, { method, evidencePrefix });
  const synced = syncFlowsFromControls(ledger, platform);
  persistLedger(ledger);
  if (result.controls.length || result.flows.length) {
    console.log(
      `stamped ${platform}/${logicalId}: controls=[${result.controls.join(", ")}] flows=[${result.flows.join(", ")}] hash=${getPlatformHash(ledger, platform)} synced=${synced}`
    );
  }
  stampedControls += result.controls.length;
  stampedFlows += result.flows.length;
}

console.log(`ledger_stamp_stale_pass: controls=${stampedControls} flows=${stampedFlows} on ${platform}`);
