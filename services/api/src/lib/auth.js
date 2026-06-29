const crypto = require("node:crypto");

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys";
const SESSION_TTL_SECONDS = 60 * 60 * 24 * 30;

let cachedAppleKeys = null;

function base64url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function decodeBase64url(value) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  return Buffer.from(padded, "base64");
}

function parseJwt(token) {
  const [headerPart, payloadPart, signaturePart] = String(token || "").split(".");
  if (!headerPart || !payloadPart || !signaturePart) throw new Error("invalid_jwt");
  return {
    header: JSON.parse(decodeBase64url(headerPart).toString("utf8")),
    payload: JSON.parse(decodeBase64url(payloadPart).toString("utf8")),
    signed: `${headerPart}.${payloadPart}`,
    signature: decodeBase64url(signaturePart)
  };
}

function sessionSecret() {
  const secret = process.env.SESSION_SECRET || process.env.JWT_SESSION_SECRET;
  if (!secret || secret.length < 24) {
    throw new Error("SESSION_SECRET must be set to at least 24 characters");
  }
  return secret;
}

function createSessionToken(user) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "HS256", typ: "JWT" };
  const payload = {
    sub: user.id,
    appleSub: user.appleSub,
    iat: now,
    exp: now + SESSION_TTL_SECONDS
  };
  const signed = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = crypto.createHmac("sha256", sessionSecret()).update(signed).digest();
  return `${signed}.${base64url(signature)}`;
}

function verifySessionToken(token) {
  const parsed = parseJwt(token);
  if (parsed.header.alg !== "HS256") throw new Error("invalid_session_alg");
  const expected = crypto.createHmac("sha256", sessionSecret()).update(parsed.signed).digest();
  if (!crypto.timingSafeEqual(expected, parsed.signature)) throw new Error("invalid_session_signature");
  if (!parsed.payload.sub || parsed.payload.exp < Math.floor(Date.now() / 1000)) {
    throw new Error("session_expired");
  }
  return parsed.payload;
}

async function appleKeys() {
  if (cachedAppleKeys) return cachedAppleKeys;
  const response = await fetch(APPLE_KEYS_URL);
  if (!response.ok) throw new Error("apple_keys_unavailable");
  cachedAppleKeys = await response.json();
  return cachedAppleKeys;
}

async function verifyAppleIdentityToken(identityToken) {
  if (process.env.APPLE_AUTH_BYPASS === "1") {
    return {
      sub: `dev-${crypto.createHash("sha256").update(identityToken || "tester").digest("hex").slice(0, 16)}`,
      email: "tester@likeminded.local",
      emailVerified: true
    };
  }

  const expectedAudience = process.env.APPLE_CLIENT_ID || process.env.APPLE_BUNDLE_ID;
  if (!expectedAudience) throw new Error("APPLE_CLIENT_ID or APPLE_BUNDLE_ID must be set");

  const parsed = parseJwt(identityToken);
  const keys = await appleKeys();
  const jwk = keys.keys.find((key) => key.kid === parsed.header.kid);
  if (!jwk) throw new Error("apple_key_not_found");

  const publicKey = crypto.createPublicKey({ key: jwk, format: "jwk" });
  const isValid = crypto.verify("RSA-SHA256", Buffer.from(parsed.signed), publicKey, parsed.signature);
  if (!isValid) throw new Error("invalid_apple_signature");

  const now = Math.floor(Date.now() / 1000);
  if (parsed.payload.iss !== APPLE_ISSUER) throw new Error("invalid_apple_issuer");
  if (parsed.payload.aud !== expectedAudience) throw new Error("invalid_apple_audience");
  if (parsed.payload.exp < now) throw new Error("apple_token_expired");
  if (!parsed.payload.sub) throw new Error("apple_sub_missing");
  return parsed.payload;
}

function bearerToken(req) {
  const header = req.headers.authorization || "";
  const [scheme, token] = header.split(" ");
  return /^Bearer$/i.test(scheme) ? token : null;
}

module.exports = {
  createSessionToken,
  verifySessionToken,
  verifyAppleIdentityToken,
  bearerToken
};
