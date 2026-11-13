"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const test = require("node:test");
const path = require("node:path");
const { listScreenFiles, loadScreenFile } = require("./ledger_screens");

const root = path.resolve(__dirname, "..");

function openReport(platform) {
  const result = spawnSync(
    process.execPath,
    ["script/ledger_open_controls.js", `--platform=${platform}`, "--json"],
    { cwd: root, encoding: "utf8" }
  );
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout).platforms[0];
}

test("ledger JSON uses one explicit stdout write and parses completely", () => {
  const source = fs.readFileSync(
    path.join(root, "script/ledger_open_controls.js"),
    "utf8"
  );
  const result = spawnSync(
    process.execPath,
    [path.join(root, "script/ledger_open_controls.js"), "--platform=ios", "--json"],
    {
      cwd: path.join(root, ".agents/skills/testing-ledger"),
      encoding: "utf8"
    }
  );

  assert.equal(result.status, 0, result.stderr);
  assert.match(source, /process\.stdout\.write\(`\$\{JSON\.stringify/);
  assert.doesNotThrow(() => JSON.parse(result.stdout));
});

for (const platform of ["ios", "macos"]) {
  test(`missing ${platform} UI validation remains an open quality gap`, () => {
    const report = openReport(platform);
    const byScreen = new Map(report.screens.map((screen) => [screen.logical_screen_id, screen]));

    for (const file of listScreenFiles(root)) {
      const { data, logicalId } = loadScreenFile(file, root);
      const slice = data.platforms?.[platform];
      if (!slice || slice.implemented === false) continue;
      const status = slice.ui_validation?.result || slice.visual_parity?.result;
      if (status) continue;

      const gap = byScreen.get(logicalId)?.flows.find((flow) => flow.id === "visual_parity");
      assert.ok(gap, `${logicalId}/${platform} omitted UI validation disappeared from open report`);
      assert.equal(gap.result, "missing");
    }
  });
}

test("testing-ledger declares every mandatory testing-framework owner binding", () => {
  const skill = fs.readFileSync(
    path.join(root, ".agents/skills/testing-ledger/SKILL.md"),
    "utf8"
  );
  for (const binding of [
    "Requirements owner",
    "Design owner",
    "Journey inventory",
    "State coverage",
    "Verification gate",
    "Orchestrator receipt",
    "Quality dimensions",
    "Evidence routes"
  ]) {
    assert.match(skill, new RegExp(`\\| ${binding} \\|`));
  }
});

test("testing-ledger freezes semantic proof before immutable acceptance review", () => {
  const skill = fs.readFileSync(
    path.join(root, ".agents/skills/testing-ledger/SKILL.md"),
    "utf8"
  );
  const gates = fs.readFileSync(
    path.join(root, ".agents/skills/testing-ledger/references/quality-gates.md"),
    "utf8"
  );

  assert.match(skill, /Pre-proof readiness and source-freeze gate/);
  assert.match(skill, /authoritative visible or\s+persisted readback/);
  assert.match(skill, /output\/validation\/acceptance\/<source-hash>\//);
  assert.match(skill, /Collect\s+all known P0–P2 findings before one coherent source batch/);
  assert.match(gates, /proof-branch review → static → targeted runtime → source freeze/);
  assert.match(gates, /Do not overwrite a `latest` package/);
  assert.match(gates, /Do not drain the full affected screen-family flows before the first blind visual/);
  assert.match(gates, /After dual\s+visual and UX acceptance, run those proofs/);
});

test("testing-ledger run cards record the required proof tier", () => {
  const runner = fs.readFileSync(path.join(root, "script/testing_ledger_run.js"), "utf8");
  assert.match(runner, /"api-persist": "api-persist"/);
  assert.match(runner, /"real-auth": "real-auth"/);
  assert.match(runner, /\[pkt\.proof_tier\]/);
  assert.doesNotMatch(runner, /platform === "ios" \? "screenshot"/);
});

test("profile-edit capture cannot stamp interactive actions by screenshot", () => {
  const { iosStampControlsForScreen } = require("./ios_screen_stamp_map");
  assert.deepEqual(iosStampControlsForScreen("profile-edit").controls, []);
});

test("profile-edit iOS actions have explicit semantic proof branches", () => {
  const prove = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  assert.match(prove, /profile-edit\/profile-update-voice\)/);
  assert.match(prove, /ios_scroll_until_tappable "profile-update-with-voice"/);
  assert.match(prove, /"Voice profile"/);
  assert.match(prove, /--likeminded-dev-voice-preview/);
  assert.match(prove, /profile-edit-voice-review\.png/);
  assert.match(prove, /ios_scroll_until_visible "Voice profile saved"/);
  assert.match(prove, /profile-edit-voice-saved\.png/);
  assert.match(prove, /ios_scroll_until_visible "Prefers slow, honest conversation"/);
  assert.match(prove, /profile-edit-voice-failure\.png/);
  assert.match(prove, /stamp_controls "profile-update-voice"/);
  assert.match(prove, /profile-edit\/profile-update-text\)/);
  assert.match(prove, /"Typed profile proof update"/);
  assert.match(prove, /stamp_controls "profile-update-text"/);
  assert.match(prove, /profile-edit\/save\)/);
  assert.match(prove, /ios_tap_button "Back to profile" "Your profile"/);
  assert.match(prove, /stamp_controls "save"/);
});

test("notifications activity filters scroll into the tappable viewport", () => {
  const prove = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  const branch = prove.slice(
    prove.indexOf("notifications/activity-filter-pills)"),
    prove.indexOf("notifications/notif-filter-pills)")
  );

  assert.match(branch, /ios_scroll_label_into_safe_band "Circles activity filter"/);
  assert.doesNotMatch(branch, /ios_scroll_until_visible "Circles activity filter"/);
});

test("onboarding step rows enter the safe viewport in both directions", () => {
  const prove = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  const helper = prove.slice(
    prove.indexOf("ios_scroll_label_into_safe_band()"),
    prove.indexOf('echo "prove_flow')
  );
  const branch = prove.slice(
    prove.indexOf("onboarding/onboarding-join-circle)"),
    prove.indexOf("onboarding/complete-first-time-setup)")
  );

  assert.match(helper, /cy < 180[\s\S]*"\$IDB" swipe-down/);
  for (const label of ["Voice profile step", "Join your first circle step", "About you step"]) {
    assert.match(branch, new RegExp(`ios_scroll_label_into_safe_band "${label}"`));
  }
});

test("explicit iOS validation routes override persisted chat fallback", () => {
  const soulmate = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedApp/Views/SoulmateView.swift"),
    "utf8"
  );
  const rootView = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedApp/Views/RootView.swift"),
    "utf8"
  );

  assert.match(soulmate, /if process\.arguments\.contains\("--likeminded-start-chat"\) \{ return true \}/);
  assert.match(soulmate, /if process\.arguments\.contains\(where: \{ \$0\.hasPrefix\("--likeminded-start-"\) \}\) \{ return false \}/);
  assert.match(rootView, /IOSChatFixtures\.isActive/);
});

test("Create Event types fit the viewport and non-default proof taps once", () => {
  const source = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedApp/Views/CommunitiesPrototypeView.swift"),
    "utf8"
  );
  const createEvent = source.slice(
    source.indexOf("struct CreateEventView"),
    source.indexOf("private func eventSecondaryButton", source.indexOf("struct CreateEventView"))
  );
  const prove = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  const branch = prove.slice(
    prove.indexOf("create-event/event-type-meetup|"),
    prove.indexOf("create-event/event-fields)")
  );

  assert.match(createEvent, /ViewThatFits\(in: \.horizontal\)/);
  assert.match(createEvent, /LazyVGrid\(columns:/);
  assert.doesNotMatch(createEvent, /ScrollView\(\.horizontal/);
  assert.equal((branch.match(/"\$IDB" tap "\$pill_label"/g) || []).length, 1);
});

test("profile-edit voice preview is persistence-backed and re-fetched before stamping", () => {
  const state = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedApp/Data/PrototypeAppState.swift"),
    "utf8"
  );
  const prove = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  assert.match(state, /client\.updateProfile\(reflectionSummary: previewSummary\)/);
  assert.match(state, /slice\?\.profile\.reflection\.summary != previewSummary/);
  assert.match(prove, /voice-derived summary did not survive relaunch and profile refetch/);
});

test("one-screen iOS capture clears account verification before screenshot", () => {
  const capture = fs.readFileSync(
    path.join(root, "script/cross_platform_screen_validate.sh"),
    "utf8"
  );
  const alertProbe = capture.indexOf("account_verification_present");
  const dismiss = capture.indexOf('tap "Not Now"');
  const screenshot = capture.indexOf('screenshot "$outfile"');
  assert.ok(alertProbe >= 0);
  assert.ok(dismiss > alertProbe);
  assert.ok(screenshot > dismiss);
  assert.match(capture, /Apple Account Verification still obscures iOS capture/);
});

test("Soulmate management remains Settings-owned on both native platforms", () => {
  const ios = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedApp/Views/SoulmateView.swift"),
    "utf8"
  );
  const mac = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedMac/MacScreens.swift"),
    "utf8"
  );
  const macSoulmate = mac.slice(
    mac.indexOf("// MARK: - 10. soulmateOverview"),
    mac.indexOf("// MARK: - 12. soulmateDetail")
  );

  assert.match(mac, /case \.soulmateOverview, \.soulmateDiscover: soulmateDiscover/);
  assert.doesNotMatch(mac, /private var soulmateOverview/);

  for (const source of [ios, macSoulmate]) {
    assert.doesNotMatch(source, /Soulmate matching is (?:on|off)/);
    assert.doesNotMatch(source, /Enable Soulmate/);
    assert.doesNotMatch(source, /Discovery preferences/);
    assert.doesNotMatch(source, /How it works/);
    assert.doesNotMatch(source, /Refresh matches/);
    assert.doesNotMatch(source, /Button\("Not now"/);
    assert.match(source, /Keep for later/);
    assert.match(source, /Saved for later/);
    assert.match(source, /View full introduction/);
    assert.doesNotMatch(source, /also spends time on/);
    assert.match(source, /Private until the choice was mutual\./);
    assert.match(source, /You both privately chose each other\./);
  }
  assert.match(ios, /SecondaryActionButton\(title: "Keep for later", systemImage: "bookmark"\)/);
  assert.match(macSoulmate, /Label\("Keep for later", systemImage: "bookmark"\)/);
  assert.match(macSoulmate, /Label\("Private until the choice was mutual\.", systemImage: "lock"\)\s+\.font\(MacType\.body\)/);
  assert.doesNotMatch(macSoulmate, /Text\("This week’s introduction"\)/);
  assert.doesNotMatch(ios.slice(ios.indexOf("var body"), ios.indexOf("private func featuredIntroduction")), /trailingHeader:/);

  for (const screen of ["soulmate-overview", "soulmate-discover"]) {
    const { data } = loadScreenFile(screen, root);
    assert.ok(data.platforms.macos.source_files.includes("apps/ios-macos/Sources/LikemindedMac/MacScreens.swift"));
    assert.ok(data.platforms.macos.source_files.includes("apps/ios-macos/Sources/LikemindedMac/MacRootView.swift"));
    assert.ok(!data.flows.some((flow) => flow.id === "refresh-matches"));
    assert.ok(!data.flows.some((flow) => flow.id === "conversations-icon"));
    for (const platform of ["ios", "macos"]) {
      assert.ok(!(data.controls?.[platform] || []).some((control) => control.id === "refresh-matches"));
      assert.ok(!(data.controls?.[platform] || []).some((control) => control.id === "conversations-icon"));
    }
  }

  const gapRegistry = JSON.parse(
    fs.readFileSync(path.join(root, "validation/gap-flows-registry.json"), "utf8")
  );
  const migrationVerifier = fs.readFileSync(
    path.join(root, "script/verify_ledger_migration.js"),
    "utf8"
  );
  assert.ok(gapRegistry.retired_legacy_controls.includes("ios:14-soulmate#conversations-icon"));
  assert.match(migrationVerifier, /const retirementKey = `ios:\$\{c\.file\}#\$\{c\.id\}`/);

  const iosProof = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  const matchRowProof = iosProof.slice(
    iosProof.indexOf("soulmate-overview/match-row)"),
    iosProof.indexOf("soulmate-overview/post-meet-select)")
  );
  assert.match(iosProof, /soulmate-overview\/save-introduction\)/);
  assert.match(iosProof, /ios_tap_button "Keep for later" "Saved for later"/);
  assert.match(matchRowProof, /ios_tap_button "View full introduction" "Start chatting"/);
  assert.doesNotMatch(matchRowProof, /MUTUAL MATCHES/);
  assert.doesNotMatch(iosProof, /soulmate-overview\/refresh-matches\)/);
});

