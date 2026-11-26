const assert = require("node:assert/strict");
const test = require("node:test");
const { startApi } = require("./helpers/api-server");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const { createSessionToken } = require("../src/lib/auth");
const { encryptRefreshToken } = require("../src/lib/apple-token");

async function startProductionAppleDelete({ mode = "success", withToken = true } = {}) {
  const dbDir = fs.mkdtempSync(path.join(os.tmpdir(), "likeminded-prod-delete-"));
  const capture = path.join(dbDir, "revoke-requests.jsonl");
  const release = path.join(dbDir, "release");
  const secret = "local-test-secret-minimum-24-chars";
  const previousSecret = process.env.SESSION_SECRET;
  process.env.SESSION_SECRET = secret;
  const userId = `usr_${crypto.createHash("sha256").update("apple:production-delete-user").digest("hex").slice(0, 24)}`;
  const refreshToken = "seeded-refresh-token-for-revoke-test";
  const { privateKey } = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const user = {
    id: userId,
    apple_sub: "production-delete-user",
    google_sub: null,
    wallet_address: null,
    wallet_chain: null,
    auth_provider: "apple",
    email: "delete-test@example.invalid",
    full_name: "Delete Test",
    apple_refresh_token_ciphertext: withToken ? encryptRefreshToken(refreshToken, secret) : null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };
  fs.writeFileSync(path.join(dbDir, "mvp-store.json"), JSON.stringify({
    users: { [userId]: user },
    profiles: [{ id: "production-delete-profile", user_id: userId, data: { profileId: "production-delete-profile", userId }, created_at: new Date().toISOString() }]
  }));
  const token = createSessionToken({ id: userId, authProvider: "apple", appleSub: user.apple_sub });
  if (previousSecret === undefined) delete process.env.SESSION_SECRET;
  else process.env.SESSION_SECRET = previousSecret;
  const preload = path.join(__dirname, "helpers", "apple-revoke-fetch-stub.cjs");
  const api = await startApi({
    APPLE_AUTH_BYPASS: "0",
    APPLE_CLIENT_ID: "com.gurusharan.likeminded",
    APPLE_TEAM_ID: "TESTTEAM123",
    APPLE_KEY_ID: "TESTKEY1234",
    APPLE_PRIVATE_KEY: privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
    SESSION_SECRET: secret,
    LIKEMINDED_DB_DIR: dbDir,
    NODE_OPTIONS: `--require=${preload}`,
    APPLE_REVOKE_TEST_MODE: mode,
    APPLE_REVOKE_TEST_CAPTURE: capture,
    APPLE_REVOKE_TEST_RELEASE: release
  });
  return { api, dbDir, capture, release, refreshToken, token, userId };
}

async function waitForFile(pathname) {
  const until = Date.now() + 3000;
  while (!fs.existsSync(pathname) && Date.now() < until) await new Promise(resolve => setTimeout(resolve, 10));
  assert.ok(fs.existsSync(pathname), `expected file ${pathname}`);
}

function revokeRequests(capture) {
  return fs.existsSync(capture) ? fs.readFileSync(capture, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse) : [];
}

const {
  AppleIdentityServiceError,
  appleAudiences,
  verifyNonce,
  verifyAppleIdentityToken,
  verifySessionToken,
  parseJwt
} = require("../src/lib/auth");

const originalEnv = { ...process.env };
const originalFetch = global.fetch;

test.afterEach(() => {
  process.env = { ...originalEnv };
  global.fetch = originalFetch;
});

test("Apple key service outages are distinguishable from invalid identity proof", async () => {
  process.env.APPLE_AUTH_BYPASS = "0";
  process.env.APPLE_CLIENT_IDS = "com.gurusharan.likeminded";
  global.fetch = async () => { throw new Error("network unavailable"); };
  const header = Buffer.from(JSON.stringify({ alg: "RS256", kid: "missing-key" })).toString("base64url");
  const payload = Buffer.from(JSON.stringify({ aud: "com.gurusharan.likeminded" })).toString("base64url");
  await assert.rejects(
    () => verifyAppleIdentityToken(`${header}.${payload}.c2ln`),
    error => error instanceof AppleIdentityServiceError && error.code === "apple_identity_service_unavailable"
  );
});

test("appleAudiences merges bundle, client, and comma-separated ids", () => {
  process.env.APPLE_BUNDLE_ID = "com.gurusharan.likeminded";
  process.env.APPLE_CLIENT_ID = "com.gurusharan.likeminded";
  process.env.APPLE_MAC_BUNDLE_ID = "com.gurusharan.likeminded";
  process.env.APPLE_CLIENT_IDS = "com.gurusharan.likeminded";

  const audiences = appleAudiences();
  assert.equal(audiences.size, 1);
  assert.ok(audiences.has("com.gurusharan.likeminded"));
});

test("verifyNonce accepts matching sha256 hex nonce", () => {
  const rawNonce = "test-nonce-123";
  const tokenNonce = crypto.createHash("sha256").update(rawNonce).digest("hex");
  assert.doesNotThrow(() => verifyNonce(rawNonce, tokenNonce));
});

test("verifyNonce rejects mismatched nonce", () => {
  assert.throws(() => verifyNonce("raw", "deadbeef"), /apple_nonce_mismatch/);
});

test("verifyNonce can require client nonce in production mode", () => {
  assert.throws(() => verifyNonce(undefined, "abc", { requireNonce: true }), /nonce_required/);
});

