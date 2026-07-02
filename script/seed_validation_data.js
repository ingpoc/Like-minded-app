#!/usr/bin/env node
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const action = process.argv.find((arg) => ["seed", "remove", "reset"].includes(arg)) || "seed";
const showToken = process.argv.includes("--show-token");
const root = path.resolve(__dirname, "..");
const dbDir = path.resolve(process.env.LIKEMINDED_DB_DIR || path.join(root, "data"));
const mvpStorePath = path.join(dbDir, "mvp-store.json");
const architectureStorePath = path.join(dbDir, "likeminded.json");
const baseURL = process.env.LIKEMINDED_API_BASE_URL || "http://127.0.0.1:8787";

const people = [
  ["priya", "Priya Shah", "female", ["Jazz", "Design", "Cooking"], "Reflective host energy, warm direct speech, steady trust."],
  ["marco", "Marco D'Souza", "male", ["Jazz", "Film", "Startups"], "Playful host, inclusive, good at drawing quiet people in."],
  ["ananya", "Ananya Rao", "female", ["Books", "Psychology", "Writing"], "Thoughtful listener, slow trust, low-pressure conversation."],
  ["rohan", "Rohan Mehta", "male", ["Trekking", "Startups", "Design"], "Energetic builder, curious, comfortable with momentum."],
  ["meera", "Meera Iyer", "female", ["Poetry", "Film", "Travel"], "Tender, expressive, emotionally careful and direct."],
  ["arjun", "Arjun Nair", "male", ["Books", "Music", "Cooking"], "Calm, analytical, grounded, likes small rooms."]
];

function userIdForSeed(seedId) {
  const appleSub = `dev-${crypto.createHash("sha256").update(`validation-${seedId}`).digest("hex").slice(0, 16)}`;
  return `usr_${crypto.createHash("sha256").update(appleSub).digest("hex").slice(0, 24)}`;
}

function seededUserIds() {
  return people.map(([seedId]) => userIdForSeed(seedId));
}

