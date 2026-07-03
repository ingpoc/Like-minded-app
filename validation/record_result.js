#!/usr/bin/env node
// record_result.js — update a validation JSON ledger with one control's result.
// Usage: ./validation/record_result.js <screen.json> <control-id> <result> <evidence>
// result ∈ {pass, fail, blocked, untested}
const fs = require("fs");
const [,, screenPath, controlId, result, ...evidenceParts] = process.argv;
if (!screenPath || !controlId || !result) {
  console.error("Usage: record_result.js <screen.json> <control-id> <result> <evidence...>");
  process.exit(2);
}
const evidence = evidenceParts.join(" ");
const data = JSON.parse(fs.readFileSync(screenPath, "utf8"));
const ctrl = data.controls.find((c) => c.id === controlId);
if (!ctrl) {
  console.error(`Control '${controlId}' not found in ${screenPath}. Known: ${data.controls.map((c) => c.id).join(", ")}`);
  process.exit(3);
}
ctrl.result = result;
ctrl.evidence = evidence;
fs.writeFileSync(screenPath, JSON.stringify(data, null, 2) + "\n");
console.log(`✓ ${data.screen} :: ${controlId} = ${result}`);
