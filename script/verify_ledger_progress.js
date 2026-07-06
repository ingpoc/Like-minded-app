#!/usr/bin/env node
const { ownershipReport, formatGoalNextLines } = require("./ledger_progress");

const report = ownershipReport();
for (const line of formatGoalNextLines(report)) {
  console.log(line);
}

if (!report.ok) {
  console.error("\nLedger ↔ PROGRESS ownership failed:");
  for (const error of report.errors) {
    console.error(`- ${error}`);
  }
  console.error(
    "\nFix: align PROGRESS.md checkboxes with validation JSON, remove stale goal.json route_contract, and ensure open validation controls have track owners. Do not mark phase/track complete while actionable fail/pending/stale-blocked/stale_pass controls lack an owner or contradict PROGRESS."
  );
  process.exit(1);
}

console.log("ledger_progress_ok: yes");
