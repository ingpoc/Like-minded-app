#!/usr/bin/env node
/**
 * Compact list of non-pass and stale-pass validation controls.
 */
const fs = require("node:fs");
const path = require("node:path");
const { hashScreenSources, isControlStale } = require("./ledger_hash");

const root = path.resolve(__dirname, "..");
const onlyPlatform = process.argv.find((a) => a.startsWith("--platform="))?.split("=")[1];
const asJson = process.argv.includes("--json");
const staleOnly = process.argv.includes("--stale-only");

const OPEN = new Set(["fail", "pending", "blocked", "untested", ""]);

function summarizePlatform(platform) {
  const dir = path.join(root, "validation", platform);
  if (!fs.existsSync(dir)) {
    return { platform, screens: [], totals: { pass: 0, open: 0, stale_pass: 0 } };
  }

  const screens = [];
  let pass = 0;
  let open = 0;
  let stalePass = 0;

  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".json")).sort()) {
    const data = JSON.parse(fs.readFileSync(path.join(dir, file), "utf8"));
    const currentHash = hashScreenSources(data, root) || data.source_hash || null;
    if (currentHash && data.source_hash !== currentHash) {
      data.source_hash = currentHash;
    }
    const openControls = [];

    for (const control of data.controls || []) {
      const result = String(control.result || "pending").toLowerCase();
      if (result === "pass") {
        pass += 1;
        if (isControlStale(control, currentHash)) {
          stalePass += 1;
          openControls.push({
            id: control.id,
            label: control.label,
            result: "stale-pass",
            expected: control.expected || "",
            blocker: "",
            evidence: control.evidence || "",
            last_tested_at: control.last_tested_at || null,
            tested_source_hash: control.tested_source_hash || null,
            source_hash: currentHash
          });
        }
        continue;
      }
      if (!OPEN.has(result)) continue;
      open += 1;
      openControls.push({
        id: control.id,
        label: control.label,
        result,
        expected: control.expected || "",
        blocker: control.blocker || "",
        evidence: control.evidence || ""
      });
    }

    if (!staleOnly) {
      const vp = data.visual_parity?.result;
      if (vp && /pending|fail|partial/i.test(String(vp))) {
        openControls.push({
          id: "visual_parity",
          label: "visual parity",
          result: String(vp),
          expected: data.mockup_ref || "",
          blocker: "",
          evidence: data.visual_parity?.notes || ""
        });
        open += 1;
      }
    } else {
      const filtered = openControls.filter((c) => c.result === "stale-pass");
      openControls.length = 0;
      openControls.push(...filtered);
    }

    const rows = staleOnly ? openControls.filter((c) => c.result === "stale-pass") : openControls;
    if (rows.length > 0) {
      screens.push({
        file: `validation/${platform}/${file}`,
        screen: data.screen,
        source_hash: currentHash,
        mockup_ref: data.mockup_ref || null,
        controls: rows
      });
    }
  }

  return {
    platform,
    screens,
    totals: { pass, open, stale_pass: stalePass, actionable: open + stalePass }
  };
}

const platforms = onlyPlatform ? [onlyPlatform] : ["ios", "macos"];
const report = platforms.map(summarizePlatform);

if (asJson) {
  console.log(JSON.stringify({ platforms: report }, null, 2));
  process.exit(0);
}

for (const p of report) {
  const label = staleOnly ? "stale-pass" : "open";
  console.log(
    `# ${p.platform} ${label}=${staleOnly ? p.totals.stale_pass : p.totals.actionable} pass=${p.totals.pass} stale_pass=${p.totals.stale_pass}`
  );
  for (const screen of p.screens) {
    console.log(`\n${screen.file} | ${screen.screen} | source_hash=${screen.source_hash || "?"}`);
    for (const c of screen.controls) {
      const blocker = c.blocker ? ` | ${c.blocker}` : "";
      const tested = c.last_tested_at ? ` tested=${c.last_tested_at}` : "";
      console.log(`  - ${c.id} | ${c.result} | ${c.label}${blocker}${tested}`);
      if (c.expected) console.log(`    expected: ${c.expected}`);
      if (c.result === "stale-pass" && c.tested_source_hash) {
        console.log(`    tested_source_hash=${c.tested_source_hash} (current=${c.source_hash})`);
      }
    }
  }
  if (p.screens.length === 0) console.log(`  (no ${label} controls)`);
}
