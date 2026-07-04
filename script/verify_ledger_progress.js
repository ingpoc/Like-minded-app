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
    "\nFix: add unchecked PROGRESS.md items under Track — macOS Visual Parity or Track — iOS Ledger Honesty (or fix the open validation/<platform>/*.json controls). Do not mark phase/track complete while actionable fail/pending/stale-blocked controls lack an owner."
  );
  process.exit(1);
}

console.log("ledger_progress_ok: yes");
