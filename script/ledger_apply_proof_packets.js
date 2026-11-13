#!/usr/bin/env node
/**
 * Backfill flows[].proof agent packets on validation/screens/*.json
 * Usage: node script/ledger_apply_proof_packets.js [--force]
 */
const { listScreenFiles, loadScreenFile, writeScreen } = require("./ledger_screens");
const { buildDefaultProof } = require("./ledger_proof");

const force = process.argv.includes("--force");
let updated = 0;

for (const file of listScreenFiles()) {
  const { abs, data, logicalId } = loadScreenFile(file);
  let touched = false;

  for (const flow of data.flows || []) {
    if (flow.proof && !force) continue;
    const base = buildDefaultProof(flow, data, logicalId, "ios");
    flow.proof = {
      tier: flow.proof?.tier || base.tier,
      preconditions: flow.proof?.preconditions || base.preconditions,
      success_signals: flow.proof?.success_signals || base.success_signals,
      mockup_ref: flow.proof?.mockup_ref ?? null,
      mockup_note: flow.proof?.mockup_note || base.mockup_note,
      commands: force ? base.commands : (flow.proof?.commands || base.commands),
      record_pass: force ? base.record_pass : (flow.proof?.record_pass || base.record_pass)
    };
    touched = true;
  }

  if (touched) {
    writeScreen(abs, data);
    updated += 1;
    console.log(`proof packets: ${logicalId} (${(data.flows || []).length} flows)`);
  }
}

console.log(`ledger_apply_proof_packets: screens_updated=${updated}`);
