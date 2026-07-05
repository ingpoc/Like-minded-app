const { OAuth2Client } = require("google-auth-library");

function googleClientIds() {
  const ids = new Set();
  for (const value of [
    process.env.GOOGLE_CLIENT_IDS,
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_ID_IOS,
    process.env.GOOGLE_CLIENT_ID_WEB
  ]) {
    if (!value) continue;
    for (const part of String(value).split(",")) {
      const trimmed = part.trim();
      if (trimmed) ids.add(trimmed);
    }
  }
  return ids;
}

async function verifyGoogleIdentityToken(idToken) {
  if (process.env.GOOGLE_AUTH_BYPASS === "1") {
    const crypto = require("node:crypto");
    return {
      sub: `dev-google-${crypto.createHash("sha256").update(idToken || "tester").digest("hex").slice(0, 16)}`,
      email: "tester@likeminded.local",
      email_verified: true,
      name: "Google Tester"
    };
  }

  const audiences = googleClientIds();
  if (audiences.size === 0) {
    throw new Error("GOOGLE_CLIENT_ID or GOOGLE_CLIENT_IDS must be set");
  }

  const client = new OAuth2Client([...audiences][0]);
  const ticket = await client.verifyIdToken({
    idToken,
    audience: [...audiences]
  });
  const payload = ticket.getPayload();
  if (!payload?.sub) throw new Error("google_sub_missing");
  if (payload.email && payload.email_verified === false) {
    throw new Error("google_email_unverified");
  }
  return payload;
}

module.exports = {
  verifyGoogleIdentityToken,
  googleClientIds
};
