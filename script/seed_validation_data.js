#!/usr/bin/env node
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const action = process.argv.find((arg) => ["seed", "remove", "reset"].includes(arg)) || "seed";
const showToken = process.argv.includes("--show-token");
const root = path.resolve(__dirname, "..");
const dbDir = path.resolve(process.env.LIKEMINDED_DB_DIR || path.join(root, "data"));
const mvpStorePath = path.join(dbDir, "mvp-store.json");
const architectureStorePath = path.join(dbDir, "likeminded.json");
const baseURL = process.env.LIKEMINDED_API_BASE_URL || "http://127.0.0.1:8787";

// ---------------------------------------------------------------------------
// 24 users: varied personalities, genders, circles, interests, communities.
// Enough density to form multiple groups, exercise gender balance, host
// selection, soulmate matching, and realistic notification/chat volume.
// ---------------------------------------------------------------------------
const PEOPLE = [
  // gurusharan = primary validation user (reflective-builders circle)
  // >5 interests so macOS/iOS profile "View all" expand control is present in validation.
  ["gurusharan", "Gurusharan Gupta", "male", "reflective-builders", ["AI","Startups","Design","Systems thinking","Jazz","Writing","Hosting"], "Systems thinker who builds deliberately — high openness, analytical depth, warm underneath. Prefers small rooms with honest feedback over performative networking.", { o:.85,c:.80,e:.48,a:.72,n:.30, att:"secure",     se:"medium",     cs:"analytical", tp:"slowTrust",  hs:"observational", cf:"analytical" }],
  // reflective-builders — 7 more (3M/4F), forms 1 circle group
  ["priya",    "Priya Shah",      "female", "reflective-builders", ["Design","Cooking","Tech"],     "Reflective host energy, warm direct speech, steady trust.",          { o:.78,c:.74,e:.44,a:.83,n:.28, att:"secure",     se:"medium",     cs:"warm",       tp:"fastTrust",  hs:"observational", cf:"analytical" }],
  ["rohan",    "Rohan Mehta",     "male",   "reflective-builders", ["Startups","Tech","Books"],     "Energetic builder, curious, comfortable with momentum.",             { o:.82,c:.80,e:.58,a:.65,n:.30, att:"secure",     se:"medium",     cs:"direct",     tp:"fastTrust",  hs:"witty",          cf:"engaging"    }],
  ["ananya",   "Ananya Rao",      "female", "reflective-builders", ["Books","Psychology","Writing"],"Thoughtful listener, slow trust, low-pressure conversation.",        { o:.85,c:.70,e:.38,a:.80,n:.40, att:"avoidant",   se:"low",        cs:"analytical", tp:"slowTrust",  hs:"observational", cf:"analytical" }],
  ["arjun",    "Arjun Nair",      "male",   "reflective-builders", ["Books","Music","Cooking"],     "Calm, analytical, grounded, likes small rooms.",                     { o:.72,c:.78,e:.42,a:.75,n:.25, att:"secure",     se:"low",        cs:"direct",     tp:"slowTrust",  hs:"absent",         cf:"analytical" }],
  ["kavya",    "Kavya Reddy",     "female", "reflective-builders", ["Design","Art","Writing"],      "Precise, visual thinker, builds with intention.",                   { o:.80,c:.82,e:.48,a:.70,n:.32, att:"secure",     se:"medium",     cs:"analytical", tp:"conditionalTrust", hs:"observational", cf:"avoiding" }],
  ["vivek",    "Vivek Kumar",     "male",   "reflective-builders", ["Tech","Startups","Music"],     "Systems thinker, patient, builds deep before shipping.",            { o:.76,c:.85,e:.40,a:.72,n:.28, att:"avoidant",   se:"low",        cs:"analytical", tp:"slowTrust",  hs:"dry",            cf:"analytical" }],
  ["isha",     "Isha Gupta",      "female", "reflective-builders", ["Tech","Books","Design"],       "Direct, warm underneath, values honesty over comfort.",             { o:.75,c:.70,e:.52,a:.68,n:.35, att:"secure",     se:"medium",     cs:"direct",     tp:"fastTrust",  hs:"witty",          cf:"engaging"    }],
  ["aditya",   "Aditya Verma",    "male",   "reflective-builders", ["Startups","Outdoors","Film"],  "Quiet intensity, leads by doing, earns trust through consistency.", { o:.70,c:.80,e:.45,a:.76,n:.22, att:"secure",     se:"medium",     cs:"warm",       tp:"slowTrust",  hs:"observational", cf:"accommodating"}],

  // bold-explorers — 6 people (3M/3F), forms 1 circle group
  ["karan",    "Karan Singh",     "male",   "bold-explorers",      ["Outdoors","Film","Travel"],    "High energy, tries everything, fast trust, loves momentum.",         { o:.90,c:.45,e:.85,a:.55,n:.35, att:"secure",     se:"high",       cs:"expressive", tp:"fastTrust",  hs:"physical",       cf:"engaging"    }],
  ["zara",     "Zara Khan",       "female", "bold-explorers",      ["Travel","Music","Film"],       "Spontaneous, expressive, collects experiences not things.",        { o:.88,c:.40,e:.82,a:.60,n:.38, att:"secure",     se:"high",       cs:"expressive", tp:"fastTrust",  hs:"witty",          cf:"engaging"    }],
  ["neil",     "Neil Patel",      "male",   "bold-explorers",      ["Outdoors","Tech","Travel"],    "Adventurous builder, prototypes life like products.",               { o:.85,c:.50,e:.80,a:.50,n:.30, att:"secure",     se:"high",       cs:"direct",     tp:"fastTrust",  hs:"observational", cf:"engaging"    }],
  ["diya",     "Diya Joshi",      "female", "bold-explorers",      ["Travel","Art","Cooking"],      "Fearless creative, says yes first, figures it out later.",         { o:.92,c:.38,e:.88,a:.58,n:.32, att:"anxious",    se:"high",       cs:"expressive", tp:"fastTrust",  hs:"physical",       cf:"engaging"    }],
  ["raj",      "Raj Malhotra",    "male",   "bold-explorers",      ["Outdoors","Film","Startups"],  "Bold, irreverent, action over analysis.",                           { o:.80,c:.42,e:.85,a:.48,n:.25, att:"secure",     se:"high",       cs:"direct",     tp:"fastTrust",  hs:"witty",          cf:"engaging"    }],
  ["naina",    "Naina Chopra",    "female", "bold-explorers",      ["Music","Travel","Writing"],    "Energetic conversationalist, draws people out, lives loudly.",     { o:.87,c:.48,e:.78,a:.62,n:.40, att:"secure",     se:"high",       cs:"warm",       tp:"fastTrust",  hs:"warm",           cf:"engaging"    }],

  // grounded-nurturers — 5 people (2M/3F), below threshold — no circle meeting
  ["meera",    "Meera Iyer",      "female", "grounded-nurturers",  ["Poetry","Film","Travel"],      "Tender, expressive, emotionally careful and direct.",               { o:.65,c:.75,e:.50,a:.88,n:.45, att:"secure",     se:"medium",     cs:"warm",       tp:"slowTrust",  hs:"warm",           cf:"accommodating"}],
  ["sanjay",   "Sanjay Rao",      "male",   "grounded-nurturers",  ["Cooking","Books","Mindfulness"],"Steady presence, shows up consistently, quiet strength.",          { o:.55,c:.82,e:.42,a:.85,n:.20, att:"secure",     se:"medium",     cs:"warm",       tp:"slowTrust",  hs:"warm",           cf:"avoiding"    }],
  ["pooja",    "Pooja Desai",     "female", "grounded-nurturers",  ["Cooking","Art","Mindfulness"], "Nurturing, patient, holds space for others without resentment.",   { o:.60,c:.78,e:.48,a:.90,n:.30, att:"secure",     se:"medium",     cs:"warm",       tp:"conditionalTrust", hs:"warm", cf:"accommodating"}],
  ["nikhil",   "Nikhil Shah",     "male",   "grounded-nurturers",  ["Books","Outdoors","Cooking"],  "Grounded, reliable, prefers depth over breadth in friendship.",     { o:.50,c:.80,e:.40,a:.82,n:.25, att:"secure",     se:"low",        cs:"analytical", tp:"slowTrust",  hs:"observational", cf:"analytical" }],
  ["richa",    "Richa Agarwal",   "female", "grounded-nurturers",  ["Mindfulness","Writing","Art"], "Calm, deliberate, creates safe spaces naturally.",                 { o:.62,c:.72,e:.45,a:.87,n:.35, att:"secure",     se:"medium",     cs:"warm",       tp:"slowTrust",  hs:"warm",           cf:"accommodating"}],

  // longform-thinkers — 5 people (2M/3F), below threshold — no circle meeting
  ["farhan",   "Farhan Ahmed",    "male",   "longform-thinkers",   ["Books","Psychology","Film"],   "Bookish, introspective, prefers layered conversation.",             { o:.95,c:.65,e:.25,a:.65,n:.50, att:"avoidant",   se:"low",        cs:"analytical", tp:"slowTrust",  hs:"observational", cf:"analytical" }],
  ["tara",     "Tara Menon",      "female", "longform-thinkers",   ["Books","Writing","Psychology"],"Quietly expansive, reads deeply, thinks before speaking.",         { o:.92,c:.60,e:.28,a:.70,n:.55, att:"avoidant",   se:"low",        cs:"analytical", tp:"slowTrust",  hs:"dry",            cf:"avoiding"    }],
  ["dhruv",    "Dhruv Kapoor",    "male",   "longform-thinkers",   ["Books","Music","Tech"],        "Intellectual companion, values ideas over small talk.",             { o:.88,c:.55,e:.35,a:.60,n:.48, att:"secure",     se:"low",        cs:"analytical", tp:"slowTrust",  hs:"observational", cf:"analytical" }],
  ["sonal",    "Sonal Bhatia",    "female", "longform-thinkers",   ["Writing","Books","Art"],       "Essayist mind, finds patterns others miss, slow to open.",          { o:.90,c:.58,e:.30,a:.68,n:.52, att:"avoidant",   se:"low",        cs:"expressive", tp:"slowTrust",  hs:"observational", cf:"analytical" }],
  ["amit",     "Amit Saxena",     "male",   "longform-thinkers",   ["Books","Psychology","Music"],  "Philosophical, patient, seeks root causes in everything.",          { o:.85,c:.62,e:.38,a:.72,n:.42, att:"secure",     se:"low",        cs:"analytical", tp:"conditionalTrust", hs:"dry", cf:"analytical" }],
];

