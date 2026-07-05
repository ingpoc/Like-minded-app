const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const {
  architecture,
  buildProfileFromInterview,
  buildPlacement,
  profiles,
  circles,
  communities,
  seedCircles,
  seedCommunities,
  computeCircleFit,
  matchCircles,
  shouldCreateNewCircle,
  createCircleFromProfile,
  generateId
} = require("./lib/architecture");
const { savePlacement, getAllPlacements, getPlacementsByProfile, saveTranscript, registerDevice, getDevice, getProfilesByDevice } = require("./lib/db");
const { bearerToken, createSessionToken, verifyAppleIdentityToken, verifySessionToken } = require("./lib/auth");
const { verifyGoogleIdentityToken } = require("./lib/google-auth");
const {
  createWalletChallenge,
  getWalletChallenge,
  consumeWalletChallenge,
  verifyWalletSignature,
  normalizeWallet,
  walletChainForWallet
} = require("./lib/wallet-auth");
const {
  migrateMvpStore,
  upsertAppleUser,
  upsertGoogleUser,
  upsertWalletUser,
  getUserById,
  saveProfilePlacement,
  getLatestProfile,
  getLatestPlacement,
  updateLatestProfile,
  updateLatestPlacement,
  joinCommunity,
  leaveCommunity,
  getJoinedCommunities,
  getCommunityMembers,
  saveMeetingRsvp,
  getMeetingRsvps,
  getUserMeetingRsvps,
  saveMeeting,
  listMeetingsForUser,
  getMeetingById,
  saveMeetingRecapNote,
  setSoulmateEnabled,
  isSoulmateEnabled,
  getSoulmatePreferences,
  setSoulmatePreferences,
  saveSoulmateSelection,
  getSoulmateMatches,
  getSoulmateMatch,
  archiveStaleMatches,
  saveMessage,
  getMessages,
  saveFeedback,
  deleteUserAccount,
  LOCAL_PATH: MVP_STORE_PATH
} = require("./lib/mvp-store");
const { generateParticipantToken } = require("./lib/livekit");
const { buildMeetings, nextWeekendAt } = require("./lib/scheduling");
const { modelBackedProfilePlacement, profilePlacementFromModelResult } = require("./lib/model-placement");

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

function authResponse(user) {
  return { user, sessionToken: createSessionToken(user), expiresIn: 60 * 60 * 24 * 30 };
}

function html(res, statusCode, body) {
  const payload = String(body);
  res.writeHead(statusCode, {
    "content-type": "text/html; charset=utf-8",
    "content-length": Buffer.byteLength(payload)
  });
  res.end(payload);
}

