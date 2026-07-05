#!/usr/bin/env node
/**
 * Shared ledger ↔ PROGRESS ownership checks.
 *
 * Prevents agents from claiming phase/track/goal complete while validation JSON
 * still has open work, and plugs common evasion paths:
 * - open fail/pending without PROGRESS owners
 * - stale "automation unavailable" blocked treated as done
 * - sibling .md ledgers competing with JSON
 * - empty control arrays / wiped ledger dirs
 * - historical phase checkboxes that still read as ledger-green
 * - goal.json status=completed while ownership is broken
 * - stale "GUI automation unavailable" evidence while macos_cua_screen.sh exists
 * - README routing that lists Phase 9 external setup without goal:next / ledger deferral
 * - competing context surfaces (validation README status tables, PROGRESS phase graveyard, etc.)
 */
const fs = require("node:fs");
const path = require("node:path");
const { hashScreenSources, isControlStale } = require("./ledger_hash");

const root = path.resolve(__dirname, "..");

const PLATFORM_OWNERS = {
  ios: /Track — iOS Ledger Honesty|validation\/ios|iOS stale_pass|iOS infra-blocked/i,
  macos:
    /Track — macOS|validation\/macos|macOS infra-blocked|macOS stale_pass/i
};

const TRACK_LABELS = {
  ios: "ios-ledger-honesty",
  macos: "macos-visual-parity"
};

/** Blocked rows that are really "not exercised yet", not infra (LiveKit/Apple). */
const STALE_AUTOMATION_RE =
  /GUI automation unavailable|macOS GUI automation unavailable|Cannot interact:|CUA (typing |not |never )|automation unavailable/i;

/** Checked PROGRESS lines that must be explicitly historical when present. */
const HISTORICAL_OVERCLAIM = [
  {
    claim: /Manual proofs — \*\*iOS\*\*/i,
    require: /historical|not ledger-green|owned by/i,
    message:
      "checked Manual proofs — **iOS** must say historical / not ledger-green / owned by Track — iOS Ledger Honesty"
  },
  {
    claim: /every macOS screen exercise real functionality/i,
    require: /historical/i,
    message: "checked 'every macOS screen exercise real functionality' must be labeled historical"
  },
  {
    claim: /functional parity \(visual parity deferred\)/i,
    require: /historical|deferred to|JSON ledgers are status owner|wire-up/i,
    message: "checked functional-parity claim must not read as current ledger-green"
  }
];

function readProgress() {
  return fs.readFileSync(path.join(root, "PROGRESS.md"), "utf8");
}

function readGoalStatus() {
  try {
    return JSON.parse(fs.readFileSync(path.join(root, "goal.json"), "utf8")).status;
  } catch {
    return null;
  }
}

function uncheckedLines(progress) {
  return progress.split("\n").filter((line) => /^\s*-\s*\[ \]/.test(line));
}

function checkedLines(progress) {
  return progress.split("\n").filter((line) => /^\s*-\s*\[[xX]\]/.test(line));
}

function siblingMdLedgers() {
  const found = [];
  const validationRoot = path.join(root, "validation");
  if (!fs.existsSync(validationRoot)) return found;

  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (!entry.name.endsWith(".md") || entry.name === "README.md") continue;
      const json = full.replace(/\.md$/, ".json");
      if (fs.existsSync(json)) {
        found.push(path.relative(root, full));
      }
    }
  }
  walk(validationRoot);
  return found;
}

function summarizePlatform(platform) {
  const dir = path.join(root, "validation", platform);
  const summary = {
    platform,
    dir_exists: fs.existsSync(dir),
    screens: 0,
    empty_ledgers: [],
    fail: 0,
    pending: 0,
    blocked: 0,
    blocked_stale_automation: 0,
    stale_pass: 0,
    stubs: 0,
    actionable: 0,
    open_screens: []
  };
  if (!summary.dir_exists) return summary;

  for (const name of fs.readdirSync(dir).filter((f) => f.endsWith(".json")).sort()) {
    const data = JSON.parse(fs.readFileSync(path.join(dir, name), "utf8"));
    const controls = Array.isArray(data.controls) ? data.controls : [];
    const currentHash = hashScreenSources(data, root) || data.source_hash || null;
    summary.screens += 1;
    if (controls.length === 0) {
      summary.empty_ledgers.push(name);
      summary.open_screens.push(name);
      continue;
    }
    let screenActionable = false;
    for (const control of controls) {
      const result = String(control.result || control.status || "").toLowerCase();
      const evidence = `${control.evidence || ""} ${control.blocker || ""}`;
      if (control.stub) summary.stubs += 1;
      if (result === "fail") {
        summary.fail += 1;
        screenActionable = true;
      } else if (result === "pending" || result === "untested") {
        summary.pending += 1;
        screenActionable = true;
      } else if (result === "blocked") {
        summary.blocked += 1;
        if (STALE_AUTOMATION_RE.test(evidence)) {
          summary.blocked_stale_automation += 1;
          screenActionable = true;
        }
      } else if (!result) {
        summary.pending += 1;
        screenActionable = true;
      } else if (result === "pass" && isControlStale(control, currentHash)) {
        summary.stale_pass += 1;
        screenActionable = true;
      }
    }
    if (screenActionable) summary.open_screens.push(name);
  }
  summary.actionable =
    summary.fail +
    summary.pending +
    summary.blocked_stale_automation +
    summary.stale_pass +
    summary.empty_ledgers.length;
  return summary;
}

