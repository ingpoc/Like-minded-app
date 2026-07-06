#!/usr/bin/env node
/**
 * Apply validation/gap-flows-registry.json to validation/screens/*.json
 * Usage: node script/ledger_apply_gap_flows.js [--dry-run]
 */
const fs = require("node:fs");
const path = require("node:path");
const { SCHEMA_VERSION, writeScreen } = require("./ledger_screens");

const root = path.resolve(__dirname, "..");
const screensDir = path.join(root, "validation", "screens");
const registryPath = path.join(root, "validation", "gap-flows-registry.json");
const dryRun = process.argv.includes("--dry-run");

function pending(result, blocker = "", evidence = "") {
  return {
    result: result || "pending",
    evidence:
      evidence ||
      `Gap audit ${registry.audit_date}: control exists in source; not yet runtime-validated`,
    blocker,
    last_tested_at: "",
    tested_source_hash: "",
    last_test_method: ""
  };
}

function controlStub(c, platform) {
  return {
    id: c.id,
    type: c.type || "button",
    label: c.label,
    expected: c.expected,
    result: "pending",
    evidence: `Gap audit ${registry.audit_date}`,
    blocker: "",
    stub: false,
    last_tested_at: "",
    tested_source_hash: "",
    last_test_method: ""
  };
}

function mergeControls(screen, platform, controls) {
  if (!controls?.length) return 0;
  screen.controls = screen.controls || { ios: [], macos: [] };
  screen.controls[platform] = screen.controls[platform] || [];
  let added = 0;
  for (const c of controls) {
    if (screen.controls[platform].some((x) => x.id === c.id)) continue;
    screen.controls[platform].push(controlStub(c, platform));
    added += 1;
  }
  return added;
}

function buildFlow(gap, flowDef) {
  const f = flowDef;
  const validation = {};
  if (f.ios !== undefined || (f.control_ids?.ios || []).length) {
    validation.ios = pending(
      f.ios || ((f.control_ids?.ios || []).length ? "pending" : "not-applicable"),
      f.ios_blocker || ""
    );
  } else {
    validation.ios = pending("not-applicable", "", "No iOS controls for this flow");
  }
  if (f.macos !== undefined || (f.control_ids?.macos || []).length) {
    validation.macos = pending(
      f.macos || ((f.control_ids?.macos || []).length ? "pending" : "not-applicable"),
      f.macos_blocker || ""
    );
  } else {
    validation.macos = pending("not-applicable", "", "No macOS controls for this flow");
  }

  return {
    id: f.id,
    name: f.name,
    origin: gap.screen,
    steps: f.steps || [],
    destinations: f.destinations || [],
    spans: f.spans || [],
    backend: f.backend || [],
    control_ids: {
      ios: f.control_ids?.ios || [],
      macos: f.control_ids?.macos || []
    },
    gap_audit: registry.audit_date,
    validation
  };
}

function loadScreen(id) {
  const abs = path.join(screensDir, `${id}.json`);
  if (!fs.existsSync(abs)) return null;
  return { abs, data: JSON.parse(fs.readFileSync(abs, "utf8")) };
}

function createAppShell(def) {
  const template = JSON.parse(
    fs.readFileSync(path.join(screensDir, "_template.screen.json"), "utf8")
  );
  template.logical_screen_id = "app-shell";
  template.screen = def.screen;
  template.schema_version = SCHEMA_VERSION;
  for (const plat of ["ios", "macos"]) {
    const src = def.platforms[plat];
    template.platforms[plat] = {
      ledger_legacy_id: null,
      implemented: src.implemented !== false,
      source_files: src.source_files || [],
      source_hash: null,
      mockup_ref: null,
      mockup_missing: true,
      entry_points: src.entry_points || [],
      backend_dependencies: [],
      ui_validation: null,
      visual_parity: null,
      recent_screenshot_ref: null,
      notes: `Gap audit ${registry.audit_date}: global chrome screen`
    };
  }
  template.flows = [];
  template.controls = { ios: [], macos: [] };
  return template;
}

const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
let flowsAdded = 0;
let flowsPatched = 0;
let controlsAdded = 0;
let screensCreated = 0;

for (const [id, def] of Object.entries(registry.new_screens || {})) {
  const abs = path.join(screensDir, `${id}.json`);
  if (!fs.existsSync(abs)) {
    const data = createAppShell(def);
    if (!dryRun) writeScreen(abs, data);
    screensCreated += 1;
    console.log(`created screen: ${id}`);
  }
}

for (const gap of registry.gaps || []) {
  const loaded = loadScreen(gap.screen);
  if (!loaded) {
    console.error(`missing screen: ${gap.screen}`);
    process.exit(1);
  }
  const { abs, data } = loaded;

  if (gap.patch_control) {
    const plat = "ios";
    const pc = gap.patch_control;
    const ctrl = (data.controls?.[plat] || []).find((c) => c.id === pc.ios || c.id === gap.patch_control.ios);
    const target = (data.controls?.ios || []).find((c) => c.id === pc.ios);
    if (target && pc.label) {
      target.label = pc.label;
      if (pc.expected) target.expected = pc.expected;
      target.notes = pc.expected;
    }
  }

  if (gap.patch_flow && gap.flow) {
    const idx = (data.flows || []).findIndex((f) => f.id === gap.patch_flow);
    const built = buildFlow(gap, gap.flow);
    if (idx >= 0) {
      data.flows[idx] = { ...data.flows[idx], ...built, id: gap.patch_flow };
      flowsPatched += 1;
    } else {
      data.flows = data.flows || [];
      data.flows.push(built);
      flowsAdded += 1;
    }
  } else if (gap.flow) {
    const exists = (data.flows || []).some((f) => f.id === gap.flow.id);
    if (exists) {
      console.log(`skip existing flow: ${gap.screen}/${gap.flow.id}`);
    } else {
      data.flows = data.flows || [];
      data.flows.push(buildFlow(gap, gap.flow));
      flowsAdded += 1;
    }
  }

  if (gap.controls) {
    controlsAdded += mergeControls(data, "ios", gap.controls.ios);
    controlsAdded += mergeControls(data, "macos", gap.controls.macos);
  }

  if (!dryRun) writeScreen(abs, data);
}

console.log(
  `${dryRun ? "[dry-run] " : ""}gaps applied: screens_created=${screensCreated} flows_added=${flowsAdded} flows_patched=${flowsPatched} controls_added=${controlsAdded}`
);
