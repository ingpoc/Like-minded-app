#!/usr/bin/env node
"use strict";

const { pickNextFlow } = require("./testing_ledger_pick_next");
const { loadScreenFile, hashPlatformSlice } = require("./ledger_screens");

function arg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

function sourcePath(value) {
  return String(value || "").replace(/\s+\([^)]*\)\s*$/, "");
}

function screenRoute(screen, platform, cache) {
  if (cache.has(screen)) return cache.get(screen);
  const { data } = loadScreenFile(screen);
  const slice = data.platforms?.[platform] || {};
  const route = {
    screen,
    source_hash: hashPlatformSlice(data, platform),
    source_files: (slice.source_files || []).map(sourcePath).filter(Boolean),
    entry_points: slice.entry_points || []
  };
  cache.set(screen, route);
  return route;
}

const platform = arg("--platform", "macos");
const requestedScreen = arg("--screen");
const requestedFlow = arg("--flow");
const requestedLimit = Number(arg("--limit", "10"));
const asJson = process.argv.includes("--json");

if (!["ios", "macos"].includes(platform) || !Number.isInteger(requestedLimit) || requestedLimit < 1 || requestedLimit > 12) {
  console.error("Usage: testing_ledger_batch_plan.js --platform ios|macos [--screen id] [--flow id] [--limit 1..12] [--json]");
  process.exit(2);
}

const { candidates } = pickNextFlow(platform);
const seed = candidates.find((candidate) =>
  (!requestedScreen || candidate.screen === requestedScreen)
    && (!requestedFlow || candidate.flow_id === requestedFlow)
);

if (!seed) {
  const empty = { schema: "testing-ledger-batch-plan-v1", status: "empty", platform, batch: [] };
  console.log(asJson ? JSON.stringify(empty, null, 2) : `testing-ledger-batch-plan: no eligible seed (${platform})`);
  process.exit(requestedScreen || requestedFlow ? 1 : 0);
}

const cache = new Map();
const seedRoute = screenRoute(seed.screen, platform, cache);
const seedFiles = new Set(seedRoute.source_files);
const compatible = candidates
  .map((candidate, queueIndex) => {
    const route = screenRoute(candidate.screen, platform, cache);
    const sharedSources = route.source_files.filter((file) => seedFiles.has(file));
    return { candidate, route, queueIndex, sharedSources };
  })
  .filter(({ candidate, sharedSources }) =>
    candidate.packet?.proof_tier === seed.packet?.proof_tier
      && (candidate.screen === seed.screen || sharedSources.length > 0)
  )
  .sort((a, b) => {
    if (a.candidate === seed) return -1;
    if (b.candidate === seed) return 1;
    if (a.candidate.screen === seed.screen && b.candidate.screen !== seed.screen) return -1;
    if (b.candidate.screen === seed.screen && a.candidate.screen !== seed.screen) return 1;
    return b.sharedSources.length - a.sharedSources.length || a.queueIndex - b.queueIndex;
  });

const selected = compatible.slice(0, requestedLimit);
const selectedKeys = new Set(selected.map(({ candidate }) => `${candidate.screen}/${candidate.flow_id}`));
const resume = candidates.find((candidate) => !selectedKeys.has(`${candidate.screen}/${candidate.flow_id}`)) || null;
const batchId = `${platform}-${seed.screen}-${String(seedRoute.source_hash || "unhashed").slice(0, 8)}`;

const output = {
  schema: "testing-ledger-batch-plan-v1",
  status: "ready",
  platform,
  batch_id: batchId,
  requested_limit: requestedLimit,
  selected_count: selected.length,
  seed: `${seed.screen}/${seed.flow_id}`,
  proof_tier: seed.packet?.proof_tier || null,
  source_files: [...new Set(selected.flatMap(({ route }) => route.source_files))],
  runtime_contract: {
    build_install: "once per unchanged source hash and runtime identity",
    flow_failure: "stop at first failed semantic postcondition; retain one compact artifact",
    evidence: "co-capture where possible; record each quality judgment independently"
  },
  batch: selected.map(({ candidate, route }) => ({
    screen: candidate.screen,
    flow_id: candidate.flow_id,
    result: candidate.result,
    last_tested_at: candidate.last_tested_at,
    coverage_reason: candidate.last_tested_at
      ? `${candidate.result}; last tested ${candidate.last_tested_at}`
      : `${candidate.result}; never tested`,
    source_hash: route.source_hash,
    prove: `npm run testing:ledger-run -- --platform ${platform} --screen ${candidate.screen} --flow ${candidate.flow_id}`
  })),
  resume_cursor: resume ? `${resume.screen}/${resume.flow_id}` : null
};

if (asJson) {
  console.log(JSON.stringify(output, null, 2));
} else {
  console.log(`# testing-ledger-batch-plan ${batchId}`);
  console.log(`platform: ${platform} | seed: ${output.seed} | tier: ${output.proof_tier}`);
  console.log(`selected: ${selected.length}/${requestedLimit} | resume: ${output.resume_cursor || "queue-empty"}`);
  console.log(`runtime: ${output.runtime_contract.build_install}`);
  for (const item of output.batch) console.log(`- ${item.screen}/${item.flow_id} (${item.result})`);
}
