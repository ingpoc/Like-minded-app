const fs = require("node:fs");
const path = require("node:path");

const DB_DIR = path.resolve(process.env.LIKEMINDED_DB_DIR || path.join(process.cwd(), "data"));
const DB_PATH = path.join(DB_DIR, "likeminded.json");

function emptyStore() {
  return {
    profiles: {},
    circles: {},
    devices: {},
    placements: [],
    transcripts: []
  };
}

function readStore() {
  fs.mkdirSync(DB_DIR, { recursive: true });
  if (!fs.existsSync(DB_PATH)) {
    const store = emptyStore();
    writeStore(store);
    return store;
  }
  return { ...emptyStore(), ...JSON.parse(fs.readFileSync(DB_PATH, "utf8")) };
}

function writeStore(store) {
  fs.mkdirSync(DB_DIR, { recursive: true });
  fs.writeFileSync(DB_PATH, JSON.stringify(store, null, 2));
}

function getDb() {
  return {
    transaction(fn) {
      return () => fn();
    }
  };
}

class DBMap {
  constructor(tableName) {
    if (!["profiles", "circles"].includes(tableName)) throw new Error(`Unknown table: ${tableName}`);
    this.table = tableName;
  }

  get(id) {
    return readStore()[this.table][id];
  }

  set(id, obj) {
    const store = readStore();
    store[this.table][id] = obj;
    writeStore(store);
    return this;
  }

  has(id) {
    return !!this.get(id);
  }

  delete(id) {
    const store = readStore();
    if (!store[this.table][id]) return false;
    delete store[this.table][id];
    writeStore(store);
    return true;
  }

  get size() {
    return Object.keys(readStore()[this.table]).length;
  }

  values() {
    return Object.values(readStore()[this.table]);
  }

  entries() {
    return Object.entries(readStore()[this.table]);
  }

  forEach(cb) {
    for (const [id, obj] of this.entries()) cb(obj, id, this);
  }

  [Symbol.iterator]() {
    return this.entries()[Symbol.iterator]();
  }
}

function savePlacement(placement) {
  const store = readStore();
  const id = store.placements.reduce((max, row) => Math.max(max, Number(row.id) || 0), 0) + 1;
  store.placements.push({
    id,
    profileId: placement.profileId,
    circleId: placement.primaryCircle?.id || null,
    confidenceLabel: placement.confidenceLabel || null,
    fitReasons: placement.fitReasons || [],
    userState: placement.userState || "proposed",
    isNewCircle: !!placement.isNewCircle,
    createdAt: new Date().toISOString()
  });
  writeStore(store);
  return id;
}

function getPlacementsByProfile(profileId) {
  return readStore().placements
    .filter((row) => row.profileId === profileId)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

function getAllPlacements() {
  return readStore().placements.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

function saveTranscript(transcript, profileId) {
  const store = readStore();
  const id = store.transcripts.reduce((max, row) => Math.max(max, Number(row.id) || 0), 0) + 1;
  store.transcripts.push({ id, profileId: profileId || null, content: transcript, createdAt: new Date().toISOString() });
  writeStore(store);
  return id;
}

function getTranscriptsByProfile(profileId) {
  return readStore().transcripts
    .filter((row) => row.profileId === profileId)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

function registerDevice(deviceId) {
  const store = readStore();
  const now = new Date().toISOString();
  const existing = store.devices[deviceId];
  store.devices[deviceId] = { id: deviceId, createdAt: existing?.createdAt || now, lastSeenAt: now };
  writeStore(store);
  return store.devices[deviceId];
}

function getDevice(deviceId) {
  return readStore().devices[deviceId] || null;
}

function getProfilesByDevice(deviceId) {
  return Object.values(readStore().profiles)
    .filter((profile) => profile.deviceId === deviceId)
    .sort((a, b) => String(b.synthesizedAt).localeCompare(String(a.synthesizedAt)));
}

module.exports = {
  getDb,
  DBMap,
  savePlacement,
  getPlacementsByProfile,
  getAllPlacements,
  saveTranscript,
  getTranscriptsByProfile,
  registerDevice,
  getDevice,
  getProfilesByDevice,
  DB_PATH
};
