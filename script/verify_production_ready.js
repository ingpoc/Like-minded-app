#!/usr/bin/env node
/**
 * Composite gate: UI ledger + API smoke + PROGRESS Phase 9 + release/external graders.
 */
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { root } = require("./ledger_hash");
const { ownershipReport } = require("./ledger_progress");
const { loadProductionContract, auditProductionUi } = require("./ledger_proof");

function phase9Unchecked() {
  const progress = fs.readFileSync(path.join(root, "PROGRESS.md"), "utf8");
  const start = progress.indexOf("## Phase 9");
  if (start < 0) return 0;
  const end = progress.indexOf("\n## ", start + 1);
  const section = end < 0 ? progress.slice(start) : progress.slice(start, end);
  return (section.match(/- \[ \]/g) || []).length;
}

function runGrader(command) {
  const [cmd, ...args] = command.split(/\s+/);
  try {
    execFileSync(cmd, args, { cwd: root, encoding: "utf8", stdio: "pipe" });
    return { ok: true };
  } catch (error) {
    return { ok: false, output: `${error.stdout || ""}${error.stderr || ""}`.trim() };
  }
}

const contract = loadProductionContract();
if (!contract) {
  console.error("missing validation/production-contract.json");
  process.exit(1);
}

const errors = [];
const warnings = [];

const ui = auditProductionUi(contract);
errors.push(...ui.errors);
warnings.push(...ui.warnings);

const ownership = ownershipReport();
if (!ownership.ok) {
  errors.push("verify:ledger-progress ownership failed");
  for (const e of ownership.errors) errors.push(`  ${e}`);
}

const phase9Open = phase9Unchecked();
if (phase9Open > 0) {
  errors.push(`PROGRESS.md Phase 9: ${phase9Open} unchecked item(s)`);
}

for (const grader of contract.production_ready_when?.graders || []) {
  if (grader.includes("ledger-progress")) continue;
  const result = runGrader(grader);
  if (!result.ok) {
    errors.push(`grader failed: ${grader}`);
    if (result.output) warnings.push(result.output.slice(0, 500));
  }
}

const smoke = runGrader("npm run smoke:mvp");
if (!smoke.ok) {
  errors.push("grader failed: npm run smoke:mvp");
}

console.log("# Production readiness (TestFlight MVP contract v1)\n");
console.log(`claim: ${contract.claim}`);
console.log(`in_scope_screens: ${contract.in_scope_screens.length}`);
console.log(`ui_errors: ${ui.errors.length}`);
console.log(`phase9_open: ${phase9Open}`);
console.log(`ledger_progress_ok: ${ownership.ok ? "yes" : "no"}`);
console.log(`smoke_mvp: ${smoke.ok ? "yes" : "no"}`);

if (warnings.length) {
  console.log("\n## Warnings");
  warnings.slice(0, 10).forEach((w) => console.log(`  - ${w}`));
}

if (errors.length) {
  console.error("\n## NOT production-ready");
  errors.slice(0, 30).forEach((e) => console.error(`  - ${e}`));
  if (errors.length > 30) console.error(`  … and ${errors.length - 30} more`);
  process.exit(1);
}

console.log("\nOK: production-ready per contract v1 (TestFlight MVP scope).");
process.exit(0);
