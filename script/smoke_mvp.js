#!/usr/bin/env node
const assert = require("node:assert/strict");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "likeminded-mvp-"));
const port = String(19000 + Math.floor(Math.random() * 1000));
const baseURL = `http://127.0.0.1:${port}`;

const child = spawn(process.execPath, ["services/api/src/server.js"], {
  cwd: root,
  env: {
    ...process.env,
    PORT: port,
    HOST: "127.0.0.1",
    LIKEMINDED_DB_DIR: tmp,
    SESSION_SECRET: "local-smoke-secret-minimum-24-chars",
    APPLE_AUTH_BYPASS: "1",
    OPENAI_API_KEY: "",
    OPENAI_REALTIME_MODEL: "gpt-realtime-mini",
    OPENAI_REALTIME_VOICE: "marin",
    LIVEKIT_API_KEY: "devkey",
    LIVEKIT_API_SECRET: "devsecretdevsecretdevsecret",
    LIVEKIT_URL: "ws://127.0.0.1:7880"
  },
  stdio: ["ignore", "pipe", "pipe"]
});

let output = "";
child.stdout.on("data", (chunk) => { output += chunk.toString(); });
child.stderr.on("data", (chunk) => { output += chunk.toString(); });

function stop() {
  child.kill("SIGTERM");
  fs.rmSync(tmp, { recursive: true, force: true });
}

async function request(pathname, options = {}) {
  const response = await fetch(`${baseURL}${pathname}`, {
    ...options,
    headers: {
      ...(options.body ? { "content-type": "application/json" } : {}),
      ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
      ...(options.headers || {})
    },
    body: options.rawBody ?? (options.body ? JSON.stringify(options.body) : undefined)
  });
  const text = await response.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  return { response, body };
}

