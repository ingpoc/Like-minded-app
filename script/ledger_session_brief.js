#!/usr/bin/env node
/**
 * Session-start validation brief — what is done, what is open, what NOT to re-test.
 * Run after goal:next when validation work is in scope.
 *
 *   npm run ledger:brief
 *   npm run ledger:brief -- --platform ios --json
 */
const crypto = require("node:crypto");
const { summarizeFlows, listScreenFiles, loadScreenFile, isFlowOpen, isFlowStale, hashPlatformSlice } = require("./ledger_screens");
const { flowSuccessCriteria } = require("./ledger_hash");

const asJson = process.argv.includes("--json");
const includeAll = process.argv.includes("--all");
const receiptOnly = process.argv.includes("--receipt");
const platformEquals = process.argv.find((a) => a.startsWith("--platform="))?.split("=")[1];
const platformIndex = process.argv.indexOf("--platform");
const onlyPlatform = platformEquals || (platformIndex >= 0 ? process.argv[platformIndex + 1] : null);

function flowInventoryForPlatform(platform) {
  const items = [];
  for (const file of listScreenFiles()) {
    const { data, logicalId } = loadScreenFile(file);
    const slice = data.platforms?.[platform];
    if (!slice || slice.implemented === false) continue;
    const currentHash = hashPlatformSlice(data, platform);
    for (const flow of data.flows || []) {
      const v = flow.validation?.[platform] || {};
      const declaredResult = String(v.result || "pending").toLowerCase();
      const ids = flow.control_ids?.[platform] || [];
      if (!ids.length && declaredResult === "not-applicable") continue;
      const stale = declaredResult === "pass" && isFlowStale(flow, platform, currentHash);
      const lastTested = v.last_tested_at || null;
      const parsed = lastTested ? Date.parse(lastTested) : NaN;
      items.push({
        screen: logicalId,
        flow_id: flow.id,
        name: flow.name,
        result: stale ? "stale-pass" : declaredResult,
        last_tested_at: lastTested,
        age_days: Number.isFinite(parsed) ? Math.max(0, Math.floor((Date.now() - parsed) / 86400000)) : null,
        last_test_method: v.last_test_method || null,
        tested_source_hash: v.tested_source_hash || null,
        current_source_hash: currentHash || null,
        blocker: v.blocker || null,
        evidence: v.evidence || null,
        never_tested: !v.last_tested_at && !v.tested_source_hash,
        missing_success_signal: !(flow.proof?.success_signals || []).length
      });
    }
  }
  return items;
}

function fingerprintInventory(items) {
  return crypto
    .createHash("sha256")
    .update(JSON.stringify(items.map((item) => ({
      screen: item.screen,
      flow_id: item.flow_id,
      result: item.result,
      last_tested_at: item.last_tested_at,
      last_test_method: item.last_test_method,
      tested_source_hash: item.tested_source_hash,
      current_source_hash: item.current_source_hash,
      blocker: item.blocker,
      evidence: item.evidence
    }))))
    .digest("hex");
}

function coverageSummary(items) {
  const tested = items.filter((item) => item.last_tested_at).sort((a, b) =>
    String(a.last_tested_at).localeCompare(String(b.last_tested_at))
  );
  return {
    declared_applicable: items.length,
    current_pass: items.filter((item) => item.result === "pass").length,
    stale_pass: items.filter((item) => item.result === "stale-pass").length,
    pending_or_fail: items.filter((item) => ["pending", "untested", "fail"].includes(item.result)).length,
    blocked: items.filter((item) => item.result === "blocked").length,
    never_tested: items.filter((item) => item.never_tested).length,
    missing_success_signals: items.filter((item) => item.missing_success_signal).length,
    oldest_tested_at: tested[0]?.last_tested_at || null,
    newest_tested_at: tested.at(-1)?.last_tested_at || null,
    oldest_tested: tested.slice(0, 5).map(({ screen, flow_id, last_tested_at, result }) => ({ screen, flow_id, last_tested_at, result })),
    never_tested_flows: items.filter((item) => item.never_tested).map(({ screen, flow_id, result }) => ({ screen, flow_id, result })),
    missing_signal_flows: items.filter((item) => item.missing_success_signal).map(({ screen, flow_id }) => ({ screen, flow_id }))
  };
}

