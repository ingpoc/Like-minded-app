const crypto = require("node:crypto");

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys";
const SESSION_TTL_SECONDS = 60 * 60 * 24 * 30;
const APPLE_KEYS_CACHE_MS = 60 * 60 * 1000;

let cachedAppleKeys = null;
let cachedAppleKeysAt = 0;

class AppleIdentityServiceError extends Error {
  constructor(code = "apple_identity_service_unavailable") {
    super(code);
    this.name = "AppleIdentityServiceError";
    this.code = code;
  }
}

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
    authProvider: user.authProvider || (user.appleSub ? "apple" : user.googleSub ? "google" : user.walletAddress ? "wallet" : null),
    authSubject: user.authSubject || user.appleSub || user.googleSub || null,
    appleSub: user.appleSub || null,
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

function appleAudiences() {
  const audiences = new Set();
  for (const value of [
    process.env.APPLE_CLIENT_IDS,
    process.env.APPLE_CLIENT_ID,
    process.env.APPLE_BUNDLE_ID,
    process.env.APPLE_MAC_BUNDLE_ID
  ]) {
    if (!value) continue;
    for (const part of String(value).split(",")) {
      const trimmed = part.trim();
      if (trimmed) audiences.add(trimmed);
    }
  }
  return audiences;
}

function verifyNonce(rawNonce, tokenNonce, { requireNonce = false } = {}) {
  if (!rawNonce) {
    if (requireNonce) throw new Error("nonce_required");
    return;
  }
  if (!tokenNonce) throw new Error("apple_nonce_missing");
  const expected = crypto.createHash("sha256").update(rawNonce).digest("hex");
  if (expected !== tokenNonce) throw new Error("apple_nonce_mismatch");
}

async function fetchAppleKeys() {
  let response;
  try {
    response = await fetch(APPLE_KEYS_URL);
  } catch {
    throw new AppleIdentityServiceError();
  }
  if (!response.ok) throw new AppleIdentityServiceError();
  try {
    return await response.json();
  } catch {
    throw new AppleIdentityServiceError("apple_identity_service_invalid_response");
  }
}

async function appleKeys({ forceRefresh = false } = {}) {
  const isFresh = cachedAppleKeys && Date.now() - cachedAppleKeysAt < APPLE_KEYS_CACHE_MS;
  if (!forceRefresh && isFresh) return cachedAppleKeys;
  cachedAppleKeys = await fetchAppleKeys();
  cachedAppleKeysAt = Date.now();
  return cachedAppleKeys;
}

function findAppleJwk(keys, kid) {
  return keys.keys.find((key) => key.kid === kid);
}

async function verifyAppleIdentityToken(identityToken, options = {}) {
  if (process.env.APPLE_AUTH_BYPASS === "1") {
    return {
      sub: `dev-${crypto.createHash("sha256").update(identityToken || "tester").digest("hex").slice(0, 16)}`,
      email: "tester@likeminded.local",
      email_verified: true
    };
  }

  const audiences = appleAudiences();
  if (audiences.size === 0) {
    throw new Error("APPLE_CLIENT_ID, APPLE_BUNDLE_ID, or APPLE_CLIENT_IDS must be set");
  }

  const parsed = parseJwt(identityToken);
  const requireNonce = process.env.APPLE_REQUIRE_NONCE === "1" || options.requireNonce === true;
  verifyNonce(options.nonce, parsed.payload.nonce, { requireNonce });

  let keys = await appleKeys();
  let jwk = findAppleJwk(keys, parsed.header.kid);
  if (!jwk) {
    keys = await appleKeys({ forceRefresh: true });
    jwk = findAppleJwk(keys, parsed.header.kid);
  }
  if (!jwk) throw new Error("apple_key_not_found");

  const publicKey = crypto.createPublicKey({ key: jwk, format: "jwk" });
  const isValid = crypto.verify("RSA-SHA256", Buffer.from(parsed.signed), publicKey, parsed.signature);
  if (!isValid) throw new Error("invalid_apple_signature");

  const now = Math.floor(Date.now() / 1000);
  if (parsed.payload.iss !== APPLE_ISSUER) throw new Error("invalid_apple_issuer");
  if (!audiences.has(parsed.payload.aud)) throw new Error("invalid_apple_audience");
  if (parsed.payload.exp < now) throw new Error("apple_token_expired");
  if (!parsed.payload.sub) throw new Error("apple_sub_missing");
  if (typeof parsed.payload.auth_time === "number" && parsed.payload.auth_time > now + 60) {
    throw new Error("apple_auth_time_invalid");
  }
  if (parsed.payload.email && parsed.payload.email_verified === false) {
    throw new Error("apple_email_unverified");
  }
  return parsed.payload;
}

function bearerToken(req) {
  const header = req.headers.authorization || "";
  const [scheme, token] = header.split(" ");
  return /^Bearer$/i.test(scheme) ? token : null;
}

module.exports = {
  AppleIdentityServiceError,
  createSessionToken,
  verifySessionToken,
  verifyAppleIdentityToken,
  bearerToken,
  appleAudiences,
  verifyNonce,
  parseJwt
};
