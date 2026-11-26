const assert = require("node:assert/strict");
const test = require("node:test");
const crypto = require("node:crypto");
const { startApi } = require("./helpers/api-server");

const {
  AppleIdentityServiceError,
  appleAudiences,
  verifyNonce,
  verifyAppleIdentityToken,
  createSessionToken,
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
