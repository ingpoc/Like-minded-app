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
assertIncludes("apps/ios-macos/project.yml", project, "INFOPLIST_KEY_LIKEMINDED_API_BASE_URL");
assertNotIncludes("apps/ios-macos/project.yml", project, "com.likeminded.prototype");

const entitlements = read("apps/ios-macos/Entitlements/Likeminded.entitlements");
assertIncludes("apps/ios-macos/Entitlements/Likeminded.entitlements", entitlements, "com.apple.developer.applesignin");
assertIncludes("apps/ios-macos/Entitlements/Likeminded.entitlements", entitlements, "<string>Default</string>");

const apiClient = read("apps/ios-macos/Sources/LikemindedApp/Data/LikemindedAPIClient.swift");
assertIncludes("LikemindedAPIClient.swift", apiClient, "https://likeminded-api.onrender.com");
assertIncludes("LikemindedAPIClient.swift", apiClient, "Authorization");
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
  "APPLE_BUNDLE_ID",
  "APPLE_CLIENT_ID",
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
  "APPLE_BUNDLE_ID=com.likeminded.app",
  "APPLE_CLIENT_ID=com.likeminded.app",
  "APPLE_AUTH_BYPASS=0"
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

console.log("Release config verified");
