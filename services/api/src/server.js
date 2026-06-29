const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const {
  architecture,
  buildProfileFromInterview,
  buildPlacement,
  profiles,
  circles,
  seedCircles,
  matchCircles,
  shouldCreateNewCircle,
  createCircleFromProfile
} = require("./lib/architecture");
const { savePlacement, getAllPlacements, getPlacementsByProfile, saveTranscript, registerDevice, getDevice, getProfilesByDevice } = require("./lib/db");
const { bearerToken, createSessionToken, verifyAppleIdentityToken, verifySessionToken } = require("./lib/auth");
const {
  migrateMvpStore,
  upsertAppleUser,
  getUserById,
  saveProfilePlacement,
  getLatestProfile,
  getLatestPlacement,
  updateLatestProfile,
  updateLatestPlacement,
  saveFeedback
} = require("./lib/mvp-store");

function loadLocalEnv() {
  const envPath = path.resolve(process.cwd(), ".env.local");
  if (!fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
    const separator = trimmed.indexOf("=");
    const key = trimmed.slice(0, separator).trim();
    const value = trimmed.slice(separator + 1).trim().replace(/^['"]|['"]$/g, "");
    if (key && process.env[key] === undefined) process.env[key] = value;
  }
}
loadLocalEnv();

const HOST = process.env.HOST || "127.0.0.1";
const PORT = Number(process.env.PORT || 8787);
const REALTIME_MODEL = process.env.OPENAI_REALTIME_MODEL || "gpt-realtime-2";
const REALTIME_VOICE = process.env.OPENAI_REALTIME_VOICE || "marin";

function json(res, statusCode, body) {
  const payload = JSON.stringify(body, null, 2);
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(payload)
  });
  res.end(payload);
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", chunk => chunks.push(chunk));
    req.on("end", () => {
      if (chunks.length === 0) return resolve({});
      try { resolve(JSON.parse(Buffer.concat(chunks).toString("utf8"))); }
      catch (error) { reject(error); }
    });
    req.on("error", reject);
  });
}

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", chunk => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

async function currentUser(req) {
  const token = bearerToken(req);
  if (!token) return null;
  const session = verifySessionToken(token);
  return getUserById(session.sub);
}

async function requireUser(req, res) {
  try {
    const user = await currentUser(req);
    if (user) return user;
  } catch {
    // Fall through to the standard auth response.
  }
  json(res, 401, { error: "unauthorized", message: "Sign in with Apple is required." });
  return null;
}

function resultEnvelope(profile, placement, allCircleFits = null) {
  return {
    profileId: profile.profileId,
    signals: profile.signals,
    placement,
    allCircleFits
  };
}

async function createRealtimeClientSecret(input = {}) {
  if (!process.env.OPENAI_API_KEY) {
    return { statusCode: 503, body: { error: "openai_api_key_missing", message: "Set OPENAI_API_KEY on the API server to create a realtime voice session." } };
  }
  const safetyIdentifier = typeof input.safetyIdentifier === "string" && input.safetyIdentifier.trim() ? input.safetyIdentifier.trim() : undefined;
  const headers = { authorization: `Bearer ${process.env.OPENAI_API_KEY}`, "content-type": "application/json" };
  if (safetyIdentifier) headers["openai-safety-identifier"] = safetyIdentifier;

  const response = await fetch("https://api.openai.com/v1/realtime/client_secrets", {
    method: "POST",
    headers,
    body: JSON.stringify({ session: { type: "realtime", model: REALTIME_MODEL, audio: { output: { voice: REALTIME_VOICE } } } })
  });

  const text = await response.text();
  let body;
  try { body = JSON.parse(text); } catch { body = { error: "openai_realtime_unparseable_response", message: text }; }
  return { statusCode: response.status, body };
}

