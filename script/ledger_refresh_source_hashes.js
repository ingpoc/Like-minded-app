#!/usr/bin/env node
/**
 * Persist source_hash on validation/screens/*.json platform slices.
 */
const { listScreenFiles, loadScreenFile, refreshPlatformHashes, writeScreen } = require("./ledger_screens");

let updated = 0;
for (const file of listScreenFiles()) {
  const { abs, data, logicalId } = loadScreenFile(file);
  const before = JSON.stringify(data.platforms);
  refreshPlatformHashes(data);
  if (JSON.stringify(data.platforms) !== before) {
    writeScreen(abs, data);
    updated += 1;
    console.log(`${logicalId}: refreshed platform source_hash`);
  }
}

console.log(`ledger:refresh-hashes updated=${updated}`);