function historicalOverclaimErrors(progress) {
  const errors = [];
  for (const line of checkedLines(progress)) {
    for (const rule of HISTORICAL_OVERCLAIM) {
      if (rule.claim.test(line) && !rule.require.test(line)) {
        errors.push(rule.message);
      }
    }
  }
  return errors;
}

/** CUA exists — claiming GUI automation is unavailable is a stale lie. */
const FORBIDDEN_AUTOMATION_CLAIM = /GUI automation unavailable|macOS GUI automation unavailable/i;

function forbiddenAutomationClaimErrors() {
  if (!fs.existsSync(path.join(root, "script/macos_cua_screen.sh"))) return [];
  const hits = [];
  for (const platform of ["ios", "macos"]) {
    const dir = path.join(root, "validation", platform);
    if (!fs.existsSync(dir)) continue;
    for (const name of fs.readdirSync(dir).filter((f) => f.endsWith(".json"))) {
      const data = JSON.parse(fs.readFileSync(path.join(dir, name), "utf8"));
      for (const control of data.controls || []) {
        const text = `${control.evidence || ""} ${control.blocker || ""}`;
        if (FORBIDDEN_AUTOMATION_CLAIM.test(text)) {
          hits.push(`${platform}/${name}#${control.id || "?"}`);
        }
      }
    }
  }
  if (hits.length === 0) return [];
  const sample = hits.slice(0, 8).join(", ") + (hits.length > 8 ? "…" : "");
  return [
    `stale "GUI automation unavailable" claim while script/macos_cua_screen.sh exists (${hits.length}): ${sample}. Use result=pending and point at ./script/macos_cua_screen.sh — do not mark infrastructure-blocked.`
  ];
}