test("Soulmate toggle proof restores deterministic validation state", () => {
  const proof = fs.readFileSync(path.join(root, "script/testing_ledger_prove_ios.sh"), "utf8");
  const branch = proof.slice(
    proof.indexOf("settings/settings-soulmate-toggle)"),
    proof.indexOf("settings/settings-discovery)")
  );
  assert.match(branch, /stamp_controls "soulmate-toggle"[\s\S]*reset:validation-data/);
});

test("Discovery age proof keeps repeated taps above the tab bar", () => {
  const proof = fs.readFileSync(path.join(root, "script/testing_ledger_prove_ios.sh"), "utf8");
  const branch = proof.slice(
    proof.indexOf("settings/settings-discovery-details)"),
    proof.indexOf("settings/settings-delete-cancel)")
  );
  assert.match(branch, /ios_scroll_label_into_safe_band "Increase maximum age"/);
  assert.doesNotMatch(branch, /ios_scroll_until_visible "Decrease minimum age"/);
  assert.match(branch, /stamp_controls "discovery-who,discovery-age-range,discovery-visibility,discovery-save" "api-persist"[\s\S]*reset:validation-data/);
});

test("Communities card proofs reject off-screen accessibility nodes", () => {
  const proof = fs.readFileSync(path.join(root, "script/testing_ledger_prove_ios.sh"), "utf8");
  const branch = proof.slice(
    proof.indexOf("communities/create-card)"),
    proof.indexOf("soulmate-overview/enable-toggle)")
  );
  assert.match(branch, /ios_scroll_label_into_safe_band "Create a community"/);
  assert.match(branch, /ios_scroll_label_into_safe_band "\$joined_label"/);
  assert.match(branch, /ios_scroll_label_into_safe_band "\$browse_label"/);
  assert.doesNotMatch(branch, /ios_scroll_until_visible "Create a community"/);
});

