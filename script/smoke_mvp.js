#!/usr/bin/env node
const assert = require("node:assert/strict");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "likeminded-mvp-"));
const port = String(19000 + Math.floor(Math.random() * 1000));
const baseURL = `http://127.0.0.1:${port}`;

const child = spawn(process.execPath, ["services/api/src/server.js"], {
  cwd: root,
  env: {
    ...process.env,
    PORT: port,
    HOST: "127.0.0.1",
    LIKEMINDED_DB_DIR: tmp,
    SESSION_SECRET: "local-smoke-secret-minimum-24-chars",
    APPLE_AUTH_BYPASS: "1",
    OPENAI_REALTIME_MODEL: "gpt-realtime-1.5",
    OPENAI_REALTIME_VOICE: "marin"
  },
  stdio: ["ignore", "pipe", "pipe"]
});

let output = "";
child.stdout.on("data", (chunk) => { output += chunk.toString(); });
child.stderr.on("data", (chunk) => { output += chunk.toString(); });

function stop() {
  child.kill("SIGTERM");
  fs.rmSync(tmp, { recursive: true, force: true });
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
  return { response, body };
}

async function waitForHealth() {
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    try {
      const { response, body } = await request("/health");
      if (response.status === 200 && body.status === "ok") return body;
    } catch {
      // Server is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error(`API did not become healthy:\n${output}`);
}

async function expectStatus(status, pathname, options) {
  const result = await request(pathname, options);
  assert.equal(result.response.status, status, `${pathname} expected ${status}, got ${result.response.status}: ${JSON.stringify(result.body)}`);
  return result.body;
}

(async () => {
  try {
    const health = await waitForHealth();
    assert.equal(health.db, "sqlite");

    await expectStatus(401, "/v1/discover", { method: "POST", body: {} });
    await expectStatus(401, "/v1/realtime/session", { method: "POST", body: {} });
    await expectStatus(401, "/v1/me/profile", { method: "GET" });
    await expectStatus(401, "/v1/me/placement", { method: "GET" });
    await expectStatus(401, "/v1/feedback", { method: "POST", body: { rating: 4, message: "blocked" } });

    const auth = await expectStatus(200, "/v1/auth/apple", {
      method: "POST",
      body: { identityToken: "tester-one", fullName: "Tester One" }
    });
    assert.ok(auth.sessionToken, "auth must return a session token");
    assert.ok(auth.user.id, "auth must return a user id");

    const transcript = "I like honest conversations, thoughtful friends, small warm circles, design, books, and steady trust.";
    const discovered = await expectStatus(200, "/v1/discover", {
      method: "POST",
      token: auth.sessionToken,
      body: { interviewTranscript: transcript, reflectionAnswers: ["I want a calm circle", "I prefer warm direct people"] }
    });
    assert.ok(discovered.profileId, "discover must return profileId");
    assert.ok(discovered.placement?.primaryCircle?.id, "discover must return a primary circle");

    const profile = await expectStatus(200, "/v1/me/profile", { method: "GET", token: auth.sessionToken });
    assert.equal(profile.profile.profileId, discovered.profileId);

    const placement = await expectStatus(200, "/v1/me/placement", { method: "GET", token: auth.sessionToken });
    assert.equal(placement.profileId, discovered.profileId);
    assert.ok(placement.placementId, "resume placement must include placementId");

    const accepted = await expectStatus(200, "/v1/me/placement/actions", {
      method: "POST",
      token: auth.sessionToken,
      body: { action: "accept" }
    });
    assert.equal(accepted.placement.userState, "accepted");

    await expectStatus(201, "/v1/feedback", {
      method: "POST",
      token: auth.sessionToken,
      body: {
        profileId: discovered.profileId,
        placementId: placement.placementId,
        rating: 5,
        message: "Placement loop works.",
        appVersion: "0.1.0"
      }
    });

    const secondAuth = await expectStatus(200, "/v1/auth/apple", {
      method: "POST",
      body: { identityToken: "tester-two", fullName: "Tester Two" }
    });
    await expectStatus(404, "/v1/me/placement", { method: "GET", token: secondAuth.sessionToken });

    console.log("MVP smoke passed");
  } finally {
    stop();
  }
})().catch((error) => {
  stop();
  console.error(error.stack || error.message);
  process.exit(1);
});
