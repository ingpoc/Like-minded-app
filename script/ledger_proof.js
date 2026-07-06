#!/usr/bin/env node
/**
 * Proof tiers, agent packets, and production-contract helpers (schema v2).
 */
const fs = require("node:fs");
const path = require("node:path");
const { root, flowSuccessCriteria } = require("./ledger_hash");
const {
  listScreenFiles,
  loadScreenFile,
  hashPlatformSlice,
  isFlowStale,
  flowValidation
} = require("./ledger_screens");
const { logicalIdFromScreenArg, macScreenForLogical } = require("./ios_screen_stamp_map");

const CONTRACT_PATH = path.join(root, "validation", "production-contract.json");

const TIER_RANK = {
  "blocked-infra": 0,
  capture: 1,
  "cua-click": 2,
  "api-persist": 3,
  "real-auth": 4,
  "real-livekit": 4
};

const METHOD_RANK = {
  manual: 1,
  backfill: 1,
  "screen-capture": 1,
  capture: 1,
  "synced-from-controls": 2,
  cua: 2,
  "cua-click": 2,
  CUA: 2,
  "CUA-click": 2,
  reproof: 2,
  "api-persist": 3,
  smoke: 3,
  "real-auth": 4,
  testflight: 4,
  "real-livekit": 4,
  livekit: 4
};

const STANDARD_PRECONDITIONS = [
  "curl -s http://127.0.0.1:8787/health → dbPath contains validation-db",
  "LIKEMINDED_VALIDATION_USER=validation-gurusharan (dev-auth bypass unless flow tier is real-auth)"
];

function loadProductionContract(repoRoot = root) {
  const abs = path.join(repoRoot, "validation", "production-contract.json");
  if (!fs.existsSync(abs)) return null;
  return JSON.parse(fs.readFileSync(abs, "utf8"));
}

function tierRank(tier) {
  return TIER_RANK[String(tier || "cua-click").toLowerCase()] ?? 2;
}

function methodRank(method) {
  const key = String(method || "manual").toLowerCase();
  if (METHOD_RANK[method]) return METHOD_RANK[method];
  if (/cua/i.test(key)) return 2;
  if (/capture|screen-capture/i.test(key)) return 1;
  if (/api|smoke|persist/i.test(key)) return 3;
  if (/livekit/i.test(key)) return 4;
  if (/auth|testflight|apple/i.test(key)) return 4;
  return 1;
}

function satisfiesTier(method, tier) {
  if (tier === "blocked-infra") return true;
  return methodRank(method) >= tierRank(tier);
}

function inferProofTier(flow) {
  const id = String(flow.id || "").toLowerCase();
  if (/sign-in-apple|sign-in-google|sign-in-metamask|sign-in-solflare|alternate-auth/.test(id)) {
    return "real-auth";
  }
  if (/join-live|join-room|livekit|video-call/.test(id) && /join/.test(id)) {
    return "real-livekit";
  }
  const backend = flow.backend || [];
  if (backend.some((r) => /^(POST|PUT|PATCH|DELETE)\s/i.test(String(r)))) {
    return "api-persist";
  }
  if (/visual|parity|capture/.test(id)) {
    return "capture";
  }
  return "cua-click";
}

function inferSuccessSignals(flow, platform) {
  const steps = (flow.steps || []).filter(Boolean);
  if (steps.length) return steps.map((s) => `Step satisfied: ${s}`);
  const controls = flow.control_ids?.[platform] || [];
  if (controls.length) {
    return controls.map((id) => `Control ${id} responds without error and matches expected UI state`);
  }
  return [`User outcome achieved: ${flow.name || flow.id}`];
}

function defaultCommands(logicalId, platform, flowId) {
  if (platform === "ios") {
    return `./script/cross_platform_screen_validate.sh --screen ${logicalId} --platform ios`;
  }
  if (flowId) {
    return `./script/testing_ledger_prove_flow.sh --screen ${logicalId} --flow ${flowId}`;
  }
  const mac = macScreenForLogical(logicalId);
  if (mac) {
    return `./script/macos_cua_preflight.sh && ./script/macos_audit_prepare.sh ${mac} && ./script/macos_cua_screen.sh ${mac}`;
  }
  return `npm run ledger:screen -- --platform macos --screen ${logicalId} --section flows`;
}

function resolveRunCommands(logicalId, platform, proof, flowId) {
  const fresh = defaultCommands(logicalId, platform, flowId);
  const stored = proof.commands?.[platform];
  if (!stored) return fresh;
  if (
    platform === "macos" &&
    stored &&
    /ledger:screen/.test(stored) &&
    /testing_ledger_prove_flow|macos_cua|macos_audit/.test(fresh)
  ) {
    return fresh;
  }
  return stored;
}

function defaultRecordPass(logicalId, platform, flowId, tier) {
  const method =
    tier === "capture" ? "screen-capture" : tier === "cua-click" ? "CUA-click" : tier;
  return `npm run ledger:record-flow -- --platform ${platform} --screen ${logicalId} --flow ${flowId} --result pass --method ${method} --evidence "..."`;
}

