"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync, spawnSync } = require("node:child_process");
const {
  matchingRetestIssues,
  resolveFixOwner,
  resolveMatchingRetestIssues,
  selectOpenFixIssue
} = require("./testing_ledger_issue_queue");

function issue(id, overrides = {}) {
  return {
    id,
    platform: "ios",
    screen: "chat",
    flow_id: "chat-call-headers",
    retest_ready: true,
    status: "retest_ready",
    ...overrides
  };
}

test("operator-requested reprove requires an exact target", () => {
  const result = spawnSync(
    process.execPath,
    [path.join(__dirname, "testing_ledger_run.js"), "--platform", "ios", "--reprove", "--card-only", "--json"],
    { encoding: "utf8" }
  );
  assert.equal(result.status, 2);
  const payload = JSON.parse(result.stdout);
  assert.equal(payload.status, "invalid-usage");
  assert.match(payload.hint, /--screen <screen> --flow <flow> --reprove/);
});

test("operator-requested reprove selects one exact clean target", () => {
  const result = spawnSync(
    process.execPath,
    [
      path.join(__dirname, "testing_ledger_run.js"),
      "--platform",
      "ios",
      "--screen",
      "circle-detail",
      "--flow",
      "secondary-circle-selection",
      "--reprove",
      "--card-only",
      "--json"
    ],
    { encoding: "utf8" }
  );
  assert.equal(result.status, 0, result.stderr || result.stdout);
  const payload = JSON.parse(result.stdout);
  assert.equal(payload.screen, "circle-detail");
  assert.equal(payload.flow_id, "secondary-circle-selection");
  assert.equal(payload.selection_mode, "operator-requested-reprove");
});

test("successful selected-flow retest resolves every matching packet only", () => {
  const queue = {
    issues: [
      issue("matching-1"),
      issue("matching-2"),
      issue("other-flow", { flow_id: "chat-send-message" }),
      issue("other-platform", { platform: "macos" }),
      issue("already-resolved", { status: "resolved" }),
      issue("not-ready", { retest_ready: false, status: "fixing" })
    ]
  };
  const target = { platform: "ios", screen: "chat", flowId: "chat-call-headers" };

  assert.deepEqual(
    matchingRetestIssues(queue, target).map((item) => item.id),
    ["matching-1", "matching-2"]
  );

  const resolved = resolveMatchingRetestIssues(queue, target, {
    resolvedAt: "2026-07-14T02:00:00.000Z",
    resolution: "Successful fixture retest"
  });
  assert.deepEqual(resolved, ["matching-1", "matching-2"]);

  for (const id of resolved) {
    const item = queue.issues.find((candidate) => candidate.id === id);
    assert.equal(item.status, "resolved");
    assert.equal(item.retest_ready, false);
    assert.equal(item.resolved_at, "2026-07-14T02:00:00.000Z");
    assert.equal(item.resolution, "Successful fixture retest");
  }
  assert.equal(queue.issues.find((item) => item.id === "other-flow").status, "retest_ready");
  assert.equal(queue.issues.find((item) => item.id === "other-platform").status, "retest_ready");
  assert.equal(queue.issues.find((item) => item.id === "already-resolved").status, "resolved");
  assert.equal(queue.issues.find((item) => item.id === "not-ready").status, "fixing");
});

test("targeted fixer selection returns only the requested open issue", () => {
  const queue = {
    issues: [
      issue("older-fixing", { status: "fixing", retest_ready: false }),
      issue("requested", { status: "open", retest_ready: false }),
      issue("resolved", { status: "resolved", retest_ready: false })
    ]
  };

  assert.equal(selectOpenFixIssue(queue, { platform: "ios" }).id, "older-fixing");
  assert.equal(
    selectOpenFixIssue(queue, { platform: "ios", issueId: "requested" }).id,
    "requested"
  );
  assert.equal(selectOpenFixIssue(queue, { platform: "macos", issueId: "requested" }), null);
  assert.equal(selectOpenFixIssue(queue, { issueId: "resolved" }), null);
});

test("iOS AX probe recognizes the identifier field emitted by idb", () => {
  const source = fs.readFileSync(path.join(__dirname, "testing_ledger_prove_ios.sh"), "utf8");
  assert.match(
    source,
    /for key in \('AXLabel', 'AXValue', 'AXTitle', 'AXIdentifier', 'AXUniqueId'\):/,
    "idb describe exposes SwiftUI accessibility identifiers as AXUniqueId"
  );
});

test("iOS tap-id recognizes SwiftUI AXUniqueId identifiers", () => {
  const source = fs.readFileSync(path.join(__dirname, "../validation/idb_ctl.sh"), "utf8");
  assert.match(
    source,
    /for key in \('AXIdentifier', 'AXUniqueId'\)/,
    "tap-id must search the same identifier fields as the readiness probe"
  );
  assert.match(source, /anchor="\$\{2:-center\}"/);
  assert.match(source, /tap_y = f\['y'\] \+ min\(f\['height'\] \/ 2, 24\)/);
  assert.doesNotMatch(
    source,
    /idb ui tap --duration/,
    "idb's forced short press misses SwiftUI buttons; use the proven default tap"
  );
});