function ledgerIntegrity() {
  const loaded = listScreenFiles().map((file) => loadScreenFile(file));
  const knownScreens = new Set(loaded.map(({ logicalId }) => logicalId));
  const gaps = [];
  for (const { data, logicalId } of loaded) {
    for (const platform of ["ios", "macos"]) {
      const controls = data.controls?.[platform] || [];
      const controlIds = new Set(controls.map((control) => control.id || control.control_id).filter(Boolean));
      const referenced = new Set((data.flows || []).flatMap((flow) => flow.control_ids?.[platform] || []));
      for (const controlId of controlIds) {
        if (!referenced.has(controlId)) gaps.push({ type: "unmapped-control", screen: logicalId, platform, id: controlId });
      }
      for (const controlId of referenced) {
        if (!controlIds.has(controlId)) gaps.push({ type: "missing-control", screen: logicalId, platform, id: controlId });
      }
    }
    for (const flow of data.flows || []) {
      for (const destination of flow.destinations || []) {
        if (!String(destination).includes(" ") && !knownScreens.has(destination)) {
          gaps.push({ type: "missing-destination", screen: logicalId, flow_id: flow.id, destination });
        }
      }
    }
  }
  return { ok: gaps.length === 0, gap_count: gaps.length, gaps };
}

function openFlowsForPlatform(platform) {
  const items = [];
  for (const file of listScreenFiles()) {
    const { data, logicalId } = loadScreenFile(file);
    const slice = data.platforms?.[platform];
    if (!slice || slice.implemented === false) continue;
    const currentHash = hashPlatformSlice(data, platform);
    for (const flow of data.flows || []) {
      const v = flow.validation?.[platform] || {};
      const result = String(v.result || "pending").toLowerCase();
      if (result === "pass" && isFlowStale(flow, platform, currentHash)) {
        items.push({
          screen: logicalId,
          flow_id: flow.id,
          name: flow.name,
          result: "stale-pass",
          success_criteria: flowSuccessCriteria(flow, platform),
          last_tested_at: v.last_tested_at || null,
          last_test_method: v.last_test_method || null
        });
      } else if (isFlowOpen(flow, platform)) {
        items.push({
          screen: logicalId,
          flow_id: flow.id,
          name: flow.name,
          result,
          success_criteria: flowSuccessCriteria(flow, platform),
          blocker: v.blocker || "",
          steps: flow.steps || []
        });
      }
    }
  }
  return items;
}

function buildBrief() {
  const platforms = onlyPlatform ? [onlyPlatform] : ["ios", "macos"];
  const counts = {};
  const open = {};
  const coverage = {};
  const inventory = {};
  const sourceStateFingerprints = {};
  for (const platform of platforms) {
    const s = summarizeFlows(platform);
    counts[platform] = {
      flows: s.flows,
      pass: s.pass,
      pending: s.pending,
      fail: s.fail,
      blocked: s.blocked,
      stale_pass: s.stale_pass,
      actionable: s.actionable
    };
    open[platform] = openFlowsForPlatform(platform).slice(0, 12);
    const platformInventory = flowInventoryForPlatform(platform);
    coverage[platform] = coverageSummary(platformInventory);
    sourceStateFingerprints[platform] = fingerprintInventory(platformInventory);
    if (includeAll) inventory[platform] = platformInventory;
  }

  const nextIos = open.ios?.find((f) => f.result === "pending" || f.result === "fail");
  const nextMac = open.macos?.find((f) => f.result === "pending" || f.result === "fail");

  return {
    schema: "validation-session-brief-v1",
    status_owner: "validation/screens/*.json → flows[].validation.{ios,macos}",
    trust_pass:
      "Do not re-run capture/Computer proof on pass flows unless ledger:stale lists them or source_files changed",
    success_criteria_field: "flow.steps[] + control_ids; see flowSuccessCriteria in ledger_hash.js",
    counts,
    coverage,
    integrity: ledgerIntegrity(),
    source_state_fingerprints: sourceStateFingerprints,
    ...(includeAll ? { inventory } : {}),
    next_open: {
      ios: nextIos || open.ios?.[0] || null,
      macos: nextMac || open.macos?.[0] || null
    },
    open_sample: open,
    commands: {
      gap_scan: "npm run ledger:open",
      complete_history: "npm run ledger:brief -- --platform ios|macos --all --json",
      stale_only: "npm run ledger:stale",
      one_screen: "npm run ledger:screen -- --platform macos --screen <id> --section flows",
      record_flow: "npm run ledger:record-flow -- --platform macos --screen <id> --flow <flow-id> --result pass --evidence '...' --method Computer-use",
      sync_after_stamp: "npm run ledger:sync-flows -- --platform macos --screen <id>",
      macos_one_screen: "testing:ledger-run card → canonical launch → bundled @Computer",
      ios_one_screen: "./script/cross_platform_screen_validate.sh --screen <id> --platform ios"
    }
  };
}

