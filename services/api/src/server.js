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
    json(res, 200, { status: "ok", service: "likeminded-api", version: "0.1.0" });
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/system/architecture") {
    json(res, 200, { service: "likeminded-api", architecture });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/realtime/session") {
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
    try {
      const body = await readJsonBody(req);
      const { interviewTranscript, reflectionAnswers } = body || {};
      const profile = buildProfileFromInterview(interviewTranscript || "", reflectionAnswers || []);
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
      json(res, 400, { error: "invalid_json", message: error.message });
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

  // ---------------------------------------------------------------------------
  // Legacy MVP reflect-place-connect (kept for backward compat)
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

server.listen(PORT, HOST, () => {
  console.log(`likeminded-api listening on http://${HOST}:${PORT}`);
  console.log(`Circles seeded: ${circles.size} archetypes`);
});
