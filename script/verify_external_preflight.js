#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const evidencePath = path.join(root, "release/testflight-evidence.json");
const templatePath = path.join(root, "release/testflight-evidence.template.json");

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function missing(message, items) {
  items.push(message);
}

assert.ok(fs.existsSync(templatePath), "release/testflight-evidence.template.json is required");

if (!fs.existsSync(evidencePath)) {
  console.error("External preflight evidence missing: release/testflight-evidence.json");
  console.error("Copy release/testflight-evidence.template.json, fill it after real Render/Neon/Apple/TestFlight proof, then rerun.");
  process.exit(1);
}

const evidence = readJson(evidencePath);
const failures = [];

if (evidence.schema_version !== 2) missing("testflight evidence schema_version must be 2", failures);

if (!/^https:\/\/.+/.test(evidence.render?.service_url || "")) missing("Render HTTPS service_url is required", failures);
if (evidence.render?.health_status !== "ok") missing("Render /health must be checked and health_status must be ok", failures);
if (!evidence.render?.health_checked_at) missing("Render health_checked_at is required", failures);

if (evidence.neon?.database_configured !== true) missing("Neon database_configured must be true", failures);
if (!evidence.neon?.migration_checked_at) missing("Neon migration_checked_at is required", failures);

if (evidence.apple?.bundle_id !== "com.gurusharan.likeminded") missing("Apple bundle_id must be com.gurusharan.likeminded", failures);
if (evidence.apple?.bundle_id_configured !== true) missing("Apple bundle_id_configured must be true", failures);
if (evidence.apple?.sign_in_with_apple_enabled !== true) missing("Sign in with Apple capability must be enabled", failures);
if (evidence.apple?.app_store_connect_app_created !== true) missing("App Store Connect app must be created", failures);

if (evidence.testflight?.signed_build_uploaded !== true) missing("Signed TestFlight build must be uploaded", failures);
if (!/^\d+$/.test(evidence.testflight?.ios_build_number || "")) missing("TestFlight ios_build_number is required", failures);
if (!evidence.testflight?.uploaded_at) missing("TestFlight uploaded_at is required", failures);
if (evidence.testflight?.beta_review_status !== "approved") missing("External Beta App Review must be approved", failures);
if (evidence.testflight?.privacy_policy_added !== true) missing("TestFlight privacy policy must be added", failures);
if (evidence.testflight?.tester_group_configured !== true) missing("TestFlight tester group must be configured", failures);
if (evidence.testflight?.external_group_name !== "Likeminded Early Access") missing("External group must be Likeminded Early Access", failures);
if (evidence.testflight?.external_group_limit !== 25) missing("External group limit must be 25", failures);
if (evidence.testflight?.public_link_enabled !== false) missing("Public TestFlight link must remain disabled", failures);
if (evidence.testflight?.first_install_verified !== true) missing("First external TestFlight install must be verified", failures);
if (!evidence.testflight?.first_install_checked_at) missing("First install checked_at is required", failures);

if (evidence.manual_proof?.real_apple_sign_in_verified !== true) missing("Real Apple sign-in must be verified", failures);
if (evidence.manual_proof?.spoken_audio_to_profile_verified !== true) missing("Spoken audio to profile/placement must be verified", failures);
if (evidence.manual_proof?.livekit_room_verified !== true) missing("LiveKit room join must be verified", failures);
if (evidence.manual_proof?.cross_user_privacy_verified !== true) missing("Cross-user privacy isolation must be verified", failures);
if (evidence.manual_proof?.account_deletion_verified !== true) missing("Apple account deletion and token revocation must be verified", failures);
if (evidence.manual_proof?.tester_loop_verified !== true) missing("Full tester loop must be verified", failures);

if (failures.length) {
  console.error("External preflight incomplete:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("External TestFlight preflight verified");
