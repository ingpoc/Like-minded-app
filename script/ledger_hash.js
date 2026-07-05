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
  const dir = path.join(repoRoot, "validation", platform);
  let file = fileOrId;
  if (!file.endsWith(".json")) file = `${fileOrId}.json`;
  const abs = path.join(dir, file);
  if (!fs.existsSync(abs)) throw new Error(`ledger not found: ${abs}`);
  return { abs, data: JSON.parse(fs.readFileSync(abs, "utf8")), file };
}

function normalizeScreenToken(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

function findLedgerByScreenArg(platform, screenArg, repoRoot = root) {
  const dir = path.join(repoRoot, "validation", platform);
  const needle = normalizeScreenToken(screenArg);
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".json"))) {
    const abs = path.join(dir, file);
    const data = JSON.parse(fs.readFileSync(abs, "utf8"));
    const fileStem = normalizeScreenToken(file.replace(/\.json$/, ""));
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
  parseSourceHint,
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
