#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function assertIncludes(file, content, expected) {
  assert.ok(content.includes(expected), `${file} must include ${expected}`);
}

function assertNotIncludes(file, content, rejected) {
  assert.ok(!content.includes(rejected), `${file} must not include ${rejected}`);
}

const project = read("apps/ios-macos/project.yml");
assertIncludes("apps/ios-macos/project.yml", project, "PRODUCT_BUNDLE_IDENTIFIER: com.likeminded.app");
assertIncludes("apps/ios-macos/project.yml", project, "CODE_SIGN_ENTITLEMENTS: Entitlements/Likeminded.entitlements");
assertIncludes("apps/ios-macos/project.yml", project, "INFOPLIST_KEY_NSMicrophoneUsageDescription");
assertIncludes("apps/ios-macos/project.yml", project, "INFOPLIST_KEY_NSCameraUsageDescription");
assertIncludes("apps/ios-macos/project.yml", project, "INFOPLIST_KEY_LIKEMINDED_API_BASE_URL");
assertNotIncludes("apps/ios-macos/project.yml", project, "com.likeminded.prototype");

const entitlements = read("apps/ios-macos/Entitlements/Likeminded.entitlements");
assertIncludes("apps/ios-macos/Entitlements/Likeminded.entitlements", entitlements, "com.apple.developer.applesignin");
assertIncludes("apps/ios-macos/Entitlements/Likeminded.entitlements", entitlements, "<string>Default</string>");

const macEntitlements = read("apps/ios-macos/Entitlements/LikemindedMac.entitlements");
assertIncludes("apps/ios-macos/Entitlements/LikemindedMac.entitlements", macEntitlements, "com.apple.developer.applesignin");
assertIncludes("apps/ios-macos/project.yml", project, "CODE_SIGN_ENTITLEMENTS: Entitlements/LikemindedMac.entitlements");
assertIncludes("apps/ios-macos/project.yml", project, "CODE_SIGN_ENTITLEMENTS: Entitlements/LikemindedMac.Debug.entitlements");

const macDebugEntitlements = read("apps/ios-macos/Entitlements/LikemindedMac.Debug.entitlements");
assertNotIncludes("apps/ios-macos/Entitlements/LikemindedMac.Debug.entitlements", macDebugEntitlements, "com.apple.developer.applesignin");

assertIncludes("apps/ios-macos/Info/Likeminded-Info.plist", read("apps/ios-macos/Info/Likeminded-Info.plist"), "GIDClientID");
assertIncludes("apps/ios-macos/Info/LikemindedMac-Info.plist", read("apps/ios-macos/Info/LikemindedMac-Info.plist"), "com.likeminded.mac");

const apiClient = read("apps/ios-macos/Sources/LikemindedApp/Data/LikemindedAPIClient.swift");
assertIncludes("LikemindedAPIClient.swift", apiClient, "https://likeminded-api.onrender.com");
assertIncludes("LikemindedAPIClient.swift", apiClient, "Bearer");

const voiceClient = read("apps/ios-macos/Sources/LikemindedApp/Data/RealtimeVoiceClient.swift");
assertIncludes("RealtimeVoiceClient.swift", voiceClient, "authToken");
assertIncludes("RealtimeVoiceClient.swift", voiceClient, "Authorization");
assertNotIncludes("RealtimeVoiceClient.swift", voiceClient, "http://127.0.0.1:8787/v1/realtime/calls");

const render = read("render.yaml");
for (const key of [
  "DATABASE_URL",
  "SESSION_SECRET",
  "OPENAI_API_KEY",
  "LIVEKIT_API_KEY",
  "LIVEKIT_API_SECRET",
  "LIVEKIT_URL",
  "APPLE_BUNDLE_ID",
  "APPLE_CLIENT_ID",
  "APPLE_MAC_BUNDLE_ID",
  "APPLE_CLIENT_IDS",
  "APPLE_REQUIRE_NONCE",
  "APPLE_AUTH_BYPASS"
]) {
  assertIncludes("render.yaml", render, `key: ${key}`);
}
assertIncludes("render.yaml", render, 'value: "0"');
assertIncludes("render.yaml", render, "healthCheckPath: /health");

const envExample = read(".env.example");
for (const key of [
  "DATABASE_URL=",
  "SESSION_SECRET=",
  "LIVEKIT_API_KEY=",
  "LIVEKIT_API_SECRET=",
  "LIVEKIT_URL=",
  "APPLE_BUNDLE_ID=com.likeminded.app",
  "APPLE_CLIENT_ID=com.likeminded.app",
  "APPLE_MAC_BUNDLE_ID=com.likeminded.mac",
  "APPLE_CLIENT_IDS=com.likeminded.app,com.likeminded.mac",
  "APPLE_REQUIRE_NONCE=1",
  "APPLE_AUTH_BYPASS=0",
  "GOOGLE_CLIENT_ID_IOS=",
  "GOOGLE_CLIENT_ID_MAC=",
  "GOOGLE_REVERSED_CLIENT_ID=",
  "GOOGLE_CLIENT_IDS=",
  "WALLETCONNECT_PROJECT_ID="
]) {
  assertIncludes(".env.example", envExample, key);
}

const privacy = read("docs/references/privacy-policy-testflight.md");
for (const phrase of ["Voice interview transcript", "AI Processing", "Retention And Deletion"]) {
  assertIncludes("privacy-policy-testflight.md", privacy, phrase);
}

const buildScript = read("script/build_and_run.sh");
assertIncludes("script/build_and_run.sh", buildScript, "com.likeminded.app");
assertNotIncludes("script/build_and_run.sh", buildScript, "com.likeminded.prototype");

const packageJson = read("package.json");
assertIncludes("package.json", packageJson, "verify:simulator-local");
assertIncludes("package.json", packageJson, "verify:external-preflight");

const setupDoc = read("docs/workflows/setup.md");
assertIncludes("docs/workflows/setup.md", setupDoc, "LiveKitMeetSession");
assertIncludes("docs/workflows/setup.md", setupDoc, "GOOGLE_REVERSED_CLIENT_ID");

const validation = read("docs/workflows/validation.md");
assertIncludes("docs/workflows/validation.md", validation, "npm run verify:simulator-local");
assertIncludes("docs/workflows/validation.md", validation, "npm run verify:external-preflight");

const externalEvidenceTemplate = read("release/testflight-evidence.template.json");
for (const phrase of ["service_url", "database_configured", "sign_in_with_apple_enabled", "spoken_audio_to_profile_verified"]) {
  assertIncludes("release/testflight-evidence.template.json", externalEvidenceTemplate, phrase);
}

console.log("Release config verified");
