const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  appleServerConfig,
  createClientSecret,
  exchangeAuthorizationCode,
  revokeRefreshToken,
  encryptRefreshToken,
  decryptRefreshToken
} = require("../src/lib/apple-token");

const { privateKey } = crypto.generateKeyPairSync("ec", { namedCurve: "P-256" });
const config = {
  teamId: "9UPQL479Z5",
  keyId: "TESTKEY123",
  clientId: "com.gurusharan.likeminded",
  privateKey: privateKey.export({ type: "pkcs8", format: "pem" })
};

test("client secret has the required Apple claims and ES256 signature", () => {
  const jwt = createClientSecret(config, 1000);
  const [header, payload, signature] = jwt.split(".");
  assert.deepEqual(JSON.parse(Buffer.from(header, "base64url")), { alg: "ES256", kid: config.keyId });
  assert.deepEqual(JSON.parse(Buffer.from(payload, "base64url")), {
    iss: config.teamId,
    iat: 1000,
    exp: 1300,
    aud: "https://appleid.apple.com",
    sub: config.clientId
  });
  assert.equal(Buffer.from(signature, "base64url").length, 64);
});

test("refresh tokens encrypt and decrypt with SESSION_SECRET", () => {
  const encrypted = encryptRefreshToken("refresh-token", "local-session-secret-minimum-24-chars");
  assert.notEqual(encrypted, "refresh-token");
  assert.equal(decryptRefreshToken(encrypted, "local-session-secret-minimum-24-chars"), "refresh-token");
  assert.throws(() => decryptRefreshToken(encrypted, "different-session-secret-24-chars"));
});

test("authorization codes are exchanged and refresh tokens are revoked", async () => {
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url, body: new URLSearchParams(options.body) });
    return { ok: true, status: 200, json: async () => ({ refresh_token: "refresh-token", id_token: "identity-token" }) };
  };
  assert.deepEqual(await exchangeAuthorizationCode("one-time-code", config, fetchImpl), {
    refreshToken: "refresh-token",
    identityToken: "identity-token"
  });
  await revokeRefreshToken("refresh-token", config, fetchImpl);
  assert.equal(calls[0].url, "https://appleid.apple.com/auth/token");
  assert.equal(calls[0].body.get("grant_type"), "authorization_code");
  assert.equal(calls[1].url, "https://appleid.apple.com/auth/revoke");
  assert.equal(calls[1].body.get("token_type_hint"), "refresh_token");
});

test("server config fails closed without private Apple credentials", () => {
  assert.throws(() => appleServerConfig({ APPLE_CLIENT_ID: config.clientId }), /apple_token_revocation_not_configured/);
});

test("code-exchanged Apple identity tokens reuse the client nonce", () => {
  const source = fs.readFileSync(path.join(__dirname, "../src/server.js"), "utf8");
  const start = source.indexOf("const exchangedPayload");
  const end = source.indexOf("if (exchangedPayload.sub", start);
  assert.ok(start >= 0 && end > start);
  assert.match(source.slice(start, end), /nonce: typeof body\.nonce/);
  assert.match(source.slice(start, end), /requireNonce: process\.env\.APPLE_REQUIRE_NONCE/);
});
