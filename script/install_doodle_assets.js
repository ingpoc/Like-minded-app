#!/usr/bin/env node
/**
 * Register generated doodle PNGs into Assets.xcassets imagesets.
 * Usage: node script/install_doodle_assets.js <assets-dir-with-pngs>
 * Expects files named exactly like the imageset (e.g. DoodleCircleReflectiveBuilders.png).
 */
const fs = require("fs");
const path = require("path");

const repoRoot = path.join(__dirname, "..");
const catalog = path.join(repoRoot, "apps/ios-macos/Assets.xcassets");
const srcDir = process.argv[2] || path.join(repoRoot, "output/doodle-art");

const contentsJson = (filename) => ({
  images: [{ filename, idiom: "universal", scale: "1x" }],
  info: { author: "xcode", version: 1 },
});

if (!fs.existsSync(srcDir)) {
  console.error(`Missing source dir: ${srcDir}`);
  process.exit(1);
}

for (const file of fs.readdirSync(srcDir).filter((f) => f.endsWith(".png"))) {
  const base = file.replace(/\.png$/i, "");
  const setDir = path.join(catalog, `${base}.imageset`);
  const destFile = `${base}.png`;
  fs.mkdirSync(setDir, { recursive: true });
  fs.copyFileSync(path.join(srcDir, file), path.join(setDir, destFile));
  fs.writeFileSync(path.join(setDir, "Contents.json"), `${JSON.stringify(contentsJson(destFile), null, 2)}\n`);
  console.log(`installed ${base}.imageset`);
}
