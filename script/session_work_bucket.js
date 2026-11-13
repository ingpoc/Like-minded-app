#!/usr/bin/env node
/**
 * Single owner for "continue previous session" — maps dirty/stamped paths to
 * ledger screens, mockups, and one continue_command.
 *
 *   npm run session:work
 *   npm run session:stamp [-- --summary "…"]
 */
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { root, parseSourcePath, parseSourceHint } = require("./ledger_hash");
const { ownershipReport } = require("./ledger_progress");
const { listScreenFiles, loadScreenFile } = require("./ledger_screens");

const BUCKET_PATH = path.join(root, "session", "work-bucket.json");
const SCHEMA_VERSION = 1;
const SCREENSHOT_STOP_CONDITION = "Screenshot-compare vs mockup_ref before claiming pass.";
const STALE_PASS_STOP_CONDITION =
  `${SCREENSHOT_STOP_CONDITION} Do not start Phase 9 while macOS/iOS stale_pass tracks are open.`;

const MOCKUP_SCREEN_HINTS = [
  { re: /auth[-/]|welcome|login/i, screen: "auth" },
  { re: /meet/i, screen: "meet" },
  { re: /circle/i, screen: "circles" },
  { re: /communit/i, screen: "communities" },
  { re: /profile/i, screen: "profile" },
  { re: /chat/i, screen: "chat" },
  { re: /settings/i, screen: "settings" },
  { re: /onboard|voice|profile-setup/i, screen: "profile-setup" }
];

const SWIFT_SCREEN_HINTS = [
  { re: /AuthGate|authgate/i, screen: "auth" },
  { re: /MeetView|meetOverview|MeetVenue/i, screen: "meet" },
  { re: /Circles|circlesRoom/i, screen: "circles" },
  { re: /Communities/i, screen: "communities" },
  { re: /Profile/i, screen: "profile" },
  { re: /Chat/i, screen: "chat" },
  { re: /Settings/i, screen: "settings" },
  { re: /ConvergenceField/i, screen: "auth" }
];

function gitDirtyPaths() {
  try {
    const out = execFileSync("git", ["status", "--short"], { cwd: root, encoding: "utf8" }).trim();
    if (!out) return [];
    return out
      .split("\n")
      .map((line) => line.replace(/^\s*\S+\s+/, "").trim())
      .filter(Boolean);
  } catch {
    return [];
  }
}

