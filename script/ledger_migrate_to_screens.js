#!/usr/bin/env node
/**
 * Migrate validation/ios + validation/macos → validation/screens/*.json
 * Preserves all controls, evidence, and derives flows[] as primary status unit.
 */
const fs = require("node:fs");
const path = require("node:path");
const { root, hashScreenSources } = require("./ledger_hash");
const { SCHEMA_VERSION, writeScreen } = require("./ledger_screens");

const IOS_DIR = path.join(root, "validation", "ios");
const MAC_DIR = path.join(root, "validation", "macos");
const OUT_DIR = path.join(root, "validation", "screens");
const LEGACY_DIR = path.join(root, "validation", "_legacy");

/** @type {Array<{id:string,name:string,ios?:string|null,macos?:string|null}>} */
const SCREEN_REGISTRY = [
  { id: "auth", name: "Auth / Sign in", ios: "01-auth-gate", macos: "01-welcome" },
  { id: "onboarding", name: "Profile Onboarding (3-step)", ios: "02-onboarding", macos: "13-profile-onboarding" },
  { id: "profile-empty", name: "Profile (empty — voice interview hero)", ios: "03-profile-empty", macos: null },
  { id: "profile-populated", name: "Profile (populated — signals + interests)", ios: "04-profile-populated", macos: "12-my-profile" },
  { id: "profile-concern", name: "Profile (re-interview when concernFlag)", ios: "05-profile-concern", macos: null },
  { id: "voice-session", name: "Voice Profile Session Sheet", ios: "06-voice-session-sheet", macos: null },
  { id: "profile-edit", name: "Profile Edit (traits / living profile)", ios: null, macos: "05-profile-edit" },
  { id: "profile-signals", name: "Profile Signals (share / edit mode)", ios: null, macos: "14-profile-signals" },
  { id: "meet", name: "Meet (RSVP + upcoming + past)", ios: "07-meet", macos: "02-meet-overview" },
  { id: "past-meet-recap", name: "Past Meet Detail / Recap", ios: "08-past-meet-detail", macos: "11-meet-recap" },
  { id: "video-call", name: "Group Video Call (LiveKit)", ios: "09-group-video-call", macos: "21-meet-video-call" },
  { id: "circles", name: "Circles (your circle + browse + concern)", ios: "10-circles", macos: "03-circles-room" },
  { id: "circle-detail", name: "Circle Detail", ios: "11-circle-detail", macos: "04-circle-detail" },
  { id: "communities", name: "Communities (browse + search)", ios: "12-communities", macos: "07-communities-browse" },
  { id: "community-detail", name: "Community Detail", ios: "13-community-detail", macos: "08-community-detail" },
  { id: "community-members", name: "Community Members", ios: "25-community-members", macos: "09-community-members" },
  { id: "create-community", name: "Create Community", ios: "24-create-community", macos: "22-create-community" },
  { id: "create-event", name: "Create Event", ios: "26-create-event", macos: "10-create-event" },
  { id: "soulmate-overview", name: "Soulmate Overview", ios: "14-soulmate", macos: "15-soulmate-overview" },
  { id: "soulmate-discover", name: "Soulmate Discover", ios: null, macos: "16-soulmate-discover" },
  { id: "soulmate-match", name: "Soulmate Match Detail", ios: "15-soulmate-match-detail", macos: "17-soulmate-detail" },
  { id: "soulmate-selection", name: "Soulmate Selection (post-meet)", ios: "18-soulmate-selection", macos: null },
  { id: "chat", name: "Chat (match thread)", ios: "16-chat", macos: "06-chat" },
  { id: "conversations", name: "Conversations / Messages list", ios: "17-conversations", macos: "18-messages" },
  { id: "notifications", name: "Notifications + Activity", ios: "19-notifications", macos: "19-notifications" },
  { id: "settings", name: "Settings (account, privacy, support)", ios: "20-settings", macos: "20-settings-soulmate" }
];

