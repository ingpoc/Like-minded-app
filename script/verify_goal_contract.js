#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function commandSet(goal) {
  return new Set(goal.deterministic_graders.map((grader) => grader.command));
}

function assertGoalShape(file, goal) {
  assert.equal(goal.schema_version, 1, `${file}: schema_version must be 1`);
  assert.ok(goal.goal || goal.purpose, `${file}: goal or purpose is required`);
  assert.equal(goal.ultimate_goal_source, "GOAL.md", `${file}: ultimate goal must point to GOAL.md`);
  assert.equal(goal.progress_source, "PROGRESS.md", `${file}: progress source must point to PROGRESS.md`);

  const commands = commandSet(goal);
  for (const command of [
    "npm run check",
    "npm run smoke:mvp",
    "npm run verify:release-config",
    "npm run verify:goal",
    "workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs lint",
    "npm run verify:simulator-local"
  ]) {
    assert.ok(commands.has(command), `${file}: missing grader command ${command}`);
  }

  for (const grader of goal.deterministic_graders) {
    assert.equal(grader.cost, "zero_token", `${file}: ${grader.name} must be zero_token`);
    assert.ok(grader.proves, `${file}: ${grader.name} must state what it proves`);
  }

  assert.equal(goal.simulator_validation?.preferred_agent?.name, "validation-release", `${file}: simulator preferred agent must be validation-release`);
  assert.equal(goal.simulator_validation?.preferred_agent?.model, "gpt-5.4-mini", `${file}: validation-release must be pinned to gpt-5.4-mini`);
  assert.equal(goal.simulator_validation?.preferred_agent?.effort, "medium", `${file}: validation-release effort must be medium`);

  const validationAgent = goal.subagents?.allowed?.find((agent) => agent.name === "validation-release");
  assert.ok(validationAgent, `${file}: validation-release subagent policy is required`);
  assert.equal(validationAgent.model, "gpt-5.4-mini", `${file}: validation-release model must be gpt-5.4-mini`);
  assert.equal(validationAgent.effort, "medium", `${file}: validation-release effort must be medium`);
  assert.ok(validationAgent.cannot_do.some((item) => item.includes("weaken assertions")), `${file}: validation-release must be forbidden from weakening assertions`);

  const totalWeight = goal.rubric.criteria.reduce((sum, criterion) => sum + criterion.weight, 0);
  assert.ok(Math.abs(totalWeight - 1) < 0.0001, `${file}: rubric weights must sum to 1`);
  assert.ok(goal.rubric.min_score >= 0.7, `${file}: rubric minimum score must be at least 0.7`);
  assert.equal(goal.completion_commit?.required, true, `${file}: completion_commit.required must be true`);
  assert.ok(goal.completion_commit?.must_include?.includes("goal.json"), `${file}: completion commit must include goal.json`);
  assert.ok(
    goal.completion_commit?.when?.includes("before marking the session goal complete"),
    `${file}: completion commit timing must be before marking the goal complete`
  );
  assert.ok(
    goal.done_criteria.some((criterion) => criterion.includes("committed") && criterion.includes("goal.json")),
    `${file}: done criteria must require committing goal.json`
  );
  assert.ok(
    goal.done_criteria.some((criterion) => criterion.includes("npm run verify:external-preflight")),
    `${file}: done criteria must require external preflight verification`
  );
  assert.ok(goal.max_iterations > 0, `${file}: max_iterations must be positive`);
}

const template = readJson("goal.template.json");
const current = readJson("goal.json");

assertGoalShape("goal.template.json", template);
assertGoalShape("goal.json", current);

assert.deepEqual(
  [...commandSet(current)].sort(),
  [...commandSet(template)].sort(),
  "goal.json and goal.template.json must list the same deterministic grader commands"
);

console.log("Goal contract verified");