test("iOS screenshot fallback preserves the explicit simulator identity", () => {
  const source = fs.readFileSync(path.join(__dirname, "../validation/idb_ctl.sh"), "utf8");
  assert.match(source, /xcrun simctl io "\$UDID" screenshot/);
  assert.doesNotMatch(
    source,
    /simctl io booted screenshot/,
    "a fallback must never switch from the selected UDID to an arbitrary booted simulator"
  );
});

test("iOS point-id prefers a visible duplicate and reports viewport bounds", () => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "likeminded-fake-idb-"));
  const fakeIdb = path.join(temp, "idb");
  fs.writeFileSync(
    fakeIdb,
    "#!/usr/bin/env bash\n[[ \"$*\" == \"ui describe-all --json\" ]] && printf '%s' \"$FAKE_IDB_AX\"\n"
  );
  fs.chmodSync(fakeIdb, 0o755);
  const frame = (x, y, width, height) => ({ x, y, width, height });
  const inventory = [
    { type: "Application", frame: frame(0, 0, 402, 874) },
    { type: "Button", AXUniqueId: " target   card ", frame: frame(500, 100, 100, 80) },
    { type: "Button", AXUniqueId: "target card", frame: frame(20, 200, 200, 100) }
  ];
  const output = execFileSync(
    path.join(__dirname, "../validation/idb_ctl.sh"),
    ["point-id", "target card", "top", "viewport"],
    {
      encoding: "utf8",
      env: {
        ...process.env,
        PATH: `${temp}:${process.env.PATH}`,
        IDB_UDID: "fixture",
        FAKE_IDB_AX: JSON.stringify(inventory)
      }
    }
  ).trim();
  assert.equal(output, "120 224 0 0 402 874");
  fs.rmSync(temp, { recursive: true, force: true });
});

test("secondary-circle proof scrolls every same-flow action into a safe tap area", () => {
  const source = fs.readFileSync(path.join(__dirname, "testing_ledger_prove_ios.sh"), "utf8");
  const idbSource = fs.readFileSync(path.join(__dirname, "../validation/idb_ctl.sh"), "utf8");
  assert.match(idbSource, /point-id\)/);
  assert.match(idbSource, /resolve_id_point \"\$identifier\" \"\$anchor\"/);
  assert.match(
    idbSource,
    /swipe-up-short\)\s+[\s\S]{0,120}idb ui swipe --duration 0\.45 --delta 10 390 700 390 500/
  );
  assert.match(source, /ios_scroll_until_tappable\(\)/);
  assert.match(
    source,
    /if \(\( did_scroll \)\); then\s+sleep 1\.2/,
    "a point reached by scrolling must settle before its tap is dispatched"
  );
  const branch = source.slice(
    source.indexOf("circle-detail/secondary-circle-selection)"),
    source.indexOf(";;", source.indexOf("circle-detail/secondary-circle-selection)"))
  );
  const gates = [...branch.matchAll(
    /ios_scroll_until_tappable(?: \\\n\s+| )"([^"]+)" (center|top) (\d+) (\d+)(?: (\d+))?/g
  )].map((match) => match.slice(1));
  assert.deepEqual(gates, [
    ["secondary-circle-card-longform-thinkers", "center", "700", "3", undefined],
    ["make-secondary-circle", "center", "830", "6", "40"],
    ["secondary-circle-card-longform-thinkers", "center", "700", "3", undefined]
  ]);
  assert.equal(
    (branch.match(/present \\\n\s+center/g) || []).length,
    3,
    "all three same-flow actions must use the manually proven center anchor"
  );
  assert.equal(
    (branch.match(/"\$IOS_TAPPABLE_POINT"/g) || []).length,
    3,
    "same-flow actions must reuse the point proven tappable before dispatch"
  );
  assert.match(
    branch,
    /"\$IOS_TAPPABLE_POINT"\s+if \[\[ "\$FLOW_FAIL" -eq 0 \]\]; then\s+sleep 1\.2\s+fi\s+fi\s+if \[\[ "\$FLOW_FAIL" -eq 0 \]\] && ! ios_scroll_until_tappable \\\n\s+"make-secondary-circle"/,
    "the full-screen circle-detail transition must settle before its action is tapped"
  );
});

test("harness issues route to the platform proof owner instead of product source", () => {
  const screen = {
    platforms: {
      ios: { source_files: ["apps/ios-macos/Sources/LikemindedApp/Views/CommunitiesPrototypeView.swift"] },
      macos: { source_files: ["apps/ios-macos/Sources/LikemindedMac/Views/MacCircleDetailView.swift"] }
    }
  };

  assert.equal(
    resolveFixOwner(screen, "ios", "options-report-concern", "harness"),
    "script/testing_ledger_prove_ios.sh"
  );
  assert.equal(
    resolveFixOwner(screen, "macos", "options-report-concern", "harness"),
    ".agents/skills/testing-ledger/SKILL.md + bundled @Computer"
  );
});

