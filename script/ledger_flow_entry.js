#!/usr/bin/env node
"use strict";

const { findLedgerByScreenArg } = require("./ledger_hash");
const { buildAgentPacket, findFlow } = require("./ledger_proof");

function arg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

const platform = arg("--platform", "macos");
const screen = arg("--screen");
const flowId = arg("--flow");
const asText = process.argv.includes("--text");

if (!screen || !flowId) {
  console.error(
    "Usage: ledger_flow_entry.js --platform ios|macos --screen <logical-id> --flow <flow-id> [--text]"
  );
  process.exit(2);
}

const ledger = findLedgerByScreenArg(platform, screen);
const unified = ledger.unified || ledger.data;
const logicalId = ledger.logicalId || unified.logical_screen_id || screen;
const flow = findFlow(unified, flowId);

if (!flow) {
  console.error(`flow not found: ${logicalId}/${flowId}`);
  process.exit(1);
}

const packet = buildAgentPacket(unified, flow, platform, logicalId);

if (asText) {
  console.log(`screen: ${packet.screen} | flow: ${packet.flow_id} | platform: ${packet.platform}`);
  console.log(`result: ${packet.result}${packet.stale_pass ? " (stale-pass)" : ""}`);
  console.log(`tier: ${packet.proof_tier} | method_ok: ${packet.method_meets_tier}`);
  console.log(`PRE: ${packet.preconditions.join(" | ")}`);
  console.log(`PASS: ${packet.success_signals.join(" | ")}`);
  console.log(`MOCKUP: ${packet.mockup_ref || "(none)"}`);
  if (packet.mockup_note) console.log(`MOCKUP_NOTE: ${packet.mockup_note}`);
  console.log(`BASELINE: ${packet.baseline_screenshot || "(none)"}`);
  console.log(`PROOF_PNG: ${packet.proof_screenshot || "(none)"}`);
  console.log(`RUN: ${packet.commands}`);
  console.log(`RECORD: ${packet.record_pass}`);
  process.exit(0);
}

process.stdout.write(`${JSON.stringify(packet, null, 2)}\n`);
