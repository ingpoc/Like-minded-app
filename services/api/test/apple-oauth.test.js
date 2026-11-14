const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

const {
  APPLE_TOKEN_URL,
  APPLE_REVOKE_URL,
  AppleOAuthError,
  appleOAuthConfig,
  createAppleClientSecret,
  exchangeAppleAuthorizationCode,
  revokeAppleAuthorizationCode
} = require("../src/lib/apple-oauth");

function decodePart(part) {
  return JSON.parse(Buffer.from(part, "base64url").toString("utf8"));
}

function testConfig() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  return {
    config: {
      teamId: "9UPQL479Z5",
      keyId: "TESTKEY123",
      clientId: "com.gurusharan.likeminded",
      privateKey: privateKey.export({ format: "pem", type: "pkcs8" })
    },
    publicKey
  };
}

test("appleOAuthConfig fails closed without required secrets", () => {
  assert.throws(() => appleOAuthConfig({}), error => {
    assert.ok(error instanceof AppleOAuthError);
    assert.equal(error.code, "apple_oauth_not_configured");
    assert.doesNotMatch(error.message, /PRIVATE|KEY|TEAM/);
    return true;
  });
});

test("createAppleClientSecret produces a signed ES256 client secret", () => {
  const { config, publicKey } = testConfig();
  const now = Date.UTC(2026, 6, 21, 12, 0, 0);
  const token = createAppleClientSecret({ config, now });
  const [headerPart, payloadPart, signaturePart] = token.split(".");
  assert.deepEqual(decodePart(headerPart), { alg: "ES256", kid: config.keyId, typ: "JWT" });
  const payload = decodePart(payloadPart);
  assert.equal(payload.iss, config.teamId);
  assert.equal(payload.sub, config.clientId);
  assert.equal(payload.aud, "https://appleid.apple.com");
  assert.equal(payload.exp - payload.iat, 60 * 60 * 24 * 30);
  assert.ok(crypto.verify("sha256", Buffer.from(`${headerPart}.${payloadPart}`), {
    key: publicKey,
    dsaEncoding: "ieee-p1363"
  }, Buffer.from(signaturePart, "base64url")));
});

test("exchangeAppleAuthorizationCode posts the one-time code without logging secrets", async () => {
  const { config } = testConfig();
  const calls = [];
  const result = await exchangeAppleAuthorizationCode("fresh-code", {
    config,
    fetchImpl: async (url, request) => {
      calls.push({ url, request });
      return { ok: true, json: async () => ({ refresh_token: "refresh-secret", id_token: "exchange-id-token" }) };
    }
  });
  assert.equal(result.refreshToken, "refresh-secret");
  assert.equal(result.identityToken, "exchange-id-token");
  assert.equal(calls[0].url, APPLE_TOKEN_URL);
  const body = new URLSearchParams(calls[0].request.body);
  assert.equal(body.get("code"), "fresh-code");
  assert.equal(body.get("grant_type"), "authorization_code");
  assert.equal(body.get("client_id"), config.clientId);
});

test("revokeAppleAuthorizationCode exchanges then revokes the refresh token", async () => {
  const { config } = testConfig();
  const calls = [];
  await revokeAppleAuthorizationCode("fresh-code", {
    config,
    fetchImpl: async (url, request) => {
      calls.push({ url, request });
      if (url === APPLE_TOKEN_URL) return { ok: true, json: async () => ({ refresh_token: "refresh-secret", id_token: "exchange-id-token" }) };
      return { ok: true, json: async () => ({}) };
    }
  });
  assert.deepEqual(calls.map(call => call.url), [APPLE_TOKEN_URL, APPLE_REVOKE_URL]);
  const revokeBody = new URLSearchParams(calls[1].request.body);
  assert.equal(revokeBody.get("token"), "refresh-secret");
  assert.equal(revokeBody.get("token_type_hint"), "refresh_token");
});

test("Apple code exchange fails closed when the response cannot bind an identity", async () => {
  const { config } = testConfig();
  await assert.rejects(
    () => exchangeAppleAuthorizationCode("fresh-code", {
      config,
      fetchImpl: async () => ({ ok: true, json: async () => ({ refresh_token: "refresh-secret" }) })
    }),
    error => error instanceof AppleOAuthError && error.code === "apple_identity_token_missing"
  );
});

test("Apple token endpoint failures return stable errors without response contents", async () => {
  const { config } = testConfig();
  await assert.rejects(
    () => exchangeAppleAuthorizationCode("bad-code", {
      config,
      fetchImpl: async () => ({ ok: false, status: 400, json: async () => ({ error: "sensitive-provider-detail" }) })
    }),
    error => error instanceof AppleOAuthError
      && error.code === "apple_code_exchange_failed"
      && !error.message.includes("sensitive-provider-detail")
  );
});
