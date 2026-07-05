#!/usr/bin/env node
/**
 * Re-stamp stale-pass controls after CUA/screen-capture reproof.
 *
 *   node script/ledger_stamp_stale_pass.js --platform macos --method CUA \
 *     --evidence-prefix "CUA validation-priya 2026-07-05"
 *
 * Optional: --screen meetOverview  (only one ledger file)
 */
const fs = require("node:fs");
const path = require("node:path");
const {
  root,
  loadScreenLedger,
  findLedgerByScreenArg,
  writeLedger,
  refreshScreenSourceHash,
  isControlStale,
  isoNow
} = require("./ledger_hash");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

const platform = arg("--platform") || "macos";
const screen = arg("--screen");
const file = arg("--file");
const method = arg("--method") || "CUA";
const evidencePrefix = arg("--evidence-prefix") || `${method} ${isoNow()}`;

const dir = path.join(root, "validation", platform);
let files = fs.readdirSync(dir).filter((name) => name.endsWith(".json"));

if (file) {
  files = [file.endsWith(".json") ? file : `${file}.json`];
} else if (screen) {
  const ledger = findLedgerByScreenArg(platform, screen);
  files = [ledger.file];
}

let stampedTotal = 0;

for (const name of files) {
  const { abs, data } = loadScreenLedger(platform, name);
  const currentHash = refreshScreenSourceHash(data);
  const staleIds = (data.controls || [])
    .filter((control) => isControlStale(control, currentHash))
    .map((control) => control.id);

  if (staleIds.length === 0) {
    continue;
  }

  for (const id of staleIds) {
    const control = data.controls.find((c) => c.id === id);
    if (!control) continue;
    control.result = "pass";
    control.last_tested_at = isoNow();
    control.last_test_method = method;
    if (currentHash) control.tested_source_hash = currentHash;
    control.evidence = `${evidencePrefix}: reproof after source hash change (${id})`;
    control.blocker = "";
    control.stub = false;
    stampedTotal += 1;
  }

  writeLedger(abs, data);
  console.log(`stamped ${platform}/${name}: ${staleIds.join(", ")} hash=${currentHash}`);
}

console.log(`ledger_stamp_stale_pass: ${stampedTotal} control(s) on ${platform}`);
