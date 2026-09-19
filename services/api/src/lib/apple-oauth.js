const crypto = require("node:crypto");

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_TOKEN_URL = `${APPLE_ISSUER}/auth/token`;
const APPLE_REVOKE_URL = `${APPLE_ISSUER}/auth/revoke`;
const CLIENT_SECRET_TTL_SECONDS = 60 * 60 * 24 * 30;

class AppleOAuthError extends Error {
  constructor(code, statusCode = 502) {
    super(code);
    this.name = "AppleOAuthError";
    this.code = code;
    this.statusCode = statusCode;
  }
}

function base64url(input) {
  return Buffer.from(input).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function appleOAuthConfig(env = process.env) {
  const config = {
    teamId: String(env.APPLE_TEAM_ID || "").trim(),
    keyId: String(env.APPLE_KEY_ID || "").trim(),
    clientId: String(env.APPLE_CLIENT_ID || env.APPLE_BUNDLE_ID || "").trim(),
    privateKey: String(env.APPLE_PRIVATE_KEY || "").replace(/\\n/g, "\n").trim()
  };
  if (Object.values(config).some(value => !value)) throw new AppleOAuthError("apple_oauth_not_configured", 502);
  return config;
}

function createAppleClientSecret({ config = appleOAuthConfig(), now = Date.now() } = {}) {
  const issuedAt = Math.floor(now / 1000);
  const header = { alg: "ES256", kid: config.keyId, typ: "JWT" };
  const payload = {
    iss: config.teamId,
    iat: issuedAt,
    exp: issuedAt + CLIENT_SECRET_TTL_SECONDS,
    aud: APPLE_ISSUER,
    sub: config.clientId
  };
  const signed = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  try {
    const signature = crypto.sign("sha256", Buffer.from(signed), {
      key: config.privateKey,
      dsaEncoding: "ieee-p1363"
    });
    return `${signed}.${base64url(signature)}`;
  } catch {
    throw new AppleOAuthError("apple_private_key_invalid", 502);
  }
}

async function appleFormRequest(url, form, { fetchImpl = fetch, errorCode } = {}) {
  let response;
  try {
    response = await fetchImpl(url, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(form).toString()
    });
  } catch {
    throw new AppleOAuthError(`${errorCode}_unavailable`, 502);
  }
  if (!response.ok) throw new AppleOAuthError(errorCode, 502);
  return response;
}

async function exchangeAppleAuthorizationCode(authorizationCode, options = {}) {
  if (!authorizationCode || typeof authorizationCode !== "string") {
    throw new AppleOAuthError("apple_authorization_code_required", 400);
  }
  const config = options.config || appleOAuthConfig(options.env);
  const clientSecret = createAppleClientSecret({ config, now: options.now });
  const response = await appleFormRequest(APPLE_TOKEN_URL, {
    client_id: config.clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: "authorization_code"
  }, { fetchImpl: options.fetchImpl, errorCode: "apple_code_exchange_failed" });
  let body;
  try {
    body = await response.json();
  } catch {
    throw new AppleOAuthError("apple_code_exchange_invalid_response", 502);
  }
  if (!body.refresh_token) throw new AppleOAuthError("apple_refresh_token_missing", 502);
  if (!body.id_token) throw new AppleOAuthError("apple_identity_token_missing", 502);
  return { refreshToken: body.refresh_token, identityToken: body.id_token, config, clientSecret };
}

async function revokeAppleRefreshToken(refreshToken, { config, clientSecret, fetchImpl } = {}) {
  if (!refreshToken) throw new AppleOAuthError("apple_refresh_token_missing", 502);
  const resolvedConfig = config || appleOAuthConfig();
  const resolvedSecret = clientSecret || createAppleClientSecret({ config: resolvedConfig });
  await appleFormRequest(APPLE_REVOKE_URL, {
    client_id: resolvedConfig.clientId,
    client_secret: resolvedSecret,
    token: refreshToken,
    token_type_hint: "refresh_token"
  }, { fetchImpl, errorCode: "apple_token_revoke_failed" });
}

async function revokeAppleAuthorizationCode(authorizationCode, options = {}) {
  const exchanged = await exchangeAppleAuthorizationCode(authorizationCode, options);
  await revokeAppleRefreshToken(exchanged.refreshToken, {
    config: exchanged.config,
    clientSecret: exchanged.clientSecret,
    fetchImpl: options.fetchImpl
  });
  return exchanged;
}

module.exports = {
  APPLE_ISSUER,
  APPLE_TOKEN_URL,
  APPLE_REVOKE_URL,
  AppleOAuthError,
  appleOAuthConfig,
  createAppleClientSecret,
  exchangeAppleAuthorizationCode,
  revokeAppleRefreshToken,
  revokeAppleAuthorizationCode
};
