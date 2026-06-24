/**
 * SQLite-backed persistent storage for profiles and circles.
 * Provides a Map-like interface so architecture.js code works with minimal changes.
 *
 * Database file: data/likeminded.db (relative to project root)
 */

const Database = require("better-sqlite3");
const path = require("node:path");
const fs = require("node:fs");

const DB_DIR = path.resolve(process.cwd(), "data");
const DB_PATH = path.join(DB_DIR, "likeminded.db");

let db;

function getDb() {
  if (db) return db;
  fs.mkdirSync(DB_DIR, { recursive: true });
  db = new Database(DB_PATH);
  db.pragma("journal_mode = WAL");
  db.pragma("foreign_keys = ON");
  migrate(db);
  return db;
}

function migrate(conn) {
  conn.exec(`
    CREATE TABLE IF NOT EXISTS profiles (
      id TEXT PRIMARY KEY,
      signals TEXT NOT NULL,
      source_interview TEXT DEFAULT '',
      source_reflections TEXT DEFAULT '[]',
      synthesized_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS circles (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS placements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id TEXT NOT NULL,
      circle_id TEXT NOT NULL,
      confidence_label TEXT,
      fit_reasons TEXT DEFAULT '[]',
      user_state TEXT DEFAULT 'proposed',
      is_new_circle INTEGER DEFAULT 0,
      created_at TEXT NOT NULL
    );
  `);
}

// ---------------------------------------------------------------------------
// DBMap — Map-like wrapper around a SQLite table
// ---------------------------------------------------------------------------

class DBMap {
  /**
   * @param {string} tableName
   * @param {object} conn - better-sqlite3 connection
   */
  constructor(tableName, conn) {
    this.table = tableName;
    this.conn = conn;

    // Prepared statements (lazy)
    this._getStmt = null;
    this._setStmt = null;
    this._hasStmt = null;
    this._deleteStmt = null;
    this._allStmt = null;
    this._countStmt = null;
  }

  _prep(key) {
    if (this.table === "profiles") {
      return {
        get: this.conn.prepare("SELECT * FROM profiles WHERE id = ?"),
        set: this.conn.prepare(
          "INSERT OR REPLACE INTO profiles (id, signals, source_interview, source_reflections, synthesized_at) VALUES (?, ?, ?, ?, ?)"
        ),
        has: this.conn.prepare("SELECT 1 FROM profiles WHERE id = ?"),
        delete: this.conn.prepare("DELETE FROM profiles WHERE id = ?"),
        all: this.conn.prepare("SELECT * FROM profiles"),
        count: this.conn.prepare("SELECT COUNT(*) as n FROM profiles"),
      };
    }
    if (this.table === "circles") {
      return {
        get: this.conn.prepare("SELECT * FROM circles WHERE id = ?"),
        set: this.conn.prepare(
          "INSERT OR REPLACE INTO circles (id, data, created_at) VALUES (?, ?, ?)"
        ),
        has: this.conn.prepare("SELECT 1 FROM circles WHERE id = ?"),
        delete: this.conn.prepare("DELETE FROM circles WHERE id = ?"),
        all: this.conn.prepare("SELECT * FROM circles"),
        count: this.conn.prepare("SELECT COUNT(*) as n FROM circles"),
      };
    }
    throw new Error(`Unknown table: ${this.table}`);
  }

  _stmts() {
    if (!this._cached) {
      this._cached = this._prep();
    }
    return this._cached;
  }

  _rowToObj(row) {
    if (!row) return undefined;
    if (this.table === "profiles") {
      return {
        profileId: row.id,
        signals: JSON.parse(row.signals),
        sourceInput: {
          interviewExcerpt: row.source_interview,
          reflectionAnswers: JSON.parse(row.source_reflections),
        },
        synthesizedAt: row.synthesized_at,
      };
    }
    if (this.table === "circles") {
      const data = JSON.parse(row.data);
      return data; // full circle object stored as JSON
    }
    return row;
  }