test("verifyAppleIdentityToken bypass mode is deterministic per token", async () => {
  process.env.APPLE_AUTH_BYPASS = "1";
  const first = await verifyAppleIdentityToken("validation-gurusharan");
  const second = await verifyAppleIdentityToken("validation-gurusharan");
  assert.equal(first.sub, second.sub);
  assert.equal(first.email, "tester@likeminded.local");
});

test("verifyAppleIdentityToken requires audience config outside bypass", async () => {
  process.env.APPLE_AUTH_BYPASS = "0";
  delete process.env.APPLE_BUNDLE_ID;
  delete process.env.APPLE_CLIENT_ID;
  delete process.env.APPLE_CLIENT_IDS;
  delete process.env.APPLE_MAC_BUNDLE_ID;

  await assert.rejects(
    () => verifyAppleIdentityToken("not-a-real-token"),
    /APPLE_CLIENT_ID, APPLE_BUNDLE_ID, or APPLE_CLIENT_IDS must be set/
  );
});

test("account deletion without Apple proof deletes bypass account and revokes session", async () => {
  const api = await startApi({ APPLE_AUTH_BYPASS: "1", WALLETCONNECT_PROJECT_ID: "" });
  try {
    const signedIn = await api.request("/v1/auth/apple", {
      method: "POST",
      body: { identityToken: "lane1-delete-user", fullName: "Lane One" }
    });
    assert.equal(signedIn.status, 200);
    const token = signedIn.body.sessionToken;
    const deleted = await api.request("/v1/me/account", { method: "DELETE", token });
    assert.equal(deleted.status, 200);
    const staleSession = await api.request("/v1/me/profile", { token });
    assert.equal(staleSession.status, 401);
  } finally {
    await api.stop();
  }
});

test("wallet challenge returns unavailable when wallet auth is not configured", async () => {
  const api = await startApi({ WALLETCONNECT_PROJECT_ID: "", WALLET_AUTH_BYPASS: "0" });
  try {
    const result = await api.request("/v1/auth/wallet/challenge", {
      method: "POST",
      body: { wallet: "metamask", chain: "ethereum" }
    });
    assert.equal(result.status, 503);
    assert.equal(result.body.error, "wallet_auth_unavailable");
  } finally {
    await api.stop();
  }
});

test("production Apple deletion holds the account until one revoke request succeeds", async () => {
  const seeded = await startProductionAppleDelete({ mode: "hold" });
  try {
    const deleting = seeded.api.request("/v1/me/account", { method: "DELETE", token: seeded.token });
    await waitForFile(seeded.capture);
    const requests = revokeRequests(seeded.capture);
    assert.equal(requests.length, 1);
    assert.equal(requests[0].url, "https://appleid.apple.com/auth/revoke");
    assert.equal(new URLSearchParams(requests[0].body).get("token"), seeded.refreshToken);
    const stillSignedIn = await seeded.api.request("/v1/me/profile", { token: seeded.token });
    assert.equal(stillSignedIn.status, 200);
    fs.writeFileSync(seeded.release, "release");
    const deleted = await deleting;
    assert.equal(deleted.status, 200);
    assert.equal((await seeded.api.request("/v1/me/profile", { token: seeded.token })).status, 401);
    assert.equal(revokeRequests(seeded.capture).length, 1);
  } finally {
    await seeded.api.stop();
    fs.rmSync(seeded.dbDir, { recursive: true, force: true });
  }
});

test("production Apple deletion preserves account and session when revoke fails", async () => {
  const seeded = await startProductionAppleDelete({ mode: "failure" });
  try {
    const deleted = await seeded.api.request("/v1/me/account", { method: "DELETE", token: seeded.token });
    assert.equal(deleted.status, 502);
    const requests = revokeRequests(seeded.capture);
    assert.equal(requests.length, 1);
    assert.equal(new URLSearchParams(requests[0].body).get("token"), seeded.refreshToken);
    assert.equal((await seeded.api.request("/v1/me/profile", { token: seeded.token })).status, 200);
  } finally {
    await seeded.api.stop();
    fs.rmSync(seeded.dbDir, { recursive: true, force: true });
  }
});

test("production Apple deletion without stored token returns 409 without revoke", async () => {
  const seeded = await startProductionAppleDelete({ mode: "success", withToken: false });
  try {
    const deleted = await seeded.api.request("/v1/me/account", { method: "DELETE", token: seeded.token });
    assert.equal(deleted.status, 409);
    assert.equal(revokeRequests(seeded.capture).length, 0);
    assert.equal((await seeded.api.request("/v1/me/profile", { token: seeded.token })).status, 200);
  } finally {
    await seeded.api.stop();
    fs.rmSync(seeded.dbDir, { recursive: true, force: true });
  }
});

test("session tokens round-trip with SESSION_SECRET", () => {
  process.env.SESSION_SECRET = "local-smoke-secret-minimum-24-chars";
  const user = { id: "usr_test", appleSub: "apple-sub-1" };
  const token = createSessionToken(user);
  const payload = verifySessionToken(token);
  assert.equal(payload.sub, user.id);
  assert.equal(payload.appleSub, user.appleSub);
});

test("parseJwt rejects malformed tokens", () => {
  assert.throws(() => parseJwt("not-a-jwt"), /invalid_jwt/);
});