async function handleRequest(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || `${HOST}:${PORT}`}`);

  if (req.method === "GET" && url.pathname === "/health") {
    const { DB_PATH } = require("./lib/db");
    const fs = require("node:fs");
    const dbExists = fs.existsSync(DB_PATH);
    json(res, 200, {
      status: "ok",
      service: "likeminded-api",
      version: "0.1.0",
      db: process.env.DATABASE_URL ? "postgres" : dbExists ? "sqlite" : "none",
      dbPath: process.env.DATABASE_URL ? undefined : DB_PATH
    });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/auth/apple") {
    try {
      const body = await readJsonBody(req);
      const applePayload = await verifyAppleIdentityToken(body.identityToken);
      const user = await upsertAppleUser({
        appleSub: applePayload.sub,
        email: applePayload.email,
        fullName: typeof body.fullName === "string" ? body.fullName.trim() : null
      });
      json(res, 200, { user, sessionToken: createSessionToken(user), expiresIn: 60 * 60 * 24 * 30 });
    } catch (error) {
      json(res, 401, { error: "apple_auth_failed", message: error.message });
    }
    return;
  }

  // ---------------------------------------------------------------------------
  // Device auth (anonymous UUID)
  // ---------------------------------------------------------------------------

  // POST /v1/auth/device — register or refresh a device, returns device record
  if (req.method === "POST" && url.pathname === "/v1/auth/device") {
    try {
      const body = await readJsonBody(req);
      const deviceId = body?.deviceId;
      if (!deviceId || typeof deviceId !== "string" || deviceId.length < 8) {
        json(res, 400, { error: "invalid_device_id", message: "deviceId must be a string of at least 8 characters." });
        return;
      }
      const device = registerDevice(deviceId);
      json(res, 200, { device });
    } catch (error) {
      json(res, 500, { error: "device_registration_failed", message: error.message });
    }
    return;
  }

  // GET /v1/auth/device — get device info from X-Device-Id header
  if (req.method === "GET" && url.pathname === "/v1/auth/device") {
    const deviceId = req.headers["x-device-id"];
    if (!deviceId) {
      json(res, 400, { error: "missing_device_id", message: "Send X-Device-Id header." });
      return;
    }
    const device = getDevice(deviceId);
    if (!device) {
      json(res, 404, { error: "device_not_found", message: "Unknown device. POST /v1/auth/device to register." });
      return;
    }
    json(res, 200, { device });
    return;
  }

  // GET /v1/devices/:id/profiles — all profiles belonging to a device
  if (req.method === "GET" && url.pathname.startsWith("/v1/devices/") && url.pathname.endsWith("/profiles")) {
    const parts = url.pathname.split("/");
    const deviceId = decodeURIComponent(parts[3]);
    const device = getDevice(deviceId);
    if (!device) {
      json(res, 404, { error: "device_not_found", message: `No device found for id: ${deviceId}` });
      return;
    }
    const deviceProfiles = getProfilesByDevice(deviceId);
    json(res, 200, { deviceId, profiles: deviceProfiles });
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/system/architecture") {
    json(res, 200, { service: "likeminded-api", architecture });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/realtime/session") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const result = await createRealtimeClientSecret(body);
      json(res, result.statusCode, { transport: "webrtc", model: REALTIME_MODEL, voice: REALTIME_VOICE, toolPolicy: architecture.toolPolicy, clientSecret: result.body });
    } catch (error) {
      json(res, 400, { error: "invalid_realtime_session_request", message: error.message });
    }
    return;
  }

  // POST /v1/realtime/calls — WebRTC SDP exchange (unified interface)
  // Client sends SDP offer as text/plain, server forwards to OpenAI with session config
  if (req.method === "POST" && url.pathname === "/v1/realtime/calls") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const sdp = await readRawBody(req);
      if (!sdp.trim()) {
        json(res, 400, { error: "invalid_sdp", message: "SDP offer body is required." });
        return;
      }

      if (!process.env.OPENAI_API_KEY) {
        json(res, 503, { error: "openai_api_key_missing", message: "Set OPENAI_API_KEY on the API server." });
        return;
      }

      const sessionConfig = JSON.stringify({
        type: "realtime",
        model: REALTIME_MODEL,
        output_modalities: ["audio"],
        audio: {
          input: {
            format: { type: "audio/pcm", rate: 24000 },
            turn_detection: { type: "server_vad", threshold: 0.5, prefix_padding_ms: 500, silence_duration_ms: 1500 }
          },
          output: {
            format: { type: "audio/pcm", rate: 24000 },
            voice: REALTIME_VOICE
          }
        },
        instructions: "You are a warm, insightful interviewer conducting a personality discovery conversation for the Likeminded app. Start by introducing yourself briefly and warmly. Ask open-ended questions one at a time. Listen carefully. Let the conversation flow naturally. Aim for 3-5 questions before wrapping up. Be genuine, warm, and curious. IMPORTANT: Wait patiently for the user to finish speaking. Do not interrupt."
      });

      const formData = new FormData();
      formData.append("sdp", sdp);
      formData.append("session", sessionConfig);

      const realtimeResponse = await fetch("https://api.openai.com/v1/realtime/calls", {
        method: "POST",
        headers: { "Authorization": `Bearer ${process.env.OPENAI_API_KEY}` },
        body: formData
      });

      const answerSdp = await realtimeResponse.text();
      if (!realtimeResponse.ok) {
        json(res, realtimeResponse.status, { error: "realtime_call_failed", message: answerSdp });
        return;
      }

      res.writeHead(realtimeResponse.status, { "Content-Type": "application/sdp" });
      res.end(answerSdp);
    } catch (error) {
      json(res, 500, { error: "realtime_call_error", message: error.message });
    }
    return;
  }

  // ---------------------------------------------------------------------------
  // Profile endpoints
  // ---------------------------------------------------------------------------

  // POST /v1/profiles — create a profile from interview transcript + reflection answers
  if (req.method === "POST" && url.pathname === "/v1/profiles") {
    try {
      const body = await readJsonBody(req);
      const { interviewTranscript, reflectionAnswers } = body;
      const profile = buildProfileFromInterview(interviewTranscript, reflectionAnswers);
      profiles.set(profile.profileId, profile);
      json(res, 201, {
        profile: {
          profileId: profile.profileId,
          signals: profile.signals,
          synthesizedAt: profile.synthesizedAt
        }
      });
    } catch (error) {
      json(res, 400, { error: "invalid_json", message: "Expected a valid JSON request body." });
    }
    return;
  }

  // POST /v1/discover — AI interview → personality profile → circle placement
  if (req.method === "POST" && url.pathname === "/v1/discover") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const { interviewTranscript, reflectionAnswers } = body || {};
      const deviceId = req.headers["x-device-id"] || "";
      const profile = buildProfileFromInterview(interviewTranscript || "", reflectionAnswers || []);
      profile.deviceId = deviceId;
      profiles.set(profile.profileId, profile);
      const fits = matchCircles(profile.signals);
      const placement = buildPlacement(profile);

      await saveProfilePlacement({ userId: user.id, profile, placement, transcript: interviewTranscript });

      json(res, 200, resultEnvelope(profile, placement, fits.map(f => ({ circleId: f.circle.id, name: f.circle.name, score: Math.round(f.score * 100) / 100 }))));
    } catch (error) {
      json(res, 400, { error: "invalid_json", message: error.message });
    }
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/me/profile") {
    const user = await requireUser(req, res);
    if (!user) return;
    const profile = await getLatestProfile(user.id);
    if (!profile) {
      json(res, 404, { error: "profile_not_found", message: "No profile has been created yet." });
      return;
    }
    json(res, 200, { profile });
    return;
  }

  if (req.method === "PATCH" && url.pathname === "/v1/me/profile") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const profile = await updateLatestProfile(user.id, {
        reflectionSummary: typeof body.reflectionSummary === "string" ? body.reflectionSummary.trim() : null,
        signals: body.signals && typeof body.signals === "object" ? body.signals : null
      });
      if (!profile) {
        json(res, 404, { error: "profile_not_found", message: "No profile has been created yet." });
        return;
      }
      json(res, 200, { profile });
    } catch (error) {
      json(res, 400, { error: "invalid_profile_update", message: error.message });
    }
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/me/placement") {
    const user = await requireUser(req, res);
    if (!user) return;
    const profile = await getLatestProfile(user.id);
    const placed = await getLatestPlacement(user.id);
    if (!profile || !placed) {
      json(res, 404, { error: "placement_not_found", message: "No placement has been created yet." });
      return;
    }
    json(res, 200, { ...resultEnvelope(profile, placed.placement), placementId: placed.id });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/me/placement/actions") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const action = String(body.action || "");
      if (!["accept", "defer", "swap"].includes(action)) {
        json(res, 400, { error: "invalid_placement_action", message: "Use action accept, defer, or swap." });
        return;
      }
      const placed = await updateLatestPlacement(user.id, action);
      if (!placed) {
        json(res, 404, { error: "placement_not_found", message: "No placement has been created yet." });
        return;
      }
      const profile = await getLatestProfile(user.id);
      json(res, 200, { ...resultEnvelope(profile, placed.placement), placementId: placed.id });
    } catch (error) {
      json(res, 400, { error: "invalid_placement_action", message: error.message });
    }
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/feedback") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      await saveFeedback({
        userId: user.id,
        profileId: body.profileId,
        placementId: body.placementId,
        rating: Number.isInteger(body.rating) ? body.rating : null,
        message: typeof body.message === "string" ? body.message.trim() : null,
        appVersion: typeof body.appVersion === "string" ? body.appVersion.trim() : null
      });
      json(res, 201, { status: "saved" });
    } catch (error) {
      json(res, 400, { error: "invalid_feedback", message: error.message });
    }
    return;
  }

  // GET /v1/profiles/:id — retrieve a profile
  if (req.method === "GET" && url.pathname.startsWith("/v1/profiles/")) {
    const id = decodeURIComponent(url.pathname.split("/").pop());
    const profile = profiles.get(id);
    if (!profile) {
      json(res, 404, { error: "profile_not_found", message: `No profile found for id: ${id}` });
      return;
    }
    const placement = buildPlacement(profile);
    json(res, 200, {
      profile: {
        profileId: profile.profileId,
        signals: profile.signals,
        synthesizedAt: profile.synthesizedAt
      },
      placement
    });
    return;
  }

  // ---------------------------------------------------------------------------
  // Circle endpoints
  // ---------------------------------------------------------------------------

  // GET /v1/circles — list all circles
  if (req.method === "GET" && url.pathname === "/v1/circles") {
    const circleList = Array.from(circles.values()).map(c => ({
      id: c.id,
      name: c.name,
      description: c.description,
      roomEnergy: c.roomEnergy,
      membersCount: c.members.length,
      isArchetype: c.isArchetype || false,
      createdFromProfile: c.createdFromProfile || false,
      themes: c.themes,
      socialFormat: c.socialFormat
    }));
    json(res, 200, { circles: circleList });
    return;
  }

  // GET /v1/circles/:id — get circle details
  if (req.method === "GET" && url.pathname.startsWith("/v1/circles/")) {
    const id = decodeURIComponent(url.pathname.split("/").pop());
    const circle = circles.get(id);
    if (!circle) {
      json(res, 404, { error: "circle_not_found", message: `No circle found for id: ${id}` });
      return;
    }
    json(res, 200, { circle });
    return;
  }

  // POST /v1/circles/:id/match — given a profile, match into this circle or suggest new
  if (req.method === "POST" && url.pathname.match(/^\/v1\/circle[^/]+\/match$/)) {
    try {
      const circleId = decodeURIComponent(url.pathname.split("/")[3]);
      const body = await readJsonBody(req);
      const { interviewTranscript, reflectionAnswers } = body;
      const profile = buildProfileFromInterview(interviewTranscript, reflectionAnswers);
      profiles.set(profile.profileId, profile);

      const fits = matchCircles(profile.signals);
      const createNew = shouldCreateNewCircle(profile.signals, fits);
      const placement = buildPlacement(profile);

      json(res, 200, {
        profileId: profile.profileId,
        signals: profile.signals,
        placement,
        allCircleFits: fits.map(f => ({ circleId: f.circle.id, name: f.circle.name, score: Math.round(f.score * 100) / 100 }))
      });
    } catch (error) {
      json(res, 400, { error: "invalid_json", message: "Expected a valid JSON request body." });
    }
    return;
  }

  // GET /v1/placements — list all saved placements
  if (req.method === "GET" && url.pathname === "/v1/placements") {
    const placementList = getAllPlacements();
    json(res, 200, { placements: placementList });
    return;
  }

  // GET /v1/placements/:profileId — placements for a specific profile
  if (req.method === "GET" && url.pathname.startsWith("/v1/placements/")) {
    const profileId = decodeURIComponent(url.pathname.split("/").pop());
    const placementList = getPlacementsByProfile(profileId);
    json(res, 200, { placements: placementList });
    return;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  if (req.method === "POST" && url.pathname === "/v1/profiles/synthesize") {
    try {
      const body = await readJsonBody(req);
      const promptSummary = typeof body.promptSummary === "string" && body.promptSummary.trim()
        ? body.promptSummary.trim() : "User wants a calm, meaningful onboarding experience.";
      const profile = buildProfileFromInterview(promptSummary, body.reflectionAnswers || []);
      profiles.set(profile.profileId, profile);
      const placement = buildPlacement(profile);
      json(res, 200, {
        profile: {
          profileId: profile.profileId,
          displayName: "Likeminded User",
          signals: profile.signals,
          reflection: {
            summary: promptSummary,
            strengths: ["emotionally honest", "thoughtful pacing", "curious about compatibility"]
          }
        },
        placement
      });
    } catch (error) {
      json(res, 400, { error: "invalid_json", message: "Expected a valid JSON request body." });
    }
    return;
  }

  json(res, 404, { error: "not_found", message: "No route matched the request." });
}

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch(error => {
    json(res, 500, { error: "internal_error", message: error.message });
  });
});

migrateMvpStore()
  .then(() => {
    server.listen(PORT, HOST, () => {
      console.log(`likeminded-api listening on http://${HOST}:${PORT}`);
      console.log(`Circles seeded: ${circles.size} archetypes`);
    });
  })
  .catch((error) => {
    console.error(`likeminded-api failed to start: ${error.message}`);
    process.exit(1);
  });
