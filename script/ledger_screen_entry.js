#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { findLedgerByScreenArg, refreshScreenSourceHash } = require("./ledger_hash");

function arg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

const platform = arg("--platform", "macos");
const screen = arg("--screen");
const section = arg("--section", "all");

if (!screen) {
  console.error("Usage: ledger_screen_entry.js --platform macos|ios --screen <screen> [--section all|ui|controls|flows|summary]");
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

let payload;
switch (section) {
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