function readJson(file, fallback) {
  if (!fs.existsSync(file)) return fallback;
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function removeLocalValidationData() {
  assert.ok(!process.env.DATABASE_URL, "remove is local-only; refusing to modify DATABASE_URL data");
  const ids = new Set(seededUserIds());
  const mvp = readJson(mvpStorePath, null);
  const architecture = readJson(architectureStorePath, null);
  let removed = 0;

  if (mvp) {
    for (const [id, user] of Object.entries(mvp.users || {})) {
      if (ids.has(id) || String(user.apple_sub || "").startsWith("dev-")) {
        if (ids.has(id)) {
          delete mvp.users[id];
          removed += 1;
        }
      }
    }
    mvp.profiles = (mvp.profiles || []).filter((row) => !ids.has(row.user_id));
    mvp.placements = (mvp.placements || []).filter((row) => !ids.has(row.user_id));
    mvp.transcripts = (mvp.transcripts || []).filter((row) => !ids.has(row.user_id));
    mvp.feedback = (mvp.feedback || []).filter((row) => !ids.has(row.user_id));
    mvp.communityMemberships = (mvp.communityMemberships || []).filter((row) => !ids.has(row.user_id));
    mvp.meetingRsvps = (mvp.meetingRsvps || []).filter((row) => !ids.has(row.user_id));
    mvp.meetings = (mvp.meetings || []).filter((row) => !(row.participantIds || []).some((id) => ids.has(id)));
    mvp.soulmateUsers = Object.fromEntries(Object.entries(mvp.soulmateUsers || {}).filter(([id]) => !ids.has(id)));
    mvp.soulmateSelections = (mvp.soulmateSelections || []).filter((row) => !ids.has(row.userId));
    const keptMatches = new Set();
    mvp.soulmateMatches = (mvp.soulmateMatches || []).filter((row) => {
      const keep = !ids.has(row.userAId) && !ids.has(row.userBId);
      if (keep) keptMatches.add(row.id);
      return keep;
    });
    mvp.chatMessages = (mvp.chatMessages || []).filter((row) => keptMatches.has(row.matchId));
    writeJson(mvpStorePath, mvp);
  }

  if (architecture) {
    for (const collection of ["circles", "communities"]) {
      for (const item of Object.values(architecture[collection] || {})) {
        item.members = (item.members || []).filter((id) => !ids.has(id));
      }
    }
    architecture.profiles = Object.fromEntries(Object.entries(architecture.profiles || {}).filter(([, row]) => !ids.has(row.userId)));
    architecture.placements = (architecture.placements || []).filter((row) => !ids.has(row.userId));
    architecture.transcripts = (architecture.transcripts || []).filter((row) => !ids.has(row.userId));
    writeJson(architectureStorePath, architecture);
  }

  console.log(JSON.stringify({ action: "remove", dbDir, removedSeedUsers: removed }, null, 2));
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
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  assert.ok(response.status >= 200 && response.status < 300, `${options.method || "GET"} ${pathname} failed: ${response.status} ${text}`);
  return body;
}

function profileFor(index, [id, name, gender, interests, summary]) {
  return {
    interviewTranscript: `${name}: ${summary} I want real weekend conversations, not passive browsing.`,
    signals: {
      bigFive: { openness: 0.82, conscientiousness: 0.72, extraversion: index % 2 ? 0.58 : 0.42, agreeableness: 0.83, neuroticism: 0.28 },
      attachment: "secure",
      socialEnergy: index % 2 ? "medium" : "low-to-medium",
      communicationStyle: { primary: index % 2 ? "warm" : "direct", pace: 0.48 },
      trustPattern: index % 2 ? "fastTrust" : "slowTrust",
      humorStyle: "observational",
      conflictStyle: "analytical"
    },
    basicInfo: { name, gender, dateOfBirth: "1996-01-01", city: "Bangalore", pincode: "560001" },
    interests: interests.map((label) => ({ label, depth: "active" })),
    hiddenSignals: { shyness: 0.35, languageComfort: 0.9, warmth: 0.86, vulnerabilityOpenness: 0.74, dominanceTendency: 0.24, energyTrajectory: "warms_up" },
    primaryCircleId: index === 4 ? "gentle-romantics" : "reflective-builders",
    secondaryCircleIds: ["longform-thinkers"],
    fitReasons: ["Prefers small rooms.", "Shows warm, steady trust.", "Can contribute without dominating."],
    sourceReflectionSignals: [summary],
    profileSummary: summary
  };
}

async function seedValidationData() {
  await request("/health");
  const users = [];

  for (let index = 0; index < people.length; index += 1) {
    const person = people[index];
    const auth = await request("/v1/auth/apple", {
      method: "POST",
      body: { identityToken: `validation-${person[0]}`, fullName: person[1] }
    });
    await request("/v1/realtime/profile-placement", {
      method: "POST",
      token: auth.sessionToken,
      body: profileFor(index, person)
    });
    await request("/v1/communities/jazz-music/join", { method: "POST", token: auth.sessionToken });
    if (index < 3) await request("/v1/communities/creative-writing/join", { method: "POST", token: auth.sessionToken });
    await request("/v1/meetings/rsvp", { method: "POST", token: auth.sessionToken, body: { kind: "community", available: true } });
    await request("/v1/meetings/rsvp", { method: "POST", token: auth.sessionToken, body: { kind: "circle", available: true } });
    await request("/v1/me/soulmate/enable", { method: "POST", token: auth.sessionToken, body: { enabled: true } });
    users.push({ id: auth.user.id, name: person[1], sessionToken: auth.sessionToken });
  }

  const scheduled = await request("/v1/admin/run-scheduling", { method: "POST" });
  const upcoming = await request("/v1/meetings/upcoming", { token: users[0].sessionToken });
  const meetingId = upcoming.upcoming[0]?.id || scheduled.meetings[0]?.id;
  assert.ok(meetingId, "expected at least one seeded meeting");

  await request("/v1/me/soulmate/select", { method: "POST", token: users[0].sessionToken, body: { meetingId, selectedUserIds: [users[1].id] } });
  await request("/v1/me/soulmate/select", { method: "POST", token: users[1].sessionToken, body: { meetingId, selectedUserIds: [users[0].id] } });
  const matches = await request("/v1/me/soulmate/matches", { token: users[0].sessionToken });
  assert.ok(matches.length > 0, "expected seeded soulmate match");
  await request(`/v1/me/soulmate/matches/${matches[0].matchId}/messages`, {
    method: "POST",
    token: users[0].sessionToken,
    body: { text: "Loved the listening session. Want to compare notes tomorrow?" }
  });

  console.log(JSON.stringify({
    action: "seed",
    baseURL,
    primaryUser: showToken ? users[0] : { id: users[0].id, name: users[0].name },
    meetingId,
    matchId: matches[0].matchId,
    users: users.map(({ id, name }) => ({ id, name }))
  }, null, 2));
}

(async () => {
  if (action === "remove") {
    removeLocalValidationData();
    return;
  }
  if (action === "reset") removeLocalValidationData();
  await seedValidationData();
})().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