// Community memberships per user (by seed id)
const COMMUNITY_JOINS = {
  gurusharan: ["ai-builders","startups","design-craft"],
  priya:   ["ai-builders","design-craft","mindful-living","creative-writing","longform-reading","jazz-music"],
  rohan:   ["ai-builders","startups","jazz-music"],
  ananya:  ["longform-reading","creative-writing","mindful-living"],
  arjun:   ["jazz-music","longform-reading","trekking-outdoors"],
  kavya:   ["design-craft","creative-writing","ai-builders"],
  vivek:   ["ai-builders","startups","longform-reading"],
  isha:    ["ai-builders","design-craft","startups"],
  aditya:  ["startups","trekking-outdoors","jazz-music"],
  karan:   ["trekking-outdoors","startups","jazz-music"],
  zara:    ["jazz-music","creative-writing","trekking-outdoors"],
  neil:    ["ai-builders","trekking-outdoors","startups"],
  diya:    ["design-craft","creative-writing","jazz-music"],
  raj:     ["startups","trekking-outdoors","ai-builders"],
  naina:   ["jazz-music","creative-writing","longform-reading"],
  meera:   ["creative-writing","jazz-music","mindful-living"],
  sanjay:  ["mindful-living","longform-reading","trekking-outdoors"],
  pooja:   ["mindful-living","design-craft","creative-writing"],
  nikhil:  ["trekking-outdoors","longform-reading","mindful-living"],
  richa:   ["mindful-living","creative-writing","design-craft"],
  farhan:  ["longform-reading","creative-writing","mindful-living"],
  tara:    ["longform-reading","creative-writing","design-craft"],
  dhruv:   ["ai-builders","longform-reading","jazz-music"],
  sonal:   ["creative-writing","longform-reading","design-craft"],
  amit:    ["longform-reading","jazz-music","mindful-living"],
};

