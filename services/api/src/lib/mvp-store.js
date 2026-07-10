const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { Pool } = require("pg");

const isPostgres = !!process.env.DATABASE_URL;
const LOCAL_DIR = path.resolve(process.env.LIKEMINDED_DB_DIR || path.join(process.cwd(), "data"));
const LOCAL_PATH = path.join(LOCAL_DIR, "mvp-store.json");
let pool;

function userIdForAppleSub(appleSub) {
  return userIdForAuthSubject("apple", appleSub);
}

function userIdForAuthSubject(provider, subject) {
  return `usr_${crypto.createHash("sha256").update(`${provider}:${subject}`).digest("hex").slice(0, 24)}`;
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
  await getPool().query(`
    ALTER TABLE soulmate_users
    ADD COLUMN IF NOT EXISTS preferences JSONB NOT NULL DEFAULT '{"discovery":"circles_extended","ageMin":22,"ageMax":35,"visibility":"circles_only"}'::jsonb;
  `);
  await getPool().query(`ALTER TABLE users ALTER COLUMN apple_sub DROP NOT NULL;`);
  await getPool().query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub TEXT UNIQUE;`);
  await getPool().query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS wallet_address TEXT;`);
  await getPool().query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS wallet_chain TEXT;`);
  await getPool().query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider TEXT;`);
  await getPool().query(`
    CREATE UNIQUE INDEX IF NOT EXISTS users_wallet_unique
    ON users (wallet_chain, lower(wallet_address))
    WHERE wallet_address IS NOT NULL;
  `);
}

async function upsertAuthUser({ provider, subject, email, fullName, walletChain, walletAddress }) {
  const id = userIdForAuthSubject(provider, subject);
  const now = new Date().toISOString();
  const appleSub = provider === "apple" ? subject : null;
  const googleSub = provider === "google" ? subject : null;
  const walletAddressValue = provider === "wallet" ? walletAddress : null;
  const walletChainValue = provider === "wallet" ? walletChain : null;

  if (isPostgres) {
    let existingId = id;
    if (provider === "apple") {
      const existing = await getPool().query("SELECT id FROM users WHERE apple_sub = $1 LIMIT 1", [subject]);
      if (existing.rows[0]?.id) existingId = existing.rows[0].id;
    } else if (provider === "google") {
      const existing = await getPool().query("SELECT id FROM users WHERE google_sub = $1 LIMIT 1", [subject]);
      if (existing.rows[0]?.id) existingId = existing.rows[0].id;
    } else {
      const existing = await getPool().query(
        "SELECT id FROM users WHERE wallet_chain = $1 AND lower(wallet_address) = lower($2) LIMIT 1",
        [walletChainValue, walletAddressValue]
      );
      if (existing.rows[0]?.id) existingId = existing.rows[0].id;
    }

    const result = await getPool().query(
      `INSERT INTO users (id, apple_sub, google_sub, wallet_address, wallet_chain, auth_provider, email, full_name, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now(), now())
       ON CONFLICT (id) DO UPDATE
       SET apple_sub = COALESCE(users.apple_sub, EXCLUDED.apple_sub),
           google_sub = COALESCE(users.google_sub, EXCLUDED.google_sub),
           wallet_address = COALESCE(users.wallet_address, EXCLUDED.wallet_address),
           wallet_chain = COALESCE(users.wallet_chain, EXCLUDED.wallet_chain),
           auth_provider = COALESCE(users.auth_provider, EXCLUDED.auth_provider),
           email = COALESCE(EXCLUDED.email, users.email),
           full_name = COALESCE(EXCLUDED.full_name, users.full_name),
           updated_at = now()
       RETURNING id, apple_sub, google_sub, wallet_address, wallet_chain, auth_provider, email, full_name`,
      [existingId, appleSub, googleSub, walletAddressValue, walletChainValue, provider, email || null, fullName || null]
    );
    return rowToUser(result.rows[0]);
  }

  const store = readLocalStore();
  const existing =
    store.users[id] ||
    Object.values(store.users).find((user) => {
      if (provider === "apple") return user.apple_sub === subject;
      if (provider === "google") return user.google_sub === subject;
      return user.wallet_chain === walletChain && String(user.wallet_address || "").toLowerCase() === String(walletAddress || "").toLowerCase();
    });

  store.users[id] = {
    id,
    apple_sub: appleSub || existing?.apple_sub || null,
    google_sub: googleSub || existing?.google_sub || null,
    wallet_address: walletAddressValue || existing?.wallet_address || null,
    wallet_chain: walletChainValue || existing?.wallet_chain || null,
    auth_provider: existing?.auth_provider || provider,
    email: email || existing?.email || null,
    full_name: fullName || existing?.full_name || null,
    created_at: existing?.created_at || now,
    updated_at: now
  };
  writeLocalStore(store);
  return rowToUser(store.users[id]);
}

