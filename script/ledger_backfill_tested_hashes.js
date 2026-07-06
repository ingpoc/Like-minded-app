#!/usr/bin/env node
/**
 * Backfill tested_source_hash on pass controls/flows that lack it (schema v2).
 */
const { listScreenFiles, loadScreenFile, hashPlatformSlice, writeScreen } = require("./ledger_screens");
const { isoNow } = require("./ledger_hash");

const onlyPlatform = process.argv.find((a) => a.startsWith("--platform="))?.split("=")[1];
const platforms = onlyPlatform ? [onlyPlatform] : ["ios", "macos"];
let updated = 0;

function dateFromEvidence(evidence) {
  const m = String(evidence || "").match(/(20\d{2}-\d{2}-\d{2})/);
  return m ? m[1] : isoNow();
}

for (const file of listScreenFiles()) {
  const { abs, data, logicalId } = loadScreenFile(file);
  let touched = false;
  for (const platform of platforms) {
    const currentHash = hashPlatformSlice(data, platform);
    if (!currentHash) continue;
    for (const control of data.controls?.[platform] || []) {
      if (String(control.result).toLowerCase() !== "pass") continue;
      if (control.tested_source_hash) continue;
      control.tested_source_hash = currentHash;
      control.last_tested_at = control.last_tested_at || dateFromEvidence(control.evidence);
      control.last_test_method = control.last_test_method || "backfill";
      touched = true;
      updated += 1;
    }
    for (const flow of data.flows || []) {
      const v = flow.validation?.[platform];
      if (!v || String(v.result).toLowerCase() !== "pass") continue;
      if (v.tested_source_hash) continue;
      v.tested_source_hash = currentHash;
      v.last_tested_at = v.last_tested_at || dateFromEvidence(v.evidence);
      v.last_test_method = v.last_test_method || "backfill";
      touched = true;
      updated += 1;
    }
  }
  if (touched) {
    writeScreen(abs, data);
    console.log(`backfilled ${logicalId}`);
  }
}

console.log(`ledger:backfill-test-hashes rows_updated=${updated}`);