  _objToRow(id, obj) {
    if (this.table === "profiles") {
      return [
        id,
        JSON.stringify(obj.signals),
        obj.sourceInput?.interviewExcerpt || "",
        JSON.stringify(obj.sourceInput?.reflectionAnswers || []),
        obj.synthesizedAt,
      ];
    }
    if (this.table === "circles") {
      return [id, JSON.stringify(obj), obj.createdAt || new Date().toISOString()];
    }
    return [id, JSON.stringify(obj)];
  }

  get(id) {
    const s = this._stmts();
    const row = s.get.get(id);
    return this._rowToObj(row);
  }

  set(id, obj) {
    const s = this._stmts();
    const args = this._objToRow(id, obj);
    s.set.run(...args);
    return this;
  }

  has(id) {
    const s = this._stmts();
    return !!s.has.get(id);
  }

  delete(id) {
    const s = this._stmts();
    const info = s.delete.run(id);
    return info.changes > 0;
  }

  get size() {
    const s = this._stmts();
    return s.count.get().n;
  }

  values() {
    const s = this._stmts();
    return s.all.all().map((row) => this._rowToObj(row));
  }

  entries() {
    const s = this._stmts();
    return s.all.all().map((row) => [row.id, this._rowToObj(row)]);
  }

  forEach(cb) {
    for (const [id, obj] of this.entries()) {
      cb(obj, id, this);
    }
  }

  [Symbol.iterator]() {
    return this.entries()[Symbol.iterator]();
  }
}

// ---------------------------------------------------------------------------
// Placement CRUD (separate from Maps since placements aren't Map-shaped)
// ---------------------------------------------------------------------------

function savePlacement(placement) {
  const d = getDb();
  const stmt = d.prepare(
    "INSERT INTO placements (profile_id, circle_id, confidence_label, fit_reasons, user_state, is_new_circle, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
  );
  const info = stmt.run(
    placement.profileId,
    placement.primaryCircle?.id || null,
    placement.confidenceLabel || null,
    JSON.stringify(placement.fitReasons || []),
    placement.userState || "proposed",
    placement.isNewCircle ? 1 : 0,
    new Date().toISOString()
  );
  return info.lastInsertRowid;
}

function getPlacementsByProfile(profileId) {
  const d = getDb();
  const rows = d.prepare("SELECT * FROM placements WHERE profile_id = ? ORDER BY created_at DESC").all(profileId);
  return rows.map((r) => ({
    id: r.id,
    profileId: r.profile_id,
    circleId: r.circle_id,
    confidenceLabel: r.confidence_label,
    fitReasons: JSON.parse(r.fit_reasons),
    userState: r.user_state,
    isNewCircle: !!r.is_new_circle,
    createdAt: r.created_at,
  }));
}

function getAllPlacements() {
  const d = getDb();
  const rows = d.prepare("SELECT * FROM placements ORDER BY created_at DESC").all();
  return rows.map((r) => ({
    id: r.id,
    profileId: r.profile_id,
    circleId: r.circle_id,
    confidenceLabel: r.confidence_label,
    fitReasons: JSON.parse(r.fit_reasons),
    userState: r.user_state,
    isNewCircle: !!r.is_new_circle,
    createdAt: r.created_at,
  }));
}

// ---------------------------------------------------------------------------
// Transcript storage (for Phase 1 item #3 — wire voice transcript)
// ---------------------------------------------------------------------------

function saveTranscript(transcript, profileId) {
  const d = getDb();
  // Create table if not exists
  d.exec(`
    CREATE TABLE IF NOT EXISTS transcripts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id TEXT,
      content TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  `);
  const stmt = d.prepare("INSERT INTO transcripts (profile_id, content, created_at) VALUES (?, ?, ?)");
  return stmt.run(profileId || null, transcript, new Date().toISOString()).lastInsertRowid;
}

function getTranscriptsByProfile(profileId) {
  const d = getDb();
  try {
    return d.prepare("SELECT * FROM transcripts WHERE profile_id = ? ORDER BY created_at DESC").all(profileId);
  } catch {
    return [];
  }
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

module.exports = {
  getDb,
  DBMap,
  savePlacement,
  getPlacementsByProfile,
  getAllPlacements,
  saveTranscript,
  getTranscriptsByProfile,
  DB_PATH,
};
