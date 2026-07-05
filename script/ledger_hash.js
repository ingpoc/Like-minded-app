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

function hashScreenSources(screenData, repoRoot = root) {
  const files = resolveSourceFiles(screenData.source_files, repoRoot);
  if (files.length === 0) return null;
  const hash = crypto.createHash("sha256");
  for (const file of files) {
    hash.update(path.relative(repoRoot, file));
    hash.update("\0");
    hash.update(fs.readFileSync(file));
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
  const dir = path.join(repoRoot, "validation", platform);
  let file = fileOrId;
  if (!file.endsWith(".json")) file = `${fileOrId}.json`;
  const abs = path.join(dir, file);
  if (!fs.existsSync(abs)) throw new Error(`ledger not found: ${abs}`);
  return { abs, data: JSON.parse(fs.readFileSync(abs, "utf8")), file };
}

function findLedgerByScreenArg(platform, screenArg, repoRoot = root) {
  const dir = path.join(repoRoot, "validation", platform);
  const needle = screenArg.toLowerCase();
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".json"))) {
    const abs = path.join(dir, file);
    const data = JSON.parse(fs.readFileSync(abs, "utf8"));
    if (file.replace(/\.json$/, "").toLowerCase().includes(needle)) {
      return { abs, data, file };
    }
    if ((data.source_files || []).some((s) => {
      const lower = s.toLowerCase();
      return lower.includes(`(${needle})`) || lower.includes(needle);
    })) {
      return { abs, data, file };
    }
  }
  throw new Error(`no ledger for screen ${screenArg} on ${platform}`);
}

function writeLedger(abs, data) {
  fs.writeFileSync(abs, `${JSON.stringify(data, null, 2)}\n`);
}

function refreshScreenSourceHash(data, repoRoot = root) {
  const current = hashScreenSources(data, repoRoot);
  if (current) data.source_hash = current;
  return current;
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
  resolveSourceFiles,
  hashScreenSources,
  isControlStale,
  isoNow,
  loadScreenLedger,
  findLedgerByScreenArg,
  writeLedger,
  refreshScreenSourceHash,
  recordControl,
  stampControls
};