async function waitForHealth() {
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    try {
      const { response, body } = await request("/health");
      if (response.status === 200 && body.status === "ok") return body;
    } catch {
      // Server is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error(`API did not become healthy:\n${output}`);
}

async function expectStatus(status, pathname, options) {
  const result = await request(pathname, options);
  assert.equal(result.response.status, status, `${pathname} expected ${status}, got ${result.response.status}: ${JSON.stringify(result.body)}`);
  return result.body;
}

(async () => {
  try {
    const health = await waitForHealth();
    assert.equal(health.db, "local-json");

    const privacy = await request("/privacy");
    assert.equal(privacy.response.status, 200);
    assert.match(privacy.response.headers.get("content-type") || "", /^text\/html/);
    assert.match(privacy.body, /Retention And Deletion/);

    await expectStatus(401, "/v1/discover", { method: "POST", body: {} });
    await expectStatus(401, "/v1/realtime/session", { method: "POST", body: {} });
    await expectStatus(401, "/v1/realtime/profile-placement", { method: "POST", body: {} });
    await expectStatus(404, "/v1/realtime/calls", {
      method: "POST",
      headers: { "content-type": "application/sdp" },
      rawBody: "v=0"
    });
    await expectStatus(401, "/v1/me/profile", { method: "GET" });
    await expectStatus(401, "/v1/me/placement", { method: "GET" });
    await expectStatus(401, "/v1/feedback", { method: "POST", body: { rating: 4, message: "blocked" } });

    const auth = await expectStatus(200, "/v1/auth/apple", {
      method: "POST",
      body: { identityToken: "tester-one", fullName: "Tester One" }
    });
    assert.ok(auth.sessionToken, "auth must return a session token");
    assert.ok(auth.user.id, "auth must return a user id");
    const initialPrimaryCircle = await expectStatus(200, "/v1/circles/reflective-builders", { method: "GET", token: auth.sessionToken });
    const initialPrimaryCircleCount = initialPrimaryCircle.circle.membersCount;

    const coercedPlacement = await expectStatus(201, "/v1/realtime/profile-placement", {
      method: "POST",
      token: auth.sessionToken,
      body: {
        signals: {},
        primaryCircleId: "reflective-builders",
        secondaryCircleIds: "longform-thinkers",
        fitReasons: "not an array",
        sourceReflectionSignals: ["kept", 7]
      }
    });
    assert.deepEqual(coercedPlacement.placement.fitReasons, []);
    assert.deepEqual(coercedPlacement.placement.sourceReflectionSignals, ["kept"]);

    const transcript = "I like honest conversations, thoughtful friends, small warm circles, design, books, and steady trust.";
    const discovered = await expectStatus(200, "/v1/discover", {
      method: "POST",
      token: auth.sessionToken,
      body: { interviewTranscript: transcript, reflectionAnswers: ["I want a calm circle", "I prefer warm direct people"] }
    });
    assert.ok(discovered.profileId, "discover must return profileId");
    assert.ok(discovered.placement?.primaryCircle?.id, "discover must return a primary circle");

    const realtimePlacementBody = {
      interviewTranscript: "User: I want small, thoughtful circles.\nAI: I will place you with a warm direct group.",
      signals: {
        bigFive: { openness: 0.75, conscientiousness: 0.7, extraversion: 0.35, agreeableness: 0.82, neuroticism: 0.32 },
        attachment: "secure",
        socialEnergy: "low-to-medium",
        communicationStyle: { primary: "direct", pace: 0.42 },
        trustPattern: "slow earned trust",
        humorStyle: "dry",
        conflictStyle: "clear and kind"
      },
      primaryCircleId: "reflective-builders",
      secondaryCircleIds: ["longform-thinkers"],
      fitReasons: ["Prefers small warm rooms.", "Names direct communication and steady trust."],
      sourceReflectionSignals: ["Small thoughtful circles.", "Warm direct group."],
      profileSummary: "Looks for warm, direct, low-pressure connection."
    };
    const realtimePlaced = await expectStatus(201, "/v1/realtime/profile-placement", {
      method: "POST",
      token: auth.sessionToken,
      headers: { "idempotency-key": "smoke-realtime-placement-1" },
      body: realtimePlacementBody
    });
    assert.equal(realtimePlaced.synthesisMode, "realtime_tool");
    assert.ok(realtimePlaced.profileId, "Realtime placement must return profileId");
    const realtimeReplay = await expectStatus(201, "/v1/realtime/profile-placement", {
      method: "POST",
      token: auth.sessionToken,
      headers: { "idempotency-key": "smoke-realtime-placement-1" },
      body: realtimePlacementBody
    });
    assert.equal(realtimeReplay.placementId, realtimePlaced.placementId, "idempotent retry must return the original placement");
    assert.equal(realtimeReplay.synthesisMode, "idempotent_replay");

    const profile = await expectStatus(200, "/v1/me/profile", { method: "GET", token: auth.sessionToken });
    assert.equal(profile.profile.profileId, realtimePlaced.profileId);

    const editedSummary = "Simulator edited private profile summary.";
    const updatedProfile = await expectStatus(200, "/v1/me/profile", {
      method: "PATCH",
      token: auth.sessionToken,
      body: { reflectionSummary: editedSummary }
    });
    assert.equal(updatedProfile.profile.reflection.summary, editedSummary);
    const resumedProfile = await expectStatus(200, "/v1/me/profile", { method: "GET", token: auth.sessionToken });
    assert.equal(resumedProfile.profile.reflection.summary, editedSummary);

    await expectStatus(400, "/v1/me/profile", {
      method: "PATCH",
      token: auth.sessionToken,
      body: {
        basicInfo: { name: "A", city: "P", dateOfBirth: "2026-01-01" },
        interests: []
      }
    });
    const replacedBasics = await expectStatus(200, "/v1/me/profile", {
      method: "PATCH",
      token: auth.sessionToken,
      body: {
        basicInfo: { name: "Maya", city: "Pune", dateOfBirth: "1995-04-10" },
        interests: [
          { area: "general", label: "Design", depth: "active" },
          { area: "general", label: "Urban gardening", depth: "active" }
        ]
      }
    });
    assert.deepEqual(replacedBasics.profile.interests.map((interest) => interest.label).sort(), ["Design", "Urban gardening"]);

    const placement = await expectStatus(200, "/v1/me/placement", { method: "GET", token: auth.sessionToken });
    assert.equal(placement.profileId, realtimePlaced.profileId);
    assert.ok(placement.placementId, "resume placement must include placementId");

    const myCircles = await expectStatus(200, "/v1/me/circles", { method: "GET", token: auth.sessionToken });
    assert.ok(Array.isArray(myCircles.circles), "user circles endpoint must return an array");
    assert.equal(myCircles.circles.length, 0, "proposed placement must not join a circle before acceptance");
    const circleDetail = await expectStatus(200, "/v1/circles/reflective-builders", { method: "GET", token: auth.sessionToken });
    assert.equal(circleDetail.circle.id, "reflective-builders");
    assert.equal(circleDetail.circle.membersCount, initialPrimaryCircleCount, "proposed placement must not change circle membership");

    for (const [action, expectedState] of [["defer", "deferred"], ["accept", "accepted"]]) {
      const updated = await expectStatus(200, "/v1/me/placement/actions", {
        method: "POST",
        token: auth.sessionToken,
        body: { action }
      });
      assert.equal(updated.placement.userState, expectedState);
      const circlesAfterAction = await expectStatus(200, "/v1/me/circles", { method: "GET", token: auth.sessionToken });
      assert.equal(
        circlesAfterAction.circles.some((circle) => circle.id === "reflective-builders"),
        action === "accept",
        `${action} must ${action === "accept" ? "add" : "not add"} primary-circle membership`
      );
    }

    const acceptedCircleDetail = await expectStatus(200, "/v1/circles/reflective-builders", { method: "GET", token: auth.sessionToken });
    assert.equal(acceptedCircleDetail.circle.membersCount, initialPrimaryCircleCount + 1, "accept must add exactly one primary-circle member");

    const secondaryPick = await expectStatus(200, "/v1/me/placement/actions", {
      method: "POST",
      token: auth.sessionToken,
      body: { action: "select_secondary", circleId: "longform-thinkers" }
    });
    assert.equal(secondaryPick.placement.selectedSecondaryCircleId, "longform-thinkers");

    await expectStatus(201, "/v1/feedback", {
      method: "POST",
      token: auth.sessionToken,
      body: {
        profileId: realtimePlaced.profileId,
        placementId: placement.placementId,
        rating: 5,
        message: "Placement loop works.",
        appVersion: "0.1.0"
      }
    });

    await expectStatus(200, "/v1/meetings/rsvp", {
      method: "POST",
      token: auth.sessionToken,
      body: { kind: "circle", available: true }
    });
    await expectStatus(200, "/v1/meetings/rsvp", {
      method: "POST",
      token: auth.sessionToken,
      body: { kind: "community", available: true }
    });
    const initialMeetings = await expectStatus(200, "/v1/meetings/upcoming", { method: "GET", token: auth.sessionToken });
    assert.equal(initialMeetings.rsvps.circle, true);
    assert.equal(initialMeetings.rsvps.community, true);

    const communities = await expectStatus(200, "/v1/communities", { method: "GET", token: auth.sessionToken });
    assert.ok(communities.communities.length >= 1, "communities catalog must not be empty");
    const communityId = communities.communities[0].id;
    const joined = await expectStatus(200, `/v1/communities/${communityId}/join`, { method: "POST", token: auth.sessionToken });
    assert.equal(joined.status, "joined");
    const myCommunities = await expectStatus(200, "/v1/me/communities", { method: "GET", token: auth.sessionToken });
    assert.ok(myCommunities.communities.some((community) => community.id === communityId), "joined community must appear in user communities");
    const communityReport = await expectStatus(201, `/v1/communities/${communityId}/report`, {
      method: "POST",
      token: auth.sessionToken,
      body: { reason: "Smoke-test community report" }
    });
    assert.equal(communityReport.status, "reported");

    let scheduledParticipantToken = null;
    const scheduledUsers = [];
    for (let index = 2; index <= 7; index += 1) {
      const user = await expectStatus(200, "/v1/auth/apple", {
        method: "POST",
        body: { identityToken: `tester-${index}`, fullName: `Tester ${index}` }
      });
      scheduledParticipantToken = user.sessionToken;
      scheduledUsers.push(user);
      await expectStatus(201, "/v1/realtime/profile-placement", {
        method: "POST",
        token: user.sessionToken,
        body: {
          signals: {
            bigFive: { openness: 0.8, conscientiousness: 0.7, extraversion: 0.55, agreeableness: 0.8, neuroticism: 0.3 },
            socialEnergy: index % 2 === 0 ? "medium" : "high",
            communicationStyle: { primary: "warm", pace: 0.5 },
            trustPattern: "fastTrust",
            conflictStyle: "accommodating"
          },
          basicInfo: { name: `Tester ${index}`, gender: index % 2 === 0 ? "male" : "female", dateOfBirth: "1990-01-01", city: "Pune", pincode: "411001" },
          primaryCircleId: "reflective-builders",
          fitReasons: ["Warm group fit"],
          sourceReflectionSignals: ["Small thoughtful circles"],
          profileSummary: "Warm, thoughtful meetup participant."
        }
      });
      await expectStatus(200, "/v1/meetings/rsvp", {
        method: "POST",
        token: user.sessionToken,
        body: { kind: "circle", available: true }
      });
      await expectStatus(200, "/v1/me/soulmate/enable", {
        method: "POST",
        token: user.sessionToken,
        body: { enabled: true }
      });
    }

    const scheduled = await expectStatus(200, "/v1/admin/run-scheduling", { method: "POST" });
    assert.ok(scheduled.meetings.length >= 1, "scheduling must create at least one meeting");
    const upcoming = await expectStatus(200, "/v1/meetings/upcoming", { method: "GET", token: scheduledParticipantToken });
    assert.ok(upcoming.upcoming.length >= 1, "user must see scheduled meeting");
    const join = await expectStatus(200, `/v1/meetings/${upcoming.upcoming[0].id}/join`, { method: "POST", token: scheduledParticipantToken });
    assert.ok(join.token, "LiveKit join must return a token");
    assert.equal(join.url, "ws://127.0.0.1:7880");

    const recapNote = "Private recap note from smoke.";
    await expectStatus(200, `/v1/meetings/${upcoming.upcoming[0].id}/recap-note`, {
      method: "POST",
      token: scheduledParticipantToken,
      body: { note: recapNote }
    });
    const recapReadback = await expectStatus(200, "/v1/meetings/upcoming", { method: "GET", token: scheduledParticipantToken });
    assert.equal(recapReadback.upcoming[0].recapNote, recapNote, "meeting recap note must persist per user");

    const soulmateStatus = await expectStatus(200, "/v1/me/soulmate/status", { method: "GET", token: scheduledUsers[0].sessionToken });
    assert.equal(soulmateStatus.enabled, true);
    assert.ok(soulmateStatus.preferences, "soulmate status must include preferences");
    assert.equal(soulmateStatus.preferences.visibility, "circles_only");
    const updatedPrefs = await expectStatus(200, "/v1/me/soulmate/preferences", {
      method: "POST",
      token: scheduledUsers[0].sessionToken,
      body: { discovery: "communities", ageMin: 24, ageMax: 34, visibility: "matches_only" }
    });
    assert.equal(updatedPrefs.preferences.discovery, "communities");
    assert.equal(updatedPrefs.preferences.ageMin, 24);
    assert.equal(updatedPrefs.preferences.visibility, "matches_only");
    assert.ok(soulmateStatus.pendingSelections.some((selection) => selection.meetingId === upcoming.upcoming[0].id), "soulmate status must expose pending meetup selection");

    const firstPick = await expectStatus(200, "/v1/me/soulmate/select", {
      method: "POST",
      token: scheduledUsers[0].sessionToken,
      body: { meetingId: upcoming.upcoming[0].id, selectedUserIds: [scheduledUsers[1].user.id] }
    });
    assert.deepEqual(firstPick.newMatches, []);
    const secondPick = await expectStatus(200, "/v1/me/soulmate/select", {
      method: "POST",
      token: scheduledUsers[1].sessionToken,
      body: { meetingId: upcoming.upcoming[0].id, selectedUserIds: [scheduledUsers[0].user.id] }
    });
    assert.equal(secondPick.newMatches.length, 1, "mutual soulmate selection must create one match");

    const matches = await expectStatus(200, "/v1/me/soulmate/matches", { method: "GET", token: scheduledUsers[0].sessionToken });
    assert.equal(matches.length, 1);
    const detail = await expectStatus(200, `/v1/me/soulmate/matches/${matches[0].matchId}`, { method: "GET", token: scheduledUsers[0].sessionToken });
    assert.equal(detail.basicInfo.name, "Tester 3");
    assert.ok(Array.isArray(detail.interests), "soulmate detail must expose interests");
    assert.equal(detail.hiddenSignals, undefined, "soulmate detail must not expose hidden signals");

    const sent = await expectStatus(201, `/v1/me/soulmate/matches/${matches[0].matchId}/messages`, {
      method: "POST",
      token: scheduledUsers[0].sessionToken,
      body: { text: "Good to meet you." }
    });
    assert.equal(sent.message.text, "Good to meet you.");
    const messages = await expectStatus(200, `/v1/me/soulmate/matches/${matches[0].matchId}/messages`, { method: "GET", token: scheduledUsers[1].sessionToken });
    assert.equal(messages.messages.length, 1, "match participant must read chat messages");

    // Seeded native parity: notifications + authorized community members
    const notifications = await expectStatus(200, "/v1/me/notifications", { method: "GET", token: scheduledUsers[0].sessionToken });
    assert.ok(Array.isArray(notifications.notifications), "notifications response must include a notifications array");
    assert.ok(Array.isArray(notifications.activity), "notifications response must include an activity array");

    await expectStatus(403, `/v1/communities/${communityId}/members`, { method: "GET", token: scheduledUsers[0].sessionToken });
    const communityMembers = await expectStatus(200, `/v1/communities/${communityId}/members`, { method: "GET", token: auth.sessionToken });
    assert.ok(Array.isArray(communityMembers.members), "community members response must include a members array");
    assert.ok(communityMembers.members.some((member) => member.name), "community members must expose at least one name");
    assert.equal(communityMembers.members[0].hiddenSignals, undefined, "community members must not expose hidden signals");

    const secondAuth = await expectStatus(200, "/v1/auth/apple", {
      method: "POST",
      body: { identityToken: "tester-no-placement", fullName: "Tester No Placement" }
    });
    await expectStatus(404, "/v1/me/placement", { method: "GET", token: secondAuth.sessionToken });

    const deleteAuth = await expectStatus(200, "/v1/auth/apple", {
      method: "POST",
      body: { identityToken: "tester-delete", fullName: "Tester Delete" }
    });
    await expectStatus(201, "/v1/realtime/profile-placement", {
      method: "POST",
      token: deleteAuth.sessionToken,
      body: {
        interviewTranscript: "Delete test profile.",
        primaryCircleId: "reflective-builders",
        profileSummary: "Temporary profile for account deletion."
      }
    });
    await expectStatus(200, "/v1/me/profile", { method: "GET", token: deleteAuth.sessionToken });
    await expectStatus(200, "/v1/me/account", { method: "DELETE", token: deleteAuth.sessionToken });
    await expectStatus(401, "/v1/me/profile", { method: "GET", token: deleteAuth.sessionToken });

    console.log("MVP smoke passed");
  } finally {
    stop();
  }
})().catch((error) => {
  stop();
  console.error(error.stack || error.message);
  process.exit(1);
});
