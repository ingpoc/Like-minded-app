#!/usr/bin/env node
/**
 * Grader: optimization registry + transcript discovery health.
 * Fails on structural issues; warns on cloud/Linux without local transcripts.
 */
const path = require("node:path");
const lib = require("./lib/optimization_validate_lib");

const root = path.resolve(__dirname, "..");
const REGISTRY_PATH = path.join(root, "session", "optimization-registry.json");
const STALE_PENDING_DAYS = Number(process.env.OPTIMIZATION_STALE_DAYS || "14");
const requireTranscripts = process.env.LIKEMINDED_REQUIRE_TRANSCRIPTS === "1";

function daysSince(iso) {
  if (!iso) return null;
  return (Date.now() - Date.parse(iso)) / (1000 * 60 * 60 * 24);
}

function fail(msg) {
  console.error(`verify:optimization FAIL — ${msg}`);
  process.exit(1);
}

function warn(msg) {
  console.warn(`verify:optimization WARN — ${msg}`);
}

function main() {
  const reg = lib.readRegistry(REGISTRY_PATH);
  if (!reg.schema_version) fail("session/optimization-registry.json missing schema_version");
  if (!Array.isArray(reg.optimizations)) fail("optimizations must be an array");

  const { roots, resolved, hint } = lib.resolveTranscriptRoots(root);
  if (!resolved) {
    const msg = hint || "no transcript roots";
    if (requireTranscripts) fail(msg);
    warn(`${msg} (skipped — set LIKEMINDED_REQUIRE_TRANSCRIPTS=1 to fail)`);
  } else {
    console.log(`verify:optimization: transcript roots=${roots.length}`);
  }

  const pending = reg.optimizations.filter((o) => !o.validated_at);
  if (pending.length > 1) {
    fail(`multiple pending optimizations (${pending.length}) — validate or --replace before next record`);
  }

  for (const opt of pending) {
    const age = daysSince(opt.recorded_at);
    if (age !== null && age > STALE_PENDING_DAYS) {
      warn(
        `pending optimization ${opt.id} is ${Math.floor(age)}d old — run npm run optimization:validate -- --mode after`
      );
    }
    if (!opt.anchor_session_id) {
      warn(`${opt.id}: anchor_session_id unset — after-window uses recorded_at only`);
    }
    if (!opt.baseline_validation?.verdict) {
      warn(`${opt.id}: no baseline_validation — after verdict has lower confidence`);
    }
  }

  const scriptPath = path.join(root, "script/lib/optimization_validate_lib.js");
  try {
    require(scriptPath);
  } catch (e) {
    fail(`optimization_validate_lib load failed: ${e.message}`);
  }

  console.log("verify:optimization OK");
}

main();
