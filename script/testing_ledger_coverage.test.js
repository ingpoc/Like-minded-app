"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const path = require("node:path");
const test = require("node:test");
const { interleaveByScreen } = require("./testing_ledger_pick_next");
const { orchestrationReceipt, fingerprintInventory } = require("./ledger_session_brief");

const root = path.resolve(__dirname, "..");

test("queue breadth prioritizes never-tested and oldest evidence before recent repeats", () => {
  const ordered = interleaveByScreen([
    { screen: "recent", flow_id: "b", last_tested_at: "2026-07-22" },
    { screen: "old", flow_id: "b", last_tested_at: "2026-07-02" },
    { screen: "recent", flow_id: "a", last_tested_at: "2026-07-21" },
    { screen: "never", flow_id: "a", last_tested_at: null },
    { screen: "old", flow_id: "a", last_tested_at: "2026-07-01" }
  ]);
  assert.deepEqual(ordered.map((item) => `${item.screen}/${item.flow_id}`), [
    "never/a", "old/a", "recent/a", "old/b", "recent/b"
  ]);
});

test("compact brief exposes coverage debt without emitting the full inventory", () => {
  const result = spawnSync(process.execPath, ["script/ledger_session_brief.js", "--platform", "ios", "--json"], {
    cwd: root, encoding: "utf8"
  });
  assert.equal(result.status, 0, result.stderr);
  const payload = JSON.parse(result.stdout);
  assert.ok(payload.coverage.ios.declared_applicable > 0);
  assert.ok(Object.hasOwn(payload.integrity, "gap_count"));
  assert.equal(Object.hasOwn(payload, "inventory"), false);
});

test("orchestration receipt is fingerprinted and excludes flow-level context", () => {
  const result = spawnSync(process.execPath, ["script/ledger_session_brief.js", "--receipt"], {
    cwd: root, encoding: "utf8"
  });
  assert.equal(result.status, 0, result.stderr);
  assert.ok(Buffer.byteLength(result.stdout) < 3000, `receipt was ${Buffer.byteLength(result.stdout)} bytes`);
  const payload = JSON.parse(result.stdout);
  assert.equal(payload.schema, "testing-ledger-orchestration-receipt-v1");
  assert.match(payload.receipt_fingerprint, /^[a-f0-9]{64}$/);
  assert.ok(payload.next_owner_command);
  assert.equal(Object.hasOwn(payload, "open_sample"), false);
  assert.equal(Object.hasOwn(payload, "next_open"), false);
  assert.equal(Object.hasOwn(payload, "inventory"), false);
  assert.equal(Object.hasOwn(payload.coverage.ios, "never_tested_flows"), false);
});

test("orchestration receipt changes for same-source proof updates and source changes", () => {
  const baseItem = {
    screen: "profile-edit",
    flow_id: "save",
    result: "pass",
    last_tested_at: "2026-07-20T10:00:00Z",
    last_test_method: "Computer-use",
    tested_source_hash: "source-a",
    current_source_hash: "source-a",
    blocker: null,
    evidence: "proof-a"
  };
  const briefWith = (item) => ({
    status_owner: "validation/screens/*.json",
    integrity: { ok: true, gap_count: 0 },
    counts: { ios: { flows: 1, pass: 1, pending: 0, fail: 0, blocked: 0, stale_pass: 0, actionable: 0 } },
    coverage: { ios: {
      declared_applicable: 1, current_pass: 1, stale_pass: 0,
      pending_or_fail: 0, blocked: 0, never_tested: 0,
      missing_success_signals: 0, oldest_tested_at: item.last_tested_at,
      newest_tested_at: item.last_tested_at
    } },
    source_state_fingerprints: { ios: fingerprintInventory([item]) }
  });
  const base = orchestrationReceipt(briefWith(baseItem)).receipt_fingerprint;
  const proofUpdate = orchestrationReceipt(briefWith({
    ...baseItem,
    last_tested_at: "2026-07-21T10:00:00Z",
    evidence: "proof-b"
  })).receipt_fingerprint;
  const sourceUpdate = orchestrationReceipt(briefWith({
    ...baseItem,
    current_source_hash: "source-b"
  })).receipt_fingerprint;
  assert.notEqual(base, proofUpdate);
  assert.notEqual(base, sourceUpdate);
});

test("full history is opt-in and carries timestamp plus source-hash freshness", () => {
  const result = spawnSync(process.execPath, ["script/ledger_session_brief.js", "--platform", "macos", "--all", "--json"], {
    cwd: root, encoding: "utf8"
  });
  assert.equal(result.status, 0, result.stderr);
  const payload = JSON.parse(result.stdout);
  assert.ok(payload.inventory.macos.length > 0);
  assert.ok(payload.inventory.macos.every((item) => Object.hasOwn(item, "last_tested_at")));
  assert.ok(payload.inventory.macos.every((item) => Object.hasOwn(item, "current_source_hash")));
});
