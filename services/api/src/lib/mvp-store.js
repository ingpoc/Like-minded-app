const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { Pool } = require("pg");

const isPostgres = !!process.env.DATABASE_URL;
const LOCAL_DIR = path.resolve(process.env.LIKEMINDED_DB_DIR || path.join(process.cwd(), "data"));
const LOCAL_PATH = path.join(LOCAL_DIR, "mvp-store.json");
let pool;

function userIdForAppleSub(appleSub) {
  return `usr_${crypto.createHash("sha256").update(appleSub).digest("hex").slice(0, 24)}`;
}

function getPool() {
  if (!pool) {
    pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.DATABASE_SSL === "0" ? false : { rejectUnauthorized: false }
    });
  }
  return pool;
}

function emptyLocalStore() {
  return {
    users: {},
    profiles: [],
    placements: [],
    transcripts: [],
    feedback: [],
    communityMemberships: [],
    meetingRsvps: [],
    meetings: [],
    soulmateUsers: {},
    soulmateSelections: [],
    soulmateMatches: [],
    chatMessages: []
  };
}

function readLocalStore() {
  fs.mkdirSync(LOCAL_DIR, { recursive: true });
  if (!fs.existsSync(LOCAL_PATH)) {
    const store = emptyLocalStore();
    writeLocalStore(store);
    return store;
  }
  return { ...emptyLocalStore(), ...JSON.parse(fs.readFileSync(LOCAL_PATH, "utf8")) };
}

function writeLocalStore(store) {
  fs.mkdirSync(LOCAL_DIR, { recursive: true });
  fs.writeFileSync(LOCAL_PATH, JSON.stringify(store, null, 2));
}

