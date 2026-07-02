#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");

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
    const match = lines[index].match(/^## Phase (\d+) .*/);
    if (!match) continue;
    const start = index;
    let end = lines.length;
    for (let next = index + 1; next < lines.length; next += 1) {
      if (/^## Phase \d+ /.test(lines[next])) {
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

const goal = readJson("goal.json");
const dirty = gitStatus();
const nextPhase = phaseSections(read("PROGRESS.md")).find((phase) => phase.unchecked > 0);
const dirtyFirst = dirty.length > 0;
const firstCommand = dirtyFirst
  ? "git status --short"
  : goal.status !== "completed"
    ? `./script/project_context.sh query --task ${JSON.stringify(goal.goal)}`
    : nextPhase
      ? `npm run phase:preflight -- ${nextPhase.number}`
      : "npm run verify:goal";

console.log(`# Goal Next
current_status: ${goal.status}
current_goal: ${goal.goal}
dirty_work_required: ${dirtyFirst ? "yes" : "no"}
dirty_path_count: ${dirty ? dirty.split("\n").length : 0}
next_phase: ${nextPhase ? nextPhase.title : "none"}
next_phase_unchecked: ${nextPhase ? nextPhase.unchecked : 0}
first_command: ${firstCommand}`);

if (dirtyFirst && nextPhase) {
  console.log(`after_dirty_resolved: npm run phase:preflight -- ${nextPhase.number}`);
}
