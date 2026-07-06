#!/usr/bin/env node
/**
 * Source hashing + stale-pass detection for validation ledgers.
 */
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function parseSourcePath(entry) {
  const raw = String(entry || "").trim();
  const match = raw.match(/^(.+?)(?:\s+\([^)]+\))?\s*$/);
  return match ? match[1].trim() : raw;
}

function parseSourceHint(entry) {
  const match = String(entry || "").match(/\(([^)]+)\)\s*$/);
  return match ? match[1].trim() : "";
}

function resolveSourceFiles(sourceFiles, repoRoot = root) {
  const files = [];
  for (const entry of sourceFiles || []) {
    const rel = parseSourcePath(entry);
    if (!rel) continue;
    const abs = path.join(repoRoot, rel);
    if (fs.existsSync(abs) && fs.statSync(abs).isFile()) {
      files.push(abs);
    }
  }
  return [...new Set(files)].sort();
}

function sourceContent(entry, repoRoot = root) {
  const rel = parseSourcePath(entry);
  const abs = path.join(repoRoot, rel);
  const text = fs.readFileSync(abs, "utf8");
  const hint = parseSourceHint(entry);
  if (!hint) return text;
  const escaped = hint.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  let start = text.search(new RegExp(`\\n\\s*private\\s+(?:var|func)\\s+${escaped}\\b`));
  if (start >= 0) start += 1;
  if (start < 0) start = text.search(new RegExp(`\\b${escaped}\\b`));
  if (start < 0) return text;
  const rest = text.slice(start + hint.length);
  const next = rest.search(/\n\s*(?:\/\/ MARK:|private\s+(?:var|func)\s+\w+)/);
  return text.slice(start, next < 0 ? undefined : start + hint.length + next);
}

function hashScreenSources(screenData, repoRoot = root) {
  if (!screenData.source_files?.length) return null;
  const hash = crypto.createHash("sha256");
  for (const entry of screenData.source_files) {
    const rel = parseSourcePath(entry);
    if (!rel) continue;
    const file = path.join(repoRoot, rel);
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) continue;
    hash.update(path.relative(repoRoot, file));
    hash.update(parseSourceHint(entry));
    hash.update("\0");
    hash.update(sourceContent(entry, repoRoot));
    hash.update("\0");
  }
  return hash.digest("hex").slice(0, 16);
}

function isControlStale(control, currentHash) {
  if (!currentHash) return false;
  const result = String(control.result || "").toLowerCase();
  if (result !== "pass") return false;
  const tested = control.tested_source_hash || "";
  if (!tested) return true;
  return tested !== currentHash;
}

function isoNow() {
  return new Date().toISOString().slice(0, 10);
}

function loadScreenLedger(platform, fileOrId, repoRoot = root) {
  const screensDir = path.join(repoRoot, "validation", "screens");
  if (fs.existsSync(screensDir)) {
    const { findScreenByArg, flattenForPlatform } = require("./ledger_screens");
    const token = String(fileOrId).replace(/\.json$/, "");
    const found = findScreenByArg(token, platform, repoRoot);
    if (!found.legacy) {
      return {
        abs: found.abs,
        data: flattenForPlatform(found.data, platform),
        file: found.file,
        unified: found.data,
        logicalId: found.logicalId
      };
    }
  }
  const legacyDir = path.join(repoRoot, "validation", "_legacy", platform);
  if (!fs.existsSync(legacyDir)) {
    throw new Error(`ledger not found: ${fileOrId} on ${platform}`);
  }
  const base = legacyDir;
  let file = fileOrId;
  if (!file.endsWith(".json")) file = `${fileOrId}.json`;
  const abs = path.join(base, file);
  if (!fs.existsSync(abs)) throw new Error(`ledger not found: ${abs}`);
  return { abs, data: JSON.parse(fs.readFileSync(abs, "utf8")), file };
}