function orchestrationReceipt(brief) {
  const coverage = Object.fromEntries(Object.entries(brief.coverage).map(([platform, value]) => [platform, {
    declared_applicable: value.declared_applicable,
    current_pass: value.current_pass,
    stale_pass: value.stale_pass,
    pending_or_fail: value.pending_or_fail,
    blocked: value.blocked,
    never_tested: value.never_tested,
    missing_success_signals: value.missing_success_signals,
    oldest_tested_at: value.oldest_tested_at,
    newest_tested_at: value.newest_tested_at
  }]));
  const openPlatform = Object.keys(brief.counts).find((platform) => brief.counts[platform].actionable > 0);
  const core = {
    schema: "testing-ledger-orchestration-receipt-v1",
    status_owner: brief.status_owner,
    integrity: { ok: brief.integrity.ok, gap_count: brief.integrity.gap_count },
    counts: brief.counts,
    coverage,
    source_state_fingerprints: brief.source_state_fingerprints,
    next_owner_command: brief.integrity.ok
      ? (openPlatform
          ? `npm run testing:ledger-run -- --platform ${openPlatform}`
          : "npm run verify:production-ready")
      : "npm run verify:testing-ledger"
  };
  return {
    ...core,
    receipt_fingerprint: crypto.createHash("sha256").update(JSON.stringify(core)).digest("hex")
  };
}

function main() {
  const brief = buildBrief();
  if (receiptOnly) {
    console.log(JSON.stringify(orchestrationReceipt(brief), null, 2));
    return;
  }
  if (asJson) {
    process.stdout.write(`${JSON.stringify(brief, null, 2)}\n`);
    return;
  }

  console.log("# Validation session brief");
  console.log(`status_owner: ${brief.status_owner}`);
  console.log(`trust_pass: ${brief.trust_pass}`);
  console.log(`inventory_integrity: ${brief.integrity.ok ? "ok" : "gaps"} (${brief.integrity.gap_count})`);
  for (const [platform, c] of Object.entries(brief.counts)) {
    console.log(
      `${platform}: pass=${c.pass} pending=${c.pending} fail=${c.fail} blocked=${c.blocked} stale_pass=${c.stale_pass} actionable=${c.actionable}`
    );
    const coverage = brief.coverage[platform];
    console.log(
      `${platform}_coverage: declared=${coverage.declared_applicable} current=${coverage.current_pass} stale=${coverage.stale_pass} never_tested=${coverage.never_tested} missing_signals=${coverage.missing_success_signals} oldest=${coverage.oldest_tested_at || "none"}`
    );
  }
  for (const platform of Object.keys(brief.counts)) {
    const next = brief.next_open[platform];
    if (next) {
      console.log(
        `next_${platform}: ${next.screen}/${next.flow_id} (${next.result}) — ${next.success_criteria}`
      );
    }
  }
  console.log("commands: ledger:brief -- --platform <p> --all --json | ledger:screen | ledger:record-flow");
}

if (require.main === module) main();

module.exports = { buildBrief, orchestrationReceipt, fingerprintInventory, flowInventoryForPlatform, coverageSummary, ledgerIntegrity };