function buildDefaultProof(flow, screenData, logicalId, platform) {
  const tier = inferProofTier(flow);
  const slice = screenData.platforms?.[platform] || {};
  return {
    tier,
    preconditions: [...STANDARD_PRECONDITIONS],
    success_signals: inferSuccessSignals(flow, platform),
    mockup_ref: null,
    mockup_note: slice.mockup_ref
      ? `Inherit platforms.${platform}.mockup_ref: ${slice.mockup_ref}`
      : "No mockup — functional proof only",
    commands: {
      ios: defaultCommands(logicalId, "ios"),
      macos: defaultCommands(logicalId, "macos")
    },
    record_pass: `npm run ledger:record-flow -- --platform ${platform} --screen ${logicalId} --flow ${flow.id} --result pass --method <tier-method> --evidence "..."`
  };
}

function resolveMockupRef(flow, screenData, platform) {
  if (flow.proof?.mockup_ref) return flow.proof.mockup_ref;
  return screenData.platforms?.[platform]?.mockup_ref || null;
}

function buildAgentPacket(screenData, flow, platform, logicalId) {
  const proof = flow.proof || buildDefaultProof(flow, screenData, logicalId, platform);
  const slice = screenData.platforms?.[platform] || {};
  const validation = flowValidation(flow, platform);
  const currentHash = hashPlatformSlice(screenData, platform);
  const stale =
    String(validation.result || "").toLowerCase() === "pass" &&
    isFlowStale(flow, platform, currentHash);

  return {
    schema: "ledger-flow-packet-v1",
    screen: logicalId,
    screen_title: screenData.screen,
    flow_id: flow.id,
    flow_name: flow.name,
    platform,
    result: validation.result || "pending",
    stale_pass: stale,
    proof_tier: proof.tier,
    method_meets_tier:
      validation.result !== "pass" ||
      satisfiesTier(validation.last_test_method, proof.tier),
    preconditions: proof.preconditions || STANDARD_PRECONDITIONS,
    success_signals: proof.success_signals || inferSuccessSignals(flow, platform),
    success_criteria: flowSuccessCriteria(flow, platform),
    mockup_ref: resolveMockupRef(flow, screenData, platform),
    mockup_note: proof.mockup_note || null,
    baseline_screenshot: slice.recent_screenshot_ref || null,
    proof_screenshot: validation.screenshot_ref || null,
    commands: resolveRunCommands(logicalId, platform, proof, flow.id),
    record_pass:
      proof.record_pass && proof.record_pass.includes(`--platform ${platform}`)
        ? proof.record_pass
        : defaultRecordPass(logicalId, platform, flow.id, proof.tier),
    source_hash: slice.source_hash || currentHash,
    tested_source_hash: validation.tested_source_hash || null,
    control_ids: flow.control_ids?.[platform] || [],
    backend: flow.backend || slice.backend_dependencies || []
  };
}

function findFlow(screenData, flowId) {
  return (screenData.flows || []).find((f) => f.id === flowId);
}

function validatePassTier(flow, platform, method, result) {
  if (String(result).toLowerCase() !== "pass") return { ok: true };
  const tier = flow.proof?.tier || inferProofTier(flow);
  if (satisfiesTier(method, tier)) return { ok: true, tier };
  return {
    ok: false,
    tier,
    method,
    message: `method "${method}" (rank ${methodRank(method)}) does not meet proof.tier "${tier}" (rank ${tierRank(tier)})`
  };
}

function auditProductionUi(contract, repoRoot = root) {
  const errors = [];
  const warnings = [];
  const inScope = new Set(contract?.in_scope_screens || []);

  for (const file of listScreenFiles(repoRoot)) {
    const { data, logicalId } = loadScreenFile(file, repoRoot);
    if (inScope.size && !inScope.has(logicalId)) continue;

    for (const flow of data.flows || []) {
      for (const platform of ["ios", "macos"]) {
        const ids = flow.control_ids?.[platform] || [];
        const v = flowValidation(flow, platform);
        const result = String(v.result || "pending").toLowerCase();
        if (!ids.length && result === "not-applicable") continue;

        if (["pending", "fail", ""].includes(result)) {
          errors.push(`${logicalId}/${flow.id} ${platform}: ${result || "pending"}`);
        } else if (result === "blocked") {
          const text = `${v.blocker || ""} ${flow.id}`.toLowerCase();
          const allowed = (contract?.allowed_blocked_reasons || []).some((code) =>
            text.includes(code.replace(/-/g, "")) || text.includes(code)
          );
          if (!allowed && !/apple|livekit|infra/i.test(text)) {
            warnings.push(`${logicalId}/${flow.id} ${platform}: blocked without known infra code`);
          }
        } else if (result === "pass") {
          const tier = flow.proof?.tier || inferProofTier(flow);
          if (!satisfiesTier(v.last_test_method, tier)) {
            errors.push(
              `${logicalId}/${flow.id} ${platform}: pass method "${v.last_test_method}" < tier "${tier}"`
            );
          }
          if (isFlowStale(flow, platform, hashPlatformSlice(data, platform, repoRoot))) {
            errors.push(`${logicalId}/${flow.id} ${platform}: stale-pass`);
          }
        }
      }
    }
  }

  return { errors, warnings };
}

module.exports = {
  CONTRACT_PATH,
  TIER_RANK,
  loadProductionContract,
  tierRank,
  methodRank,
  satisfiesTier,
  inferProofTier,
  inferSuccessSignals,
  buildDefaultProof,
  buildAgentPacket,
  findFlow,
  validatePassTier,
  auditProductionUi,
  defaultCommands
};
