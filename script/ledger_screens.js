#!/usr/bin/env node
/**
 * Canonical validation ledger — validation/screens/*.json (schema v2).
 * Single owner for logical screens, flows, and per-platform controls.
 */
const fs = require("node:fs");
const path = require("node:path");
const {
  root,
  hashScreenSources,
  isControlStale,
  parseSourcePath
} = require("./ledger_hash");

const SCREENS_DIR = path.join(root, "validation", "screens");
const LEGACY_IOS = path.join(root, "validation", "_legacy", "ios");
const LEGACY_MACOS = path.join(root, "validation", "_legacy", "macos");
const SCHEMA_VERSION = 2;

function normalizeScreenToken(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

function isLedgerScreenFile(filename) {
  return filename.endsWith(".json") && !filename.startsWith("_");
}

function listScreenFiles(repoRoot = root) {
  const screensDir = path.join(repoRoot, "validation", "screens");
  if (!fs.existsSync(screensDir)) return [];
  return fs.readdirSync(screensDir).filter(isLedgerScreenFile).sort();
}

function loadScreenFile(fileOrId, repoRoot = root) {
  const dir = path.join(repoRoot, "validation", "screens");
  let file = fileOrId;
  if (!file.endsWith(".json")) file = `${fileOrId}.json`;
  const abs = path.join(dir, file);
  if (!fs.existsSync(abs)) throw new Error(`screen ledger not found: ${abs}`);
  const data = JSON.parse(fs.readFileSync(abs, "utf8"));
  return { abs, file, data, logicalId: data.logical_screen_id || file.replace(/\.json$/, "") };
}

function platformSlice(screenData, platform) {
  const slice = screenData.platforms?.[platform];
  if (!slice) return null;
  return slice;
}

function platformControls(screenData, platform) {
  if (screenData.controls?.[platform]) return screenData.controls[platform];
  const slice = platformSlice(screenData, platform);
  return slice?.controls || [];
}

function hashPlatformSlice(screenData, platform, repoRoot = root) {
  const slice = platformSlice(screenData, platform);
  if (!slice?.source_files?.length) return slice?.source_hash || null;
  return hashScreenSources({ source_files: slice.source_files }, repoRoot) || slice.source_hash || null;
}

function refreshPlatformHashes(screenData, repoRoot = root) {
  for (const platform of ["ios", "macos"]) {
    const slice = platformSlice(screenData, platform);
    if (!slice) continue;
    const hash = hashPlatformSlice(screenData, platform, repoRoot);
    if (hash) slice.source_hash = hash;
  }
  return screenData;
}

function flattenForPlatform(screenData, platform) {
  const slice = platformSlice(screenData, platform) || {};
  const controls = platformControls(screenData, platform);
  return {
    schema_version: screenData.schema_version || SCHEMA_VERSION,
    logical_screen_id: screenData.logical_screen_id,
    screen: screenData.screen,
    platform,
    source_files: slice.source_files || [],
    source_hash: slice.source_hash || hashPlatformSlice(screenData, platform),
    mockup_ref: slice.mockup_ref || null,
    mockup_missing: slice.mockup_missing ?? false,
    entry_points: slice.entry_points || [],
    backend_dependencies: slice.backend_dependencies || [],
    controls,
    flows: screenData.flows || [],
    ui_validation: slice.ui_validation || slice.visual_parity || null,
    visual_parity: slice.visual_parity || slice.ui_validation || null,
    recent_screenshot_ref: slice.recent_screenshot_ref || null,
    notes: slice.notes || "",
    implemented: slice.implemented !== false
  };
}

function findScreenByArg(screenArg, platform = null, repoRoot = root) {
  const dir = path.join(repoRoot, "validation", "screens");
  if (!fs.existsSync(dir)) {
    return findLegacyLedger(screenArg, platform, repoRoot);
  }
  const needle = normalizeScreenToken(screenArg);
  const entries = listScreenFiles(repoRoot).map((file) => {
    const loaded = loadScreenFile(file, repoRoot);
    return loaded;
  });

  const exact = entries.find((e) => normalizeScreenToken(e.logicalId) === needle);
  if (exact) return exact;

  const byFile = entries.find((e) => normalizeScreenToken(e.file.replace(/\.json$/, "")) === needle);
  if (byFile) return byFile;

  for (const entry of entries) {
    const { data } = entry;
    if (normalizeScreenToken(data.screen) === needle) return entry;
    for (const plat of ["ios", "macos"]) {
      const legacy = data.platforms?.[plat]?.ledger_legacy_id;
      if (legacy && normalizeScreenToken(legacy) === needle) return entry;
    }
    if (platform) {
      const slice = data.platforms?.[platform];
      for (const src of slice?.source_files || []) {
        const hint = String(src).match(/\(([a-zA-Z]+)\)\s*$/)?.[1];
        if (hint && normalizeScreenToken(hint) === needle) return entry;
      }
    }
  }

  if (platform) {
    return findLegacyLedger(screenArg, platform, repoRoot);
  }
  throw new Error(`no screen ledger for ${screenArg}`);
}

function findLegacyLedger(screenArg, platform, repoRoot = root) {
  const { findLedgerByScreenArg } = require("./ledger_hash");
  const legacy = findLedgerByScreenArg(platform, screenArg, repoRoot);
  return {
    abs: legacy.abs,
    file: legacy.file,
    data: legacy.data,
    logicalId: legacy.file.replace(/\.json$/, ""),
    legacy: true
  };
}

function flowValidation(flow, platform) {
  return flow.validation?.[platform] || { result: "pending" };
}

function isFlowStale(flow, platform, currentHash) {
  const v = flowValidation(flow, platform);
  if (String(v.result || "").toLowerCase() !== "pass") return false;
  if (!currentHash) return false;
  const tested = v.tested_source_hash || "";
  if (!tested) return true;
  return tested !== currentHash;
}

function isFlowOpen(flow, platform) {
  const v = flowValidation(flow, platform);
  const result = String(v.result || "pending").toLowerCase();
  if (["pass", "not-applicable"].includes(result)) return false;
  if (["fail", "pending", "untested", ""].includes(result)) return true;
  if (result === "blocked") {
    const text = `${v.blocker || ""} ${v.evidence || ""}`;
    return /GUI automation unavailable|automation unavailable/i.test(text);
  }
  return false;
}

function summarizeFlows(platform, repoRoot = root) {
  const dir = path.join(repoRoot, "validation", "screens");
  const summary = {
    platform,
    screens: 0,
    flows: 0,
    pass: 0,
    fail: 0,
    pending: 0,
    blocked: 0,
    stale_pass: 0,
    not_implemented: 0,
    actionable: 0,
    open_items: []
  };
  if (!fs.existsSync(dir)) return summary;

  for (const file of listScreenFiles(repoRoot)) {
    const { data, logicalId } = loadScreenFile(file, repoRoot);
    const slice = platformSlice(data, platform);
    if (!slice) continue;
    summary.screens += 1;
    const currentHash = hashPlatformSlice(data, platform, repoRoot);

    if (slice.implemented === false) {
      summary.not_implemented += 1;
    }

    for (const flow of data.flows || []) {
      summary.flows += 1;
      const v = flowValidation(flow, platform);
      const result = String(v.result || "pending").toLowerCase();
      if (result === "pass") {
        summary.pass += 1;
        if (isFlowStale(flow, platform, currentHash)) {
          summary.stale_pass += 1;
          summary.actionable += 1;
          summary.open_items.push({
            screen: logicalId,
            flow_id: flow.id,
            result: "stale-pass",
            name: flow.name
          });
        }
      } else if (result === "not-applicable") {
        // parity gap tracking only — not actionable
      } else if (result === "fail") {
        summary.fail += 1;
        summary.actionable += 1;
        summary.open_items.push({ screen: logicalId, flow_id: flow.id, result: "fail", name: flow.name });
      } else if (result === "blocked") {
        summary.blocked += 1;
      } else {
        summary.pending += 1;
        summary.actionable += 1;
        summary.open_items.push({ screen: logicalId, flow_id: flow.id, result: result || "pending", name: flow.name });
      }
    }
  }
  return summary;
}

function writeScreen(abs, data) {
  fs.writeFileSync(abs, `${JSON.stringify(data, null, 2)}\n`);
}

module.exports = {
  SCHEMA_VERSION,
  SCREENS_DIR,
  LEGACY_IOS,
  LEGACY_MACOS,
  listScreenFiles,
  loadScreenFile,
  platformSlice,
  platformControls,
  hashPlatformSlice,
  refreshPlatformHashes,
  flattenForPlatform,
  findScreenByArg,
  flowValidation,
  isFlowStale,
  isFlowOpen,
  summarizeFlows,
  writeScreen
};
