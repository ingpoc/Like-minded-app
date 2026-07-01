const { AccessToken, RoomServiceClient } = require("livekit-server-sdk");

function requireLiveKitEnv() {
  const { LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_URL } = process.env;
  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL) {
    const error = new Error("Set LIVEKIT_API_KEY, LIVEKIT_API_SECRET, and LIVEKIT_URL on the API server.");
    error.code = "livekit_env_missing";
    throw error;
  }
  return { apiKey: LIVEKIT_API_KEY, apiSecret: LIVEKIT_API_SECRET, url: LIVEKIT_URL };
}

async function createRoom(meetingId) {
  const { apiKey, apiSecret, url } = requireLiveKitEnv();
  const service = new RoomServiceClient(url, apiKey, apiSecret);
  try {
    await service.createRoom({ name: meetingId, emptyTimeout: 10 * 60, maxParticipants: 10 });
  } catch (error) {
    if (!String(error.message || "").toLowerCase().includes("already exists")) throw error;
  }
  return { roomName: meetingId, url };
}

async function generateParticipantToken(userId, meetingId) {
  const { apiKey, apiSecret, url } = requireLiveKitEnv();
  const token = new AccessToken(apiKey, apiSecret, { identity: userId, ttl: "2h" });
  token.addGrant({ room: meetingId, roomJoin: true, canPublish: true, canSubscribe: true });
  return { token: await token.toJwt(), url };
}

module.exports = {
  createRoom,
  generateParticipantToken
};