function renderWalletSignPage({ wallet, challengeId }) {
  const templatePath = path.join(__dirname, "../static/wallet-sign.html");
  const walletLabel = wallet === "metamask" ? "MetaMask" : "Solflare";
  return fs.readFileSync(templatePath, "utf8")
    .replaceAll("__WALLET_LABEL__", walletLabel)
    .replaceAll("__WALLETCONNECT_PROJECT_ID__", process.env.WALLETCONNECT_PROJECT_ID || "");
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

function resultEnvelope(profile, placement, allCircleFits = null, synthesisMode = null) {
  const safeProfile = publicProfile(profile);
  return {
    profileId: safeProfile.profileId,
    profileSummary: safeProfile.profileSummary || null,
    signals: safeProfile.signals,
    basicInfo: safeProfile.basicInfo || null,
    interests: safeProfile.interests || [],
    placement: placementWithMemberCounts(placement),
    allCircleFits,
    synthesisMode
  };
}

function circleWithMemberCount(circle) {
  if (!circle || typeof circle !== "object") return circle;
  const count = (circles.get(circle.id)?.members || circle.members || []).length;
  return { ...circle, membersCount: count, membersOnline: count };
}

function placementWithMemberCounts(placement) {
  if (!placement || typeof placement !== "object") return placement;
  return {
    ...placement,
    primaryCircle: circleWithMemberCount(placement.primaryCircle),
    secondaryCircles: (placement.secondaryCircles || []).map(circleWithMemberCount)
  };
}

function rememberCircleMember(placement, profileId) {
  const circleId = placement?.primaryCircle?.id;
  if (!circleId || !profileId) return;
  const circle = circles.get(circleId);
  if (!circle) return;
  circle.members = Array.from(new Set([...(circle.members || []), profileId]));
  circles.set(circleId, circle);
}

function publicProfile(profile) {
  if (!profile || typeof profile !== "object") return profile;
  const { hiddenSignals, ...safeProfile } = profile;
  return safeProfile;
}

function circleSummary(circle) {
  return {
    id: circle.id,
    name: circle.name,
    roomEnergy: circle.roomEnergy,
    themes: circle.themes || [],
    membersCount: (circle.members || []).length,
    membersOnline: (circle.members || []).length,
    meetingFormat: circle.meetingFormat
  };
}

function communitySummary(community) {
  return {
    id: community.id,
    name: community.name,
    summary: community.summary,
    themes: community.themes || [],
    meetingFormat: community.meetingFormat,
    membersCount: (community.members || []).length
  };
}

function meetingSummary(meeting, userId = null) {
  return {
    id: meeting.id,
    kind: meeting.kind,
    targetId: meeting.targetId,
    title: meeting.title,
    scheduledAt: meeting.scheduledAt,
    hostUserId: meeting.hostUserId,
    hostName: meeting.hostName,
    groupSize: meeting.groupSize,
    status: meeting.status,
    compositionSummary: meeting.compositionSummary,
    recapNote: userId ? meeting.recapNotes?.[userId] || "" : ""
  };
}

function soulmateMatchSummary(match, otherProfile, meeting) {
  return {
    matchId: match.id,
    userId: otherProfile.userId,
    name: otherProfile.basicInfo?.name || "Someone from your meetup",
    meetingId: match.meetingId,
    meetingDate: meeting?.scheduledAt || null,
    createdAt: match.createdAt
  };
}

function soulmateMatchDetail(match, otherProfile, meeting) {
  return {
    ...soulmateMatchSummary(match, otherProfile, meeting),
    basicInfo: {
      name: otherProfile.basicInfo?.name || null,
      gender: otherProfile.basicInfo?.gender || null
    },
    interests: otherProfile.interests || []
  };
}

function oppositeGender(a, b) {
  const first = String(a || "").toLowerCase();
  const second = String(b || "").toLowerCase();
  return first && second && first !== second;
}

async function participantForUser(userId) {
  const profile = await getLatestProfile(userId);
  const placed = await getLatestPlacement(userId);
  if (!profile || !placed) return null;
  return { userId, profile, placement: placed.placement };
}

async function pendingSoulmateSelections(userId) {
  const current = await participantForUser(userId);
  if (!current) return [];
  const pending = [];
  for (const meeting of await listMeetingsForUser(userId)) {
    const potentialMatches = [];
    const potentialMatchDetails = [];
    for (const otherUserId of meeting.participantIds || []) {
      if (otherUserId === userId || !(await isSoulmateEnabled(otherUserId))) continue;
      const other = await participantForUser(otherUserId);
      if (other && oppositeGender(current.profile.basicInfo?.gender, other.profile.basicInfo?.gender)) {
        potentialMatches.push(otherUserId);
        potentialMatchDetails.push({ userId: otherUserId, name: other.profile.basicInfo?.name || "Member" });
      }
    }
    if (potentialMatches.length) pending.push({ meetingId: meeting.id, potentialMatches, potentialMatchDetails });
  }
  return pending;
}

async function matchResponse(userId, match) {
  const otherUserId = match.userAId === userId ? match.userBId : match.userAId;
  const otherProfile = await getLatestProfile(otherUserId);
  const meeting = await getMeetingById(match.meetingId);
  if (!otherProfile) return null;
  return { otherProfile: { ...otherProfile, userId: otherUserId }, meeting };
}

async function runWeekendScheduling() {
  const created = [];
  const rsvps = (await getMeetingRsvps()).filter((row) => row.available);
  const participants = [];
  for (const rsvp of rsvps) {
    const participant = await participantForUser(rsvp.user_id);
    if (participant) participants.push({ ...participant, kind: rsvp.kind });
  }

  const circleGroups = new Map();
  for (const participant of participants.filter((item) => item.kind === "circle")) {
    const circle = participant.placement.primaryCircle;
    if (!circleGroups.has(circle.id)) circleGroups.set(circle.id, { target: circle, participants: [] });
    circleGroups.get(circle.id).participants.push(participant);
  }
  for (const { target, participants: group } of circleGroups.values()) {
    if (group.length < 6) continue;
    for (const meeting of buildMeetings({ kind: "circle", targetId: target.id, targetName: target.name, participants: group, scheduledAt: nextWeekendAt(0) })) {
      created.push(await saveMeeting(meeting));
    }
  }

  const communityGroups = new Map();
  for (const participant of participants.filter((item) => item.kind === "community")) {
    for (const communityId of await getJoinedCommunities(participant.userId)) {
      const community = communities.get(communityId);
      if (!community) continue;
      if (!communityGroups.has(communityId)) communityGroups.set(communityId, { target: community, participants: [] });
      communityGroups.get(communityId).participants.push(participant);
    }
  }
  for (const { target, participants: group } of communityGroups.values()) {
    if (group.length < 6) continue;
    for (const meeting of buildMeetings({ kind: "community", targetId: target.id, targetName: target.name, participants: group, scheduledAt: nextWeekendAt(6) })) {
      created.push(await saveMeeting(meeting));
    }
  }
  return created;
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
    const fs = require("node:fs");
    const dbExists = fs.existsSync(MVP_STORE_PATH);
    json(res, 200, {
      status: "ok",
      service: "likeminded-api",
      version: "0.1.0",
      db: process.env.DATABASE_URL ? "postgres" : dbExists ? "local-json" : "none",
      dbPath: process.env.DATABASE_URL ? undefined : MVP_STORE_PATH
    });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/auth/apple") {
    try {
      const body = await readJsonBody(req);
      const applePayload = await verifyAppleIdentityToken(body.identityToken, {
        nonce: typeof body.nonce === "string" ? body.nonce : undefined,
        requireNonce: process.env.APPLE_REQUIRE_NONCE === "1"
      });
      const user = await upsertAppleUser({
        appleSub: applePayload.sub,
        email: applePayload.email,
        fullName: typeof body.fullName === "string" ? body.fullName.trim() : null
      });
      json(res, 200, authResponse(user));
    } catch (error) {
      json(res, 401, { error: "apple_auth_failed", message: error.message });
    }
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/auth/google") {
    try {
      const body = await readJsonBody(req);
      const googlePayload = await verifyGoogleIdentityToken(body.idToken);
      const user = await upsertGoogleUser({
        googleSub: googlePayload.sub,
        email: googlePayload.email,
        fullName: typeof googlePayload.name === "string" ? googlePayload.name.trim() : null
      });
      json(res, 200, authResponse(user));
    } catch (error) {
      json(res, 401, { error: "google_auth_failed", message: error.message });
    }
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/auth/wallet/challenge") {
    try {
      const body = await readJsonBody(req);
      const wallet = normalizeWallet(body.wallet);
      const chain = body.chain ? String(body.chain) : walletChainForWallet(wallet);
      const challenge = createWalletChallenge({ wallet, chain });
      json(res, 200, {
        challengeId: challenge.id,
        wallet: challenge.wallet,
        chain: challenge.chain,
        message: challenge.message,
        expiresAt: new Date(challenge.expiresAt).toISOString()
      });
    } catch (error) {
      json(res, 400, { error: "wallet_challenge_failed", message: error.message });
    }
    return;
  }

  if (req.method === "GET" && url.pathname.startsWith("/v1/auth/wallet/challenge/")) {
    try {
      const challengeId = decodeURIComponent(url.pathname.split("/").pop());
      const challenge = getWalletChallenge(challengeId);
      json(res, 200, {
        challengeId: challenge.id,
        wallet: challenge.wallet,
        chain: challenge.chain,
        message: challenge.message,
        expiresAt: new Date(challenge.expiresAt).toISOString()
      });
    } catch (error) {
      json(res, 404, { error: "wallet_challenge_not_found", message: error.message });
    }
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/auth/wallet/sign") {
    try {
      const wallet = normalizeWallet(url.searchParams.get("wallet"));
      const challengeId = url.searchParams.get("challengeId");
      if (!challengeId) throw new Error("challenge_id_required");
      getWalletChallenge(challengeId);
      html(res, 200, renderWalletSignPage({ wallet, challengeId }));
    } catch (error) {
      html(res, 400, `<html><body><p>${error.message}</p></body></html>`);
    }
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/auth/wallet/verify") {
    try {
      const body = await readJsonBody(req);
      const challenge = consumeWalletChallenge(body.challengeId);
      const verifiedAddress = verifyWalletSignature({
        chain: challenge.chain,
        message: challenge.message,
        signature: body.signature,
        address: body.address
      });
      const user = await upsertWalletUser({
        walletChain: challenge.chain,
        walletAddress: verifiedAddress
      });
      json(res, 200, authResponse(user));
    } catch (error) {
      json(res, 401, { error: "wallet_auth_failed", message: error.message });
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

      const reinterviewContext = String(req.headers["x-likeminded-reinterview-context"] || "").trim().slice(0, 1200);
      const reinterviewInstructions = reinterviewContext
        ? `\n\nThis is a placement correction re-interview. Use the existing state below as context, then ask only what is needed to refresh the profile and starter circle.\n${reinterviewContext}`
        : "";
      const sessionConfig = JSON.stringify({
        type: "realtime",
        model: REALTIME_MODEL,
        output_modalities: ["audio"],
        tools: [
          {
            type: "function",
            name: "submit_profile_placement",
            description: "Create or update the user's private profile draft and best starter circle from the conversation so far.",
            parameters: {
              type: "object",
              additionalProperties: false,
              required: ["signals", "primaryCircleId", "fitReasons", "sourceReflectionSignals", "profileSummary", "interests", "hiddenSignals"],
              properties: {
                signals: { type: "object" },
                primaryCircleId: { type: "string" },
                secondaryCircleIds: { type: "array", items: { type: "string" } },
                fitReasons: { type: "array", items: { type: "string" } },
                sourceReflectionSignals: { type: "array", items: { type: "string" } },
                confidenceLabel: { type: "string" },
                profileSummary: { type: "string" },
                interests: {
                  type: "array",
                  items: {
                    type: "object",
                    additionalProperties: false,
                    required: ["area", "label", "depth"],
                    properties: {
                      area: { type: "string" },
                      label: { type: "string" },
                      depth: { type: "string", enum: ["casual", "active", "deep"] }
                    }
                  }
                },
                hiddenSignals: { type: "object" }
              }
            }
          }
        ],
        tool_choice: "auto",
        audio: {
          input: {
            format: { type: "audio/pcm", rate: 24000 },
            transcription: { model: process.env.OPENAI_REALTIME_TRANSCRIPTION_MODEL || "gpt-4o-mini-transcribe" },
            turn_detection: { type: "server_vad", threshold: 0.5, prefix_padding_ms: 500, silence_duration_ms: 1500 }
          },
          output: {
            format: { type: "audio/pcm", rate: 24000 },
            voice: REALTIME_VOICE
          }
        },
        instructions: "You are a warm, insightful interviewer conducting a personality discovery conversation for the Likeminded app. Start briefly and warmly. Ask open-ended questions one at a time. Listen carefully. Naturally discover interests across movies, music, books, food/cooking, outdoors, tech/building, and art/design; infer depth as casual, active, or deep from specificity and emotional engagement. Observe private placement signals from how the user speaks: shyness, language comfort, warmth, vulnerability openness, dominance tendency, and energy trajectory. After every meaningful user answer, call submit_profile_placement to save the current private profile draft, structured interests, hidden placement signals, and best starter circle from the conversation so far. If evidence is still early, set confidenceLabel to Draft profile and say what is provisional in fitReasons; once you have enough evidence, set confidenceLabel to Full profile. Choose from these circle ids only: reflective-builders, gentle-romantics, longform-thinkers, bold-explorers, grounded-nurturers. Do not choose by keyword; decide from pacing, trust, room energy, intent, and the whole conversation. IMPORTANT: Wait patiently for the user to finish speaking. Do not interrupt." + reinterviewInstructions
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

  if (req.method === "POST" && url.pathname === "/v1/realtime/profile-placement") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const { profile, placement } = profilePlacementFromModelResult({
        modelResult: body,
        interviewTranscript: body.interviewTranscript || "",
        reflectionAnswers: body.reflectionAnswers || []
      });
      const placed = await saveProfilePlacement({ userId: user.id, profile, placement, transcript: body.interviewTranscript || "" });
      rememberCircleMember(placement, profile.profileId);
      json(res, 201, { ...resultEnvelope(profile, placement, null, "realtime_tool"), placementId: placed.placementId });
    } catch (error) {
      json(res, 400, { error: "invalid_realtime_profile_placement", message: error.message });
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
      const result = await modelBackedProfilePlacement({ interviewTranscript: interviewTranscript || "", reflectionAnswers: reflectionAnswers || [] });
      const { profile, placement, allCircleFits, synthesisMode } = result;
      profile.deviceId = deviceId;
      profiles.set(profile.profileId, profile);

      await saveProfilePlacement({ userId: user.id, profile, placement, transcript: interviewTranscript });
      rememberCircleMember(placement, profile.profileId);

      json(res, 200, resultEnvelope(profile, placement, allCircleFits, synthesisMode));
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
    json(res, 200, { profile: publicProfile(profile) });
    return;
  }

  if (req.method === "PATCH" && url.pathname === "/v1/me/profile") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const profile = await updateLatestProfile(user.id, {
        reflectionSummary: typeof body.reflectionSummary === "string" ? body.reflectionSummary.trim() : null,
        signals: body.signals && typeof body.signals === "object" ? body.signals : null,
        basicInfo: body.basicInfo && typeof body.basicInfo === "object" ? body.basicInfo : null
      });
      if (!profile) {
        json(res, 404, { error: "profile_not_found", message: "No profile has been created yet." });
        return;
      }
      json(res, 200, { profile: publicProfile(profile) });
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

  if (req.method === "GET" && url.pathname === "/v1/me/circles") {
    const user = await requireUser(req, res);
    if (!user) return;
    const profile = await getLatestProfile(user.id);
    const placed = await getLatestPlacement(user.id);
    const placementCircles = placed?.placement
      ? [placed.placement.primaryCircle, ...(placed.placement.secondaryCircles || [])].filter(Boolean)
      : [];
    const circleList = placementCircles.length > 0
      ? placementCircles.map(circleSummary)
      : profile
        ? Array.from(circles.values()).filter((circle) => (circle.members || []).includes(profile.profileId)).map(circleSummary)
        : [];
    json(res, 200, { circles: circleList });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/me/circles/concern") {
    const user = await requireUser(req, res);
    if (!user) return;
    const profile = await updateLatestProfile(user.id, { concernFlag: true });
    if (!profile) {
      json(res, 404, { error: "profile_not_found", message: "No profile has been created yet." });
      return;
    }
    json(res, 200, { status: "concern_registered", message: "Re-interview prompted." });
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/communities") {
    json(res, 200, { communities: Array.from(communities.values()).map(communitySummary) });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/communities") {
    const user = await requireUser(req, res);
    if (!user) return;
    const body = await readJsonBody(req).catch(() => null);
    const name = typeof body?.name === "string" ? body.name.trim() : "";
    const summary = typeof body?.summary === "string" ? body.summary.trim() : "";
    const themes = Array.isArray(body?.themes)
      ? body.themes.map((theme) => String(theme).trim()).filter(Boolean).slice(0, 3)
      : [];
    if (!name || !summary) {
      json(res, 400, { error: "invalid_community", message: "Community name and summary are required." });
      return;
    }
    const community = {
      id: `community-${generateId()}`,
      name,
      summary,
      themes: themes.length > 0 ? themes : ["Community", "Discussion"],
      meetingFormat: "Member-led discussion",
      members: [user.id],
      createdAt: new Date().toISOString(),
      createdBy: user.id,
      isArchetype: false
    };
    communities.set(community.id, community);
    await joinCommunity(user.id, community.id);
    json(res, 201, { community: communitySummary(community) });
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/me/communities") {
    const user = await requireUser(req, res);
    if (!user) return;
    const ids = await getJoinedCommunities(user.id);
    json(res, 200, { communities: ids.map((id) => communities.get(id)).filter(Boolean).map(communitySummary) });
    return;
  }

  if (req.method === "GET" && url.pathname.match(/^\/v1\/communities\/[^/]+$/)) {
    const id = decodeURIComponent(url.pathname.split("/").pop());
    const community = communities.get(id);
    if (!community) {
      json(res, 404, { error: "community_not_found", message: `No community found for id: ${id}` });
      return;
    }
    json(res, 200, { community: communitySummary(community) });
    return;
  }

  if (req.method === "POST" && url.pathname.match(/^\/v1\/communities\/[^/]+\/join$/)) {
    const user = await requireUser(req, res);
    if (!user) return;
    const communityId = decodeURIComponent(url.pathname.split("/")[3]);
    const community = communities.get(communityId);
    if (!community) {
      json(res, 404, { error: "community_not_found", message: `No community found for id: ${communityId}` });
      return;
    }
    await joinCommunity(user.id, communityId);
    community.members = Array.from(new Set([...(community.members || []), user.id]));
    communities.set(communityId, community);
    json(res, 200, { status: "joined" });
    return;
  }

  if (req.method === "POST" && url.pathname.match(/^\/v1\/communities\/[^/]+\/leave$/)) {
    const user = await requireUser(req, res);
    if (!user) return;
    const communityId = decodeURIComponent(url.pathname.split("/")[3]);
    const community = communities.get(communityId);
    if (!community) {
      json(res, 404, { error: "community_not_found", message: `No community found for id: ${communityId}` });
      return;
    }
    await leaveCommunity(user.id, communityId);
    community.members = (community.members || []).filter((memberId) => memberId !== user.id);
    communities.set(communityId, community);
    json(res, 200, { status: "left" });
    return;
  }

  if (req.method === "GET" && url.pathname.match(/^\/v1\/communities\/[^/]+\/members$/)) {
    const user = await requireUser(req, res);
    if (!user) return;
    const communityId = decodeURIComponent(url.pathname.split("/")[3]);
    const community = communities.get(communityId);
    if (!community) {
      json(res, 404, { error: "community_not_found", message: `No community found for id: ${communityId}` });
      return;
    }
    const joinedCommunityIds = await getJoinedCommunities(user.id);
    if (!joinedCommunityIds.includes(communityId)) {
      json(res, 403, { error: "community_membership_required", message: "Join this community before viewing members." });
      return;
    }
    const members = await getCommunityMembers(communityId);
    json(res, 200, { members });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/meetings/rsvp") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const kind = String(body.kind || "");
      if (!["circle", "community"].includes(kind)) {
        json(res, 400, { error: "invalid_meeting_kind", message: "kind must be circle or community." });
        return;
      }
      await saveMeetingRsvp(user.id, kind, Boolean(body.available));
      json(res, 200, { status: "updated", kind, available: Boolean(body.available) });
    } catch (error) {
      json(res, 400, { error: "invalid_rsvp", message: error.message });
    }
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/meetings/upcoming") {
    const user = await requireUser(req, res);
    if (!user) return;
    const now = Date.now();
    const rsvps = await getUserMeetingRsvps(user.id);
    const meetings = (await listMeetingsForUser(user.id)).map((meeting) => meetingSummary(meeting, user.id));
    json(res, 200, {
      rsvps: {
        circle: rsvps.find((row) => row.kind === "circle")?.available || false,
        community: rsvps.find((row) => row.kind === "community")?.available || false
      },
      upcoming: meetings.filter((meeting) => Date.parse(meeting.scheduledAt) >= now),
      past: meetings.filter((meeting) => Date.parse(meeting.scheduledAt) < now)
    });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/meetings") {
    const user = await requireUser(req, res);
    if (!user) return;
    const body = await readJsonBody(req).catch(() => null);
    const kind = String(body?.kind || "community");
    const title = String(body?.title || "").trim();
    const scheduledAt = String(body?.scheduledAt || "").trim();
    const location = String(body?.location || "").trim();
    const details = String(body?.details || "").trim();
    const targetId = String(body?.targetId || "").trim();
    if (!["circle", "community"].includes(kind) || !title || Number.isNaN(Date.parse(scheduledAt))) {
      json(res, 400, { error: "invalid_meeting", message: "kind, title, and a valid scheduledAt are required." });
      return;
    }
    const meeting = {
      id: `meeting-${generateId()}`,
      kind,
      targetId: targetId || kind,
      title,
      scheduledAt,
      hostUserId: user.id,
      hostName: user.fullName || "Community host",
      participantIds: [user.id],
      groupSize: 1,
      status: "scheduled",
      location,
      compositionSummary: details || "Member-hosted event.",
      recapNotes: {},
      createdAt: new Date().toISOString()
    };
    await saveMeeting(meeting);
    json(res, 201, { meeting: meetingSummary(meeting, user.id) });
    return;
  }

  if (req.method === "POST" && url.pathname.match(/^\/v1\/meetings\/[^/]+\/recap-note$/)) {
    const user = await requireUser(req, res);
    if (!user) return;
    const meetingId = decodeURIComponent(url.pathname.split("/")[3]);
    const body = await readJsonBody(req);
    const note = typeof body.note === "string" ? body.note.trim().slice(0, 2000) : "";
    const saved = await saveMeetingRecapNote(user.id, meetingId, note);
    if (saved === null) {
      json(res, 404, { error: "meeting_not_found", message: "No accessible meeting found for this recap." });
      return;
    }
    json(res, 200, { status: "saved", recapNote: saved });
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/me/notifications") {
    const user = await requireUser(req, res);
    if (!user) return;
    const meetings = (await listMeetingsForUser(user.id)).map((meeting) => meetingSummary(meeting, user.id));
    const joinedCommunities = (await getJoinedCommunities(user.id)).map(communitySummary);
    const matches = await getSoulmateMatches(user.id);
    const notifications = [];
    const activity = [];

    for (const meeting of meetings.slice(0, 3)) {
      notifications.push({
        id: `meeting-${meeting.id}`,
        title: meeting.title,
        detail: meeting.compositionSummary || "A meetup is ready for you.",
        createdAt: meeting.scheduledAt,
        kind: "meeting"
      });
      activity.push({
        id: `activity-meeting-${meeting.id}`,
        title: `You have a ${meeting.kind} meetup: ${meeting.title}`,
        detail: meeting.hostName || null,
        createdAt: meeting.scheduledAt,
        kind: "meeting"
      });
    }

    for (const community of joinedCommunities.slice(0, 3)) {
      activity.push({
        id: `activity-community-${community.id}`,
        title: `You joined ${community.name}`,
        detail: community.summary || null,
        createdAt: null,
        kind: "community"
      });
    }

    for (const match of matches.slice(0, 3)) {
      const response = await matchResponse(user.id, match);
      if (!response) continue;
      const summary = soulmateMatchSummary(match, response.otherProfile, response.meeting);
      notifications.push({
        id: `match-${summary.matchId}`,
        title: `New soulmate match: ${summary.name}`,
        detail: response.meeting?.title || "Matched from a recent meetup.",
        createdAt: summary.createdAt,
        kind: "soulmate"
      });
      const messages = await getMessages(summary.matchId);
      if (messages.length > 0) {
        notifications.push({
          id: `message-${messages[messages.length - 1].id}`,
          title: `New message from ${summary.name}`,
          detail: messages[messages.length - 1].text,
          createdAt: messages[messages.length - 1].createdAt,
          kind: "message"
        });
      }
    }

    if (notifications.length === 0) {
      notifications.push({
        id: "profile-ready",
        title: "Your backend profile is ready",
        detail: "Profile, circles, meetups, and soulmate state are synced.",
        createdAt: new Date().toISOString(),
        kind: "profile"
      });
    }

    json(res, 200, { notifications, activity });
    return;
  }

  if (req.method === "POST" && url.pathname.match(/^\/v1\/meetings\/[^/]+\/join$/)) {
    const user = await requireUser(req, res);
    if (!user) return;
    const meetingId = decodeURIComponent(url.pathname.split("/")[3]);
    const meeting = await getMeetingById(meetingId);
    if (!meeting) {
      json(res, 404, { error: "meeting_not_found", message: `No meeting found for id: ${meetingId}` });
      return;
    }
    if (!(meeting.participantIds || []).includes(user.id)) {
      json(res, 403, { error: "meeting_forbidden", message: "Only meeting participants can join this room." });
      return;
    }
    try {
      json(res, 200, await generateParticipantToken(user.id, meetingId));
    } catch (error) {
      json(res, 503, { error: error.code || "livekit_token_failed", message: error.message });
    }
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/admin/run-scheduling") {
    const configuredSecret = process.env.SCHEDULING_ADMIN_SECRET;
    if (configuredSecret && req.headers["x-scheduling-secret"] !== configuredSecret) {
      json(res, 403, { error: "forbidden", message: "Invalid scheduling secret." });
      return;
    }
    try {
      const meetings = await runWeekendScheduling();
      json(res, 200, { status: "scheduled", meetings: meetings.map(meetingSummary) });
    } catch (error) {
      json(res, 500, { error: "scheduling_failed", message: error.message });
    }
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/me/soulmate/enable") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const enabled = Boolean(body.enabled);
      await setSoulmateEnabled(user.id, enabled);
      json(res, 200, { status: "updated", enabled });
    } catch (error) {
      json(res, 400, { error: "invalid_soulmate_status", message: error.message });
    }
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/me/soulmate/status") {
    const user = await requireUser(req, res);
    if (!user) return;
    json(res, 200, {
      enabled: await isSoulmateEnabled(user.id),
      pendingSelections: await pendingSoulmateSelections(user.id),
      preferences: await getSoulmatePreferences(user.id)
    });
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/me/soulmate/preferences") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const preferences = await setSoulmatePreferences(user.id, body);
      json(res, 200, { status: "updated", preferences });
    } catch (error) {
      json(res, 400, { error: "invalid_soulmate_preferences", message: error.message });
    }
    return;
  }

  if (req.method === "POST" && url.pathname === "/v1/me/soulmate/select") {
    const user = await requireUser(req, res);
    if (!user) return;
    try {
      const body = await readJsonBody(req);
      const meetingId = String(body.meetingId || "");
      const selectedUserIds = Array.isArray(body.selectedUserIds) ? body.selectedUserIds.map(String) : [];
      const meeting = await getMeetingById(meetingId);
      if (!meeting || !(meeting.participantIds || []).includes(user.id)) {
        json(res, 404, { error: "meeting_not_found", message: "No soulmate-eligible meeting found for this user." });
        return;
      }
      const validSelectedUserIds = selectedUserIds.filter((selectedUserId) => (meeting.participantIds || []).includes(selectedUserId) && selectedUserId !== user.id);
      const result = await saveSoulmateSelection(user.id, meetingId, validSelectedUserIds);
      json(res, 200, { status: "saved", newMatches: result.newMatches });
    } catch (error) {
      json(res, 400, { error: "invalid_soulmate_selection", message: error.message });
    }
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/me/soulmate/matches") {
    const user = await requireUser(req, res);
    if (!user) return;
    const matches = [];
    await archiveStaleMatches();
    for (const match of await getSoulmateMatches(user.id)) {
      const response = await matchResponse(user.id, match);
      if (response) matches.push(soulmateMatchSummary(match, response.otherProfile, response.meeting));
    }
    json(res, 200, matches);
    return;
  }

  if (req.method === "GET" && url.pathname === "/v1/me/soulmate/past") {
    const user = await requireUser(req, res);
    if (!user) return;
    const matches = [];
    await archiveStaleMatches();
    for (const match of await getSoulmateMatches(user.id, { archived: true })) {
      const response = await matchResponse(user.id, match);
      if (response) matches.push(soulmateMatchSummary(match, response.otherProfile, response.meeting));
    }
    json(res, 200, matches);
    return;
  }

  const soulmateMessageMatch = url.pathname.match(/^\/v1\/me\/soulmate\/matches\/([^/]+)\/messages$/);
  if (soulmateMessageMatch && req.method === "GET") {
    const user = await requireUser(req, res);
    if (!user) return;
    const matchId = decodeURIComponent(soulmateMessageMatch[1]);
    const match = await getSoulmateMatch(user.id, matchId);
    if (!match) {
      json(res, 404, { error: "match_not_found", message: "No soulmate match found for this user." });
      return;
    }
    json(res, 200, { messages: await getMessages(matchId, url.searchParams.get("after")) });
    return;
  }

  if (soulmateMessageMatch && req.method === "POST") {
    const user = await requireUser(req, res);
    if (!user) return;
    const matchId = decodeURIComponent(soulmateMessageMatch[1]);
    const match = await getSoulmateMatch(user.id, matchId);
    if (!match) {
      json(res, 404, { error: "match_not_found", message: "No soulmate match found for this user." });
      return;
    }
    try {
      const body = await readJsonBody(req);
      const text = typeof body.text === "string" ? body.text.trim() : "";
      if (!text) {
        json(res, 400, { error: "invalid_message", message: "text is required." });
        return;
      }
      json(res, 201, { message: await saveMessage(matchId, user.id, text) });
    } catch (error) {
      json(res, 400, { error: "invalid_message", message: error.message });
    }
    return;
  }

  const soulmateDetailMatch = url.pathname.match(/^\/v1\/me\/soulmate\/matches\/([^/]+)$/);
  if (soulmateDetailMatch && req.method === "GET") {
    const user = await requireUser(req, res);
    if (!user) return;
    const matchId = decodeURIComponent(soulmateDetailMatch[1]);
    const match = await getSoulmateMatch(user.id, matchId);
    if (!match) {
      json(res, 404, { error: "match_not_found", message: "No soulmate match found for this user." });
      return;
    }
    const response = await matchResponse(user.id, match);
    if (!response) {
      json(res, 404, { error: "match_profile_not_found", message: "The match profile is unavailable." });
      return;
    }
    json(res, 200, soulmateMatchDetail(match, response.otherProfile, response.meeting));
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

  if (req.method === "DELETE" && url.pathname === "/v1/me/account") {
    const user = await requireUser(req, res);
    if (!user) return;
    await deleteUserAccount(user.id);
    json(res, 200, { status: "deleted" });
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
    const user = await currentUser(req);
    const id = decodeURIComponent(url.pathname.split("/").pop());
    const circle = circles.get(id);
    if (!circle) {
      json(res, 404, { error: "circle_not_found", message: `No circle found for id: ${id}` });
      return;
    }
    const profile = user ? await getLatestProfile(user.id) : null;
    const fitScore = profile?.signals ? computeCircleFit(profile.signals, circle) : null;
    json(res, 200, {
      circle: {
        ...circleSummary(circle),
        description: circle.description,
        interactionIntent: circle.interactionIntent,
        socialFormat: circle.socialFormat,
        fitBreakdown: fitScore === null ? [] : [{ dimension: "overall", score: Math.round(fitScore * 100) / 100 }]
      }
    });
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
