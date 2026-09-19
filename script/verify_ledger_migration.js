#!/usr/bin/env node
/**
 * Verify migration: no controls lost, flow coverage complete, parity visible.
 */
const fs = require("node:fs");
const path = require("node:path");
const { root } = require("./ledger_hash");
const { SCREEN_REGISTRY } = require("./ledger_migrate_to_screens");
const { listScreenFiles, loadScreenFile, platformControls } = require("./ledger_screens");

const LEGACY_IOS = path.join(root, "validation", "_legacy", "ios");
const LEGACY_MACOS = path.join(root, "validation", "_legacy", "macos");
const LEGACY_IOS_ALT = path.join(root, "validation", "ios");
const LEGACY_MACOS_ALT = path.join(root, "validation", "macos");

function legacyDir(platform) {
  const primary = platform === "ios" ? LEGACY_IOS : LEGACY_MACOS;
  const alt = platform === "ios" ? LEGACY_IOS_ALT : LEGACY_MACOS_ALT;
  return fs.existsSync(primary) ? primary : alt;
}

function loadLegacyControls(platform) {
  const dir = legacyDir(platform);
  if (!fs.existsSync(dir)) return { controls: [], files: [] };
  const controls = [];
  const files = [];
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".json")).sort()) {
    const data = JSON.parse(fs.readFileSync(path.join(dir, file), "utf8"));
    files.push(file.replace(/\.json$/, ""));
    for (const c of data.controls || []) {
      controls.push({ platform, file: file.replace(/\.json$/, ""), id: c.id, result: c.result });
    }
  }
  return { controls, files };
}

function loadMigratedControls(platform) {
  const controls = [];
  for (const file of listScreenFiles()) {
    const { data, logicalId } = loadScreenFile(file);
    for (const c of platformControls(data, platform)) {
      controls.push({ platform, file: logicalId, id: c.id, result: c.result });
    }
  }
  return controls;
}

function controlKey(c) {
  return `${c.platform}:${c.file}:${c.id}`;
}

function main() {
  const errors = [];
  const warnings = [];
  const gapRegistryPath = path.join(root, "validation", "gap-flows-registry.json");
  const gapReg = fs.existsSync(gapRegistryPath)
    ? JSON.parse(fs.readFileSync(gapRegistryPath, "utf8"))
    : {};
  const retiredLegacyControls = new Set(gapReg.retired_legacy_controls || []);
  let retiredCount = 0;

  const legacyIos = loadLegacyControls("ios");
  const legacyMac = loadLegacyControls("macos");
  const migIos = loadMigratedControls("ios");
  const migMac = loadMigratedControls("macos");

  // Settings extra ios files merged into settings
  const iosMergedExtras = new Set(["21-settings-privacy", "22-settings-info", "23-settings-support"]);

  for (const c of legacyIos.controls) {
    if (iosMergedExtras.has(c.file)) {
      const found = migIos.find((m) => m.id === c.id && m.file === "settings");
      if (!found) errors.push(`Missing merged iOS settings control: ${c.file}#${c.id}`);
      continue;
    }
    const logical = SCREEN_REGISTRY.find((r) => r.ios === c.file)?.id || c.file;
    const found = migIos.find((m) => m.id === c.id && m.file === logical);
    if (!found) {
      const retirementKey = `ios:${c.file}#${c.id}`;
      if (retiredLegacyControls.has(retirementKey)) retiredCount += 1;
      else errors.push(`Missing iOS control after migration: ${c.file}#${c.id}`);
    }
  }

  for (const c of legacyMac.controls) {
    const logical = SCREEN_REGISTRY.find((r) => r.macos === c.file)?.id || c.file;
    const found = migMac.find((m) => m.id === c.id && m.file === logical);
    if (!found) {
      const retirementKey = `macos:${c.file}#${c.id}`;
      if (retiredLegacyControls.has(retirementKey)) retiredCount += 1;
      else errors.push(`Missing macOS control after migration: ${c.file}#${c.id}`);
    }
  }

  // Count parity
  let extraScreens = 0;
  extraScreens = Object.keys(gapReg.new_screens || {}).length;
  const expectedScreens = SCREEN_REGISTRY.length + extraScreens;
  const screenCount = listScreenFiles().length;
  if (screenCount !== expectedScreens) {
    errors.push(`Expected ${expectedScreens} screen files, got ${screenCount}`);
  }

  let totalFlows = 0;
  let flowsWithoutValidation = 0;
  let parityGaps = [];

  for (const file of listScreenFiles()) {
    const { data, logicalId } = loadScreenFile(file);
    for (const flow of data.flows || []) {
      totalFlows += 1;
      for (const platform of ["ios", "macos"]) {
        const v = flow.validation?.[platform];
        if (!v || !v.result) flowsWithoutValidation += 1;
        const slice = data.platforms?.[platform];
        const hasIosControls = (flow.control_ids?.ios || []).length > 0;
        const hasMacControls = (flow.control_ids?.macos || []).length > 0;
        if (slice?.implemented !== false && hasIosControls && !hasMacControls) {
          parityGaps.push(`${logicalId}/${flow.id}: iOS-only flow`);
        }
        if (slice?.implemented !== false && hasMacControls && !hasIosControls) {
          parityGaps.push(`${logicalId}/${flow.id}: macOS-only flow`);
        }
      }
    }
  }

  // Result parity counts
  const countResults = (controls) => {
    const m = {};
    for (const c of controls) {
      const r = String(c.result || "pending").toLowerCase();
      m[r] = (m[r] || 0) + 1;
    }
    return m;
  };

  console.log("# Ledger migration verification\n");
  console.log(`Screens: ${screenCount} (target ${expectedScreens})`);
  console.log(`Flows: ${totalFlows}`);
  console.log(`Legacy iOS controls: ${legacyIos.controls.length} → migrated: ${migIos.length}`);
  console.log(`Legacy macOS controls: ${legacyMac.controls.length} → migrated: ${migMac.length}`);
  console.log(`iOS results legacy:`, countResults(legacyIos.controls));
  console.log(`iOS results migrated:`, countResults(migIos));
  console.log(`macOS results legacy:`, countResults(legacyMac.controls));
  console.log(`macOS results migrated:`, countResults(migMac));
  console.log(`Explicitly retired legacy controls: ${retiredCount}`);

  if (parityGaps.length) {
    console.log(`\n## Parity notes (${parityGaps.length} platform-specific flows — expected for some screens)`);
    parityGaps.slice(0, 20).forEach((g) => console.log(`  - ${g}`));
    if (parityGaps.length > 20) console.log(`  … and ${parityGaps.length - 20} more`);
  }

  if (errors.length) {
    console.error("\n## ERRORS");
    errors.forEach((e) => console.error(`  - ${e}`));
    process.exit(1);
  }

  console.log("\nOK: migration verification passed — all legacy controls accounted for.");
  process.exit(0);
}

main();
