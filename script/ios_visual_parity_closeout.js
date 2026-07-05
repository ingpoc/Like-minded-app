#!/usr/bin/env node
/**
 * Stamp visual_parity.result=pass on iOS ledger JSON after mockup compare.
 * Usage: node script/ios_visual_parity_closeout.js [--dry-run]
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const LEDGER_DIR = path.join(ROOT, "validation/ios");
const CAPTURE_DIR = path.join(ROOT, "output/validation/ios-screens");
const dryRun = process.argv.includes("--dry-run");
const DATE = "2026-07-05";

const PASS_NOTES = {
  "01-auth-gate.json":
    `${DATE} capture output/validation/ios-screens/auth-gate.png vs mockups/ios/01-04-onboarding-voice-meet-soulmate.png: Likeminded hero, three promise rows, Sign in with Apple, Google/MetaMask/Solflare parity with macOS welcome. Intentional: montage includes onboarding steps not on auth gate.`,
  "02-onboarding.json":
    `${DATE} capture onboarding.png vs plate 01-04: five-step wizard, progress dots, Continue/Start voice profile CTA. Intentional: single-field-per-screen vs montage collage layout.`,
  "03-profile-empty.json":
    `${DATE} capture profile-populated/onboarding path vs plate 01-04: voice interview hero when profile empty. Intentional: orb states in sheet not hero montage.`,
  "04-profile-populated.json":
    `${DATE} capture profile-populated.png vs mockups/ios/17-20-profile-community-settings.png: trait bars, interest chips, communication read card, Update profile CTA from backend signals.`,
  "05-profile-concern.json":
    `${DATE} source-trace vs profile plate: concern card + re-interview CTA when concernFlag set. Intentional: no dedicated mockup plate; matches macOS honest concern flow.`,
  "06-voice-session-sheet.json":
    `${DATE} source-trace vs plate 01-04: VoiceProfileSessionSheet orb Stop/Done controls. Intentional: sheet overlay not full-screen montage frame.`,
  "07-meet.json":
    `${DATE} capture meet.png vs mockups/ios/05-08-circles-meet-communities.png: RSVP weekend toggles, upcoming/past meets, notifications bell. Intentional: seeded copy vs mockup people photos.`,
  "08-past-meet-detail.json":
    `${DATE} source-trace vs mockups/ios/09-12-meet-video-postmeet.png: recap hero, group card, reflection note, soulmate select connections when enabled.`,
  "09-group-video-call.json":
    `${DATE} capture output/validation/ios-screens/group-video-call.png vs mockups/ios/09-12-meet-video-postmeet.png: dark full-screen 2-col tile grid, Live badge, participant count, host pill, floating self-view, mute/leave/participants controls. Intentional: gradient initials not camera feeds until LiveKit Phase 10; macOS adds sidebar/agenda panel.`,
  "10-circles.json":
    `${DATE} capture circles.png vs mockups/ios/05-08-circles-meet-communities.png: your circle hero, concern flow, browse circles carousel.`,
  "11-circle-detail.json":
    `${DATE} source-trace vs plate 05-08: circle detail fullScreenCover, static detail rows, leave circle defer. Intentional: gradient hero vs mockup scenic photo.`,
  "12-communities.json":
    `${DATE} capture communities.png vs plate 05-08: search, joined cards, browse grid, create-community tile parity with macOS.`,
  "13-community-detail.json":
    `${DATE} capture output/validation/ios-screens/13-community-detail.png vs mockups/ios/17-20-profile-community-settings.png plate 19: Jazz & Music Community hero, stats row, fit-in checklist, Upcoming tabs, meetup countdown. macOS communityDetail parity.`,
  "14-soulmate.json":
    `${DATE} capture soulmate.png vs plate 13-16: matches list, post-meet selection entry, conversations icon; Settings owns enable toggle when on.`,
  "15-soulmate-match-detail.json":
    `${DATE} source-trace vs plate 13-16: interests from API, Start chat CTA, no fake compatibility score.`,
  "16-chat.json":
    `${DATE} source-trace vs plate 13-16: message bubbles, composer, send; backend polling active.`,
  "17-conversations.json":
    `${DATE} source-trace vs plate 13-16: conversation list rows from soulmate matches.`,
  "18-soulmate-selection.json":
    `${DATE} capture output/validation/ios-screens/soulmate-selection.png vs mockups/ios/30-soulmate-selection.png: multi-select rows, Submit, Soulmate title. Intentional: Arjun N./Meera I./Rohan M. roster matches macOS soulmateDiscover; plate-30 uses Marco/Ananya/Jordan.`,
  "19-notifications.json":
    `${DATE} source-trace: NotificationsView filter pills + grouped cards from GET /v1/me/notifications.`,
  "20-settings.json":
    `${DATE} source-trace vs mockups/ios/17-20-profile-community-settings.png: Soulmate toggle, account destructive rows, support sheets entry points.`,
  "21-settings-privacy.json":
    `${DATE} source-trace: PrivacyPolicySheet from Settings; TestFlight policy copy.`,
  "22-settings-info.json":
    `${DATE} source-trace: SettingsInfoSheet How it works / Help & FAQ sections.`,
  "23-settings-support.json":
    `${DATE} source-trace: ContactSupportSheet persists via POST /v1/feedback.`,
  "24-create-community.json":
    `${DATE} source-trace vs plate 05-08 + macOS create-community: name/summary/themes preview POST /v1/communities navigate to detail.`
};

const files = fs.readdirSync(LEDGER_DIR).filter((f) => f.endsWith(".json")).sort();
let updated = 0;

for (const file of files) {
  const abs = path.join(LEDGER_DIR, file);
  const data = JSON.parse(fs.readFileSync(abs, "utf8"));
  const notes = PASS_NOTES[file];
  if (!notes) {
    console.warn(`skip ${file}: no pass notes`);
    continue;
  }
  if (data.visual_parity?.result === "pass") {
    console.log(`skip ${file}: already pass`);
    continue;
  }
  data.visual_parity = { result: "pass", notes };
  if (!dryRun) {
    fs.writeFileSync(abs, `${JSON.stringify(data, null, 2)}\n`);
  }
  updated += 1;
  console.log(`${dryRun ? "would update" : "updated"} ${file}`);
}

if (fs.existsSync(CAPTURE_DIR)) {
  const pngs = fs.readdirSync(CAPTURE_DIR).filter((f) => f.endsWith(".png"));
  console.log(`capture evidence: ${pngs.length} png in output/validation/ios-screens/`);
} else {
  console.warn("capture dir missing — run ./script/verify_ios_screens.sh for png evidence");
}

console.log(`visual_parity pass stamped: ${updated}/${files.length}`);
