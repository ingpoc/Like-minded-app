#!/usr/bin/env node
/**
 * One-time/backfill: set tested_source_hash on existing pass controls that lack it.
 * Uses date from evidence text when present; does not change result or evidence.
 */
const fs = require("node:fs");
const path = require("node:path");
const { hashScreenSources, writeLedger, root, isoNow } = require("./ledger_hash");

const onlyPlatform = process.argv.find((a) => a.startsWith("--platform="))?.split("=")[1];
const platforms = onlyPlatform ? [onlyPlatform] : ["ios", "macos"];
let updated = 0;

function dateFromEvidence(evidence) {
  const m = String(evidence || "").match(/(20\d{2}-\d{2}-\d{2})/);
  return m ? m[1] : isoNow();
}

for (const platform of platforms) {
  const dir = path.join(root, "validation", platform);
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".json")).sort()) {
    const abs = path.join(dir, file);
    const data = JSON.parse(fs.readFileSync(abs, "utf8"));
    const currentHash = hashScreenSources(data, root);
    if (!currentHash) continue;
    let touched = false;
    data.source_hash = currentHash;
    for (const control of data.controls || []) {
      if (String(control.result).toLowerCase() !== "pass") continue;
      if (control.tested_source_hash) continue;
      control.tested_source_hash = currentHash;
      control.last_tested_at = control.last_tested_at || dateFromEvidence(control.evidence);
      control.last_test_method = control.last_test_method || "backfill";
      touched = true;
      updated += 1;
    }
    if (touched) writeLedger(abs, data);
  }
}

console.log(`ledger:backfill-test-hashes controls_updated=${updated}`);