function normalizeRel(relPath) {
  return String(relPath || "").replace(/\\/g, "/").replace(/^\.\//, "");
}

function buildLedgerIndex() {
  const byFile = new Map();
  const screens = new Map();

  for (const file of listScreenFiles()) {
    const { data, logicalId } = loadScreenFile(file);
    const entry = {
      screen_id: logicalId,
      screen_title: data.screen || logicalId,
      ledger: `validation/screens/${file}`,
      platforms: {}
    };

    for (const platform of ["ios", "macos"]) {
      const slice = data.platforms?.[platform];
      if (!slice) continue;
      entry.platforms[platform] = {
        mockup_ref: slice.mockup_ref || null,
        source_files: slice.source_files || []
      };
      for (const src of slice.source_files || []) {
        const rel = normalizeRel(parseSourcePath(src));
        if (!rel) continue;
        const list = byFile.get(rel) || [];
        list.push({ screen_id: logicalId, platform, screen_title: entry.screen_title, mockup_ref: slice.mockup_ref || null });
        byFile.set(rel, list);
      }
    }
    screens.set(logicalId, entry);
  }
  return { byFile, screens };
}

function hintScreen(relPath) {
  const base = path.basename(relPath);
  for (const { re, screen } of [...MOCKUP_SCREEN_HINTS, ...SWIFT_SCREEN_HINTS]) {
    if (re.test(relPath) || re.test(base)) return screen;
  }
  return null;
}

function classifyPaths(paths, index) {
  const scores = new Map();
  const dirtyFiles = [];
  const mockups = new Map();

  for (const raw of paths) {
    const rel = normalizeRel(raw);
    dirtyFiles.push(rel);

    if (rel.startsWith("mockups/")) {
      const hinted = hintScreen(rel);
      if (hinted) {
        const bucket = mockups.get(hinted) || new Set();
        bucket.add(rel);
        mockups.set(hinted, bucket);
        bump(scores, hinted, 2, "mockup");
      }
      continue;
    }

    const ledgerHits = index.byFile.get(rel) || [];
    for (const hit of ledgerHits) {
      bump(scores, hit.screen_id, 3, "ledger_source", hit.platform);
    }

    if (rel.includes("validation/screens/")) {
      const id = path.basename(rel, ".json");
      bump(scores, id, 4, "ledger_json");
    }

    const hinted = hintScreen(rel);
    if (hinted) bump(scores, hinted, 1, "path_hint");
  }

  return { scores, dirtyFiles, mockups };
}

function bump(scores, screenId, amount, kind, platform = null) {
  const current = scores.get(screenId) || {
    screen_id: screenId,
    score: 0,
    platforms: new Set(),
    reasons: new Set()
  };
  current.score += amount;
  current.reasons.add(kind);
  if (platform) current.platforms.add(platform);
  scores.set(screenId, current);
}

function platformFromPaths(paths) {
  let ios = 0;
  let macos = 0;
  let api = 0;
  for (const rel of paths) {
    if (/LikemindedMac|macos/i.test(rel)) macos += 1;
    if (/LikemindedApp|ios-macos\/Sources\/LikemindedApp/i.test(rel)) ios += 1;
    if (/services\/api|server\.js/i.test(rel)) api += 1;
    if (rel.startsWith("mockups/macos")) macos += 2;
    if (rel.startsWith("mockups/ios")) ios += 2;
  }
  if (macos > ios) return "macos";
  if (ios > macos) return "ios";
  return macos >= ios ? "macos" : "ios";
}

function surfaceFromScore(scoreEntry, index, mockupsForScreen) {
  const meta = index.screens.get(scoreEntry.screen_id);
  if (!meta) return null;
  const platforms = [...scoreEntry.platforms];
  const mockupRefs = {};
  for (const platform of ["ios", "macos"]) {
    const fromLedger = meta.platforms[platform]?.mockup_ref || null;
    const fromDirty = mockupsForScreen ? [...mockupsForScreen].find((m) => m.startsWith(`mockups/${platform}/`)) : null;
    mockupRefs[platform] = fromDirty || fromLedger;
  }
  return {
    screen_id: scoreEntry.screen_id,
    screen_title: meta.screen_title,
    ledger: meta.ledger,
    platforms: platforms.length ? platforms : ["ios", "macos"],
    mockups: mockupRefs,
    score: scoreEntry.score,
    reasons: [...scoreEntry.reasons]
  };
}

function continueCommand(surface, preferredPlatform) {
  const platform =
    preferredPlatform ||
    (surface.platforms.includes("macos") && !surface.platforms.includes("ios") ? "macos" : null) ||
    (surface.platforms.includes("ios") && !surface.platforms.includes("macos") ? "ios" : null) ||
    platformFromPaths(Object.values(surface.mockups || {}).filter(Boolean));
  return `npm run ledger:screen -- --platform ${platform} --screen ${surface.screen_id} --section route`;
}

function stopConditionForLedger(report) {
  const hasStalePass = (report?.platforms || []).some(
    (platform) => Number(platform.stale_pass || 0) > 0
  );
  return hasStalePass ? STALE_PASS_STOP_CONDITION : SCREENSHOT_STOP_CONDITION;
}

function inferBucket(paths, summary = null, forcedScreen = null, forcedPlatform = null) {
  const index = buildLedgerIndex();
  const { scores, dirtyFiles, mockups } = classifyPaths(paths, index);

  if (forcedScreen && index.screens.has(forcedScreen)) {
    bump(scores, forcedScreen, 10, "stamp_override");
  } else if (summary) {
    for (const { re, screen } of MOCKUP_SCREEN_HINTS) {
      if (re.test(summary) && index.screens.has(screen)) {
        bump(scores, screen, 5, "summary_hint");
      }
    }
  }

  const ranked = [...scores.values()].sort((a, b) => b.score - a.score);
  const surfaces = ranked
    .map((entry) => surfaceFromScore(entry, index, mockups.get(entry.screen_id)))
    .filter(Boolean);

  let primary = surfaces[0] || null;
  if (forcedScreen && index.screens.has(forcedScreen)) {
    const forced = surfaceFromScore(
      {
        screen_id: forcedScreen,
        score: 999,
        platforms: new Set(["ios", "macos"]),
        reasons: new Set(["stamp_override"])
      },
      index,
      mockups.get(forcedScreen)
    );
    if (forced) primary = forced;
  }
  const preferredPlatform = forcedPlatform || platformFromPaths(dirtyFiles);
  const autoSummary =
    summary ||
    (primary
      ? `${primary.screen_title} — align implementation vs ledger mockup_ref (${dirtyFiles.length} dirty path(s))`
      : dirtyFiles.length
        ? `Uncommitted work — classify ${dirtyFiles.length} dirty path(s) before expanding scope`
        : "No dirty paths — stamp or pick the next ledger screen");

  return {
    schema_version: SCHEMA_VERSION,
    updated_at: new Date().toISOString(),
    source: summary ? "session:stamp" : "dirty-infer",
    summary: autoSummary,
    primary_surface: primary,
    secondary_surfaces: surfaces.slice(1, 4),
    dirty_files: dirtyFiles.slice(0, 24),
    dirty_path_count: dirtyFiles.length,
    work_platform: preferredPlatform,
    continue_command: primary ? continueCommand(primary, preferredPlatform) : "npm run ledger:open"
  };
}

function readBucket() {
  if (!fs.existsSync(BUCKET_PATH)) return null;
  try {
    const bucket = JSON.parse(fs.readFileSync(BUCKET_PATH, "utf8"));
    delete bucket.stop_condition;
    return bucket;
  } catch {
    return null;
  }
}

function writeBucket(bucket) {
  fs.mkdirSync(path.dirname(BUCKET_PATH), { recursive: true });
  fs.writeFileSync(BUCKET_PATH, `${JSON.stringify(bucket, null, 2)}\n`);
  return BUCKET_PATH;
}

function mergeBuckets(stamped, inferred) {
  if (!stamped) return inferred;
  if (!inferred?.primary_surface) return stamped;

  const stampedId = stamped.primary_surface?.screen_id;
  const inferredId = inferred.primary_surface?.screen_id;
  const drift =
    stamped.source === "session:stamp"
      ? false
      : stampedId && inferredId && stampedId !== inferredId;

  return {
    ...stamped,
    updated_at: inferred.updated_at,
    source: drift ? "stamp+dirty-drift" : stamped.source || "stamp+dirty",
    primary_surface: drift ? inferred.primary_surface : stamped.primary_surface || inferred.primary_surface,
    secondary_surfaces: inferred.secondary_surfaces,
    dirty_files: inferred.dirty_files,
    dirty_path_count: inferred.dirty_path_count,
    continue_command: drift
      ? inferred.continue_command
      : stamped.continue_command || inferred.continue_command,
    work_drift: drift ? "yes" : "no",
    stamped_summary: stamped.summary,
    summary: drift
      ? `${stamped.summary} (dirty paths now point at ${inferred.primary_surface.screen_title})`
      : stamped.summary
  };
}

function findConceptMockup(screenId, platform) {
  const dir = path.join(root, "mockups", platform, "concepts");
  if (!fs.existsSync(dir)) return null;
  const needle = screenId.toLowerCase();
  const placementSurface = /circle|communit/.test(needle);
  const hit = fs
    .readdirSync(dir)
    .filter((f) => /\.(png|jpg|webp)$/i.test(f))
    .find(
      (f) =>
        f.toLowerCase().includes(needle) ||
        (placementSurface && f.toLowerCase().includes("placement"))
    );
  return hit ? `mockups/${platform}/concepts/${hit}` : null;
}

function macEntryForScreen(screenId, platform = "macos") {
  try {
    const { data } = loadScreenFile(screenId);
    const slice = data.platforms?.[platform];
    for (const src of slice?.source_files || []) {
      const hint = parseSourceHint(src);
      if (hint) return hint;
    }
    const notes = String(slice?.notes || "");
    const match = notes.match(/--mac-screen\s+(\w+)/);
    if (match) return match[1];
  } catch {
    /* ignore */
  }
  return screenId;
}

function enrichBucket(bucket) {
  if (!bucket?.primary_surface) return bucket;

  const screenId = bucket.primary_surface.screen_id;
  const platform =
    bucket.work_platform ||
    platformFromPaths(bucket.dirty_files || []) ||
    (bucket.continue_command?.includes("--platform ios") ? "ios" : "macos");

  let recentScreenshot = null;
  let plateMockup = bucket.primary_surface.mockups?.[platform] || null;
  try {
    const { data } = loadScreenFile(screenId);
    const slice = data.platforms?.[platform] || {};
    recentScreenshot = slice.recent_screenshot_ref || null;
    plateMockup = slice.mockup_ref || plateMockup;
  } catch {
    /* ignore */
  }

  const conceptMockup =
    findConceptMockup(screenId, platform) ||
    findConceptMockup(screenId, platform === "ios" ? "macos" : "ios");
  const referenceMockup = conceptMockup || plateMockup;
  const macEntry = macEntryForScreen(screenId, "macos");

  const proof_command =
    platform === "ios"
      ? `./script/cross_platform_screen_validate.sh --screen ${screenId} --platform ios`
      : `npm run testing:ledger-run -- --platform macos --screen ${screenId} --card-only; npm run dev:macos:validation -- ${macEntry}; prove with @Computer`;

  return {
    ...bucket,
    work_platform: platform,
    decisions: [],
    reference_mockup: referenceMockup,
    concept_mockup: conceptMockup,
    recent_screenshot: recentScreenshot,
    proof_command,
    compare_before_pass: referenceMockup
      ? `Capture then open side-by-side: ${recentScreenshot || "fresh capture"} vs ${referenceMockup}`
      : "Capture screenshot and compare to ledger mockup_ref before pass"
  };
}

function resolveBucket({ refreshFromDirty = true } = {}) {
  const stamped = readBucket();
  const dirty = gitDirtyPaths();
  let bucket;
  if (!refreshFromDirty || dirty.length === 0) {
    bucket = stamped || inferBucket([], "No stamped session — run npm run session:stamp at session end");
  } else {
    const inferred = inferBucket(dirty);
    bucket = mergeBuckets(stamped, inferred);
  }
  return enrichBucket(bucket);
}

function formatLines(bucket, { compact = false, ledger = null } = {}) {
  if (!bucket) return [];
  const stopCondition = stopConditionForLedger(ledger || ownershipReport());
  const lines = [];
  lines.push(compact ? "# Work bucket" : "# Work Bucket — continue previous session");
  if (bucket.summary) lines.push(`work_summary: ${bucket.summary}`);
  if (bucket.work_drift === "yes") lines.push("work_drift: yes");
  const primary = bucket.primary_surface;
  if (primary) {
    lines.push(`work_surface: ${primary.screen_id}`);
    lines.push(`work_screen: ${primary.screen_title}`);
    lines.push(`work_ledger: ${primary.ledger}`);
    if (bucket.work_platform) lines.push(`work_platform: ${bucket.work_platform}`);
    if (bucket.concept_mockup) lines.push(`work_concept_mockup: ${bucket.concept_mockup}`);
    else if (bucket.reference_mockup) lines.push(`work_reference_mockup: ${bucket.reference_mockup}`);
    if (primary.mockups?.ios) lines.push(`work_plate_ios: ${primary.mockups.ios}`);
    if (primary.mockups?.macos) lines.push(`work_plate_macos: ${primary.mockups.macos}`);
    if (bucket.recent_screenshot) lines.push(`work_last_capture: ${bucket.recent_screenshot}`);
  }
  for (const [index, decision] of (bucket.decisions || []).entries()) {
    lines.push(`work_decision_${index + 1}: ${decision.key} — ${decision.summary}`);
  }
  if (bucket.dirty_path_count) lines.push(`work_dirty_paths: ${bucket.dirty_path_count}`);
  if (bucket.continue_command) lines.push(`continue_command: ${bucket.continue_command}`);
  if (bucket.proof_command) lines.push(`proof_command: ${bucket.proof_command}`);
  if (bucket.compare_before_pass) lines.push(`compare_before_pass: ${bucket.compare_before_pass}`);
  if (!compact && stopCondition) lines.push(`stop_condition: ${stopCondition}`);
  return lines;
}

function autoStamp({ trigger = "hook" } = {}) {
  const existing = readBucket();
  const dirty = gitDirtyPaths();
  if (!dirty.length && !existing?.primary_surface) {
    return { written: null, bucket: existing, skipped: "no_dirty_no_bucket" };
  }

  const forcedScreen = existing?.primary_surface?.screen_id || null;
  const preserveSummary =
    existing?.summary && (existing.source === "session:stamp" || existing.source === "auto-stamp")
      ? existing.summary
      : null;

  let bucket = inferBucket(dirty, preserveSummary, forcedScreen);
  if (!bucket.primary_surface && existing?.primary_surface) {
    bucket.primary_surface = existing.primary_surface;
    bucket.continue_command = existing.continue_command || bucket.continue_command;
  }
  bucket = enrichBucket(bucket);
  bucket.source = preserveSummary && existing?.source === "session:stamp" ? "session:stamp" : "auto-stamp";
  bucket.auto_stamp_trigger = trigger;
  bucket.auto_stamped_at = new Date().toISOString();
  const written = writeBucket(bucket);
  return { written, bucket, skipped: null };
}

function stampFromArgv(argv) {
  const summaryIdx = argv.indexOf("--summary");
  const summary = summaryIdx >= 0 ? argv[summaryIdx + 1] : null;
  const screenIdx = argv.indexOf("--screen");
  const forcedScreen = screenIdx >= 0 ? argv[screenIdx + 1] : null;
  const platformIdx = argv.indexOf("--platform");
  const forcedPlatform = platformIdx >= 0 ? argv[platformIdx + 1] : null;
  if (forcedPlatform && !["ios", "macos"].includes(forcedPlatform)) {
    throw new Error(`--platform must be ios or macos, received: ${forcedPlatform}`);
  }
  const dirty = gitDirtyPaths();
  let bucket = inferBucket(dirty, summary, forcedScreen, forcedPlatform);
  bucket = enrichBucket(bucket);
  const written = writeBucket(bucket);
  return { written, bucket };
}

function shouldPreferContinue(bucket, dirtyCount) {
  if (!bucket?.primary_surface || !dirtyCount) return false;
  const productive = (bucket.dirty_files || []).some(
    (f) =>
      !f.startsWith("output/") &&
      !f.startsWith("docs/") &&
      !f.startsWith(".agents/") &&
      !f.startsWith("script/ledger_progress.js")
  );
  return productive && (bucket.primary_surface.score || 0) >= 1;
}

if (require.main === module) {
  const asJson = process.argv.includes("--json");
  const doStamp = process.argv.includes("--stamp");
  const doAuto = process.argv.includes("--auto");

  if (doAuto) {
    const triggerIdx = process.argv.indexOf("--trigger");
    const trigger = triggerIdx >= 0 ? process.argv[triggerIdx + 1] : "hook";
    const result = autoStamp({ trigger });
    if (asJson) {
      process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    } else if (result.skipped) {
      console.log(`session-stamp-auto: skipped (${result.skipped})`);
    } else {
      console.log(`session-stamp-auto: ${result.written} (${trigger})`);
    }
    process.exit(0);
  }

  if (doStamp) {
    const { written, bucket } = stampFromArgv(process.argv);
    if (asJson) {
      process.stdout.write(`${JSON.stringify({ path: written, bucket }, null, 2)}\n`);
    } else {
      console.log(`# Session stamped → ${written}`);
      for (const line of formatLines(bucket)) console.log(line);
    }
    process.exit(0);
  }

  const bucket = resolveBucket();
  if (asJson) {
    process.stdout.write(`${JSON.stringify(bucket, null, 2)}\n`);
    process.exit(0);
  }
  for (const line of formatLines(bucket)) console.log(line);
}

module.exports = {
  BUCKET_PATH,
  resolveBucket,
  readBucket,
  writeBucket,
  inferBucket,
  formatLines,
  stampFromArgv,
  autoStamp,
  shouldPreferContinue,
  enrichBucket,
  stopConditionForLedger,
  findConceptMockup,
  gitDirtyPaths
};