test("fix cards keep runtime locks free during source edits", () => {
  const source = fs.readFileSync(path.join(__dirname, "testing_ledger_fix_run.js"), "utf8");
  assert.doesNotMatch(source, /LOCK_ACQUIRE/);
  assert.match(source, /keep the platform lock free during edits/);
});

test("macOS stray guard cannot hold command-substitution pipes open", () => {
  const source = fs.readFileSync(path.join(__dirname, "macos_canonical_app.sh"), "utf8");
  assert.match(
    source,
    /\) <\/dev\/null >\/dev\/null 2>&1 &/,
    "background guards must close inherited stdio so captured native output returns immediately"
  );
});

test("iOS proof API startup returns instead of waiting on its background server", () => {
  const source = fs.readFileSync(path.join(__dirname, "testing_ledger_prove_ios.sh"), "utf8");
  assert.match(source, /exec npm run dev:api:validation/);
  assert.match(source, /\) >>\/tmp\/likeminded-api-ios-prove\.log 2>&1 <\/dev\/null &/);
  assert.doesNotMatch(source, /npm run dev:api:validation[^\n]*&\)/);
});

test("iOS batch reuse fails closed unless source freshness and installed binary identity match", () => {
  const proof = fs.readFileSync(path.join(__dirname, "testing_ledger_prove_ios.sh"), "utf8");
  const build = fs.readFileSync(path.join(__dirname, "build_and_run.sh"), "utf8");
  assert.match(proof, /ios_binary_is_source_fresh \|\| \{/);
  assert.match(proof, /shasum -a 256 "\$built_exec"/);
  assert.match(proof, /shasum -a 256 "\$installed_exec"/);
  assert.match(proof, /"\$built_hash" != "\$installed_hash"/);
  assert.match(proof, /refusing interaction/);
  assert.doesNotMatch(
    proof,
    /requested iOS install reuse failed[^\n]*\n[^\n]*build_and_run/,
    "a rejected reuse request must not silently build/install and continue"
  );
  assert.match(build, /if \[\[ -n "\$\{SIMULATOR_ID:-\}" \]\]; then/);
});

test("macOS ledger runs route only to bundled Computer", () => {
  const source = fs.readFileSync(path.join(__dirname, "testing_ledger_run.js"), "utf8");
  assert.match(source, /requires_manual_computer: platform === "macos"/);
  assert.match(source, /macOS proof card ready: use @Computer/);
});

test("secondary-circle buttons enter pixels and accessibility together", () => {
  const source = fs.readFileSync(
    path.join(
      __dirname,
      "../apps/ios-macos/Sources/LikemindedApp/Views/CommunitiesPrototypeView.swift"
    ),
    "utf8"
  );
  const section = source.slice(
    source.indexOf('Text("Suggested for your second circle".uppercased())'),
    source.indexOf(".task(id: appState.isSignedIn)")
  );
  assert.match(section, /if showCards \{\s+ScrollView\(\.horizontal/);
  assert.doesNotMatch(section, /\.opacity\(showCards \? 1 : 0\)/);
  assert.match(section, /\.accessibilityIdentifier\("secondary-circle-card-/);
  assert.match(
    source,
    /withAnimation\(\.interactive\) \{\s+showCards = true\s+\}\s+await appState\.fetchCircles\(\)/,
    "decorative visibility must not wait on network refreshes"
  );
});

test("validation reset removes rows using the API-scoped Apple user id", () => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "likeminded-validation-reset-"));
  try {
    const appleSub = `dev-${crypto.createHash("sha256").update("validation-gurusharan").digest("hex").slice(0, 16)}`;
    const seededUserId = `usr_${crypto.createHash("sha256").update(`apple:${appleSub}`).digest("hex").slice(0, 24)}`;
    const retainedUserId = "usr_real_user";
    const row = (userId) => ({ id: userId, user_id: userId, created_at: "2026-01-01T00:00:00.000Z" });
    fs.writeFileSync(path.join(temp, "mvp-store.json"), JSON.stringify({
      users: {
        [seededUserId]: { id: seededUserId, apple_sub: appleSub },
        [retainedUserId]: { id: retainedUserId, apple_sub: "real-apple-sub" }
      },
      profiles: [row(seededUserId), row(retainedUserId)],
      placements: [row(seededUserId), row(retainedUserId)],
      transcripts: [row(seededUserId), row(retainedUserId)]
    }));

    execFileSync(process.execPath, [path.join(__dirname, "seed_validation_data.js"), "remove"], {
      env: { ...process.env, LIKEMINDED_DB_DIR: temp },
      stdio: "pipe"
    });

    const store = JSON.parse(fs.readFileSync(path.join(temp, "mvp-store.json"), "utf8"));
    assert.deepEqual(Object.keys(store.users), [retainedUserId]);
    for (const collection of ["profiles", "placements", "transcripts"]) {
      assert.deepEqual(store[collection].map((item) => item.user_id), [retainedUserId]);
    }
  } finally {
    fs.rmSync(temp, { recursive: true, force: true });
  }
});
