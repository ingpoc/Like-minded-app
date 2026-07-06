#!/usr/bin/env node
/**
 * Add a new flow to validation/screens with dedup checks.
 *   npm run testing:ledger-add-flow -- --screen app-shell --flow-id new-flow --name "..." \
 *     --step "Tap X" --control-macos tab-foo [--control-ios tab-foo] [--dry-run]
 */
const fs = require("node:fs");
const path = require("node:path");
const { listScreenFiles, loadScreenFile, writeScreen, findScreenByArg } = require("./ledger_screens");
const { buildDefaultProof } = require("./ledger_proof");
const { root, isoNow } = require("./ledger_hash");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

function collectArgs(flag) {
  const out = [];
  for (let i = 0; i < process.argv.length; i += 1) {
    if (process.argv[i] === flag && process.argv[i + 1]) out.push(process.argv[i + 1]);
  }
  return out;
}

const screen = arg("--screen");
const flowId = arg("--flow-id");
const name = arg("--name");
const dryRun = process.argv.includes("--dry-run");
const steps = collectArgs("--step");
const controlsMac = collectArgs("--control-macos");
const controlsIos = collectArgs("--control-ios");

if (!screen || !flowId || !name) {
  console.error(
    "Usage: testing_ledger_add_flow.js --screen <logical-id> --flow-id <kebab-id> --name \"...\" [--step \"...\"] [--control-macos id] [--control-ios id] [--dry-run]"
  );
  process.exit(2);
}

if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(flowId)) {
  console.error("flow-id must be kebab-case");
  process.exit(2);
}

// Criteria: must have at least one step OR one control on a platform
if (!steps.length && !controlsMac.length && !controlsIos.length) {
  console.error("refused: add at least one --step or --control-macos/--control-ios");
  process.exit(2);
}

for (const file of listScreenFiles()) {
  const { data, logicalId } = loadScreenFile(file);
  for (const flow of data.flows || []) {
    if (flow.id === flowId && logicalId !== screen.replace(/\.json$/, "")) {
      console.error(`refused: flow id "${flowId}" already on screen "${logicalId}"`);
      process.exit(1);
    }
    if (flow.id === flowId && logicalId === screen.replace(/\.json$/, "")) {
      console.error(`refused: flow "${flowId}" already exists on ${logicalId}`);
      process.exit(1);
    }
  }
}

let loaded;
try {
  loaded = findScreenByArg(screen);
} catch (error) {
  console.error(`screen not found: ${screen}`);
  process.exit(1);
}

const { abs, data, logicalId } = loaded;

const flow = {
  id: flowId,
  name,
  origin: logicalId,
  steps,
  destinations: [],
  spans: [],
  backend: [],
  control_ids: {
    ios: controlsIos,
    macos: controlsMac
  },
  gap_audit: isoNow(),
  validation: {
    ios: {
      result: controlsIos.length ? "pending" : "not-applicable",
      evidence: controlsIos.length ? "Discovered during testing-ledger session" : "",
      blocker: "",
      screenshot_ref: "",
      last_tested_at: "",
      tested_source_hash: "",
      last_test_method: ""
    },
    macos: {
      result: controlsMac.length ? "pending" : "not-applicable",
      evidence: controlsMac.length ? "Discovered during testing-ledger session" : "",
      blocker: "",
      screenshot_ref: "",
      last_tested_at: "",
      tested_source_hash: "",
      last_test_method: ""
    }
  }
};

flow.proof = buildDefaultProof(flow, data, logicalId, controlsMac.length ? "macos" : "ios");

for (const plat of ["ios", "macos"]) {
  const ids = flow.control_ids[plat];
  if (!ids.length) continue;
  data.controls = data.controls || { ios: [], macos: [] };
  data.controls[plat] = data.controls[plat] || [];
  for (const id of ids) {
    if (data.controls[plat].some((c) => c.id === id)) continue;
    data.controls[plat].push({
      id,
      type: "button",
      label: id,
      expected: steps[0] || name,
      result: "pending",
      evidence: `Added ${isoNow()} via testing-ledger-add-flow`,
      blocker: "",
      stub: false,
      last_tested_at: "",
      tested_source_hash: "",
      last_test_method: ""
    });
  }
}

data.flows = data.flows || [];
data.flows.push(flow);

if (dryRun) {
  console.log(JSON.stringify({ dry_run: true, screen: logicalId, flow }, null, 2));
  process.exit(0);
}

writeScreen(abs, data);
console.log(`added flow ${logicalId}/${flowId} controls ios=${controlsIos.length} macos=${controlsMac.length}`);
console.log(`next: npm run testing:ledger-next`);