test("Community member search waits for current roster copy", () => {
  const proof = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  const branch = proof.slice(
    proof.indexOf("community-members/search)"),
    proof.indexOf("create-community/create-entry)")
  );
  assert.match(branch, /ios_wait_ui_contains "Community member" 25/);
  assert.doesNotMatch(branch, /Active now/);
});

test("Meet RSVP proof uses the product accessibility labels", () => {
  const proof = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  const branch = proof.slice(
    proof.indexOf("meet/rsvp-weekend)"),
    proof.indexOf("circles/hero-circle)")
  );
  assert.match(branch, /Saturday unavailable\|community\|false/);
  assert.match(branch, /Sunday unavailable\|circle\|false/);
  assert.doesNotMatch(branch, /Saturday Not|Sunday Not/);
});

test("Onboarding completion safely focuses the initial city field", () => {
  const proof = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  const branch = proof.slice(
    proof.indexOf("onboarding/complete-first-time-setup)"),
    proof.indexOf("past-meet-recap/recap-soulmate-select)")
  );
  assert.match(branch, /ios_scroll_label_into_safe_band "Where are you based\?"/);
  assert.doesNotMatch(branch, /ios_tap_button "About you step"/);
  assert.doesNotMatch(branch, /skip re-interview/);
  assert.match(branch, /for idx in "\$\{!voice_answers\[@\]\}"/);
  assert.match(proof, /"TextField", "SearchField", "TextArea", "TextView"/);
});