async function upsertAppleUser({ appleSub, email, fullName }) {
  return upsertAuthUser({ provider: "apple", subject: appleSub, email, fullName });
}

async function upsertGoogleUser({ googleSub, email, fullName }) {
  return upsertAuthUser({ provider: "google", subject: googleSub, email, fullName });
}

async function upsertWalletUser({ walletChain, walletAddress }) {
  const subject = `${walletChain}:${String(walletAddress).toLowerCase()}`;
  return upsertAuthUser({
    provider: "wallet",
    subject,
    walletChain,
    walletAddress: String(walletAddress),
    fullName: `${walletAddress.slice(0, 6)}…${walletAddress.slice(-4)}`
  });
}

async function getUserById(id) {
  if (isPostgres) {
    const result = await getPool().query(
      "SELECT id, apple_sub, google_sub, wallet_address, wallet_chain, auth_provider, email, full_name FROM users WHERE id = $1",
      [id]
    );
    return rowToUser(result.rows[0]);
  }
  return rowToUser(readLocalStore().users[id]);
}

function mergeProfileInterests(existing = [], incoming = []) {
  const byLabel = new Map();
  for (const item of [...existing, ...incoming]) {
    if (!item || typeof item.label !== "string") continue;
    const label = item.label.trim();
    if (!label) continue;
    byLabel.set(label.toLowerCase(), {
      area: typeof item.area === "string" && item.area.trim() ? item.area.trim() : "general",
      label,
      depth: ["casual", "active", "deep"].includes(item.depth) ? item.depth : "active"
    });
  }
  return Array.from(byLabel.values()).slice(0, 10);
}

/** Apply discover/voice synthesis onto the user's current profile instead of replacing it. */
function mergeProfileWithDiscovery(existing, discovered) {
  if (!existing || typeof existing !== "object") return discovered;
  if (!discovered || typeof discovered !== "object") return existing;
  const existingBasic = existing.basicInfo && typeof existing.basicInfo === "object" ? existing.basicInfo : {};
  const discoveredBasic = discovered.basicInfo && typeof discovered.basicInfo === "object" ? discovered.basicInfo : {};
  return {
    ...existing,
    ...discovered,
    profileId: existing.profileId,
    basicInfo: { ...existingBasic, ...discoveredBasic },
    interests: mergeProfileInterests(existing.interests, discovered.interests),
    signals: discovered.signals || existing.signals,
    hiddenSignals: discovered.hiddenSignals || existing.hiddenSignals,
    profileSummary: discovered.profileSummary || existing.profileSummary,
    sourceInput: discovered.sourceInput || existing.sourceInput,
    synthesizedAt: discovered.synthesizedAt || existing.synthesizedAt,
    concernFlag: Object.prototype.hasOwnProperty.call(discovered, "concernFlag")
      ? discovered.concernFlag
      : existing.concernFlag,
    placementConcern: discovered.placementConcern ?? existing.placementConcern,
    deviceId: discovered.deviceId || existing.deviceId
  };
}