async function migrateMvpStore() {
  if (!isPostgres) {
    readLocalStore();
    return;
  }
  await getPool().query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      apple_sub TEXT NOT NULL UNIQUE,
      email TEXT,
      full_name TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS profiles (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      data JSONB NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS circles (
      id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS placements (
      id BIGSERIAL PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
      data JSONB NOT NULL,
      user_state TEXT NOT NULL DEFAULT 'proposed',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS transcripts (
      id BIGSERIAL PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      profile_id TEXT REFERENCES profiles(id) ON DELETE SET NULL,
      content TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS feedback (
      id BIGSERIAL PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      profile_id TEXT,
      placement_id TEXT,
      rating INTEGER CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
      message TEXT,
      app_version TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS community_memberships (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      community_id TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, community_id)
    );

    CREATE TABLE IF NOT EXISTS meeting_rsvps (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      kind TEXT NOT NULL,
      available BOOLEAN NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, kind)
    );

    CREATE TABLE IF NOT EXISTS meetings (
      id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS soulmate_users (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      enabled BOOLEAN NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS soulmate_selections (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      meeting_id TEXT NOT NULL,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, meeting_id)
    );

    CREATE TABLE IF NOT EXISTS soulmate_matches (
      id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS chat_messages (
      id TEXT PRIMARY KEY,
      match_id TEXT NOT NULL,
      data JSONB NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}

async function upsertAppleUser({ appleSub, email, fullName }) {
  const id = userIdForAppleSub(appleSub);
  const now = new Date().toISOString();
  if (isPostgres) {
    const result = await getPool().query(
      `INSERT INTO users (id, apple_sub, email, full_name, created_at, updated_at)
       VALUES ($1, $2, $3, $4, now(), now())
       ON CONFLICT (apple_sub) DO UPDATE
       SET email = COALESCE(EXCLUDED.email, users.email),
           full_name = COALESCE(EXCLUDED.full_name, users.full_name),
           updated_at = now()
       RETURNING id, apple_sub, email, full_name`,
      [id, appleSub, email || null, fullName || null]
    );
    return rowToUser(result.rows[0]);
  }

  const store = readLocalStore();
  const existing = Object.values(store.users).find((user) => user.apple_sub === appleSub);
  store.users[id] = {
    id,
    apple_sub: appleSub,
    email: email || existing?.email || null,
    full_name: fullName || existing?.full_name || null,
    created_at: existing?.created_at || now,
    updated_at: now
  };
  writeLocalStore(store);
  return rowToUser(store.users[id]);
}

async function getUserById(id) {
  if (isPostgres) {
    const result = await getPool().query("SELECT id, apple_sub, email, full_name FROM users WHERE id = $1", [id]);
    return rowToUser(result.rows[0]);
  }
  return rowToUser(readLocalStore().users[id]);
}

async function saveProfilePlacement({ userId, profile, placement, transcript }) {
  const now = new Date().toISOString();
  const profileData = JSON.stringify(profile);
  const placementData = JSON.stringify(placement);
  if (isPostgres) {
    const client = await getPool().connect();
    try {
      await client.query("BEGIN");
      await client.query(
        "INSERT INTO profiles (id, user_id, data, created_at) VALUES ($1, $2, $3::jsonb, now()) ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data",
        [profile.profileId, userId, profileData]
      );
      const placed = await client.query(
        "INSERT INTO placements (user_id, profile_id, data, user_state, created_at, updated_at) VALUES ($1, $2, $3::jsonb, $4, now(), now()) RETURNING id",
        [userId, profile.profileId, placementData, placement.userState || "proposed"]
      );
      if (transcript) {
        await client.query(
          "INSERT INTO transcripts (user_id, profile_id, content, created_at) VALUES ($1, $2, $3, now())",
          [userId, profile.profileId, transcript]
        );
      }
      await client.query("COMMIT");
      return { placementId: String(placed.rows[0].id) };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  const store = readLocalStore();
  store.profiles = store.profiles.filter((row) => row.id !== profile.profileId);
  store.profiles.push({ id: profile.profileId, user_id: userId, data: profile, created_at: now });
  const placementId = String(store.placements.reduce((max, row) => Math.max(max, Number(row.id) || 0), 0) + 1);
  store.placements.push({
    id: placementId,
    user_id: userId,
    profile_id: profile.profileId,
    data: placement,
    user_state: placement.userState || "proposed",
    created_at: now,
    updated_at: now
  });
  if (transcript) {
    const transcriptId = String(store.transcripts.reduce((max, row) => Math.max(max, Number(row.id) || 0), 0) + 1);
    store.transcripts.push({ id: transcriptId, user_id: userId, profile_id: profile.profileId, content: transcript, created_at: now });
  }
  writeLocalStore(store);
  return { placementId };
}

async function getLatestProfile(userId) {
  if (isPostgres) {
    const result = await getPool().query("SELECT data FROM profiles WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1", [userId]);
    return result.rows[0]?.data || null;
  }
  const profiles = readLocalStore().profiles
    .filter((profile) => profile.user_id === userId);
  if (!profiles.length) return null;
  let latest = profiles[0];
  for (let i = 1; i < profiles.length; i++) {
    if (profiles[i].created_at >= latest.created_at) latest = profiles[i];
  }
  return latest?.data || null;
}

async function getLatestPlacement(userId) {
  if (isPostgres) {
    const result = await getPool().query("SELECT id, profile_id, data FROM placements WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1", [userId]);
    return rowToPlacement(result.rows[0]);
  }
  const placements = readLocalStore().placements
    .filter((placement) => placement.user_id === userId);
  if (!placements.length) return rowToPlacement(null);
  let latest = placements[0];
  for (let i = 1; i < placements.length; i++) {
    if (placements[i].created_at >= latest.created_at) latest = placements[i];
  }
  return rowToPlacement(latest);
}

async function updateLatestProfile(userId, updates) {
  const profile = await getLatestProfile(userId);
  if (!profile) return null;
  if (updates.signals) profile.signals = updates.signals;
  if (Object.prototype.hasOwnProperty.call(updates, "concernFlag")) profile.concernFlag = !!updates.concernFlag;
  if (updates.reflectionSummary) {
    if (profile.profile?.reflection) profile.profile.reflection.summary = updates.reflectionSummary;
    profile.reflection = { ...(profile.reflection || {}), summary: updates.reflectionSummary };
  }
  const data = JSON.stringify(profile);
  if (isPostgres) {
    await getPool().query(
      `UPDATE profiles SET data = $1::jsonb
       WHERE id = (SELECT id FROM profiles WHERE user_id = $2 ORDER BY created_at DESC LIMIT 1)`,
      [data, userId]
    );
  } else {
    const store = readLocalStore();
    const latest = store.profiles
      .filter((row) => row.user_id === userId)
      .sort((a, b) => b.created_at.localeCompare(a.created_at))[0];
    if (latest) latest.data = JSON.parse(data);
    writeLocalStore(store);
  }
  return profile;
}

async function updateLatestPlacement(userId, action) {
  const current = await getLatestPlacement(userId);
  if (!current) return null;
  const placement = current.placement;
  if (action === "accept") placement.userState = "accepted";
  if (action === "defer") placement.userState = "deferred";
  if (action === "swap") {
    const [nextPrimary, ...rest] = placement.secondaryCircles || [];
    if (nextPrimary) {
      placement.secondaryCircles = [...rest, placement.primaryCircle];
      placement.primaryCircle = nextPrimary;
      placement.userState = "swapped";
    }
  }
  const data = JSON.stringify(placement);
  if (isPostgres) {
    await getPool().query("UPDATE placements SET data = $1::jsonb, user_state = $2, updated_at = now() WHERE id = $3", [data, placement.userState, current.id]);
  } else {
    const store = readLocalStore();
    const row = store.placements.find((placementRow) => String(placementRow.id) === String(current.id));
    if (row) {
      row.data = JSON.parse(data);
      row.user_state = placement.userState;
      row.updated_at = new Date().toISOString();
    }
    writeLocalStore(store);
  }
  return { ...current, placement };
}

async function joinCommunity(userId, communityId) {
  if (isPostgres) {
    await getPool().query(
      "INSERT INTO community_memberships (user_id, community_id, created_at) VALUES ($1, $2, now()) ON CONFLICT DO NOTHING",
      [userId, communityId]
    );
    return;
  }
  const store = readLocalStore();
  if (!store.communityMemberships.some((row) => row.user_id === userId && row.community_id === communityId)) {
    store.communityMemberships.push({ user_id: userId, community_id: communityId, created_at: new Date().toISOString() });
    writeLocalStore(store);
  }
}

async function leaveCommunity(userId, communityId) {
  if (isPostgres) {
    await getPool().query("DELETE FROM community_memberships WHERE user_id = $1 AND community_id = $2", [userId, communityId]);
    return;
  }
  const store = readLocalStore();
  store.communityMemberships = store.communityMemberships.filter((row) => !(row.user_id === userId && row.community_id === communityId));
  writeLocalStore(store);
}

async function getJoinedCommunities(userId) {
  if (isPostgres) {
    const result = await getPool().query("SELECT community_id FROM community_memberships WHERE user_id = $1 ORDER BY created_at", [userId]);
    return result.rows.map((row) => row.community_id);
  }
  return readLocalStore().communityMemberships
    .filter((row) => row.user_id === userId)
    .map((row) => row.community_id);
}

async function getCommunityMembers(communityId) {
  let userIds;
  if (isPostgres) {
    const result = await getPool().query("SELECT user_id FROM community_memberships WHERE community_id = $1 ORDER BY created_at", [communityId]);
    userIds = result.rows.map((row) => row.user_id);
  } else {
    userIds = readLocalStore().communityMemberships
      .filter((row) => row.community_id === communityId)
      .map((row) => row.user_id);
  }
  const members = [];
  for (const userId of userIds) {
    const profile = await getLatestProfile(userId);
    members.push({
      userId,
      name: profile?.basicInfo?.name || "Likeminded member",
      gender: profile?.basicInfo?.gender || null
    });
  }
  return members;
}

async function saveMeetingRsvp(userId, kind, available) {
  if (isPostgres) {
    await getPool().query(
      `INSERT INTO meeting_rsvps (user_id, kind, available, updated_at)
       VALUES ($1, $2, $3, now())
       ON CONFLICT (user_id, kind) DO UPDATE
       SET available = EXCLUDED.available, updated_at = now()`,
      [userId, kind, available]
    );
    return;
  }
  const store = readLocalStore();
  const existing = store.meetingRsvps.find((row) => row.user_id === userId && row.kind === kind);
  if (existing) {
    existing.available = available;
    existing.updated_at = new Date().toISOString();
  } else {
    store.meetingRsvps.push({ user_id: userId, kind, available, updated_at: new Date().toISOString() });
  }
  writeLocalStore(store);
}

async function getMeetingRsvps(kind = null) {
  if (isPostgres) {
    const result = kind
      ? await getPool().query("SELECT user_id, kind, available, updated_at FROM meeting_rsvps WHERE kind = $1", [kind])
      : await getPool().query("SELECT user_id, kind, available, updated_at FROM meeting_rsvps");
    return result.rows;
  }
  return readLocalStore().meetingRsvps.filter((row) => !kind || row.kind === kind);
}

async function getUserMeetingRsvps(userId) {
  return (await getMeetingRsvps()).filter((row) => row.user_id === userId);
}

async function saveMeeting(meeting) {
  if (isPostgres) {
    await getPool().query(
      `INSERT INTO meetings (id, data, created_at, updated_at)
       VALUES ($1, $2::jsonb, now(), now())
       ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = now()`,
      [meeting.id, JSON.stringify(meeting)]
    );
    return meeting;
  }
  const store = readLocalStore();
  const existing = store.meetings.findIndex((row) => row.id === meeting.id);
  if (existing >= 0) store.meetings[existing] = meeting;
  else store.meetings.push(meeting);
  writeLocalStore(store);
  return meeting;
}

async function listMeetingsForUser(userId) {
  const meetings = isPostgres
    ? (await getPool().query("SELECT data FROM meetings ORDER BY created_at")).rows.map((row) => row.data)
    : readLocalStore().meetings;
  return meetings.filter((meeting) => (meeting.participantIds || []).includes(userId));
}

async function getMeetingById(id) {
  if (isPostgres) {
    const result = await getPool().query("SELECT data FROM meetings WHERE id = $1", [id]);
    return result.rows[0]?.data || null;
  }
  return readLocalStore().meetings.find((meeting) => meeting.id === id) || null;
}

async function saveMeetingRecapNote(userId, meetingId, note) {
  const meeting = await getMeetingById(meetingId);
  if (!meeting || !(meeting.participantIds || []).includes(userId)) return null;
  const next = {
    ...meeting,
    recapNotes: {
      ...(meeting.recapNotes || {}),
      [userId]: note
    }
  };
  await saveMeeting(next);
  return next.recapNotes[userId];
}

async function setSoulmateEnabled(userId, enabled) {
  if (isPostgres) {
    await getPool().query(
      `INSERT INTO soulmate_users (user_id, enabled, updated_at)
       VALUES ($1, $2, now())
       ON CONFLICT (user_id) DO UPDATE SET enabled = EXCLUDED.enabled, updated_at = now()`,
      [userId, enabled]
    );
    return enabled;
  }
  const store = readLocalStore();
  store.soulmateUsers[userId] = { user_id: userId, enabled, updated_at: new Date().toISOString() };
  writeLocalStore(store);
  return enabled;
}

async function isSoulmateEnabled(userId) {
  if (isPostgres) {
    const result = await getPool().query("SELECT enabled FROM soulmate_users WHERE user_id = $1", [userId]);
    return result.rows[0]?.enabled || false;
  }
  return readLocalStore().soulmateUsers[userId]?.enabled || false;
}

function matchIdFor(meetingId, userAId, userBId) {
  return `match_${crypto.createHash("sha256").update([meetingId, ...[userAId, userBId].sort()].join(":")).digest("hex").slice(0, 24)}`;
}

async function saveSoulmateSelection(userId, meetingId, selectedUserIds) {
  const now = new Date().toISOString();
  const selection = { userId, meetingId, selectedUserIds: Array.from(new Set(selectedUserIds)), updatedAt: now };
  const newMatches = [];

  if (isPostgres) {
    const client = await getPool().connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `INSERT INTO soulmate_selections (user_id, meeting_id, data, updated_at)
         VALUES ($1, $2, $3::jsonb, now())
         ON CONFLICT (user_id, meeting_id) DO UPDATE SET data = EXCLUDED.data, updated_at = now()`,
        [userId, meetingId, JSON.stringify(selection)]
      );
      for (const selectedUserId of selection.selectedUserIds) {
        const reciprocal = await client.query("SELECT data FROM soulmate_selections WHERE user_id = $1 AND meeting_id = $2", [selectedUserId, meetingId]);
        const reciprocalSelected = reciprocal.rows[0]?.data?.selectedUserIds || [];
        if (!reciprocalSelected.includes(userId)) continue;
        const id = matchIdFor(meetingId, userId, selectedUserId);
        const match = { id, userAId: [userId, selectedUserId].sort()[0], userBId: [userId, selectedUserId].sort()[1], meetingId, createdAt: now, lastActiveAt: now, archivedAt: null };
        await client.query(
          `INSERT INTO soulmate_matches (id, data, created_at, updated_at)
           VALUES ($1, $2::jsonb, now(), now())
           ON CONFLICT (id) DO NOTHING`,
          [id, JSON.stringify(match)]
        );
        newMatches.push(id);
      }
      await client.query("COMMIT");
      return { newMatches };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  const store = readLocalStore();
  store.soulmateSelections = store.soulmateSelections.filter((row) => !(row.userId === userId && row.meetingId === meetingId));
  store.soulmateSelections.push(selection);
  for (const selectedUserId of selection.selectedUserIds) {
    const reciprocal = store.soulmateSelections.find((row) => row.userId === selectedUserId && row.meetingId === meetingId);
    if (!reciprocal?.selectedUserIds?.includes(userId)) continue;
    const id = matchIdFor(meetingId, userId, selectedUserId);
    if (store.soulmateMatches.some((row) => row.id === id)) continue;
    store.soulmateMatches.push({ id, userAId: [userId, selectedUserId].sort()[0], userBId: [userId, selectedUserId].sort()[1], meetingId, createdAt: now, lastActiveAt: now, archivedAt: null });
    newMatches.push(id);
  }
  writeLocalStore(store);
  return { newMatches };
}

async function getSoulmateMatches(userId, { archived = false } = {}) {
  const matches = isPostgres
    ? (await getPool().query("SELECT data FROM soulmate_matches ORDER BY created_at DESC")).rows.map((row) => row.data)
    : readLocalStore().soulmateMatches;
  return matches.filter((match) => [match.userAId, match.userBId].includes(userId) && Boolean(match.archivedAt) === archived);
}

async function getSoulmateMatch(userId, matchId) {
  const match = isPostgres
    ? (await getPool().query("SELECT data FROM soulmate_matches WHERE id = $1", [matchId])).rows[0]?.data
    : readLocalStore().soulmateMatches.find((row) => row.id === matchId);
  if (!match || ![match.userAId, match.userBId].includes(userId)) return null;
  return match;
}

async function archiveStaleMatches() {
  const cutoff = Date.now() - (30 * 24 * 60 * 60 * 1000);
  const now = new Date().toISOString();
  const mark = (match) => (!match.archivedAt && Date.parse(match.lastActiveAt || match.createdAt) < cutoff ? { ...match, archivedAt: now } : match);
  if (isPostgres) {
    const matches = (await getPool().query("SELECT id, data FROM soulmate_matches")).rows;
    for (const row of matches) {
      const next = mark(row.data);
      if (next !== row.data) {
        await getPool().query("UPDATE soulmate_matches SET data = $2::jsonb, updated_at = now() WHERE id = $1", [row.id, JSON.stringify(next)]);
      }
    }
    return;
  }
  const store = readLocalStore();
  store.soulmateMatches = store.soulmateMatches.map(mark);
  writeLocalStore(store);
}

async function saveMessage(matchId, senderId, text) {
  const now = new Date().toISOString();
  const message = { id: `msg_${crypto.randomUUID()}`, matchId, senderId, text, createdAt: now };
  if (isPostgres) {
    await getPool().query("INSERT INTO chat_messages (id, match_id, data, created_at) VALUES ($1, $2, $3::jsonb, now())", [message.id, matchId, JSON.stringify(message)]);
    const result = await getPool().query("SELECT data FROM soulmate_matches WHERE id = $1", [matchId]);
    const match = result.rows[0]?.data;
    if (match) await getPool().query("UPDATE soulmate_matches SET data = $2::jsonb, updated_at = now() WHERE id = $1", [matchId, JSON.stringify({ ...match, lastActiveAt: now })]);
    return message;
  }
  const store = readLocalStore();
  store.chatMessages.push(message);
  store.soulmateMatches = store.soulmateMatches.map((match) => match.id === matchId ? { ...match, lastActiveAt: now } : match);
  writeLocalStore(store);
  return message;
}

async function getMessages(matchId, afterTimestamp = null) {
  const messages = isPostgres
    ? (await getPool().query("SELECT data FROM chat_messages WHERE match_id = $1 ORDER BY created_at DESC LIMIT 50", [matchId])).rows.map((row) => row.data).reverse()
    : readLocalStore().chatMessages.filter((message) => message.matchId === matchId).slice(-50);
  return afterTimestamp ? messages.filter((message) => Date.parse(message.createdAt) > Date.parse(afterTimestamp)) : messages;
}

async function saveFeedback({ userId, profileId, placementId, rating, message, appVersion }) {
  if (isPostgres) {
    await getPool().query(
      "INSERT INTO feedback (user_id, profile_id, placement_id, rating, message, app_version, created_at) VALUES ($1, $2, $3, $4, $5, $6, now())",
      [userId, profileId || null, placementId || null, rating || null, message || null, appVersion || null]
    );
    return;
  }
  const store = readLocalStore();
  const id = String(store.feedback.reduce((max, row) => Math.max(max, Number(row.id) || 0), 0) + 1);
  store.feedback.push({
    id,
    user_id: userId,
    profile_id: profileId || null,
    placement_id: placementId || null,
    rating: rating || null,
    message: message || null,
    app_version: appVersion || null,
    created_at: new Date().toISOString()
  });
  writeLocalStore(store);
}

async function deleteUserAccount(userId) {
  if (isPostgres) {
    const client = await getPool().connect();
    try {
      await client.query("BEGIN");
      const matchRows = await client.query(
        "SELECT id FROM soulmate_matches WHERE data->>'userAId' = $1 OR data->>'userBId' = $1",
        [userId]
      );
      const matchIds = matchRows.rows.map((row) => row.id);
      if (matchIds.length) {
        await client.query("DELETE FROM chat_messages WHERE match_id = ANY($1::text[])", [matchIds]);
        await client.query("DELETE FROM soulmate_matches WHERE id = ANY($1::text[])", [matchIds]);
      }
      const meetings = await client.query("SELECT id, data FROM meetings");
      for (const row of meetings.rows) {
        const data = row.data || {};
        data.participantIds = (data.participantIds || []).filter((id) => id !== userId);
        if (data.recapNotes) delete data.recapNotes[userId];
        if (data.hostUserId === userId) {
          data.hostUserId = null;
          data.hostName = "Likeminded host";
        }
        await client.query("UPDATE meetings SET data = $1::jsonb, updated_at = now() WHERE id = $2", [JSON.stringify(data), row.id]);
      }
      await client.query("DELETE FROM users WHERE id = $1", [userId]);
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
    return;
  }

  const store = readLocalStore();
  const deletedMatchIds = store.soulmateMatches
    .filter((match) => match.userAId === userId || match.userBId === userId)
    .map((match) => match.id);
  delete store.users[userId];
  store.profiles = store.profiles.filter((row) => row.user_id !== userId);
  store.placements = store.placements.filter((row) => row.user_id !== userId);
  store.transcripts = store.transcripts.filter((row) => row.user_id !== userId);
  store.feedback = store.feedback.filter((row) => row.user_id !== userId);
  store.communityMemberships = store.communityMemberships.filter((row) => row.user_id !== userId);
  store.meetingRsvps = store.meetingRsvps.filter((row) => row.user_id !== userId);
  delete store.soulmateUsers[userId];
  store.soulmateSelections = store.soulmateSelections.filter((row) => row.userId !== userId);
  store.soulmateMatches = store.soulmateMatches.filter((match) => !deletedMatchIds.includes(match.id));
  store.chatMessages = store.chatMessages.filter((message) => !deletedMatchIds.includes(message.matchId) && message.userId !== userId);
  store.meetings = store.meetings.map((meeting) => {
    const next = {
      ...meeting,
      participantIds: (meeting.participantIds || []).filter((id) => id !== userId)
    };
    if (next.recapNotes) delete next.recapNotes[userId];
    if (next.hostUserId === userId) {
      next.hostUserId = null;
      next.hostName = "Likeminded host";
    }
    return next;
  });
  writeLocalStore(store);
}

function rowToUser(row) {
  if (!row) return null;
  return {
    id: row.id,
    appleSub: row.apple_sub,
    email: row.email || null,
    fullName: row.full_name || null
  };
}

function rowToPlacement(row) {
  if (!row) return null;
  const data = typeof row.data === "string" ? JSON.parse(row.data) : row.data;
  return { id: String(row.id), profileId: row.profile_id, placement: data };
}

module.exports = {
  isPostgres,
  migrateMvpStore,
  upsertAppleUser,
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
  saveSoulmateSelection,
  getSoulmateMatches,
  getSoulmateMatch,
  archiveStaleMatches,
  saveMessage,
  getMessages,
  saveFeedback,
  deleteUserAccount
};
module.exports.LOCAL_PATH = LOCAL_PATH;