function normalizeScreenToken(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

function findLedgerByScreenArg(platform, screenArg, repoRoot = root) {
  const screensDir = path.join(repoRoot, "validation", "screens");
  if (fs.existsSync(screensDir)) {
    try {
      const { findScreenByArg, flattenForPlatform } = require("./ledger_screens");
      const found = findScreenByArg(screenArg, platform, repoRoot);
      if (!found.legacy) {
        return {
          abs: found.abs,
          data: flattenForPlatform(found.data, platform),
          file: found.file,
          unified: found.data,
          logicalId: found.logicalId
        };
      }
    } catch {
      // fall through to legacy
    }
  }

  const legacyDir = path.join(repoRoot, "validation", "_legacy", platform);
  if (!fs.existsSync(legacyDir)) {
    throw new Error(`no ledger for screen ${screenArg} on ${platform}`);
  }
  const base = legacyDir;
  const needle = normalizeScreenToken(screenArg);
  const entries = fs.readdirSync(base).filter((f) => f.endsWith(".json")).map((file) => {
    const abs = path.join(base, file);
    const data = JSON.parse(fs.readFileSync(abs, "utf8"));
    const fileStem = normalizeScreenToken(file.replace(/\.json$/, ""));
    return { abs, data, file, fileStem };
  });

  // Exact ledger filename stem (e.g. 22-settings-info) — avoids 22-* matching 20-settings.
  const exact = entries.find((e) => e.fileStem === needle);
  if (exact) return exact;

  const exactScreen = entries.find((e) => normalizeScreenToken(e.data.screen) === needle);
  if (exactScreen) return exactScreen;

  for (const entry of entries) {
    const { abs, data, file, fileStem } = entry;
    if (fileStem.includes(needle) || needle.includes(fileStem.replace(/^\d+/, ""))) {
      return { abs, data, file };
    }
    if ((data.source_files || []).some((s) => {
      const token = normalizeScreenToken(s);
      return token.includes(needle) || needle.includes(token);
    })) {
      return { abs, data, file };
    }
    if (normalizeScreenToken(data.screen).includes(needle)) {
      return { abs, data, file };
    }
  }
  throw new Error(`no ledger for screen ${screenArg} on ${platform}`);
}

function writeLedger(abs, data) {
  fs.writeFileSync(abs, `${JSON.stringify(data, null, 2)}\n`);
}

function getPlatformControls(ledger, platform) {
  if (ledger.unified) {
    ledger.unified.controls = ledger.unified.controls || { ios: [], macos: [] };
    if (!ledger.unified.controls[platform]) ledger.unified.controls[platform] = [];
    return ledger.unified.controls[platform];
  }
  ledger.data.controls = ledger.data.controls || [];
  return ledger.data.controls;
}

function getPlatformHash(ledger, platform, repoRoot = root) {
  if (ledger.unified) {
    const { hashPlatformSlice, refreshPlatformHashes } = require("./ledger_screens");
    refreshPlatformHashes(ledger.unified, repoRoot);
    return hashPlatformSlice(ledger.unified, platform, repoRoot);
  }
  return refreshScreenSourceHash(ledger.data, repoRoot);
}

function persistLedger(ledger) {
  writeLedger(ledger.abs, ledger.unified || ledger.data);
}

function refreshScreenSourceHash(data, repoRoot = root) {
  const current = hashScreenSources(data, repoRoot);
  if (current) data.source_hash = current;
  return current;
}

function recordControlLedger(ledger, platform, controlId, { result, evidence, method, blocker, repoRoot = root }) {
  const controls = getPlatformControls(ledger, platform);
  const currentHash = getPlatformHash(ledger, platform, repoRoot);
  const control = controls.find((c) => c.id === controlId);
  if (!control) throw new Error(`control not found: ${controlId}`);
  if (result) control.result = result;
  if (evidence !== undefined) control.evidence = evidence;
  if (blocker !== undefined) control.blocker = blocker;
  control.last_tested_at = isoNow();
  if (currentHash) control.tested_source_hash = currentHash;
  if (method) control.last_test_method = method;
  control.stub = false;
  return control;
}

function stampControlsLedger(ledger, platform, controlIds, { result = "pass", evidencePrefix, method, repoRoot = root }) {
  const controls = getPlatformControls(ledger, platform);
  const currentHash = getPlatformHash(ledger, platform, repoRoot);
  const ids = controlIds.length ? controlIds : controls.map((c) => c.id);
  const stamped = [];
  for (const id of ids) {
    const control = controls.find((c) => c.id === id);
    if (!control) continue;
    if (result) control.result = result;
    control.last_tested_at = isoNow();
    if (currentHash) control.tested_source_hash = currentHash;
    if (method) control.last_test_method = method;
    if (evidencePrefix) {
      control.evidence = `${evidencePrefix} ${isoNow()}: ${id}`;
    }
    control.blocker = "";
    control.stub = false;
    stamped.push(id);
  }
  return stamped;
}

function flowSuccessCriteria(flow, platform) {
  const steps = (flow.steps || []).filter(Boolean);
  if (steps.length) return steps.join(" → ");
  const controls = flow.control_ids?.[platform] || [];
  if (controls.length) return `Controls exercised: ${controls.join(", ")}`;
  return flow.name || flow.id;
}

function recordFlowLedger(
  ledger,
  platform,
  flowId,
  {
    result,
    evidence,
    method,
    blocker,
    screenshotRef,
    syncControls = true,
    forceTier = false,
    repoRoot = root
  }
) {
  const unified = ledger.unified || ledger.data;
  const flow = (unified.flows || []).find((f) => f.id === flowId);
  if (!flow) throw new Error(`flow not found: ${flowId}`);
  const { validatePassTier } = require("./ledger_proof");
  const tierCheck = validatePassTier(flow, platform, method, result);
  if (!tierCheck.ok && !forceTier) {
    throw new Error(`${tierCheck.message} (use --force-tier to override)`);
  }
  const currentHash = getPlatformHash(ledger, platform, repoRoot);
  flow.validation = flow.validation || {};
  flow.validation[platform] = {
    result,
    evidence: evidence || "",
    blocker: blocker || "",
    screenshot_ref: screenshotRef || flow.validation[platform]?.screenshot_ref || "",
    last_tested_at: isoNow(),
    tested_source_hash: currentHash || "",
    last_test_method: method || ""
  };
  if (syncControls && result === "pass") {
    for (const id of flow.control_ids?.[platform] || []) {
      try {
        recordControlLedger(ledger, platform, id, {
          result: "pass",
          evidence: evidence || `flow ${flowId}`,
          method
        });
      } catch {
        // gap-audit controls may be added later
      }
    }
  }
  persistLedger(ledger);
  return flow;
}

function stampStaleLedger(ledger, platform, { method, evidencePrefix, repoRoot = root }) {
  const unified = ledger.unified || ledger.data;
  const controls = getPlatformControls(ledger, platform);
  const currentHash = getPlatformHash(ledger, platform, repoRoot);
  const stampedControls = [];
  const stampedFlows = [];
  const prefix = evidencePrefix || `${method || "reproof"} ${isoNow()}`;

  for (const control of controls) {
    if (!isControlStale(control, currentHash)) continue;
    control.result = "pass";
    control.last_tested_at = isoNow();
    control.last_test_method = method || "reproof";
    if (currentHash) control.tested_source_hash = currentHash;
    control.evidence = `${prefix}: reproof after source hash change (${control.id})`;
    control.blocker = "";
    control.stub = false;
    stampedControls.push(control.id);
  }

  const { isFlowStale } = require("./ledger_screens");
  for (const flow of unified.flows || []) {
    const v = flow.validation?.[platform];
    if (String(v?.result || "").toLowerCase() !== "pass") continue;
    if (!isFlowStale(flow, platform, currentHash)) continue;
    flow.validation[platform] = {
      result: "pass",
      evidence: `${prefix}: flow reproof (${flow.id})`,
      blocker: "",
      screenshot_ref: v?.screenshot_ref || "",
      last_tested_at: isoNow(),
      tested_source_hash: currentHash || "",
      last_test_method: method || "reproof"
    };
    stampedFlows.push(flow.id);
  }

  return { controls: stampedControls, flows: stampedFlows };
}

function syncFlowsFromControls(ledger, platform, repoRoot = root) {
  const unified = ledger.unified || ledger.data;
  const controls = getPlatformControls(ledger, platform);
  const currentHash = getPlatformHash(ledger, platform, repoRoot);
  let synced = 0;
  for (const flow of unified.flows || []) {
    const ids = flow.control_ids?.[platform] || [];
    if (!ids.length) continue;
    const result = String(flow.validation?.[platform]?.result || "pending").toLowerCase();
    if (["blocked", "not-applicable"].includes(result)) continue;
    const allPass = ids.every((id) => {
      const c = controls.find((x) => x.id === id);
      return c && String(c.result || "").toLowerCase() === "pass" && !isControlStale(c, currentHash);
    });
    if (!allPass) continue;
    const evidenceParts = ids.map((id) => {
      const c = controls.find((x) => x.id === id);
      return `${id}: ${c?.last_test_method || "pass"} ${c?.last_tested_at || ""}`;
    });
    const method = controls.find((c) => ids.includes(c.id))?.last_test_method || "synced-from-controls";
    flow.validation = flow.validation || {};
    flow.validation[platform] = {
      result: "pass",
      evidence: evidenceParts.join(" | "),
      blocker: "",
      screenshot_ref: flow.validation[platform]?.screenshot_ref || "",
      last_tested_at: isoNow(),
      tested_source_hash: currentHash || "",
      last_test_method: method
    };
    synced += 1;
  }
  if (synced) persistLedger(ledger);
  return synced;
}

function recordControl(data, controlId, { result, evidence, method, repoRoot = root }) {
  const currentHash = refreshScreenSourceHash(data, repoRoot);
  const control = (data.controls || []).find((c) => c.id === controlId);
  if (!control) throw new Error(`control not found: ${controlId}`);
  if (result) control.result = result;
  if (evidence !== undefined) control.evidence = evidence;
  control.last_tested_at = isoNow();
  if (currentHash) control.tested_source_hash = currentHash;
  if (method) control.last_test_method = method;
  return control;
}

function stampControls(data, controlIds, { result = "pass", evidencePrefix, method, repoRoot = root }) {
  const currentHash = refreshScreenSourceHash(data, repoRoot);
  const ids = controlIds.length ? controlIds : (data.controls || []).map((c) => c.id);
  const stamped = [];
  for (const id of ids) {
    const control = (data.controls || []).find((c) => c.id === id);
    if (!control) continue;
    if (result) control.result = result;
    control.last_tested_at = isoNow();
    if (currentHash) control.tested_source_hash = currentHash;
    if (method) control.last_test_method = method;
    if (evidencePrefix && !control.evidence) {
      control.evidence = `${evidencePrefix} ${isoNow()}`;
    }
    stamped.push(id);
  }
  return stamped;
}

module.exports = {
  root,
  parseSourcePath,
  parseSourceHint,
  resolveSourceFiles,
  hashScreenSources,
  isControlStale,
  isoNow,
  loadScreenLedger,
  findLedgerByScreenArg,
  writeLedger,
  persistLedger,
  getPlatformControls,
  getPlatformHash,
  flowSuccessCriteria,
  refreshScreenSourceHash,
  recordControl,
  stampControls,
  recordControlLedger,
  stampControlsLedger,
  recordFlowLedger,
  stampStaleLedger,
  syncFlowsFromControls
};
