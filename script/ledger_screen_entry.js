#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { findLedgerByScreenArg, refreshScreenSourceHash } = require("./ledger_hash");
const { flowValidation, isFlowStale } = require("./ledger_screens");

function arg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

const platform = arg("--platform", "macos");
const screen = arg("--screen");
const section = arg("--section", "all");

if (!screen) {
  console.error("Usage: ledger_screen_entry.js --platform macos|ios --screen <screen> [--section route|all|ui|controls|flows|summary]");
  process.exit(2);
}

const ledger = findLedgerByScreenArg(platform, screen);
refreshScreenSourceHash(ledger.data);

const summary = {
  file: path.relative(process.cwd(), ledger.abs),
  screen: ledger.data.screen,
  platform: ledger.data.platform,
  logical_screen_id: ledger.logicalId || ledger.data.logical_screen_id || null,
  mockup_ref: ledger.data.mockup_ref || null,
  recent_screenshot_ref: ledger.data.recent_screenshot_ref || null,
  source_hash: ledger.data.source_hash || null
};

function routeFlow(flow) {
  const validation = flowValidation(flow, platform);
  const result = String(validation.result || "pending").toLowerCase();
  return {
    id: flow.id,
    name: flow.name,
    result: isFlowStale(flow, platform, summary.source_hash) ? "stale-pass" : result,
    proof_tier: flow.proof?.tier || null,
    last_test_method: validation.last_test_method || null,
    tested_source_hash: validation.tested_source_hash || null
  };
}

let payload;
switch (section) {
  case "route": {
    const flows = ledger.unified?.flows || ledger.data.flows || [];
    payload = {
      ...summary,
      source_files: ledger.data.source_files || [],
      entry_points: ledger.data.entry_points || [],
      ui_validation: ledger.data.ui_validation || ledger.data.visual_parity || null,
      flows: flows.map(routeFlow)
    };
    break;
  }
  case "summary":
    payload = summary;
    break;
  case "ui":
    payload = { ...summary, ui_validation: ledger.data.ui_validation || ledger.data.visual_parity || null };
    break;
  case "controls":
    payload = { ...summary, controls: ledger.data.controls || [] };
    break;
  case "flows":
    payload = {
      ...summary,
      flows: ledger.unified?.flows || ledger.data.flows || []
    };
    break;
  case "all":
    payload = ledger.unified
      ? { ...summary, ...ledger.unified, platform_slice: ledger.data }
      : { ...summary, ...ledger.data };
    break;
  default:
    console.error(`Unknown --section ${section}`);
    process.exit(2);
}

process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);
