#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");

const MACOS_TRACK_RE =
  /LikemindedMac|DoodleArt|doodle-art|validation\/macos|macos-screen-audit|macos_cua|macos_audit|install_doodle|mockups\/macos|verify:macos-screens|run_macos_manual/;

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

function macosTrackFirstCommand(markdown) {
  const match = markdown.match(
    /Track — macOS Visual Parity[\s\S]*?First command when focusing this track: `([^`]+)`/
  );
  return match ? match[1] : "./script/macos_audit_prepare.sh";
}

function isMacosTrackGoal(goalText) {
  return /macOS Visual Parity|macos ledger|validation\/macos/i.test(goalText || "");
}

function isMacosTrackDirty(dirty) {
  return MACOS_TRACK_RE.test(dirty);
}

const { ownershipReport, formatGoalNextLines } = require("./ledger_progress");

const goal = readJson("goal.json");
const dirty = gitStatus();
const progress = read("PROGRESS.md");
const nextPhase = phaseSections(progress).find((phase) => phase.unchecked > 0);
const activeCommand = activeFirstCommand(progress);
const macosCommand = macosTrackFirstCommand(progress);
const dirtyFirst = dirty.length > 0;
const macosActive = isMacosTrackGoal(goal.goal) || isMacosTrackDirty(dirty);
const ledger = ownershipReport(progress);

const routeCommand = macosActive
  ? macosCommand
  : goal.status !== "completed" && activeCommand
    ? activeCommand
    : nextPhase
      ? `npm run phase:preflight -- ${nextPhase.number}`
      : "npm run verify:goal";

const firstCommand = dirtyFirst
  ? "git status --short"
  : goal.status !== "completed" && !activeCommand && !macosActive
    ? `./script/project_context.sh query --task ${JSON.stringify(goal.goal)}`
    : routeCommand;

console.log(`# Goal Next
current_status: ${goal.status}
current_goal: ${goal.goal}
dirty_work_required: ${dirtyFirst ? "yes" : "no"}
dirty_path_count: ${dirty ? dirty.split("\n").length : 0}
next_phase: ${nextPhase ? nextPhase.title : "none"}
next_phase_unchecked: ${nextPhase ? nextPhase.unchecked : 0}
active_track: ${macosActive ? "macos-visual-parity" : "phase"}
ledger_progress_ok: ${ledger.ok ? "yes" : "no"}
first_command: ${firstCommand}`);

for (const line of formatGoalNextLines(ledger)) {
  console.log(line);
}

if (dirtyFirst) {
  console.log(`after_dirty_resolved: ${routeCommand}`);
}

if (!ledger.ok) {
  console.log("ledger_progress_fix: npm run verify:ledger-progress");
  for (const error of ledger.errors) {
    console.log(`ledger_error: ${error}`);
  }
}
