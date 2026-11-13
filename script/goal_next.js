#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");

const MACOS_TRACK_RE =
  /LikemindedMac|DoodleArt|doodle-art|validation\/macos|testing_ledger|install_doodle|mockups\/macos|run_macos_manual/;

function readJson(file) {
  return JSON.parse(fs.readFileSync(path.join(root, file), "utf8"));
}

function read(file) {
  return fs.readFileSync(path.join(root, file), "utf8");
}

function gitStatus() {
  try {
    return execFileSync("git", ["status", "--short"], { cwd: root, encoding: "utf8" }).trim();
  } catch {
    return "";
  }
}

function phaseSections(markdown) {
  const lines = markdown.split("\n");
  const phases = [];
  for (let index = 0; index < lines.length; index += 1) {
    const match = lines[index].match(/^## Phase (\d+) [—-]/);
    if (!match) continue;
    const start = index;
    let end = lines.length;
    for (let next = index + 1; next < lines.length; next += 1) {
      if (/^## Phase \d+ [—-]/.test(lines[next])) {
        end = next;
        break;
      }
    }
    phases.push({
      number: Number(match[1]),
      title: lines[index].replace(/^## /, ""),
      unchecked: lines.slice(start, end).filter((line) => line.includes("- [ ]")).length
    });
  }
  return phases;
}

function activeFirstCommand(markdown) {
  const match = markdown.match(/active local route\. First command: `([^`]+)`/);
  return match ? match[1] : null;
}

function isMacosTrackDirty(dirty) {
  return MACOS_TRACK_RE.test(dirty);
}

function resolveMacosRoute(ledger) {
  const mac = ledger.platforms.find((p) => p.platform === "macos");
  if (!mac) return "npm run ledger:open";
  if (mac.stale_pass > 0) return reproofCommand("macos") || "npm run ledger:open";
  if (mac.fail > 0 || mac.pending > 0) return "npm run ledger:open";
  return "npm run ledger:open";
}

function resolveIosRoute(ledger) {
  const ios = ledger.platforms.find((p) => p.platform === "ios");
  if (!ios) return "npm run ledger:open";
  if (ios.stale_pass > 0) return reproofCommand("ios") || "npm run ledger:open";
  if (ios.fail > 0 || ios.pending > 0) return "npm run ledger:open";
  return "npm run ledger:open";
}


function pickActiveTrack(ledger, dirty) {
  const open = ledger.open_tracks || [];
  if (isMacosTrackDirty(dirty) && open.includes("macos-visual-parity")) {
    return "macos-visual-parity";
  }
  if (open.includes("ios-ledger-honesty")) return "ios-ledger-honesty";
  if (open.includes("macos-visual-parity")) return "macos-visual-parity";
  return "phase";
}

function routeCommandForTrack(track, ledger) {
  const wave2 = wave2ReproofCommand();
  if (wave2 && wave2 !== "npm run ledger:stale") {
    const ios = ledger.platforms.find((p) => p.platform === "ios");
    const mac = ledger.platforms.find((p) => p.platform === "macos");
    const iosStale = (ios?.stale_pass || 0) > 0;
    const macStale = (mac?.stale_pass || 0) > 0;
    if (iosStale && macStale) return wave2;
  }
  if (track === "macos-visual-parity") return resolveMacosRoute(ledger);
  if (track === "ios-ledger-honesty") return resolveIosRoute(ledger);
  return null;
}

const { ownershipReport, formatGoalNextLines } = require("./ledger_progress");
const { reproofCommand, wave2ReproofCommand } = require("./ledger_stale_screens");
const {
  resolveBucket,
  formatLines: formatWorkBucketLines,
  shouldPreferContinue
} = require("./session_work_bucket");

const goal = readJson("goal.json");
const dirty = gitStatus();
const dirtyPathCount = dirty ? dirty.split("\n").length : 0;
const dirtyFirst = dirty.length > 0;
const compact = process.argv.includes("--compact");
const progress = read("PROGRESS.md");
const ledger = ownershipReport(progress);
const workBucket = resolveBucket();
const workBucketLines = formatWorkBucketLines(workBucket, { compact, ledger });
const nextPhase = phaseSections(progress).find((phase) => phase.unchecked > 0);
const activeCommand = activeFirstCommand(progress);
const activeTrack = pickActiveTrack(ledger, dirty);
const trackRoute = routeCommandForTrack(activeTrack, ledger);
const continueCommand = workBucket?.continue_command || trackRoute;

const routeCommand =
  trackRoute ||
  (goal.status !== "completed" && activeCommand
    ? activeCommand
    : nextPhase
      ? `npm run phase:preflight -- ${nextPhase.number}`
      : "npm run verify:goal");

const contract = goal.route_contract;
const useContract =
  !dirtyFirst && goal.status !== "completed" && contract?.first_command;

const preferContinue =
  shouldPreferContinue(workBucket, dirtyPathCount) && Boolean(workBucket?.continue_command);

const firstCommand = preferContinue
  ? workBucket.continue_command
  : dirtyFirst
    ? "git status --short"
    : useContract
      ? contract.first_command
      : goal.status !== "completed" && !trackRoute && !activeCommand
        ? `./script/project_context.sh query --task ${JSON.stringify(goal.goal)}`
        : continueCommand || routeCommand;

const FORBIDDEN_UNTIL_CONTINUE =
  "GOAL.md, PROGRESS.md, ledger:open, Phase 9, mockup directory walks";

if (compact) {
  for (const line of workBucketLines) {
    console.log(line);
  }
  console.log(`forbidden_until_continue: ${FORBIDDEN_UNTIL_CONTINUE}`);
  console.log(`first_command: ${firstCommand}`);
  if (useContract && contract.lane) console.log(`session_lane: ${contract.lane}`);
  console.log(`dirty_work_required: ${dirtyFirst ? "yes" : "no"}`);
  if (dirtyFirst && !preferContinue) console.log(`after_dirty_resolved: ${continueCommand || routeCommand}`);
  if (workBucket?.proof_command) console.log(`proof_before_pass: ${workBucket.proof_command}`);
  for (const line of formatGoalNextLines(ledger)) {
    console.log(line);
  }
  const actionable = ledger.platforms.reduce((n, p) => n + (p.actionable || 0), 0);
  if (actionable > 0) console.log("validation_brief: npm run ledger:brief");
  process.exit(0);
}

for (const line of workBucketLines) {
  console.log(line);
}

console.log(`# Goal Next
active_work_goal: ${workBucket?.summary || "none"}
current_status: ${goal.status}
phase_goal_when_tracks_clean: ${goal.goal}
dirty_work_required: ${dirtyFirst ? "yes" : "no"}
dirty_path_count: ${dirtyPathCount}
next_phase: ${nextPhase ? nextPhase.title : "none"}
next_phase_unchecked: ${nextPhase ? nextPhase.unchecked : 0}
active_track: ${activeTrack}
ledger_progress_ok: ${ledger.ok ? "yes" : "no"}
first_command: ${firstCommand}`);

console.log(`forbidden_until_continue: ${FORBIDDEN_UNTIL_CONTINUE}`);

if (useContract && contract.lane) {
  console.log(`session_lane: ${contract.lane}`);
}

for (const line of formatGoalNextLines(ledger)) {
  console.log(line);
}

if (dirtyFirst && !preferContinue) {
  console.log(`after_dirty_resolved: ${continueCommand || routeCommand}`);
}
if (workBucket?.proof_command) {
  console.log(`proof_before_pass: ${workBucket.proof_command}`);
}

if (!ledger.ok) {
  console.log("ledger_progress_fix: npm run verify:ledger-progress");
  for (const error of ledger.errors) {
    console.log(`ledger_error: ${error}`);
  }
}