/** Extra iOS settings ledgers folded into settings screen controls/flows */
const IOS_SETTINGS_EXTRA = ["21-settings-privacy", "22-settings-info", "23-settings-support"];

/** Explicit multi-control flows; controls not listed fall into per-control flows */
const FLOW_DEFS = {
  auth: [
    {
      id: "sign-in-apple",
      name: "Sign in with Apple",
      ios: ["sign-in-apple"],
      macos: ["sign-in-apple"],
      destinations: ["onboarding"]
    },
    {
      id: "alternate-auth",
      name: "Google / wallet sign-in options",
      ios: ["sign-in-google", "sign-in-metamask", "sign-in-solflare"],
      macos: []
    },
    {
      id: "auth-promise-copy",
      name: "Auth promise rows visible",
      ios: ["promise-rows"],
      macos: []
    }
  ],
  onboarding: [
    {
      id: "onboarding-steps",
      name: "Navigate 3-step onboarding sidebar",
      ios: ["step-rows"],
      macos: ["step-rows"]
    },
    {
      id: "onboarding-basics",
      name: "Complete basics (name, city, interests) and continue",
      ios: ["form-lines", "continue"],
      macos: ["form-lines", "continue"],
      backend: ["PATCH /v1/me/profile"]
    },
    {
      id: "onboarding-voice",
      name: "Complete voice profile step",
      ios: ["voice-profile-step"],
      macos: ["voice-profile-step"],
      backend: ["POST /v1/me/profile/from-interview", "GET /v1/me/placement"]
    },
    {
      id: "onboarding-join-circle",
      name: "Join first circle (step 3)",
      ios: ["join-circle-step"],
      macos: ["join-circle-step"],
      destinations: ["circles"]
    },
    {
      id: "complete-first-time-setup",
      name: "E2E: onboarding → placement → meet greeting → profile name",
      ios: ["step-rows", "form-lines", "continue", "voice-profile-step", "join-circle-step"],
      macos: ["step-rows", "form-lines", "continue", "voice-profile-step", "join-circle-step"],
      spans: ["profile-populated", "circles", "meet"],
      backend: ["PATCH /v1/me/profile", "GET /v1/me/placement"]
    }
  ],
  meet: [
    {
      id: "rsvp-weekend",
      name: "RSVP Saturday (community) and Sunday (circle)",
      ios: ["rsvp-sat-yes", "rsvp-sat-no", "rsvp-sun-yes", "rsvp-sun-no"],
      macos: ["rsvp-sat-yes", "rsvp-sat-no", "rsvp-sun-yes", "rsvp-sun-no"],
      backend: ["POST /v1/meetings/rsvp"]
    },
    {
      id: "open-notifications",
      name: "Open notifications from Meet",
      ios: ["bell"],
      macos: [],
      destinations: ["notifications"]
    },
    {
      id: "join-live-meetup",
      name: "Join upcoming LiveKit room",
      ios: ["join-upcoming"],
      macos: ["join-meetup", "join-room"],
      destinations: ["video-call"],
      backend: ["POST /v1/meetings/:id/join"]
    },
    {
      id: "open-past-meet",
      name: "Open past meet recap",
      ios: ["past-row"],
      macos: ["past-row"],
      destinations: ["past-meet-recap"]
    }
  ],
  settings: [
    {
      id: "settings-soulmate-toggle",
      name: "Toggle Soulmate visibility",
      ios: ["soulmate-toggle"],
      macos: ["soulmate-toggle"]
    },
    {
      id: "settings-sign-out",
      name: "Sign out of account",
      ios: ["sign-out"],
      macos: ["log-out"]
    },
    {
      id: "settings-delete-account",
      name: "Delete account",
      ios: ["delete-account"],
      macos: ["delete-account"],
      backend: ["DELETE /v1/me/account"]
    },
    {
      id: "settings-privacy",
      name: "View privacy policy",
      ios: ["privacy", "done"],
      macos: ["privacy-safety"]
    },
    {
      id: "settings-help",
      name: "How it works / Help & FAQ",
      ios: ["how-it-works", "help", "done"],
      macos: ["help-support", "how-it-works"]
    },
    {
      id: "settings-support",
      name: "Contact support",
      ios: ["support", "message", "send"],
      macos: ["help-support"]
    },
    {
      id: "settings-discovery",
      name: "Soulmate discovery preferences",
      ios: ["discovery-preferences"],
      macos: ["discovery-preference", "age-range", "visibility"]
    }
  ],
  "past-meet-recap": [
    {
      id: "recap-save-note",
      name: "Save private recap note",
      ios: ["reflection-note", "save-note"],
      macos: ["recap-note", "save-note"],
      backend: ["POST /v1/meetings/:id/recap-note"]
    },
    {
      id: "recap-soulmate-select",
      name: "Select connections for Soulmate (post-meet)",
      ios: ["select-connections", "message-match"],
      macos: ["message-match"],
      destinations: ["soulmate-selection"]
    }
  ],
  "soulmate-selection": [
    {
      id: "post-meet-selection-submit",
      name: "Submit post-meet Soulmate selection",
      ios: ["match-toggle", "submit"],
      macos: [],
      backend: ["POST /v1/me/soulmate/select"]
    }
  ],
  chat: [
    {
      id: "send-message",
      name: "Send chat message",
      ios: ["draft", "send", "message-list"],
      macos: ["draft", "send", "match-row"]
    },
    {
      id: "chat-call-headers",
      name: "Voice/video call and conversation info",
      ios: [],
      macos: ["voice-call-header", "video-call-header", "conversation-info-header"]
    }
  ],
  conversations: [
    {
      id: "open-conversation",
      name: "Open conversation from list",
      ios: ["conv-row"],
      macos: ["match-row"],
      destinations: ["chat"]
    },
    {
      id: "messages-compose",
      name: "Messages list filters and compose",
      ios: [],
      macos: ["draft", "send", "close", "search"]
    }
  ]
};

