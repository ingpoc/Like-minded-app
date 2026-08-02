#!/usr/bin/env node
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const packetRoot = path.resolve(process.argv[2] || "");
if (!process.argv[2]) {
  console.error("Usage: node script/verify_acceptance_packet.js <packet-root>");
  process.exit(2);
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function fail(message) {
  console.error(`acceptance_packet_invalid: ${message}`);
  process.exit(1);
}

function imageDimensions(bytes, mediaType) {
  if (mediaType === "image/png" && bytes.toString("ascii", 1, 4) === "PNG") {
    return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
  }
  if (mediaType === "image/jpeg" && bytes[0] === 0xff && bytes[1] === 0xd8) {
    for (let offset = 2; offset + 8 < bytes.length;) {
      if (bytes[offset] !== 0xff) break;
      const marker = bytes[offset + 1];
      const length = bytes.readUInt16BE(offset + 2);
      if (marker >= 0xc0 && marker <= 0xc3) {
        return [bytes.readUInt16BE(offset + 7), bytes.readUInt16BE(offset + 5)];
      }
      offset += length + 2;
    }
  }
  return null;
}

const manifestPath = path.join(packetRoot, "manifest.json");
if (!fs.existsSync(manifestPath)) fail("manifest.json is missing");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
if (manifest.schema_version !== "likeminded-ui-acceptance-packet.v1") {
  fail("unsupported schema_version");
}
if (path.basename(packetRoot) !== manifest.product_source_fingerprint) {
  fail("packet directory does not match product_source_fingerprint");
}

const sourceFingerprint = sha256(
  manifest.source_slices
    .map((slice) => `${slice.platform}/${slice.logical_screen_id}=${slice.source_hash}`)
    .join("\n")
);
if (sourceFingerprint !== manifest.product_source_fingerprint) {
  fail("source_slices do not reproduce product_source_fingerprint");
}

for (const slice of manifest.source_slices) {
  const ledgerPath = path.join(root, "validation/screens", `${slice.logical_screen_id}.json`);
  if (!fs.existsSync(ledgerPath)) fail(`missing ledger ${slice.logical_screen_id}`);
  const ledger = JSON.parse(fs.readFileSync(ledgerPath, "utf8"));
  if (ledger.platforms?.[slice.platform]?.source_hash !== slice.source_hash) {
    fail(`stale source hash for ${slice.platform}/${slice.logical_screen_id}`);
  }
}

for (const artifact of manifest.artifacts) {
  if (path.basename(artifact.file) !== artifact.file) fail(`unsafe artifact path ${artifact.file}`);
  const artifactPath = path.join(packetRoot, artifact.file);
  if (!fs.existsSync(artifactPath)) fail(`missing artifact ${artifact.file}`);
  const bytes = fs.readFileSync(artifactPath);
  if (sha256(bytes) !== artifact.sha256) fail(`hash mismatch for ${artifact.file}`);
  const dimensions = imageDimensions(bytes, artifact.media_type);
  if (!dimensions) fail(`content does not match media_type for ${artifact.file}`);
  if (dimensions[0] !== artifact.pixel_width || dimensions[1] !== artifact.pixel_height) {
    fail(`dimension mismatch for ${artifact.file}`);
  }
}

console.log(JSON.stringify({
  ok: true,
  packet: packetRoot,
  fingerprint: manifest.product_source_fingerprint,
  artifacts: manifest.artifacts.length,
  source_slices: manifest.source_slices.length
}));
