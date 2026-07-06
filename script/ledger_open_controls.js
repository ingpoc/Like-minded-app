#!/usr/bin/env node
/**
 * Compact list of open flows and stale-pass flows (schema v2).
 * Falls back to validation/_legacy/{ios,macos} when screens/ absent.
 */
const fs = require("node:fs");
const path = require("node:path");
const { hashScreenSources, isControlStale } = require("./ledger_hash");
const {
  listScreenFiles,
  loadScreenFile,
  hashPlatformSlice,
  flowValidation,
  isFlowStale,
  summarizeFlows
} = require("./ledger_screens");

const root = path.resolve(__dirname, "..");
const onlyPlatform = process.argv.find((a) => a.startsWith("--platform="))?.split("=")[1];
const asJson = process.argv.includes("--json");
const staleOnly = process.argv.includes("--stale-only");
const flowsOnly = !process.argv.includes("--controls");

const OPEN = new Set(["fail", "pending", "blocked", "untested", ""]);

function summarizePlatformFlows(platform) {
  const summary = summarizeFlows(platform, root);
  const screens = [];
  const screensDir = path.join(root, "validation", "screens");

  if (!fs.existsSync(screensDir)) {
    return summarizePlatformLegacyControls(platform);
  }

  for (const file of listScreenFiles(root)) {
    const { data, logicalId } = loadScreenFile(file, root);
    const slice = data.platforms?.[platform];
    if (!slice) continue;
    const currentHash = hashPlatformSlice(data, platform, root);
    const openFlows = [];

    for (const flow of data.flows || []) {
      const v = flowValidation(flow, platform);
      const result = String(v.result || "pending").toLowerCase();
      if (result === "pass") {
        if (isFlowStale(flow, platform, currentHash)) {
          openFlows.push({
            id: flow.id,
            label: flow.name,
            result: "stale-pass",
            expected: flow.steps?.join("; ") || "",
            blocker: "",
            evidence: v.evidence || "",
            last_tested_at: v.last_tested_at || null,
            tested_source_hash: v.tested_source_hash || null,
            source_hash: currentHash
          });
        }
        continue;
      }
      if (result === "not-applicable") {
        continue;
      }
      if (!staleOnly && OPEN.has(result)) {
        openFlows.push({
          id: flow.id,
          label: flow.name,
          result,
          expected: flow.steps?.join("; ") || "",
          blocker: v.blocker || "",
          evidence: v.evidence || ""
        });
      }
    }

    if (!staleOnly) {
      const vp = slice.ui_validation?.result || slice.visual_parity?.result;
      if (vp && /pending|fail|partial/i.test(String(vp))) {
        openFlows.push({
          id: "visual_parity",
          label: "visual parity",
          result: String(vp),
          expected: slice.mockup_ref || "",
          blocker: "",
          evidence: slice.visual_parity?.notes || slice.ui_validation?.notes || ""
        });
      }
    } else {
      const filtered = openFlows.filter((f) => f.result === "stale-pass");
      openFlows.length = 0;
      openFlows.push(...filtered);
    }

    const rows = staleOnly ? openFlows.filter((f) => f.result === "stale-pass") : openFlows;
    if (rows.length > 0) {
      screens.push({
        file: `validation/screens/${file}`,
        screen: data.screen,
        logical_screen_id: logicalId,
        source_hash: currentHash,
        mockup_ref: slice.mockup_ref || null,
        flows: rows
      });
    }
  }

  return {
    platform,
    mode: "flows",
    screens,
    totals: {
      pass: summary.pass,
      open: summary.pending + summary.fail,
      stale_pass: summary.stale_pass,
      blocked: summary.blocked,
      flows: summary.flows,
      actionable: summary.actionable
    }
  };
}

function summarizePlatformLegacyControls(platform) {
  const legacyDirs = [
    path.join(root, "validation", platform),
    path.join(root, "validation", "_legacy", platform)
  ];
  const dir = legacyDirs.find((d) => fs.existsSync(d));
  if (!dir) {
    return { platform, mode: "legacy-controls", screens: [], totals: { pass: 0, open: 0, stale_pass: 0, actionable: 0 } };
  }

  const screens = [];
  let pass = 0;
  let open = 0;
  let stalePass = 0;

  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".json")).sort()) {
    const data = JSON.parse(fs.readFileSync(path.join(dir, file), "utf8"));
    const currentHash = hashScreenSources(data, root) || data.source_hash || null;
    const openControls = [];

    for (const control of data.controls || []) {
      const result = String(control.result || "pending").toLowerCase();
      if (result === "pass") {
        pass += 1;
        if (isControlStale(control, currentHash)) {
          stalePass += 1;
          openControls.push({ ...control, result: "stale-pass", source_hash: currentHash });
        }
        continue;
      }
      if (!OPEN.has(result)) continue;
      open += 1;
      openControls.push(control);
    }

    const rows = staleOnly
      ? openControls.filter((c) => c.result === "stale-pass")
      : openControls;
    if (rows.length > 0) {
      screens.push({
        file: path.relative(root, path.join(dir, file)),
        screen: data.screen,
        controls: rows
      });
    }
  }

  return {
    platform,
    mode: "legacy-controls",
    screens,
    totals: { pass, open, stale_pass: stalePass, actionable: open + stalePass }
  };
}

const platforms = onlyPlatform ? [onlyPlatform] : ["ios", "macos"];
const report = platforms.map((p) => summarizePlatformFlows(p));

if (asJson) {
  console.log(JSON.stringify({ platforms: report }, null, 2));
  process.exit(0);
}

for (const p of report) {
  const label = staleOnly ? "stale-pass" : "open";
  const mode = p.mode || "flows";
  console.log(
    `# ${p.platform} ${label}=${staleOnly ? p.totals.stale_pass : p.totals.actionable} pass=${p.totals.pass} stale_pass=${p.totals.stale_pass} mode=${mode}${p.totals.flows ? ` flows=${p.totals.flows}` : ""}`
  );
  for (const screen of p.screens) {
    console.log(`\n${screen.file} | ${screen.screen} | source_hash=${screen.source_hash || "?"}`);
    const items = screen.flows || screen.controls || [];
    for (const item of items) {
      const blocker = item.blocker ? ` | ${item.blocker}` : "";
      const tested = item.last_tested_at ? ` tested=${item.last_tested_at}` : "";
      console.log(`  - ${item.id} | ${item.result} | ${item.label}${blocker}${tested}`);
      if (item.expected) console.log(`    expected: ${item.expected}`);
      if (item.result === "stale-pass" && item.tested_source_hash) {
        console.log(`    tested_source_hash=${item.tested_source_hash} (current=${item.source_hash})`);
      }
    }
  }
  if (p.screens.length === 0) console.log(`  (no ${label} ${mode === "flows" ? "flows" : "controls"})`);
}