function loadLegacy(platform, fileId) {
  if (!fileId) return null;
  for (const dir of [
    platform === "ios" ? IOS_DIR : MAC_DIR,
    path.join(LEGACY_DIR, platform)
  ]) {
    const abs = path.join(dir, `${fileId}.json`);
    if (fs.existsSync(abs)) return JSON.parse(fs.readFileSync(abs, "utf8"));
  }
  return null;
}

function pickPlatformFields(data) {
  if (!data) return null;
  const hash = hashScreenSources(data, root) || data.source_hash || null;
  return {
    ledger_legacy_id: null,
    implemented: true,
    source_files: data.source_files || [],
    source_hash: hash,
    mockup_ref: data.mockup_ref || null,
    mockup_missing: data.mockup_missing ?? false,
    entry_points: data.entry_points || [],
    backend_dependencies: data.backend_dependencies || [],
    ui_validation: data.ui_validation || data.visual_parity || null,
    visual_parity: data.visual_parity || data.ui_validation || null,
    recent_screenshot_ref: data.recent_screenshot_ref || null,
    notes: data.notes || ""
  };
}

function absentPlatform(reason) {
  return {
    ledger_legacy_id: null,
    implemented: false,
    source_files: [],
    source_hash: null,
    mockup_ref: null,
    mockup_missing: true,
    entry_points: [],
    backend_dependencies: [],
    ui_validation: null,
    visual_parity: null,
    recent_screenshot_ref: null,
    notes: reason
  };
}