/** Competing context surfaces that waste tokens or lie about status. */
function contextRoutingErrors() {
  const errors = [];

  const validationReadme = path.join(root, "validation/README.md");
  if (fs.existsSync(validationReadme)) {
    const text = fs.readFileSync(validationReadme, "utf8");
    if (/## Status summary/i.test(text)) {
      errors.push(
        "validation/README.md must be link-only (no ## Status summary); status lives in validation/*.json"
      );
    }
    if (/\| Pass \| Fail \|/i.test(text)) {
      errors.push(
        "validation/README.md must not contain pass/fail status tables; regenerate via validation/_generate.js"
      );
    }
  }

  const progress = readProgress();
  const historicalPhases = progress.match(/^## Phase ([0-8]) /gm);
  if (historicalPhases && historicalPhases.length > 0) {
    errors.push(
      `PROGRESS.md must not list Phase 0–8 sections (found ${historicalPhases.length}); keep Current Status + tracks + Phase 9 only`
    );
  }

  const projectContext = path.join(root, "docs/references/project-context.md");
  if (fs.existsSync(projectContext) && /## Current Evidence/i.test(fs.readFileSync(projectContext, "utf8"))) {
    errors.push(
      "docs/references/project-context.md must not contain ## Current Evidence; use Boundaries only"
    );
  }

  const dupHarness = path.join(root, ".cursor/rules/harness-autopilot.mdc");
  if (fs.existsSync(dupHarness)) {
    errors.push(
      "delete .cursor/rules/harness-autopilot.mdc — harness routing is owned by AGENTS.md only"
    );
  }

  const macosAudit = path.join(root, "docs/references/macos-screen-audit.md");
  if (fs.existsSync(macosAudit)) {
    errors.push(
      "delete docs/references/macos-screen-audit.md — macOS proof routing is docs/workflows/validation.md"
    );
  }

  const rulesDir = path.join(root, ".cursor/rules");
  if (fs.existsSync(rulesDir)) {
    for (const name of fs.readdirSync(rulesDir).filter((f) => f.endsWith(".mdc"))) {
      const body = fs.readFileSync(path.join(rulesDir, name), "utf8");
      if (/Harness routing|harness-autopilot/i.test(body) && name !== "context-alignment.mdc") {
        errors.push(
          `.cursor/rules/${name} duplicates AGENTS.md harness routing — delete or fold into AGENTS.md`
        );
      }
    }
  }

  return errors;
}

function readmeRouteErrors() {
  const readmePath = path.join(root, "README.md");
  if (!fs.existsSync(readmePath)) return [];
  const readme = fs.readFileSync(readmePath, "utf8");
  const errors = [];
  if (!/npm run goal:next/.test(readme)) {
    errors.push("README.md must include `npm run goal:next` as the active route entrypoint");
  }
  if (!/verify:ledger-progress/.test(readme)) {
    errors.push("README.md must mention `verify:ledger-progress` in the validation path");
  }
  const nextDecisions = readme.match(/## Next Decisions\n([\s\S]*?)(?=\n## |$)/);
  if (
    nextDecisions &&
    /Create Render|Neon database|App Store Connect/i.test(nextDecisions[1]) &&
    !/do not start|while.*ledger|goal:next|macOS Visual Parity|iOS Ledger Honesty/i.test(nextDecisions[1])
  ) {
    errors.push(
      "README.md ## Next Decisions lists Phase 9 external setup without deferring to active ledger tracks / npm run goal:next"
    );
  }
  const renderIdx = readme.search(/Create Render service and Neon/i);
  if (renderIdx >= 0) {
    const window = readme.slice(Math.max(0, renderIdx - 500), renderIdx + 120);
    if (!/do not start|while.*ledger|open macOS|goal:next|ledger tracks/i.test(window)) {
      errors.push(
        "README.md mentions Render/Neon setup without deferral to ledger tracks / npm run goal:next"
      );
    }
  }
  return errors;
}

function ownershipReport(progress = readProgress(), goalStatus = readGoalStatus()) {
  const unchecked = uncheckedLines(progress);
  const errors = [];
  const platforms = ["ios", "macos"].map((platform) => {
    const summary = summarizePlatform(platform);
    const ownerPattern = PLATFORM_OWNERS[platform];
    const owners = unchecked.filter((line) => ownerPattern.test(line));
    let ok = true;

    if (summary.dir_exists && summary.screens === 0) {
      ok = false;
      errors.push(`${platform}: validation/${platform} exists but has no JSON ledgers`);
    }
    if (summary.empty_ledgers.length > 0) {
      ok = false;
      errors.push(
        `${platform}: empty controls[] in ${summary.empty_ledgers.join(", ")} (cannot wipe ledgers to pass)`
      );
    }
    if (summary.actionable > 0 && owners.length === 0) {
      ok = false;
      errors.push(
        `${platform}: ${summary.actionable} actionable open control(s) (fail=${summary.fail} pending=${summary.pending} stale_blocked=${summary.blocked_stale_automation} empty=${summary.empty_ledgers.length}) but PROGRESS.md has no unchecked owner matching ${ownerPattern}`
      );
    }

    return { ...summary, owner_count: owners.length, ok, track: TRACK_LABELS[platform] };
  });

  const siblingMd = siblingMdLedgers();
  if (siblingMd.length > 0) {
    errors.push(
      `sibling .md ledgers must be deleted (JSON is sole owner): ${siblingMd.join(", ")}`
    );
  }

  for (const message of historicalOverclaimErrors(progress)) {
    errors.push(message);
  }
  for (const message of forbiddenAutomationClaimErrors()) {
    errors.push(message);
  }
  for (const message of readmeRouteErrors()) {
    errors.push(message);
  }
  for (const message of contextRoutingErrors()) {
    errors.push(message);
  }

  if (goalStatus === "completed" && errors.length > 0) {
    errors.push("goal.json status is completed but ledger ↔ PROGRESS ownership still fails");
  }

  const openTracks = platforms.filter((p) => p.actionable > 0).map((p) => p.track);

  return {
    platforms,
    sibling_md: siblingMd,
    open_tracks: openTracks,
    ok: errors.length === 0,
    errors
  };
}

function formatGoalNextLines(report = ownershipReport()) {
  const lines = report.platforms.map((p) => {
    return `ledger_${p.platform}: actionable=${p.actionable} fail=${p.fail} pending=${p.pending} stale_pass=${p.stale_pass || 0} stale_blocked=${p.blocked_stale_automation} empty=${p.empty_ledgers.length} owners=${p.owner_count} ok=${p.ok ? "yes" : "no"}`;
  });
  lines.push(
    `open_tracks: ${report.open_tracks.length ? report.open_tracks.join(",") : "none"}`
  );
  if (report.sibling_md.length > 0) {
    lines.push(`sibling_md_ledgers: ${report.sibling_md.join(",")}`);
  }
  return lines;
}

module.exports = {
  PLATFORM_OWNERS,
  TRACK_LABELS,
  ownershipReport,
  summarizePlatform,
  formatGoalNextLines,
  siblingMdLedgers,
  contextRoutingErrors,
  readProgress,
  uncheckedLines
};
