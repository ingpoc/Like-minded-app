"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");

test("route section is compact and contains only actionable screen context", () => {
  const result = spawnSync(
    process.execPath,
    ["script/ledger_screen_entry.js", "--platform", "ios", "--screen", "app-shell", "--section", "route"],
    { cwd: root, encoding: "utf8" }
  );

  assert.equal(result.status, 0, result.stderr);
  assert.ok(Buffer.byteLength(result.stdout) < 5000, "route output should remain below 5 KB");

  const payload = JSON.parse(result.stdout);
  assert.equal(payload.logical_screen_id, "app-shell");
  assert.ok(payload.source_files.includes("apps/ios-macos/Sources/LikemindedApp/Views/RootView.swift"));
  assert.ok(payload.flows.some((flow) => flow.id === "global-back"));
  assert.ok(payload.flows.every((flow) => Object.hasOwn(flow, "result")));
  assert.equal(Object.hasOwn(payload, "controls"), false);
  assert.equal(Object.hasOwn(payload, "platform_slice"), false);
});

test("session work-bucket routing defaults to the compact screen section", () => {
  const source = fs.readFileSync(path.join(root, "script/session_work_bucket.js"), "utf8");
  assert.match(source, /--section route/);
  assert.doesNotMatch(source, /--section all/);
  assert.doesNotMatch(
    source,
    /project_context\.sh/,
    "goal:next must not preload the optional decision graph"
  );
});

test("session stop condition only blocks Phase 9 when stale passes exist", () => {
  const { formatLines, stopConditionForLedger } = require("./session_work_bucket");
  const clean = stopConditionForLedger({
    platforms: [
      { platform: "ios", stale_pass: 0 },
      { platform: "macos", stale_pass: 0 }
    ]
  });
  const stale = stopConditionForLedger({
    platforms: [
      { platform: "ios", stale_pass: 1 },
      { platform: "macos", stale_pass: 0 }
    ]
  });

  assert.doesNotMatch(clean, /stale_pass tracks are open/);
  assert.match(stale, /stale_pass tracks are open/);

  const rendered = formatLines({ stop_condition: stale }, { ledger: { platforms: [] } }).join("\n");
  assert.doesNotMatch(rendered, /stale_pass tracks are open/);
});

test("session stamp honors an explicit platform instead of inferring from unrelated dirty paths", () => {
  const { inferBucket } = require("./session_work_bucket");
  const bucket = inferBucket(
    [
      "apps/ios-macos/Sources/LikemindedMac/ProfileScreen.swift",
      "apps/ios-macos/Sources/LikemindedApp/Views/ProfilePrototypeView.swift"
    ],
    "Continue the iOS living-profile review",
    "profile-edit",
    "ios"
  );

  assert.equal(bucket.work_platform, "ios");
  assert.match(bucket.continue_command, /--platform ios --screen profile-edit --section route/);
});

test("concept lookup never assigns a circle-placement plate to an unrelated screen", () => {
  const { findConceptMockup } = require("./session_work_bucket");
  const result = findConceptMockup("profile-edit", "macos");
  assert.ok(!result || !result.includes("circles-placement"));
});

test("type-hinted source hashes bind the declaration instead of an earlier call site", () => {
  const { hashScreenSources } = require("./ledger_hash");
  const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "likeminded-ledger-hash-"));
  const sourceDir = path.join(repoRoot, "Sources");
  const sourcePath = path.join(sourceDir, "Profile.swift");
  fs.mkdirSync(sourceDir, { recursive: true });
  fs.writeFileSync(
    sourcePath,
    [
      "func route() {",
      "  _ = ProfileEditView()",
      "}",
      "",
      "struct ProfileEditView {",
      '  let title = "Living profile"',
      "}",
      "",
      "struct NextView {}",
      ""
    ].join("\n")
  );
  const sourceFiles = ["Sources/Profile.swift (ProfileEditView)"];
  const before = hashScreenSources({ source_files: sourceFiles }, repoRoot);
  fs.writeFileSync(
    sourcePath,
    fs
      .readFileSync(sourcePath, "utf8")
      .replace('let title = "Living profile"', 'let title = "Private living profile"')
  );
  const after = hashScreenSources({ source_files: sourceFiles }, repoRoot);
  fs.rmSync(repoRoot, { recursive: true, force: true });
  assert.notEqual(after, before);
});

test("type-hinted source hashes include attributed final classes", () => {
  const { hashScreenSources } = require("./ledger_hash");
  const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "likeminded-ledger-class-hash-"));
  const sourceDir = path.join(repoRoot, "Sources");
  const sourcePath = path.join(sourceDir, "State.swift");
  fs.mkdirSync(sourceDir, { recursive: true });
  fs.writeFileSync(
    sourcePath,
    [
      "@MainActor",
      "final class PrototypeAppState {",
      '  func save() { print("before") }',
      "}",
      "",
      "struct NextView {}",
      ""
    ].join("\n")
  );
  const sourceFiles = ["Sources/State.swift (PrototypeAppState)"];
  const before = hashScreenSources({ source_files: sourceFiles }, repoRoot);
  fs.writeFileSync(
    sourcePath,
    fs.readFileSync(sourcePath, "utf8").replace('print("before")', 'print("after")')
  );
  const after = hashScreenSources({ source_files: sourceFiles }, repoRoot);
  fs.rmSync(repoRoot, { recursive: true, force: true });
  assert.notEqual(after, before);
});