function aggregateValidation(controlIds, controls, { implemented = true } = {}) {
  if (!implemented) {
    return {
      result: "not-applicable",
      evidence: "Platform screen not implemented",
      blocker: "",
      last_tested_at: "",
      tested_source_hash: "",
      last_test_method: ""
    };
  }
  const matched = controls.filter((c) => controlIds.includes(c.id));
  if (matched.length === 0) {
    if (controlIds.length === 0) {
      return {
        result: "not-applicable",
        evidence: "No controls on this platform for this flow",
        blocker: "",
        last_tested_at: "",
        tested_source_hash: "",
        last_test_method: ""
      };
    }
    return {
      result: "pending",
      evidence: "No controls mapped for this platform",
      blocker: "",
      last_tested_at: "",
      tested_source_hash: "",
      last_test_method: ""
    };
  }
  const results = matched.map((c) => String(c.result || "pending").toLowerCase());
  const pick = (pred) => matched.find(pred) || matched[0];
  if (results.every((r) => r === "pass")) {
    const c = pick(() => true);
    return {
      result: "pass",
      evidence: matched.map((x) => `${x.id}: ${(x.evidence || "").slice(0, 120)}`).join(" | "),
      blocker: "",
      last_tested_at: c.last_tested_at || "",
      tested_source_hash: c.tested_source_hash || "",
      last_test_method: c.last_test_method || ""
    };
  }
  if (results.some((r) => r === "fail")) {
    const c = matched.find((x) => String(x.result).toLowerCase() === "fail");
    return {
      result: "fail",
      evidence: c.evidence || "",
      blocker: c.blocker || "",
      last_tested_at: c.last_tested_at || "",
      tested_source_hash: c.tested_source_hash || "",
      last_test_method: c.last_test_method || ""
    };
  }
  if (results.every((r) => r === "blocked")) {
    const c = matched[0];
    return {
      result: "blocked",
      evidence: c.evidence || "",
      blocker: c.blocker || "",
      last_tested_at: c.last_tested_at || "",
      tested_source_hash: c.tested_source_hash || "",
      last_test_method: c.last_test_method || ""
    };
  }
  if (results.some((r) => r === "blocked")) {
    const c = matched.find((x) => String(x.result).toLowerCase() === "blocked") || matched[0];
    return {
      result: "blocked",
      evidence: c.evidence || "",
      blocker: c.blocker || "",
      last_tested_at: c.last_tested_at || "",
      tested_source_hash: c.tested_source_hash || "",
      last_test_method: c.last_test_method || ""
    };
  }
  const c = matched[0];
  return {
    result: "pending",
    evidence: c.evidence || "",
    blocker: c.blocker || "",
    last_tested_at: c.last_tested_at || "",
    tested_source_hash: c.tested_source_hash || "",
    last_test_method: c.last_test_method || ""
  };
}

function buildFlows(logicalId, iosControls, macosControls, iosData, macosData) {
  const flows = [];
  const usedIos = new Set();
  const usedMac = new Set();
  const defs = FLOW_DEFS[logicalId] || [];
  const iosImplemented = iosData != null;
  const macImplemented = macosData != null;

  for (const def of defs) {
    const iosIds = def.ios || [];
    const macIds = def.macos || [];
    iosIds.forEach((id) => usedIos.add(id));
    macIds.forEach((id) => usedMac.add(id));
    flows.push({
      id: def.id,
      name: def.name,
      origin: logicalId,
      steps: def.steps || [],
      destinations: def.destinations || [],
      spans: def.spans || [],
      backend: def.backend || [],
      control_ids: { ios: iosIds, macos: macIds },
      validation: {
        ios: aggregateValidation(iosIds, iosControls, { implemented: iosImplemented }),
        macos: aggregateValidation(macIds, macosControls, { implemented: macImplemented })
      }
    });
  }

  const addSingleton = (controls, platform, used) => {
    for (const c of controls) {
      if (used.has(c.id)) continue;
      used.add(c.id);
      const flowId = `${c.id}`;
      const other = platform === "ios" ? macosControls : iosControls;
      const otherIds = other.some((x) => x.id === c.id) ? [c.id] : [];
      if (platform === "ios") {
      flows.push({
        id: flowId,
        name: c.label || c.id,
        origin: logicalId,
        steps: [],
        destinations: [],
        spans: [],
        backend: [],
        control_ids: { ios: [c.id], macos: otherIds },
        validation: {
          ios: aggregateValidation([c.id], iosControls, { implemented: iosImplemented }),
          macos: aggregateValidation(otherIds, macosControls, { implemented: macImplemented })
        }
      });
      }
    }
  };

  addSingleton(iosControls, "ios", usedIos);
  for (const c of macosControls) {
    if (usedMac.has(c.id)) continue;
    if (flows.some((f) => f.id === c.id)) continue;
    const iosIds = iosControls.some((x) => x.id === c.id) ? [c.id] : [];
    usedMac.add(c.id);
    flows.push({
      id: c.id,
      name: c.label || c.id,
      origin: logicalId,
      steps: [],
      destinations: [],
      spans: [],
      backend: [],
      control_ids: { ios: iosIds, macos: [c.id] },
      validation: {
        ios: aggregateValidation(iosIds, iosControls, { implemented: iosImplemented }),
        macos: aggregateValidation([c.id], macosControls, { implemented: macImplemented })
      }
    });
  }

  return flows;
}

