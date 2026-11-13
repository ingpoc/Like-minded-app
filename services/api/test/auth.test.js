const assert = require("node:assert/strict");
const test = require("node:test");
const crypto = require("node:crypto");

const {
  appleAudiences,
  verifyNonce,
  verifyAppleIdentityToken,
  createSessionToken,
  verifySessionToken,
  parseJwt
} = require("../src/lib/auth");

const originalEnv = { ...process.env };

test.afterEach(() => {
  process.env = { ...originalEnv };
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
