#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const phase = process.argv.find((arg) => /^\d+$/.test(arg));

if (!phase) {
  console.error("Usage: npm run phase:preflight -- <phase-number>");
  process.exit(1);
}

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function git(args) {
  return execFileSync("git", args, { cwd: root, encoding: "utf8" }).trim();
}

function shellRg(pattern, files) {
  try {
    return execFileSync("rg", ["-n", pattern, ...files], { cwd: root, encoding: "utf8" }).trim();
  } catch (error) {
    if (error.status === 1) return "";
    throw error;
  }
}

function phaseSection(markdown, phaseNumber) {
  const lines = markdown.split("\n");
  const start = lines.findIndex((line) => line.startsWith(`## Phase ${phaseNumber} `));
  if (start === -1) return null;
  let end = lines.length;
  for (let index = start + 1; index < lines.length; index += 1) {
    if (/^## Phase \d+ /.test(lines[index])) {
      end = index;
      break;
    }
  }
  return lines.slice(start, end);
}

function uncheckedItems(lines) {
  return lines
    .map((line, index) => ({ line, number: index + 1 }))
    .filter((entry) => entry.line.includes("- [ ]"));
}

function docLintRisks() {
  const output = git(["ls-files", "--others", "--exclude-standard", "docs"]);
  return output
    .split("\n")
    .filter((file) => file.endsWith(".md"))
    .filter(Boolean)
    .map((file) => {
      const text = read(file);
      return {
        file,
        missingControlOwner: !text.includes("## Control Owner")
      };
    })
    .filter((risk) => risk.missingControlOwner);
}

const staleGates = {
  "3": {
    label: "Phase 3 profile/onboarding cleanup",
    pattern: "ReflectionPrototypeView|Talk first|Start in Talk|SegmentedSignalRow|SignalSummaryRow|PrivacyStrip|VoiceStatusPill|VoiceSignalRow|EmptyVoiceSignalRow|BigFiveGauge|selectedSignal",
    files: ["apps/ios-macos/Sources/LikemindedApp", "services/api/src"]
  }
};

const section = phaseSection(read("PROGRESS.md"), phase);
if (!section) {
  console.error(`Phase ${phase} not found in PROGRESS.md`);
  process.exit(1);
}

const unchecked = uncheckedItems(section);
const gate = staleGates[phase];
const staleMatches = gate ? shellRg(gate.pattern, gate.files) : "";
const docsRisk = docLintRisks();

console.log(`# Phase ${phase} Preflight`);
console.log("");
console.log("## Acceptance Items");
if (unchecked.length === 0) {
  console.log("- No unchecked items in the scoped PROGRESS.md phase section.");
} else {
  for (const item of unchecked) {
    console.log(`- ${item.line.trim().replace(/^- \[ \]\s*/, "")}`);
  }
}

console.log("");
console.log("## Stale-Name Gate");
if (gate) {
  console.log(`- ${gate.label}`);
  console.log(`- Command: rg -n "${gate.pattern}" ${gate.files.join(" ")}`);
  console.log(staleMatches ? staleMatches : "- No current matches.");
} else {
  console.log("- No phase-specific stale-name gate is registered yet.");
}

console.log("");
console.log("## Validation Order");
console.log("- npm run check");
console.log("- npm run verify:goal");
console.log("- xcodebuild -project apps/ios-macos/Likeminded.xcodeproj -scheme Likeminded -destination 'generic/platform=iOS Simulator' build");
console.log("- npm run smoke:mvp");
console.log("- npm run verify:release-config");
if (phase === "8") {
  console.log("- npm run testing:ledger-batch-plan -- --platform macos --limit 10; prove sequentially with bundled @Computer");
}
console.log("- workflow --docs-dir /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/docs lint");
if (phase === "8") {
  console.log("- npm run remove:validation-data (after seeded validation evidence is captured)");
}
console.log("- npm run verify:simulator-local (last, only after native UI/project inputs change)");

console.log("");
console.log("## XcodeGen");
console.log("- Canonical command: (cd apps/ios-macos && xcodegen generate)");

console.log("");
console.log("## Doc Lint Risks");
if (docsRisk.length === 0) {
  console.log("- No untracked Markdown docs missing ## Control Owner.");
} else {
  for (const risk of docsRisk) {
    console.log(`- ${risk.file}: missing ## Control Owner`);
  }
}