function mergeSettingsIos() {
  const main = loadLegacy("ios", "20-settings") || { controls: [] };
  const extras = IOS_SETTINGS_EXTRA.map((id) => loadLegacy("ios", id)).filter(Boolean);
  const controls = [...(main.controls || [])];
  for (const extra of extras) {
    for (const c of extra.controls || []) {
      if (!controls.some((x) => x.id === c.id)) controls.push(c);
    }
  }
  const merged = { ...main, controls };
  merged.notes = [main.notes, ...extras.map((e) => e.notes)].filter(Boolean).join("\n");
  return merged;
}

function migrate() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const report = { screens: 0, flows: 0, ios_controls: 0, macos_controls: 0 };

  for (const entry of SCREEN_REGISTRY) {
    const iosData =
      entry.id === "settings"
        ? mergeSettingsIos()
        : entry.ios
          ? loadLegacy("ios", entry.ios)
          : null;
    const macosData = entry.macos ? loadLegacy("macos", entry.macos) : null;

    const iosControls = iosData?.controls || [];
    const macosControls = macosData?.controls || [];
    report.ios_controls += iosControls.length;
    report.macos_controls += macosControls.length;

    const platforms = {
      ios: iosData ? { ...pickPlatformFields(iosData), ledger_legacy_id: entry.ios } : absentPlatform("No dedicated iOS screen — feature may live under another logical screen"),
      macos: macosData
        ? { ...pickPlatformFields(macosData), ledger_legacy_id: entry.macos }
        : absentPlatform("No dedicated macOS screen — feature may live under another logical screen")
    };

    const flows = buildFlows(entry.id, iosControls, macosControls, iosData, macosData);
    report.flows += flows.length;

    const screenDoc = {
      schema_version: SCHEMA_VERSION,
      logical_screen_id: entry.id,
      screen: entry.name,
      platforms,
      flows,
      controls: {
        ios: iosControls,
        macos: macosControls
      }
    };

    const outPath = path.join(OUT_DIR, `${entry.id}.json`);
    writeScreen(outPath, screenDoc);
    report.screens += 1;
  }

  return report;
}

function archiveLegacy() {
  if (!fs.existsSync(LEGACY_DIR)) fs.mkdirSync(LEGACY_DIR, { recursive: true });
  for (const [name, src] of [
    ["ios", IOS_DIR],
    ["macos", MAC_DIR]
  ]) {
    const dest = path.join(LEGACY_DIR, name);
    if (fs.existsSync(src) && !fs.existsSync(dest)) {
      fs.renameSync(src, dest);
    }
  }
}

if (require.main === module) {
  const report = migrate();
  console.log(`Migrated ${report.screens} logical screens, ${report.flows} flows`);
  console.log(`Controls preserved: ios=${report.ios_controls} macos=${report.macos_controls}`);
  if (process.argv.includes("--archive-legacy")) {
    archiveLegacy();
    console.log("Archived validation/ios and validation/macos → validation/_legacy/");
  }
}

module.exports = { SCREEN_REGISTRY, FLOW_DEFS, migrate, archiveLegacy };