test("Onboarding voice proof uses text input and persisted readback", () => {
  const proof = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );
  const branch = proof.slice(
    proof.indexOf("onboarding/onboarding-voice)"),
    proof.indexOf("onboarding/onboarding-join-circle)")
  );
  assert.equal((branch.match(/ios_focus_and_type "Your answer"/g) || []).length, 3);
  assert.match(branch, /Save voice profile/);
  assert.match(branch, /sourceInput/);
  assert.match(branch, /reflectionAnswers/);
  assert.match(branch, /stamp_controls "voice-profile-step" "api-persist"/);
  assert.match(branch, /reset:validation-data/);
});

test("Profile uses deliberate mobile disclosure and keeps Review signals with its subject", () => {
  const ios = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedApp/Views/ProfilePrototypeView.swift"),
    "utf8"
  );
  const shared = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedApp/Views/Shared/PrototypeComponents.swift"),
    "utf8"
  );
  const livingProfile = ios.slice(
    ios.indexOf("private var livingProfile"),
    ios.indexOf("private func profileSignalPill")
  );
  assert.match(livingProfile, /\.prefix\(2\)/);
  assert.match(livingProfile, /Button\("Review all"\)/);
  assert.doesNotMatch(livingProfile, /ScrollView\(\.horizontal/);
  assert.ok(livingProfile.indexOf('Text("Why this placement")') < livingProfile.indexOf('Text("Voice-informed signals")'));
  assert.match(livingProfile, /Context for your circle—not proof of personality\./);
  assert.doesNotMatch(ios, /Voice profile active/);
  assert.match(shared, /struct FlexibleTagLayout[\s\S]*FlowLayout\(spacing: 8\)/);
  assert.doesNotMatch(shared, /ViewThatFits\(in: \.vertical\)/);

  const mac = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedMac/MacScreens.swift"),
    "utf8"
  );
  const signals = mac.indexOf('Text("Voice-informed signals")');
  const review = mac.indexOf('Button("Review signals")', signals);
  const placement = mac.indexOf('Text("Why this placement")', signals);
  assert.ok(signals >= 0 && review > signals && review < placement);
  assert.doesNotMatch(ios, /isSummaryExpanded/);
  assert.doesNotMatch(mac, /isProfileSummaryExpanded/);
  assert.doesNotMatch(mac, /Voice profile active/);
});

