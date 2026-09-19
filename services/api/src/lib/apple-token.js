const crypto = require("node:crypto");

const APPLE_AUDIENCE = "https://appleid.apple.com";

function appleServerConfig(env = process.env) {
  const config = {
    teamId: env.APPLE_TEAM_ID,
    keyId: env.APPLE_KEY_ID,
    clientId: env.APPLE_CLIENT_ID,
    privateKey: env.APPLE_PRIVATE_KEY?.replaceAll("\\n", "\n")
  };
  const missing = Object.entries(config).filter(([, value]) => !value).map(([key]) => key);
  if (missing.length) throw new Error(`apple_token_revocation_not_configured:${missing.join(",")}`);
  return config;
}

function createClientSecret(config, now = Math.floor(Date.now() / 1000)) {
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const header = encode({ alg: "ES256", kid: config.keyId });
  const payload = encode({
    iss: config.teamId,
    iat: now,
    exp: now + 300,
    aud: APPLE_AUDIENCE,
    sub: config.clientId
  });
  const unsigned = `${header}.${payload}`;
  const signature = crypto.sign("sha256", Buffer.from(unsigned), {
    key: config.privateKey,
    dsaEncoding: "ieee-p1363"
  }).toString("base64url");
  return `${unsigned}.${signature}`;
}

async function postAppleForm(url, fields, fetchImpl = fetch) {
  const response = await fetchImpl(url, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(fields),
    signal: AbortSignal.timeout(10_000)
  });
  if (!response.ok) throw new Error(`apple_token_request_failed:${response.status}`);
  return response;
}

async function exchangeAuthorizationCode(code, config, fetchImpl = fetch) {
  if (!code) throw new Error("apple_authorization_code_missing");
  const response = await postAppleForm(`${APPLE_AUDIENCE}/auth/token`, {
    client_id: config.clientId,
    client_secret: createClientSecret(config),
    code,
    grant_type: "authorization_code"
  }, fetchImpl);
  const tokens = await response.json();
  if (!tokens.refresh_token) throw new Error("apple_refresh_token_missing");
  if (!tokens.id_token) throw new Error("apple_exchange_identity_token_missing");
  return { refreshToken: tokens.refresh_token, identityToken: tokens.id_token };
}

async function revokeRefreshToken(refreshToken, config, fetchImpl = fetch) {
  if (!refreshToken) throw new Error("apple_refresh_token_missing");
  await postAppleForm(`${APPLE_AUDIENCE}/auth/revoke`, {
    client_id: config.clientId,
    client_secret: createClientSecret(config),
    token: refreshToken,
    token_type_hint: "refresh_token"
  }, fetchImpl);
}

function encryptionKey(sessionSecret) {
  if (!sessionSecret || sessionSecret.length < 24) throw new Error("session_secret_too_short");
  return crypto.scryptSync(sessionSecret, "likeminded-apple-refresh-token-v1", 32);
}

function encryptRefreshToken(refreshToken, sessionSecret) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", encryptionKey(sessionSecret), iv);
  const ciphertext = Buffer.concat([cipher.update(refreshToken, "utf8"), cipher.final()]);
  return ["v1", iv.toString("base64url"), cipher.getAuthTag().toString("base64url"), ciphertext.toString("base64url")].join(":");
}

function decryptRefreshToken(value, sessionSecret) {
  const [version, iv, tag, ciphertext] = String(value || "").split(":");
  if (version !== "v1" || !iv || !tag || !ciphertext) throw new Error("apple_refresh_token_ciphertext_invalid");
  const decipher = crypto.createDecipheriv("aes-256-gcm", encryptionKey(sessionSecret), Buffer.from(iv, "base64url"));
  decipher.setAuthTag(Buffer.from(tag, "base64url"));
  return Buffer.concat([decipher.update(Buffer.from(ciphertext, "base64url")), decipher.final()]).toString("utf8");
}

module.exports = {
  appleServerConfig,
  createClientSecret,
  exchangeAuthorizationCode,
  revokeRefreshToken,
  encryptRefreshToken,
  decryptRefreshToken
};