async function saveProfilePlacement({ userId, profile, placement, transcript }) {
  const now = new Date().toISOString();
  const existing = await getLatestProfile(userId);
  const profileToSave = mergeProfileWithDiscovery(existing, profile);
  const profileData = JSON.stringify(profileToSave);
  const placementData = JSON.stringify(placement);
  if (isPostgres) {
    const client = await getPool().connect();
    try {
      await client.query("BEGIN");
      await client.query(
        "INSERT INTO profiles (id, user_id, data, created_at) VALUES ($1, $2, $3::jsonb, now()) ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data",
        [profileToSave.profileId, userId, profileData]
      );
      const placed = await client.query(
        "INSERT INTO placements (user_id, profile_id, data, user_state, created_at, updated_at) VALUES ($1, $2, $3::jsonb, $4, now(), now()) RETURNING id",
        [userId, profileToSave.profileId, placementData, placement.userState || "proposed"]
      );
      if (transcript) {
        await client.query(
          "INSERT INTO transcripts (user_id, profile_id, content, created_at) VALUES ($1, $2, $3, now())",
          [userId, profileToSave.profileId, transcript]
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
  const existingRow = store.profiles.find(
    (row) => row.user_id === userId && row.id === profileToSave.profileId
  );
  if (existingRow) {
    existingRow.data = profileToSave;
  } else {
    store.profiles.push({
      id: profileToSave.profileId,
      user_id: userId,
      data: profileToSave,
      created_at: now
    });
  }
  const placementId = String(store.placements.reduce((max, row) => Math.max(max, Number(row.id) || 0), 0) + 1);
  store.placements.push({
    id: placementId,
    user_id: userId,
    profile_id: profileToSave.profileId,
    data: placement,
    user_state: placement.userState || "proposed",
    created_at: now,
    updated_at: now
  });
  if (transcript) {
    const transcriptId = String(store.transcripts.reduce((max, row) => Math.max(max, Number(row.id) || 0), 0) + 1);
    store.transcripts.push({
      id: transcriptId,
      user_id: userId,
      profile_id: profileToSave.profileId,
      content: transcript,
      created_at: now
    });
  }
  writeLocalStore(store);
  return { placementId, profile: profileToSave };
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
  let profile = await getLatestProfile(userId);
  if (!profile && updates.basicInfo) {
    profile = await ensureDraftProfile(userId);
  }
  if (!profile) return null;
  if (updates.signals) profile.signals = updates.signals;
  if (Object.prototype.hasOwnProperty.call(updates, "concernFlag")) profile.concernFlag = !!updates.concernFlag;
  if (Object.prototype.hasOwnProperty.call(updates, "placementConcern")) {
    profile.placementConcern = typeof updates.placementConcern === "string" && updates.placementConcern.trim()
      ? updates.placementConcern.trim()
      : null;
  }
  if (updates.basicInfo && typeof updates.basicInfo === "object") {
    const current = profile.basicInfo && typeof profile.basicInfo === "object" ? profile.basicInfo : {};
    const next = { ...current };
    for (const key of ["name", "gender", "dateOfBirth", "city", "pincode"]) {
      if (typeof updates.basicInfo[key] === "string" && updates.basicInfo[key].trim()) {
        next[key] = updates.basicInfo[key].trim();
      }
    }
    profile.basicInfo = next;
  }
  if (updates.reflectionSummary) {
    if (profile.profile?.reflection) profile.profile.reflection.summary = updates.reflectionSummary;
    profile.reflection = { ...(profile.reflection || {}), summary: updates.reflectionSummary };
    profile.profileSummary = updates.reflectionSummary;
  }
  if (Array.isArray(updates.interests)) {
    profile.interests = mergeProfileInterests(profile.interests, updates.interests);
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

async function updateLatestPlacement(userId, action, options = {}) {
  const current = await getLatestPlacement(userId);
  if (!current) return null;
  const placement = current.placement;
  if (action === "accept") placement.userState = "accepted";
  if (action === "defer") placement.userState = "deferred";
  if (action === "select_secondary") {
    const circleId = String(options.circleId || "");
    const allowed = new Set((placement.secondaryCircles || []).map((circle) => circle.id));
    if (!circleId || !allowed.has(circleId)) {
      throw new Error("circleId must be one of the suggested secondary circles.");
    }
    if (circleId === placement.primaryCircle?.id) {
      throw new Error("Primary circle cannot be selected as secondary.");
    }
    placement.selectedSecondaryCircleId = circleId;
    if (placement.userState === "proposed") placement.userState = "accepted";
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

const DEFAULT_SOULMATE_PREFERENCES = {
  discovery: "circles_extended",
  ageMin: 22,
  ageMax: 35,
  visibility: "circles_only"
};

function normalizeSoulmatePreferences(raw = {}) {
  const discoveryOptions = new Set(["circles", "circles_extended", "communities"]);
  const visibilityOptions = new Set(["circles_only", "circles_communities", "matches_only"]);
  const ageMin = Math.max(18, Math.min(80, Number(raw.ageMin ?? DEFAULT_SOULMATE_PREFERENCES.ageMin)));
  const ageMax = Math.max(ageMin, Math.min(80, Number(raw.ageMax ?? DEFAULT_SOULMATE_PREFERENCES.ageMax)));
  return {
    discovery: discoveryOptions.has(raw.discovery) ? raw.discovery : DEFAULT_SOULMATE_PREFERENCES.discovery,
    ageMin,
    ageMax,
    visibility: visibilityOptions.has(raw.visibility) ? raw.visibility : DEFAULT_SOULMATE_PREFERENCES.visibility
  };
}

async function getSoulmateUserRecord(userId) {
  if (isPostgres) {
    const result = await getPool().query(
      "SELECT enabled, preferences FROM soulmate_users WHERE user_id = $1",
      [userId]
    );
    const row = result.rows[0];
    if (!row) {
      return { enabled: false, preferences: { ...DEFAULT_SOULMATE_PREFERENCES } };
    }
    return {
      enabled: Boolean(row.enabled),
      preferences: normalizeSoulmatePreferences(row.preferences || {})
    };
  }
  const record = readLocalStore().soulmateUsers[userId];
  if (!record) {
    return { enabled: false, preferences: { ...DEFAULT_SOULMATE_PREFERENCES } };
  }
  return {
    enabled: Boolean(record.enabled),
    preferences: normalizeSoulmatePreferences(record.preferences || {})
  };
}

async function setSoulmateEnabled(userId, enabled) {
  if (isPostgres) {
    await getPool().query(
      `INSERT INTO soulmate_users (user_id, enabled, preferences, updated_at)
       VALUES ($1, $2, $3::jsonb, now())
       ON CONFLICT (user_id) DO UPDATE SET enabled = EXCLUDED.enabled, updated_at = now()`,
      [userId, enabled, JSON.stringify(DEFAULT_SOULMATE_PREFERENCES)]
    );
    return enabled;
  }
  const store = readLocalStore();
  const existing = store.soulmateUsers[userId] || {};
  store.soulmateUsers[userId] = {
    user_id: userId,
    enabled,
    preferences: normalizeSoulmatePreferences(existing.preferences),
    updated_at: new Date().toISOString()
  };
  writeLocalStore(store);
  return enabled;
}

async function isSoulmateEnabled(userId) {
  const record = await getSoulmateUserRecord(userId);
  return record.enabled;
}

async function getSoulmatePreferences(userId) {
  const record = await getSoulmateUserRecord(userId);
  return record.preferences;
}

async function setSoulmatePreferences(userId, preferences) {
  const normalized = normalizeSoulmatePreferences(preferences);
  if (isPostgres) {
    await getPool().query(
      `INSERT INTO soulmate_users (user_id, enabled, preferences, updated_at)
       VALUES ($1, false, $2::jsonb, now())
       ON CONFLICT (user_id) DO UPDATE SET preferences = EXCLUDED.preferences, updated_at = now()`,
      [userId, JSON.stringify(normalized)]
    );
    return normalized;
  }
  const store = readLocalStore();
  const existing = store.soulmateUsers[userId] || { user_id: userId, enabled: false };
  store.soulmateUsers[userId] = {
    ...existing,
    user_id: userId,
    preferences: normalized,
    updated_at: new Date().toISOString()
  };
  writeLocalStore(store);
  return normalized;
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
  const authProvider = row.auth_provider || (row.apple_sub ? "apple" : row.google_sub ? "google" : row.wallet_address ? "wallet" : null);
  const authSubject =
    row.apple_sub ||
    row.google_sub ||
    (row.wallet_chain && row.wallet_address ? `${row.wallet_chain}:${row.wallet_address}` : null);
  return {
    id: row.id,
    appleSub: row.apple_sub || null,
    googleSub: row.google_sub || null,
    walletAddress: row.wallet_address || null,
    walletChain: row.wallet_chain || null,
    authProvider,
    authSubject,
    email: row.email || null,
    fullName: row.full_name || null
  };
}

function rowToPlacement(row) {
  if (!row) return null;
  const data = typeof row.data === "string" ? JSON.parse(row.data) : row.data;
  return { id: String(row.id), profileId: row.profile_id, placement: data };
}

function newProfileId() {
  return `profile-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

async function ensureDraftProfile(userId) {
  const existing = await getLatestProfile(userId);
  if (existing) return existing;
  const now = new Date().toISOString();
  const profile = {
    profileId: newProfileId(),
    basicInfo: {},
    signals: {},
    interests: [],
    profileSummary: "",
    synthesizedAt: now
  };
  const profileData = JSON.stringify(profile);
  if (isPostgres) {
    await getPool().query(
      "INSERT INTO profiles (id, user_id, data, created_at) VALUES ($1, $2, $3::jsonb, now())",
      [profile.profileId, userId, profileData]
    );
  } else {
    const store = readLocalStore();
    store.profiles.push({ id: profile.profileId, user_id: userId, data: profile, created_at: now });
    writeLocalStore(store);
  }
  return profile;
}

module.exports = {
  isPostgres,
  migrateMvpStore,
  upsertAppleUser,
  upsertGoogleUser,
  upsertWalletUser,
  upsertAuthUser,
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
  deleteUserAccount
};
module.exports.LOCAL_PATH = LOCAL_PATH;
