#!/usr/bin/env node
/**
 * Ledger-driven stale screen lists for targeted reproof batches.
 * Schema v2: stale flows in validation/screens/*.json
 */
const fs = require("node:fs");
const path = require("node:path");
const { hashScreenSources, isControlStale } = require("./ledger_hash");
const {
  listScreenFiles,
  loadScreenFile,
  hashPlatformSlice,
  isFlowStale
} = require("./ledger_screens");
const { SCREEN_REGISTRY } = require("./ledger_migrate_to_screens");

const root = path.resolve(__dirname, "..");

const MAC_SCREENS = new Set([
  "welcome",
  "meetOverview",
  "circlesRoom",
  "circleDetail",
  "profileEdit",
  "chat",
  "communitiesBrowse",
  "communityDetail",
  "meetRecap",
  "meetVideoCall",
  "myProfile",
  "soulmateOverview",
  "soulmateDiscover",
  "soulmateDetail",
  "communityMembers",
  "createEvent",
  "createCommunity",
  "messages",
  "notifications",
  "profileOnboarding",
  "profileSignals",
  "settingsSoulmate"
]);

function ledgerStem(file) {
  return file.replace(/\.json$/, "");
}

function stemToCamelScreen(stem) {
  const slug = stem.replace(/^\d+-/, "");
  if (!slug.includes("-")) return slug;
  return slug.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
}

function macScreenFromLedger(file, data) {
  for (const entry of data.source_files || []) {
    const text = String(entry);
    const macHint = text.match(/MacScreens\.swift \(([a-zA-Z]+)\)/);
    if (macHint && MAC_SCREENS.has(macHint[1])) return macHint[1];
    const hint = text.match(/\(([a-zA-Z]+)\)\s*$/);
    if (hint && MAC_SCREENS.has(hint[1])) return hint[1];
  }
  const fromStem = stemToCamelScreen(ledgerStem(file));
  return MAC_SCREENS.has(fromStem) ? fromStem : null;
}

function logicalToLegacyId(platform, logicalId) {
  const row = SCREEN_REGISTRY.find((r) => r.id === logicalId);
  return row?.[platform] || logicalId;
}

function staleFlowEntries(platform, repoRoot = root) {
  const screensDir = path.join(repoRoot, "validation", "screens");
  if (fs.existsSync(screensDir)) {
    const entries = [];
    for (const file of listScreenFiles(repoRoot)) {
      const { data, logicalId } = loadScreenFile(file, repoRoot);
      const currentHash = hashPlatformSlice(data, platform, repoRoot);
      const staleFlows = (data.flows || []).filter(
        (flow) =>
          String(flow.validation?.[platform]?.result || "").toLowerCase() === "pass" &&
          isFlowStale(flow, platform, currentHash)
      );
      if (staleFlows.length === 0) continue;
      const legacyId = logicalToLegacyId(platform, logicalId);
      if (platform === "ios") {
        entries.push({ ledgerId: legacyId, logicalId, staleControls: staleFlows.length });
        continue;
      }
      const slice = data.platforms?.macos;
      const macScreen =
        macScreenFromLedger(`${legacyId}.json`, {
          source_files: slice?.source_files || []
        }) || stemToCamelScreen(logicalId);
      entries.push({ ledgerId: legacyId, logicalId, macScreen, staleControls: staleFlows.length });
    }
    return entries;
  }
  return staleLedgerEntriesLegacy(platform, repoRoot);
}

function staleLedgerEntriesLegacy(platform, repoRoot = root) {
  const dir = path.join(repoRoot, "validation", platform);
  const legacyDir = path.join(repoRoot, "validation", "_legacy", platform);
  const base = fs.existsSync(dir) ? dir : legacyDir;
  if (!fs.existsSync(base)) return [];

  const entries = [];
  for (const file of fs.readdirSync(base).filter((f) => f.endsWith(".json")).sort()) {
    const data = JSON.parse(fs.readFileSync(path.join(base, file), "utf8"));
    const currentHash = hashScreenSources(data, repoRoot) || data.source_hash || null;
    const staleControls = (data.controls || []).filter(
      (control) =>
        String(control.result || "").toLowerCase() === "pass" &&
        isControlStale(control, currentHash)
    );
    if (staleControls.length === 0) continue;

    if (platform === "ios") {
      entries.push({ ledgerId: ledgerStem(file), staleControls: staleControls.length });
      continue;
    }

    const macScreen = macScreenFromLedger(file, data);
    if (!macScreen) continue;
    entries.push({ ledgerId: ledgerStem(file), macScreen, staleControls: staleControls.length });
  }
  return entries;
}

function staleLedgerEntries(platform, repoRoot = root) {
  return staleFlowEntries(platform, repoRoot);
}

function staleLedgerScreens(platform, repoRoot = root) {
  const entries = staleLedgerEntries(platform, repoRoot);
  if (platform === "ios") return entries.map((e) => e.ledgerId || e.logicalId);
  if (platform === "macos") return entries.map((e) => e.macScreen);
  return [];
}

function stalePassCount(platform, repoRoot = root) {
  return staleLedgerEntries(platform, repoRoot).reduce((sum, e) => sum + e.staleControls, 0);
}

function reproofCommand(platform, options = {}) {
  const count = stalePassCount(platform);
  if (count === 0) return null;
  if (platform === "ios") return "npm run verify:ios-screens -- --stale-only";
  const cuaOnly = options.cuaOnly !== false;
  return cuaOnly
    ? "npm run testing:ledger-batch-plan -- --platform macos --limit 10"
    : "npm run testing:ledger-batch-plan -- --platform macos --limit 10";
}

function wave2ReproofCommand() {
  const ios = stalePassCount("ios");
  const mac = stalePassCount("macos");
  if (ios === 0 && mac === 0) return "npm run ledger:stale";
  if (ios > 0 && mac > 0) return "run one testing:ledger-batch-plan per platform; serialize shared build and seed resources";
  if (mac > 0) return reproofCommand("macos");
  return reproofCommand("ios");
}

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

if (require.main === module) {
  const platform = arg("--platform");
  if (!platform || !["ios", "macos"].includes(platform)) {
    console.error("Usage: ledger_stale_screens.js --platform ios|macos [--count] [--json]");
    process.exit(2);
  }

  if (process.argv.includes("--count")) {
    console.log(String(stalePassCount(platform)));
    process.exit(0);
  }

  const entries = staleLedgerEntries(platform);
  if (process.argv.includes("--json")) {
    console.log(JSON.stringify({ platform, entries }, null, 2));
    process.exit(0);
  }

  const lines = staleLedgerScreens(platform);
  if (lines.length === 0) process.exit(0);
  for (const line of lines) console.log(line);
}

module.exports = {
  MAC_SCREENS,
  macScreenFromLedger,
  staleLedgerEntries,
  staleLedgerScreens,
  stalePassCount,
  reproofCommand,
  wave2ReproofCommand
};
