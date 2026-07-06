#!/usr/bin/env node
/**
 * Session-start validation brief — what is done, what is open, what NOT to re-test.
 * Run after goal:next when validation work is in scope.
 *
 *   npm run ledger:brief
 *   npm run ledger:brief -- --platform ios --json
 */
const { summarizeFlows, listScreenFiles, loadScreenFile, isFlowOpen, isFlowStale, hashPlatformSlice } = require("./ledger_screens");
const { flowSuccessCriteria } = require("./ledger_hash");

const asJson = process.argv.includes("--json");
const onlyPlatform = process.argv.find((a) => a.startsWith("--platform="))?.split("=")[1];

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
  }

  const nextIos = open.ios?.find((f) => f.result === "pending" || f.result === "fail");
  const nextMac = open.macos?.find((f) => f.result === "pending" || f.result === "fail");

  return {
    schema: "validation-session-brief-v1",
    status_owner: "validation/screens/*.json → flows[].validation.{ios,macos}",
    trust_pass:
      "Do not re-run capture/CUA on pass flows unless ledger:stale lists them or source_files changed",
    success_criteria_field: "flow.steps[] + control_ids; see flowSuccessCriteria in ledger_hash.js",
    counts,
    next_open: {
      ios: nextIos || open.ios?.[0] || null,
      macos: nextMac || open.macos?.[0] || null
    },
    open_sample: open,
    commands: {
      gap_scan: "npm run ledger:open",
      stale_only: "npm run ledger:stale",
      one_screen: "npm run ledger:screen -- --platform macos --screen <id> --section flows",
      record_flow: "npm run ledger:record-flow -- --platform macos --screen <id> --flow <flow-id> --result pass --evidence '...' --method CUA",
      sync_after_stamp: "npm run ledger:sync-flows -- --platform macos --screen <id>",
      macos_one_screen: "macos_cua_preflight.sh → macos_audit_prepare.sh <screen> → macos_cua_screen.sh <screen>",
      ios_one_screen: "./script/cross_platform_screen_validate.sh --screen <id> --platform ios"
    }
  };
}

const brief = buildBrief();

if (asJson) {
  process.stdout.write(`${JSON.stringify(brief, null, 2)}\n`);
  process.exit(0);
}

console.log("# Validation session brief");
console.log(`status_owner: ${brief.status_owner}`);
console.log(`trust_pass: ${brief.trust_pass}`);
for (const [platform, c] of Object.entries(brief.counts)) {
  console.log(
    `${platform}: pass=${c.pass} pending=${c.pending} fail=${c.fail} blocked=${c.blocked} stale_pass=${c.stale_pass} actionable=${c.actionable}`
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
console.log("commands: ledger:open | ledger:screen | ledger:record-flow | ledger:sync-flows");
