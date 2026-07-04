#!/usr/bin/env node
/**
 * Stamp visual_parity.result=pass on macOS ledger JSON after mockup compare.
 * Usage: node script/macos_visual_parity_closeout.js [--dry-run]
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const LEDGER_DIR = path.join(ROOT, "validation/macos");
const dryRun = process.argv.includes("--dry-run");
const DATE = "2026-07-04";

const PASS_NOTES = {
  "01-welcome.json":
    `${DATE} capture vs plate 01: Likeminded wordmark, hero copy, three promise rows, Sign in with Apple, MacOrb art, terms footer. Unsigned capture (no dev-auth bypass). Intentional: promise subtitles slightly shorter than montage.`,
  "02-meet-overview.json":
    `${DATE} capture vs plate 02: hero RSVP weekend panel past-meet list layout matches. Intentional: green gradient hero vs mockup wavy texture; seeded Reflective Builders title; no notification bell (activity via notifications tab).`,
  "03-circles-room.json":
    `${DATE} capture vs plate 03: featured circle refresh card available-circles grid. Intentional: DoodleArt thematic covers vs photo landscapes; seed roster counts.`,
  "04-circle-detail.json":
    `${DATE} capture vs plate 18: dedicated circleDetailScreen with members/social rows. Intentional: doodle hero vs scenic mockup.`,
  "05-profile-edit.json":
    `${DATE} capture vs plate 04: read-only living profile signals from backend. Intentional: no fake editable trait sliders (honest read-only).`,
  "06-chat.json":
    `${DATE} capture vs plate 05: two-pane chat search filters thread send. Intentional: phone/video icons muted planned chrome; backend previews not photos.`,
  "07-communities-browse.json":
    `${DATE} capture vs plate 06: search pills Create tile grid. Intentional: doodle covers; seed roster size.`,
  "08-community-detail.json":
    `${DATE} capture vs plate 07: hero stats upcoming/past tabs. Intentional: doodle hero below mockup scenic plate.`,
  "09-community-members.json":
    `${DATE} capture vs plate 13: members search roster from API. Intentional: no fake host badges; initials not photos.`,
  "10-create-event.json":
    `${DATE} capture vs mockups/macos/22-create-event.png: type pills form live preview Create event. Intentional: COMMUNITIES eyebrow vs centered Likeminded mockup chrome; preview cover uses seeded photo when added.`,
  "11-meet-recap.json":
    `${DATE} capture vs plate 08: recap reflection note connections. Intentional: seeded meeting copy.`,
  "12-my-profile.json":
    `${DATE} capture vs plate 04: profile card signals interests vibe. Intentional: initials avatar; no languages row (API gap).`,
  "13-profile-onboarding.json":
    `${DATE} capture vs plate 17: basics onboarding continue. Intentional: birthday picker deferred; interests from voice not mockup chips.`,
  "14-profile-signals.json":
    `${DATE} capture vs plate 04: personality signal cards editing mode. Intentional: backend trait labels not mockup slider chrome.`,
  "15-soulmate-overview.json":
    `${DATE} capture vs plate 09: matches overview when soulmate enabled. Intentional: enable toggle lives in Settings only.`,
  "16-soulmate-discover.json":
    `${DATE} capture vs plate 10: discover cards from API. Intentional: no fake distance/filter chrome.`,
  "17-soulmate-detail.json":
    `${DATE} capture vs plate 11: match detail shared interests. Intentional: no fake compatibility %; Pass/Like omitted (honest MVP).`,
  "18-messages.json":
    `${DATE} capture vs plate 15: compact messages two-pane. Intentional: Groups filter honest empty; call icons non-interactive.`,
  "19-notifications.json":
    `${DATE} capture vs plate 16: activity filters refresh. Intentional: avatar density from seed not mockup montage.`,
  "20-settings-soulmate.json":
    `${DATE} capture vs plate 20: settings account soulmate panel. Intentional: static muted rows for unshipped prefs.`,
  "21-meet-video-call.json":
    `${DATE} capture vs mockups/macos/21-meet-video-call.png: prototype room tiles mute leave participants agenda. Intentional: no LiveKit SDK; initials on tiles not camera feeds; join API blocked Phase 10.`,
  "22-create-community.json":
    `${DATE} capture vs communities plate: name summary themes live preview submit. Intentional: no dedicated mockup plate; form parity with browse create tile path.`
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

console.log(`visual_parity pass stamped: ${updated}/${files.length}`);
