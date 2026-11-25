// Black-box tests for the non-auth API surface: health, docs, catalogue reads, profile synthesis,
// auth guards and error shapes. Runs the real server on a free port with a throwaway local store.
const assert = require("node:assert/strict");
const test = require("node:test");
const { startApi } = require("./helpers/api-server");

const ARCHETYPES = ["reflective-builders", "gentle-romantics", "longform-thinkers", "bold-explorers", "grounded-nurturers"];
let api;

test.before(async () => { api = await startApi(); });
test.after(async () => { await api.stop(); });

test("health reports the local store and no configured integrations", async () => {
  const { status, body } = await api.request("/health");
  assert.equal(status, 200);
  assert.equal(body.status, "ok");
  assert.equal(body.service, "likeminded-api");
  assert.equal(body.db, "local-json");
  assert.equal(body.livekit, false);
});

test("privacy policy is served as HTML", async () => {
  const { status, headers, text } = await api.request("/privacy");
  assert.equal(status, 200);
  assert.match(headers.get("content-type") || "", /^text\/html/);
  assert.match(text, /Privacy Policy/);
});

test("unknown routes return a JSON not_found error", async () => {
  const { status, headers, body } = await api.request("/v1/nothing-here");
  assert.equal(status, 404);
  assert.match(headers.get("content-type") || "", /application\/json/);
  assert.equal(body.error, "not_found");
});

test("system architecture is readable without auth", async () => {
  const { status, body } = await api.request("/v1/system/architecture");
  assert.equal(status, 200);
  assert.equal(body.service, "likeminded-api");
  assert.ok(body.architecture && typeof body.architecture === "object");
});

test("circles list contains the five seeded archetypes", async () => {
  const { status, body } = await api.request("/v1/circles");
  assert.equal(status, 200);
  const ids = body.circles.map(circle => circle.id);
  for (const id of ARCHETYPES) assert.ok(ids.includes(id), `missing archetype ${id}`);
  for (const circle of body.circles) {
    assert.equal(typeof circle.name, "string");
    assert.equal(typeof circle.membersCount, "number");
  }
});

test("circle detail returns a known circle and 404s an unknown one", async () => {
  const known = await api.request(`/v1/circles/${ARCHETYPES[0]}`);
  assert.equal(known.status, 200);
  assert.equal(known.body.circle.id, ARCHETYPES[0]);
  const missing = await api.request("/v1/circles/no-such-circle");
  assert.equal(missing.status, 404);
  assert.equal(missing.body.error, "circle_not_found");
});

test("a created profile can be read back with a placement", async () => {
  const created = await api.request("/v1/profiles", {
    method: "POST",
    body: { interviewTranscript: "I love long hikes, building side projects and quiet dinners.", reflectionAnswers: ["I open up slowly"] }
  });
  assert.equal(created.status, 201);
  const profileId = created.body.profile.profileId;
  assert.equal(typeof profileId, "string");
  assert.ok(created.body.profile.signals);

  const read = await api.request(`/v1/profiles/${encodeURIComponent(profileId)}`);
  assert.equal(read.status, 200);
  assert.equal(read.body.profile.profileId, profileId);
  assert.ok(read.body.placement, "placement is returned with the profile");
});

test("unknown profile ids return profile_not_found", async () => {
  const { status, body } = await api.request("/v1/profiles/does-not-exist");
  assert.equal(status, 404);
  assert.equal(body.error, "profile_not_found");
});

test("profile synthesis rejects malformed JSON and accepts a summary", async () => {
  const bad = await api.request("/v1/profiles/synthesize", { method: "POST", rawBody: "{oops" });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, "invalid_json");

  const good = await api.request("/v1/profiles/synthesize", { method: "POST", body: { promptSummary: "Calm and curious." } });
  assert.equal(good.status, 200);
  assert.equal(good.body.profile.reflection.summary, "Calm and curious.");
  assert.ok(good.body.placement);
});

test("member-only routes refuse anonymous and forged sessions", async () => {
  const routes = [
    ["GET", "/v1/me/profile"],
    ["GET", "/v1/me/placement"],
    ["GET", "/v1/me/circles"],
    ["GET", "/v1/me/notifications"],
    ["GET", "/v1/me/soulmate/status"],
    ["POST", "/v1/discover"],
    ["POST", "/v1/feedback"]
  ];
  for (const [method, path] of routes) {
    const anonymous = await api.request(path, { method, body: method === "POST" ? {} : undefined });
    assert.equal(anonymous.status, 401, `${method} ${path} anonymous`);
    const forged = await api.request(path, { method, token: "not-a-real-session", body: method === "POST" ? {} : undefined });
    assert.equal(forged.status, 401, `${method} ${path} forged token`);
  }
});

test("unknown device ids return device_not_found", async () => {
  const { status, body } = await api.request("/v1/devices/unknown-device/profiles");
  assert.equal(status, 404);
  assert.equal(body.error, "device_not_found");
});