test("Profile ledger follows the current progressive-disclosure design", () => {
  const ledger = JSON.parse(
    fs.readFileSync(path.join(root, "validation/screens/profile-populated.json"), "utf8")
  );
  const flowIds = ledger.flows.map((flow) => flow.id);
  const iosControlIds = ledger.controls.ios.map((control) => control.id);
  const proof = fs.readFileSync(path.join(root, "script/testing_ledger_prove_ios.sh"), "utf8");

  for (const id of ["profile-evidence-scope", "review-signals", "re-interview", "edit-profile"]) {
    assert.ok(flowIds.includes(id));
    assert.ok(iosControlIds.includes(id));
  }
  assert.ok(!flowIds.includes("update-profile"));
  assert.ok(!flowIds.includes("comm-read-card"));
  assert.ok(!flowIds.includes("trait-bars"));
  const retired = JSON.parse(
    fs.readFileSync(path.join(root, "validation/gap-flows-registry.json"), "utf8")
  ).retired_legacy_controls;
  for (const id of ["update-profile", "comm-read-card", "trait-bars"]) {
    assert.ok(retired.includes(`ios:04-profile-populated#${id}`));
  }
  assert.match(proof, /profile-populated\/review-signals\)/);
  assert.match(proof, /ios_scroll_label_into_safe_band "Review signals" 10/);
  assert.match(proof, /ios_scroll_label_into_safe_band "Voice-informed signals" 10/);
  assert.match(proof, /ios_scroll_label_into_safe_band "Startups"/);
  assert.match(proof, /profile-populated-interests\.png/);
  assert.doesNotMatch(proof, /Communication, Energy, Trust/);
  assert.doesNotMatch(proof, /profile-populated\/(?:update-profile|comm-read-card|trait-bars)\)/);
});

