#!/usr/bin/env node
/**
 * Promote flows to pass when all linked controls are pass + fresh hash.
 * Use after native interaction or control-level proof so flows[] stays in sync.
 *
 *   npm run ledger:sync-flows -- --platform macos
 *   npm run ledger:sync-flows -- --platform macos --screen meet
 */
const { findLedgerByScreenArg, syncFlowsFromControls } = require("./ledger_hash");
const { listScreenFiles, loadScreenFile } = require("./ledger_screens");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

const platform = arg("--platform") || "macos";
const screen = arg("--screen");
let total = 0;

if (screen) {
  const ledger = findLedgerByScreenArg(platform, screen);
  total = syncFlowsFromControls(ledger, platform);
  console.log(`ledger_sync_flows: ${platform}/${ledger.logicalId || ledger.file} synced=${total}`);
} else {
  for (const file of listScreenFiles()) {
    const { logicalId } = loadScreenFile(file);
    try {
      const ledger = findLedgerByScreenArg(platform, logicalId);
      const n = syncFlowsFromControls(ledger, platform);
      if (n > 0) console.log(`  ${logicalId}: synced ${n} flow(s)`);
      total += n;
    } catch {
      // screen may lack platform slice
    }
  }
  console.log(`ledger_sync_flows: ${platform} total_synced=${total}`);
}