// Soulmate matches: pairs of seed ids who mutually selected each other
const SOULMATE_PAIRS = [
  ["gurusharan", "priya"],
  ["priya", "rohan"],
  ["priya", "meera"],
  ["priya", "ananya"],
  ["priya", "vivek"],
  ["ananya", "arjun"],
  ["karan", "zara"],
  ["meera", "sanjay"],
];

// Chat threads per pair — mockup plate 05 (Arjun/Meera/Rohan sidebar + jazz thread)
const CHAT_THREADS = [
  {
    pair: ["priya", "gurusharan"],
    messages: [
      ["gurusharan", "That Coltrane track you mentioned in the meetup was 🔥"],
      ["priya", "Glad you noticed! What's your go-to these days?"],
      ["gurusharan", "Lately, it's been Ballads. Soothing on slow Sundays."],
      ["priya", "Same here. Anything beyond jazz you've been enjoying?"],
      ["gurusharan", "I've been reading a lot of essays. Really into long-form thinking."],
      ["priya", "Nice! Any recommendations?"],
      ["gurusharan", "That Coltrane track was insane live! 🔥"],
    ],
  },
  {
    pair: ["priya", "meera"],
    messages: [["meera", "Yes! That sounds perfect."]],
  },
  {
    pair: ["priya", "rohan"],
    messages: [["rohan", "Looking forward to our next circle check-in."]],
  },
  {
    pair: ["priya", "ananya"],
    messages: [["ananya", "The essay you recommended was brilliant."]],
  },
  {
    pair: ["priya", "vivek"],
    messages: [["vivek", "Let's catch up soon!"]],
  },
  {
    pair: ["ananya", "arjun"],
    messages: [
      ["ananya", "That book recommendation you gave — I ordered it immediately."],
      ["arjun", "Haha, trust me it rewards slow reading. Let me know when you hit chapter 4."],
      ["ananya", "Already on chapter 3. Can't put it down."],
    ],
  },
  {
    pair: ["karan", "zara"],
    messages: [
      ["karan", "Next trek — I'm thinking Hampi. You in?"],
      ["zara", "Say less. I'm already looking at trains."],
      ["karan", "Haha that energy is exactly why this works."],
      ["zara", "Stop, you're going to make me blush. Saturday can't come fast enough."],
    ],
  },
  {
    pair: ["meera", "sanjay"],
    messages: [
      ["meera", "The mindful living room felt like a exhale. Thank you for holding that space."],
      ["sanjay", "That means a lot. You brought something really honest to the circle."],
    ],
  },
];

