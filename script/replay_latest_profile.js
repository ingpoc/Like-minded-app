#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const baseURL = process.env.LIKEMINDED_API_BASE_URL || "http://127.0.0.1:8787";
const storePath = path.resolve(process.env.LIKEMINDED_DB_DIR || "data", "mvp-store.json");
const outputPath = path.resolve("output/validation/replay_latest_profile.json");
const sourceProfileId = process.env.REPLAY_SOURCE_PROFILE_ID || null;
const targetIdentityToken = process.env.REPLAY_IDENTITY_TOKEN || "replay-latest-profile";
const targetFullName = process.env.REPLAY_FULL_NAME || "Replay Latest Profile";

function latest(rows) {
  return [...rows].sort((a, b) => String(a.created_at).localeCompare(String(b.created_at))).at(-1);
}

async function request(pathname, options = {}) {
  const response = await fetch(`${baseURL}${pathname}`, {
    ...options,
    headers: {
      ...(options.body ? { "content-type": "application/json" } : {}),
      ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
      ...(options.headers || {})
    },
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  return { response, body };
}

(async () => {
  assert.ok(fs.existsSync(storePath), `Missing store: ${storePath}`);
  const store = JSON.parse(fs.readFileSync(storePath, "utf8"));
  const sourceProfile = sourceProfileId
    ? (store.profiles || []).find((profile) => profile.id === sourceProfileId)
    : latest(store.profiles || []);
  assert.ok(sourceProfile, "No saved profile to replay");
  const sourcePlacement = latest((store.placements || []).filter((row) => row.profile_id === sourceProfile.id));
  assert.ok(sourcePlacement, `No saved placement for ${sourceProfile.id}`);
  const sourceTranscript = latest((store.transcripts || []).filter((row) => row.profile_id === sourceProfile.id));

  const payload = {
    interviewTranscript: sourceTranscript?.content || sourceProfile.data?.sourceInput?.interviewExcerpt || "",
    signals: sourceProfile.data.signals,
    primaryCircleId: sourcePlacement.data.primaryCircle.id,
    secondaryCircleIds: (sourcePlacement.data.secondaryCircles || []).map((circle) => circle.id),
    fitReasons: sourcePlacement.data.fitReasons || [],
    sourceReflectionSignals: sourcePlacement.data.sourceReflectionSignals || [],
    confidenceLabel: sourcePlacement.data.confidenceLabel || "Replayed profile",
    profileSummary: sourceProfile.data.profileSummary || ""
  };

  const health = await request("/health");
  assert.equal(health.response.status, 200, `API must be running at ${baseURL}`);

  const auth = await request("/v1/auth/apple", {
    method: "POST",
    body: { identityToken: targetIdentityToken, fullName: targetFullName }
  });
  assert.equal(auth.response.status, 200, `auth failed ${JSON.stringify(auth.body)}`);

  const replayed = await request("/v1/realtime/profile-placement", {
    method: "POST",
    token: auth.body.sessionToken,
    body: payload
  });
  assert.equal(replayed.response.status, 201, `replay failed ${JSON.stringify(replayed.body)}`);

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify({ sourceProfileId: sourceProfile.id, payload, replayed: replayed.body }, null, 2));
  console.log(JSON.stringify({
    sourceProfileId: sourceProfile.id,
    replayedProfileId: replayed.body.profileId,
    circle: replayed.body.placement.primaryCircle.name,
    outputPath
  }));
})().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
