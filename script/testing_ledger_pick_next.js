#!/usr/bin/env node
"use strict";

const {
  listScreenFiles,
  loadScreenFile,
  hashPlatformSlice,
  flowValidation,
  isFlowStale
} = require("./ledger_screens");
const {
  loadProductionContract,
  satisfiesTier,
  inferProofTier,
  buildAgentPacket,
  tierRank
} = require("./ledger_proof");
const { macScreenForLogical } = require("./ios_screen_stamp_map");

function flowPriority(flow, data, plat, includeBlocked = false, includePass = false) {
  const v = flowValidation(flow, plat);
  const result = String(v.result || "pending").toLowerCase();
  const ids = flow.control_ids?.[plat] || [];
  if (!ids.length && result === "not-applicable") return null;
  if (result === "blocked" && !includeBlocked) return null;
  const hash = hashPlatformSlice(data, plat);
  const tier = flow.proof?.tier || inferProofTier(flow);

  if (result === "fail") return { rank: 0, result };
  if (result === "pending" || result === "" || result === "untested") return { rank: 1, result };
  if (result === "pass" && isFlowStale(flow, plat, hash)) return { rank: 2, result: "stale-pass" };
  if (result === "pass" && !satisfiesTier(v.last_test_method, tier)) {
    return { rank: 3, result: "tier-gap" };
  }
  if (result === "pass" && includePass) return { rank: 4, result: "retest-ready" };
  if (result === "blocked" && includeBlocked) return { rank: 4, result };
  return null;
}

/** One flow per screen per round so auth cannot monopolize the queue. */
function testedAtValue(item) {
  const parsed = Date.parse(String(item.last_tested_at || ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

function interleaveByScreen(items) {
  const byScreen = new Map();
  for (const item of items) {
    if (!byScreen.has(item.screen)) byScreen.set(item.screen, []);
    byScreen.get(item.screen).push(item);
  }
  for (const arr of byScreen.values()) {
    arr.sort((a, b) => testedAtValue(a) - testedAtValue(b) || a.flow_id.localeCompare(b.flow_id));
  }
  const screens = [...byScreen.keys()].sort((a, b) => {
    const oldestA = Math.min(...byScreen.get(a).map(testedAtValue));
    const oldestB = Math.min(...byScreen.get(b).map(testedAtValue));
    return oldestA - oldestB || a.localeCompare(b);
  });
  const out = [];
  for (let depth = 0; ; depth++) {
    let added = false;
    for (const screen of screens) {
      const arr = byScreen.get(screen);
      if (depth < arr.length) {
        out.push(arr[depth]);
        added = true;
      }
    }
    if (!added) break;
  }
  return out;
}

/** Rank → provable tier → round-robin screen (not screen-id lex order). */
function sortCandidates(candidates) {
  const buckets = new Map();
  for (const c of candidates) {
    const tier = tierRank(c.packet?.proof_tier || inferProofTier({ id: c.flow_id }));
    const key = `${c.rank}:${tier}`;
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(c);
  }
  const keys = [...buckets.keys()].sort((a, b) => {
    const [ra, ta] = a.split(":").map(Number);
    const [rb, tb] = b.split(":").map(Number);
    return ra - rb || ta - tb;
  });
  const sorted = [];
  for (const key of keys) {
    sorted.push(...interleaveByScreen(buckets.get(key)));
  }
  return sorted;
}

function pickNextFlow(
  platform,
  { includeBlocked = false, includePass = false, screen = null, flowId = null } = {}
) {
  const contract = loadProductionContract();
  const inScope = new Set(contract?.in_scope_screens || []);
  const candidates = [];

  for (const file of listScreenFiles()) {
    const { data, logicalId } = loadScreenFile(file);
    if (screen && logicalId !== screen) continue;
    if (inScope.size && !inScope.has(logicalId)) continue;
    const slice = data.platforms?.[platform];
    if (!slice || slice.implemented === false) continue;

    for (const flow of data.flows || []) {
      if (flowId && flow.id !== flowId) continue;
      const pri = flowPriority(flow, data, platform, includeBlocked, includePass);
      if (!pri) continue;
      const validation = flowValidation(flow, platform);
      candidates.push({
        screen: logicalId,
        flow_id: flow.id,
        flow_name: flow.name,
        rank: pri.rank,
        result: pri.result,
        last_tested_at: validation.last_tested_at || null,
        tested_source_hash: validation.tested_source_hash || null,
        mac_screen: platform === "macos" ? macScreenForLogical(logicalId) : null,
        packet: buildAgentPacket(data, flow, platform, logicalId)
      });
    }
  }

  const sorted = sortCandidates(candidates);
  return { candidates: sorted, next: sorted[0] || null };
}

module.exports = { pickNextFlow, flowPriority, sortCandidates, interleaveByScreen, testedAtValue };