function userIdForSeed(seedId) {
  const appleSub = `dev-${crypto.createHash("sha256").update(`validation-${seedId}`).digest("hex").slice(0, 16)}`;
  return `usr_${crypto.createHash("sha256").update(`apple:${appleSub}`).digest("hex").slice(0, 24)}`;
}

function seededUserIds() {
  return PEOPLE.map(([seedId]) => userIdForSeed(seedId));
}

function readJson(file, fallback) {
  if (!fs.existsSync(file)) return fallback;
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function removeLocalValidationData() {
  assert.ok(!process.env.DATABASE_URL, "remove is local-only; refusing to modify DATABASE_URL data");
  const ids = new Set(seededUserIds());
  const mvp = readJson(mvpStorePath, null);
  const architecture = readJson(architectureStorePath, null);
  let removed = 0;

  if (mvp) {
    for (const [id, user] of Object.entries(mvp.users || {})) {
      if (ids.has(id) || String(user.apple_sub || "").startsWith("dev-")) {
        delete mvp.users[id];
        removed += 1;
      }
    }
    mvp.profiles = (mvp.profiles || []).filter((row) => !ids.has(row.user_id));
    mvp.placements = (mvp.placements || []).filter((row) => !ids.has(row.user_id));
    mvp.transcripts = (mvp.transcripts || []).filter((row) => !ids.has(row.user_id));
    mvp.feedback = (mvp.feedback || []).filter((row) => !ids.has(row.user_id));
    mvp.communityMemberships = (mvp.communityMemberships || []).filter((row) => !ids.has(row.user_id));
    mvp.meetingRsvps = (mvp.meetingRsvps || []).filter((row) => !ids.has(row.user_id));
    mvp.meetings = (mvp.meetings || []).filter((row) => !(row.participantIds || []).some((id) => ids.has(id)));
    mvp.soulmateUsers = Object.fromEntries(Object.entries(mvp.soulmateUsers || {}).filter(([id]) => !ids.has(id)));
    mvp.soulmateSelections = (mvp.soulmateSelections || []).filter((row) => !ids.has(row.userId));
    const keptMatches = new Set();
    mvp.soulmateMatches = (mvp.soulmateMatches || []).filter((row) => {
      const keep = !ids.has(row.userAId) && !ids.has(row.userBId);
      if (keep) keptMatches.add(row.id);
      return keep;
    });
    mvp.chatMessages = (mvp.chatMessages || []).filter((row) => keptMatches.has(row.matchId));
    writeJson(mvpStorePath, mvp);
  }

  // Validation lane reset: drop orphaned soulmate/chat rows so reseed starts clean.
  if (mvpStorePath.includes("validation-db")) {
    const mvp = readJson(mvpStorePath, null);
    if (mvp) {
      mvp.soulmateMatches = [];
      mvp.chatMessages = [];
      mvp.soulmateSelections = [];
      writeJson(mvpStorePath, mvp);
    }
  }

  if (architecture) {
    for (const collection of ["circles", "communities"]) {
      for (const item of Object.values(architecture[collection] || {})) {
        // Drop seed users; also drop historical bloat so micro-circles stay room-scale.
        item.members = (item.members || []).filter((id) => !ids.has(id));
        if (collection === "circles" && (item.members || []).length > 18) {
          item.members = item.members.slice(0, 12);
        }
      }
    }
    architecture.profiles = Object.fromEntries(Object.entries(architecture.profiles || {}).filter(([, row]) => !ids.has(row.userId)));
    architecture.placements = (architecture.placements || []).filter((row) => !ids.has(row.userId));
    architecture.transcripts = (architecture.transcripts || []).filter((row) => !ids.has(row.userId));
    writeJson(architectureStorePath, architecture);
  }

  console.log(JSON.stringify({ action: "remove", dbDir, removedSeedUsers: removed }, null, 2));
}

async function request(pathname, options = {}) {
  const response = await fetch(`${baseURL}${pathname}`, {
    ...options,
    headers: {
      ...(options.body ? { "content-type": "application/json" } : {}),
      ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
      ...(options.headers || {})
    },
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  const text = await response.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  assert.ok(response.status >= 200 && response.status < 300, `${options.method || "GET"} ${pathname} failed: ${response.status} ${text}`);
  return body;
}

const INTEREST_AREAS = {
  "Books": "books", "Writing": "art", "Psychology": "books", "Film": "movies",
  "Music": "music", "Jazz": "music", "Design": "art", "Art": "art",
  "Cooking": "food", "Tech": "tech", "Startups": "tech", "Outdoors": "outdoors",
  "Travel": "outdoors", "Mindfulness": "books", "Poetry": "art",
};

const DEPTHS = ["casual", "active", "deep"];

function profileFor([id, name, gender, circleId, interests, summary, s]) {
  const interestObjects = interests.map((label, i) => ({
    area: INTEREST_AREAS[label] || "general",
    label,
    depth: DEPTHS[i % DEPTHS.length]
  }));
  return {
    interviewTranscript: `${name}: ${summary} I want real weekend conversations, not passive browsing.`,
    signals: {
      bigFive: { openness: s.o, conscientiousness: s.c, extraversion: s.e, agreeableness: s.a, neuroticism: s.n },
      attachment: s.att,
      socialEnergy: s.se,
      communicationStyle: { primary: s.cs, pace: 0.48 },
      trustPattern: s.tp,
      humorStyle: s.hs,
      conflictStyle: s.cf
    },
    basicInfo: { name, gender, dateOfBirth: "1996-01-01", city: "Bangalore", pincode: "560001" },
    interests: interestObjects,
    hiddenSignals: {
      shyness: s.se === "low" ? 0.6 : s.se === "medium" ? 0.35 : 0.15,
      languageComfort: 0.9,
      warmth: s.a,
      vulnerabilityOpenness: s.e > 0.6 ? 0.7 : 0.5,
      dominanceTendency: s.cs === "direct" ? 0.6 : 0.25,
      energyTrajectory: s.se === "high" ? "steady_high" : "warms_up"
    },
    primaryCircleId: circleId,
    secondaryCircleIds: ["longform-thinkers", "grounded-nurturers"].slice(0, 2),
    fitReasons: [`Matches ${circleId.replace("-", " ")} energy.`, "Shows warm, steady trust.", "Can contribute without dominating."],
    sourceReflectionSignals: [summary],
    profileSummary: summary
  };
}

// Create past meetings directly in the local store for users who have upcoming meetings
function addPastMeetings(userMap) {
  if (process.env.DATABASE_URL) return; // local-only
  if (!fs.existsSync(mvpStorePath)) return;
  const store = readJson(mvpStorePath, null);
  if (!store) return;

  const now = Date.now();
  const lastWeek = new Date(now - 7 * 86400000).toISOString();
  const twoWeeksAgo = new Date(now - 14 * 86400000).toISOString();

  // ponytail: two past meetings with realistic participant groups from seeded users
  const reflectiveIds = PEOPLE.filter(([, , , c]) => c === "reflective-builders").slice(0, 8).map(([sid]) => userMap[sid].id);
  const jazzIds = [
    userMap.gurusharan.id,
    ...PEOPLE.filter((p) => (COMMUNITY_JOINS[p[0]] || []).includes("jazz-music")).slice(0, 7).map(([sid]) => userMap[sid].id)
  ].filter((id, index, ids) => ids.indexOf(id) === index);

  const pastMeetings = [
    {
      id: `mtg_circle_reflective-builders_${new Date(now - 7 * 86400000).toISOString().slice(0,10)}_1`,
      kind: "circle",
      targetId: "reflective-builders",
      title: "Reflective Builders",
      scheduledAt: lastWeek,
      hostUserId: reflectiveIds[0],
      hostName: "Gurusharan Gupta",
      participantIds: reflectiveIds,
      groupSize: reflectiveIds.length,
      status: "completed",
      compositionSummary: `${reflectiveIds.length} people. You share slow-trust patterns and analytical communication.`
    },
    {
      id: `mtg_community_jazz-music_${new Date(now - 14 * 86400000).toISOString().slice(0,10)}_1`,
      kind: "community",
      targetId: "jazz-music",
      title: "Jazz Music",
      scheduledAt: twoWeeksAgo,
      hostUserId: jazzIds[0] || reflectiveIds[0],
      hostName: "Priya Shah",
      participantIds: jazzIds,
      groupSize: jazzIds.length,
      status: "completed",
      compositionSummary: `${jazzIds.length} people from nearby circles. Good mix of listeners and players.`
    }
  ];

  for (const meeting of pastMeetings) {
    if (!store.meetings.some((m) => m.id === meeting.id)) {
      store.meetings.push(meeting);
    }
  }
  writeJson(mvpStorePath, store);
}

async function seedValidationData() {
  await request("/health");
  const userMap = {};

  // Create users and proposed placements, then explicitly accept the seeded room.
  for (const person of PEOPLE) {
    const auth = await request("/v1/auth/apple", {
      method: "POST",
      body: { identityToken: `validation-${person[0]}`, fullName: person[1] }
    });
    await request("/v1/realtime/profile-placement", {
      method: "POST",
      token: auth.sessionToken,
      body: profileFor(person)
    });
    await request("/v1/me/placement/actions", {
      method: "POST",
      token: auth.sessionToken,
      body: { action: "accept" }
    });
    userMap[person[0]] = { id: auth.user.id, name: person[1], sessionToken: auth.sessionToken };
  }

  // Community joins
  for (const [seedId, communityIds] of Object.entries(COMMUNITY_JOINS)) {
    if (!userMap[seedId]) continue;
    for (const cid of communityIds) {
      await request(`/v1/communities/${cid}/join`, { method: "POST", token: userMap[seedId].sessionToken });
    }
  }

  // RSVPs — circle and community for all users
  for (const seedId of Object.keys(userMap)) {
    await request("/v1/meetings/rsvp", { method: "POST", token: userMap[seedId].sessionToken, body: { kind: "community", available: true } });
    await request("/v1/meetings/rsvp", { method: "POST", token: userMap[seedId].sessionToken, body: { kind: "circle", available: true } });
  }

  // Enable soulmate for all users
  for (const seedId of Object.keys(userMap)) {
    await request("/v1/me/soulmate/enable", { method: "POST", token: userMap[seedId].sessionToken, body: { enabled: true } });
  }

  // Run scheduling to form upcoming meetings
  const scheduled = await request("/v1/admin/run-scheduling", { method: "POST" });

  // Add past meetings directly to store
  addPastMeetings(userMap);

  // Soulmate matches — need meeting context for selection
  // Find meetings that participants share
  const upcoming = await request("/v1/meetings/upcoming", { token: userMap["gurusharan"].sessionToken });
  const allUpcoming = upcoming.upcoming || [];
  if (allUpcoming[0]) {
    await request(`/v1/meetings/${allUpcoming[0].id}/recap-note`, {
      method: "POST",
      token: userMap["gurusharan"].sessionToken,
      body: { note: "I felt the group warmed up once the host slowed the pace." }
    });
  }

  // For soulmate selection we need a meeting both share
  for (const [seedA, seedB] of SOULMATE_PAIRS) {
    const userA = userMap[seedA];
    const userB = userMap[seedB];
    if (!userA || !userB) continue;

    // Find a meeting userA is part of; the server validates that userB is also a participant
    const userAMeetings = await request("/v1/meetings/upcoming", { token: userA.sessionToken });
    const candidates = userAMeetings.upcoming || [];
    let matched = false;
    for (const meeting of candidates) {
      try {
        await request("/v1/me/soulmate/select", {
          method: "POST", token: userA.sessionToken,
          body: { meetingId: meeting.id, selectedUserIds: [userB.id] }
        });
        await request("/v1/me/soulmate/select", {
          method: "POST", token: userB.sessionToken,
          body: { meetingId: meeting.id, selectedUserIds: [userA.id] }
        });
        matched = true;
        break;
      } catch {
        // meeting doesn't include both users — try next
      }
    }
    if (!matched) console.warn(`No shared meeting for soulmate pair ${seedA}/${seedB}`);
  }

  async function findMatchId(seedA, seedB) {
    const matches = await request("/v1/me/soulmate/matches", { token: userMap[seedA].sessionToken });
    const otherId = userMap[seedB].id;
    return matches.find((row) => row.userId === otherId)?.matchId;
  }

  // Chat messages per thread (target the correct mutual match)
  for (const thread of CHAT_THREADS) {
    const [seedA, seedB] = thread.pair;
    const matchId = await findMatchId(seedA, seedB) || await findMatchId(seedB, seedA);
    if (!matchId) {
      console.warn(`No match for chat thread ${seedA}/${seedB}`);
      continue;
    }
    for (const [senderSeed, text] of thread.messages) {
      await request(`/v1/me/soulmate/matches/${matchId}/messages`, {
        method: "POST", token: userMap[senderSeed].sessionToken,
        body: { text },
      });
    }
  }

  // Verify data density
  const primaryUser = userMap["gurusharan"];
  const verifyProfile = await request("/v1/me/profile", { token: primaryUser.sessionToken });
  const verifyCircles = await request("/v1/me/circles", { token: primaryUser.sessionToken });
  const verifyMeetings = await request("/v1/meetings/upcoming", { token: primaryUser.sessionToken });
  const verifyMatches = await request("/v1/me/soulmate/matches", { token: primaryUser.sessionToken });
  const verifyNotifications = await request("/v1/me/notifications", { token: primaryUser.sessionToken });
  const verifyMessages = verifyMatches[0]
    ? await request(`/v1/me/soulmate/matches/${verifyMatches[0].matchId}/messages`, { token: primaryUser.sessionToken })
    : { messages: [] };

  assert.ok(verifyProfile.profile?.basicInfo?.name || verifyProfile.basicInfo?.name, "profile must have basicInfo");
  assert.ok((verifyCircles.circles || []).length > 0, "must have joined circles");
  assert.ok((verifyMeetings.upcoming || []).length > 0, "must have upcoming meetings");
  assert.ok((verifyMeetings.past || []).length >= 2, "must have at least two past meetings");
  assert.ok(verifyMeetings.upcoming.some((meeting) => meeting.recapNote), "must have a seeded recap note");
  assert.ok(verifyMatches.length > 0, "must have soulmate matches");
  assert.ok((verifyMessages.messages || []).length > 0, "must have seeded chat messages");
  assert.ok((verifyNotifications.notifications || []).length > 0, "must have seeded notifications");
  assert.ok((verifyNotifications.activity || []).length > 0, "must have seeded activity items");

  console.log(JSON.stringify({
    action: "seed",
    baseURL,
    primaryUser: showToken ? primaryUser : { id: primaryUser.id, name: primaryUser.name },
    stats: {
      users: PEOPLE.length,
      circlesRepresented: [...new Set(PEOPLE.map((p) => p[3]))].length,
      communitiesJoined: Object.values(COMMUNITY_JOINS).flat().length,
      soulmateMatches: SOULMATE_PAIRS.length,
      chatMessages: CHAT_THREADS.reduce((sum, thread) => sum + thread.messages.length, 0),
      upcomingMeetingsScheduled: scheduled.meetings?.length || 0,
      primaryUpcomingMeetings: verifyMeetings.upcoming?.length || 0,
      primaryPastMeetings: verifyMeetings.past?.length || 0,
      primaryChatMessages: verifyMessages.messages?.length || 0,
      primaryNotifications: verifyNotifications.notifications?.length || 0,
      primaryActivityItems: verifyNotifications.activity?.length || 0
    }
  }, null, 2));
}

(async () => {
  if (action === "remove") {
    removeLocalValidationData();
    return;
  }
  if (action === "reset") removeLocalValidationData();
  await seedValidationData();
})().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
