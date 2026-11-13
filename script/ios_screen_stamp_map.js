#!/usr/bin/env node
/**
 * iOS capture stamp map — control ids provable by screen-capture per logical screen.
 * Intersects the historical macOS screen stamp sets with ids present on platforms.ios controls.
 */
const { SCREEN_REGISTRY } = require("./ledger_migrate_to_screens");
const { findScreenByArg, platformControls } = require("./ledger_screens");

/** macOS logical launch screen → control ids retained for iOS capture compatibility. */
const MAC_STAMP_CONTROLS = {
  meetOverview: "join-meetup,rsvp-sat-yes,rsvp-sat-no,rsvp-sun-yes,rsvp-sun-no,past-row",
  communityDetail:
    "view-members,event-rows,join-leave,community-options,resources-guidelines,resources-prompts,highlights-essay,highlights-recommendation",
  circleDetail: "message-circle,placement-concern,upcoming-meet",
  circlesRoom: "concern-btn,circle-card",
  communitiesBrowse: "search,filter-pills,create-card,community-card",
  communityMembers: "sidebar-nav,search,filter-pills,member-rows",
  notifications: "notif-filter-pills,mark-all-read,activity-filter-pills,refresh,rows",
  meetRecap: "recap-note,save-note,message-match",
  createEvent:
    "event-type-meetup,event-type-listening-session,event-type-jam-session,event-fields,add-cover,add-tags,create-event,bottom-nav,traffic-lights",
  profileOnboarding: "step-rows,form-lines,continue,voice-profile-step,join-circle-step",
  profileEdit: "comm-pills,trait-sliders,save",
  soulmateOverview: "enable-toggle,how-it-works",
  soulmateDiscover:
    "mutual-match-roster,refresh-matches,manage-soulmate-settings,match-card,no-mutual-matches,pending-selection",
  soulmateDetail:
    "mutual-match-status,mutual-selection-explanation,match-interests,back-to-soulmate,message",
  settingsSoulmate:
    "sidebar-honesty,account-settings,privacy-safety,notifications-settings,connected-apps,appearance,language,help-support,log-out,delete-account,soulmate-toggle,discovery-who,discovery-age-range,discovery-visibility,discovery-save,preferences-enforcement-disclaimer",
  meetVideoCall: "tiles,mute,leave",
  myProfile:
    "voice-informed-signals,profile-inference-disclaimer,why-this-placement,placement-disclaimer,review-signals,re-interview,edit-profile",
  createCommunity: "name,summary,themes,submit",
  profileSignals: "done",
  chat: "match-row,draft,send,search,voice-call-header,video-call-header,conversation-info-header",
  messages: "match-row,draft,send,close,voice-call-header,video-call-header,conversation-info-header",
  welcome: "sign-in-apple,sign-in-google,sign-in-metamask,sign-in-solflare"
};

/** Logical screens without dedicated --mac-screen use signed-in shell entry */
const LOGICAL_MAC_FALLBACK = {
  "app-shell": "meetOverview"
};

/** Logical iOS screens whose preview captures prove layout but no behavior. */
const IOS_CAPTURE_OVERRIDES = {
  "profile-edit": [],
  "voice-session": []
};

/** Legacy iOS ledger id / slug aliases → logical_screen_id */
const SCREEN_ALIASES = {
  "01-auth-gate": "auth",
  "auth-gate": "auth",
  "02-onboarding": "onboarding",
  "03-profile-empty": "profile-empty",
  "04-profile-populated": "profile-populated",
  "05-profile-concern": "profile-concern",
  "06-voice-session-sheet": "voice-session",
  "07-meet": "meet",
  "08-past-meet-detail": "past-meet-recap",
  "09-group-video-call": "video-call",
  "10-circles": "circles",
  "11-circle-detail": "circle-detail",
  "12-communities": "communities",
  "13-community-detail": "community-detail",
  "14-soulmate": "soulmate-overview",
  "15-soulmate-match-detail": "soulmate-match",
  "16-chat": "chat",
  "17-conversations": "conversations",
  "18-soulmate-selection": "soulmate-selection",
  "19-notifications": "notifications",
  "20-settings": "settings",
  "21-settings-privacy": "settings",
  "22-settings-info": "settings",
  "23-settings-support": "settings",
  "24-create-community": "create-community",
  "25-community-members": "community-members",
  "26-create-event": "create-event"
};

function logicalIdFromScreenArg(screenArg) {
  const key = String(screenArg || "").replace(/\.json$/, "");
  if (SCREEN_ALIASES[key]) return SCREEN_ALIASES[key];
  const row = SCREEN_REGISTRY.find(
    (r) => r.id === key || r.ios === key || r.macos === key
  );
  if (row) return row.id;
  try {
    return findScreenByArg(key).logicalId;
  } catch {
    return key;
  }
}

function macScreenForLogical(logicalId) {
  try {
    const { data } = findScreenByArg(logicalId);
    for (const src of data.platforms?.macos?.source_files || []) {
      const text = String(src);
      const macHint = text.match(/MacScreens\.swift \(([a-zA-Z]+)\)/);
      if (macHint && MAC_STAMP_CONTROLS[macHint[1]]) return macHint[1];
      const hint = text.match(/\(([a-zA-Z]+)\)\s*$/);
      if (hint && MAC_STAMP_CONTROLS[hint[1]]) return hint[1];
    }
  } catch {
    // fall through
  }
  const row = SCREEN_REGISTRY.find((r) => r.id === logicalId);
  if (!row?.macos) {
    return LOGICAL_MAC_FALLBACK[logicalId] || null;
  }
  const macFile = row.macos.replace(/^\d+-/, "");
  const camel = macFile.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
  if (MAC_STAMP_CONTROLS[camel]) return camel;
  return LOGICAL_MAC_FALLBACK[logicalId] || null;
}

function iosStampControlsForScreen(screenArg) {
  const logicalId = logicalIdFromScreenArg(screenArg);
  let screenData;
  try {
    screenData = findScreenByArg(logicalId).data;
  } catch {
    return { logicalId, controls: [] };
  }
  const iosIds = new Set(platformControls(screenData, "ios").map((c) => c.id));
  if (Object.hasOwn(IOS_CAPTURE_OVERRIDES, logicalId)) {
    return { logicalId, controls: IOS_CAPTURE_OVERRIDES[logicalId] };
  }
  const macScreen = macScreenForLogical(logicalId);
  let candidates = [];
  if (macScreen && MAC_STAMP_CONTROLS[macScreen]) {
    candidates = MAC_STAMP_CONTROLS[macScreen].split(",").map((s) => s.trim());
  } else {
    candidates = [...iosIds];
  }
  const controls = candidates.filter((id) => iosIds.has(id));
  return { logicalId, controls };
}

module.exports = {
  MAC_STAMP_CONTROLS,
  LOGICAL_MAC_FALLBACK,
  IOS_CAPTURE_OVERRIDES,
  SCREEN_ALIASES,
  logicalIdFromScreenArg,
  macScreenForLogical,
  iosStampControlsForScreen
};