test("native navigation and Soulmate heading hierarchy stay cross-platform consistent", () => {
  const iosTabs = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedApp/Models/PrototypeModels.swift"),
    "utf8"
  );
  const macData = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedMac/MacPrototypeData.swift"),
    "utf8"
  );
  const iosTabBar = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedApp/Views/CustomTabBar.swift"),
    "utf8"
  );
  const macDesign = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedMac/MacDesignSystem.swift"),
    "utf8"
  );
  const macRoot = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedMac/MacRootView.swift"),
    "utf8"
  );
  const iosProof = fs.readFileSync(
    path.join(root, "script/testing_ledger_prove_ios.sh"),
    "utf8"
  );

  assert.match(iosTabs, /case communities = "Communities"\s+case soulmate = "Soulmate"\s+case profile = "Profile"/);
  assert.match(macData, /case communities = "Communities"\s+case soulmate = "Soulmate"\s+case profile = "Profile"/);
  assert.match(macData, /return \[\.meet, \.circles, \.communities, \.soulmate, \.profile\]/);
  assert.match(macData, /case \.soulmateOverview, \.soulmateDiscover: "This week’s introduction\."/);
  assert.match(macData, /case \.soulmateOverview, \.soulmateDiscover: "A slower way to meet someone, shaped by how you connect\."/);
  assert.match(iosProof, /ios_tap_button "Soulmate" "This week’s introduction\."/);
  assert.doesNotMatch(iosProof, /ios_tap_button "Soulmate" "Matches are mutual\."/);
  assert.match(iosTabBar, /\.font\(\.system\(size: 12,/);
  assert.match(macDesign, /static let small = Font\.system\(size: 16,/);
  assert.match(macRoot, /case \.soulmateOverview, \.soulmateDiscover:\s+return false/);
  assert.match(macRoot, /let tabWidth: CGFloat = 144/);
});

test("macOS chat send proof starts from a live match instead of fixture chat", () => {
  const { data } = loadScreenFile("chat", root);
  const send = data.flows.find((flow) => flow.id === "send-message");
  assert.ok(send, "chat/send-message flow must exist");
  assert.match(send.proof.commands.macos, /soulmateDiscover/);
  assert.match(send.proof.commands.macos, /Message Priya/);
  assert.doesNotMatch(send.proof.commands.macos, /-- chat(?:;|\s|$)/);
});

test("macOS voice-session proof launches the owned onboarding step", () => {
  const launcher = fs.readFileSync(
    path.join(root, "script/run_macos_manual_validation.sh"),
    "utf8"
  );
  const screens = fs.readFileSync(
    path.join(root, "apps/ios-macos/Sources/LikemindedMac/MacScreens.swift"),
    "utf8"
  );
  assert.match(launcher, /voice-session\)\s+SCREEN="profileOnboarding"\s+;;/);
  assert.match(
    launcher,
    /profileVoiceStepPanel\)\s+SCREEN="profileOnboarding"\s+EXTRA_LAUNCH_ARGS\+=\(--likeminded-dev-profile-empty\)/
  );
  assert.match(screens, /shouldHoldProfileInterviewStep = Self\.initialProfileOnboardingStep\(\) == 2/);
});

test("Soulmate proof names the weekly introduction instead of the retired roster", () => {
  const { data } = loadScreenFile("soulmate-discover", root);
  const roster = data.flows.find((flow) => flow.id === "soulmate-real-roster");
  assert.match(roster.proof.success_signals.join(" "), /This week’s introduction/);
  assert.doesNotMatch(roster.proof.success_signals.join(" "), /Your mutual matches/);
});

test("blind UI review requires a verified current-source acceptance packet", () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
  const gate = fs.readFileSync(
    path.join(root, ".agents/skills/testing-ledger/references/quality-gates.md"),
    "utf8"
  );

  assert.equal(pkg.scripts["verify:acceptance-packet"], "node script/verify_acceptance_packet.js");
  assert.match(gate, /npm run verify:acceptance-packet -- output\/validation\/acceptance\/<source-hash>/);
  assert.match(gate, /Only a packet that passes this current-source/);
});
