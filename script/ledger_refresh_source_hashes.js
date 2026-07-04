#!/usr/bin/env node
/**
 * Persist source_hash on each validation screen ledger from source_files.
 */
const fs = require("node:fs");
const path = require("node:path");
const { hashScreenSources, writeLedger, root } = require("./ledger_hash");

const onlyPlatform = process.argv.find((a) => a.startsWith("--platform="))?.split("=")[1];
const platforms = onlyPlatform ? [onlyPlatform] : ["ios", "macos"];
let updated = 0;

for (const platform of platforms) {
  const dir = path.join(root, "validation", platform);
  if (!fs.existsSync(dir)) continue;
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".json")).sort()) {
    const abs = path.join(dir, file);
    const data = JSON.parse(fs.readFileSync(abs, "utf8"));
    const next = hashScreenSources(data, root);
    if (!next) {
      console.warn(`skip ${platform}/${file}: no resolvable source_files`);
      continue;
    }
    if (data.source_hash !== next) {
      data.source_hash = next;
      writeLedger(abs, data);
      updated += 1;
      console.log(`${platform}/${file} source_hash=${next}`);
    }
  }
}

console.log(`ledger:refresh-hashes updated=${updated}`);
