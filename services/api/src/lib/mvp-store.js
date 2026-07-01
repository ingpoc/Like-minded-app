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
    feedback: []
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
  const row = readLocalStore().profiles
    .filter((profile) => profile.user_id === userId)
    .sort((a, b) => b.created_at.localeCompare(a.created_at))[0];
  return row?.data || null;
}

async function getLatestPlacement(userId) {
  if (isPostgres) {
    const result = await getPool().query("SELECT id, profile_id, data FROM placements WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1", [userId]);
    return rowToPlacement(result.rows[0]);
  }
  const row = readLocalStore().placements
    .filter((placement) => placement.user_id === userId)
    .sort((a, b) => b.created_at.localeCompare(a.created_at))[0];
  return rowToPlacement(row);
}

async function updateLatestProfile(userId, updates) {
  const profile = await getLatestProfile(userId);
  if (!profile) return null;
  if (updates.signals) profile.signals = updates.signals;
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
  saveFeedback
};
module.exports.LOCAL_PATH = LOCAL_PATH;
