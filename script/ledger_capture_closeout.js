#!/usr/bin/env node
/**
 * Post-capture ledger closeout — screenshot ref, stale reproof, control stamp, flow sync.
 *
 *   node script/ledger_capture_closeout.js --platform ios --screen 07-meet \
 *     --screenshot output/validation/ios-screens/meet.png --stamp auto
 */
const path = require("node:path");
const {
  findLedgerByScreenArg,
  stampControlsLedger,
  stampStaleLedger,
  syncFlowsFromControls,
  persistLedger,
  getPlatformHash,
  isoNow
} = require("./ledger_hash");
const { iosStampControlsForScreen } = require("./ios_screen_stamp_map");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

const platform = arg("--platform");
const screen = arg("--screen");
const screenshot = arg("--screenshot");
const stampMode = arg("--stamp") || "auto";
const staleOnly = process.argv.includes("--stale-only");
const method = arg("--method") || (platform === "ios" ? "screen-capture" : "screen-capture");
const user = process.env.LIKEMINDED_VALIDATION_USER || "validation-gurusharan";
const evidencePrefix =
  arg("--evidence-prefix") || `${method} ${user} ${isoNow()} capture closeout`;

if (!platform || !screen) {
  console.error(
    "Usage: ledger_capture_closeout.js --platform ios|macos --screen <id> [--screenshot path] [--stamp auto|none|id1,id2] [--stale-only] [--method screen-capture]"
  );
  process.exit(2);
}

const ledger = findLedgerByScreenArg(platform, screen);
const unified = ledger.unified || ledger.data;
const relShot = screenshot
  ? path.relative(path.resolve(__dirname, ".."), path.resolve(screenshot)).replace(/\\/g, "/")
  : null;

if (relShot && unified.platforms?.[platform]) {
  unified.platforms[platform].recent_screenshot_ref = relShot;
}

let stampedControls = [];
let stampedStale = { controls: [], flows: [] };

if (staleOnly) {
  stampedStale = stampStaleLedger(ledger, platform, { method, evidencePrefix });
} else if (stampMode !== "none") {
  let controlIds = [];
  if (stampMode === "auto") {
    if (platform === "ios") {
      controlIds = iosStampControlsForScreen(screen).controls;
    } else {
      const macScreen = arg("--mac-screen");
      const { MAC_STAMP_CONTROLS } = require("./ios_screen_stamp_map");
      if (macScreen && MAC_STAMP_CONTROLS[macScreen]) {
        controlIds = MAC_STAMP_CONTROLS[macScreen].split(",").map((s) => s.trim());
      }
    }
  } else {
    controlIds = stampMode.split(",").map((s) => s.trim()).filter(Boolean);
  }
  if (controlIds.length) {
    stampedControls = stampControlsLedger(ledger, platform, controlIds, {
      method,
      evidencePrefix
    });
  }
  stampedStale = stampStaleLedger(ledger, platform, { method, evidencePrefix });
}

const flowsSynced = syncFlowsFromControls(ledger, platform);
persistLedger(ledger);

console.log(
  JSON.stringify({
    platform,
    screen: ledger.logicalId || screen,
    screenshot: relShot,
    stamped_controls: stampedControls,
    stamped_stale_controls: stampedStale.controls,
    stamped_stale_flows: stampedStale.flows,
    flows_synced: flowsSynced,
    source_hash: getPlatformHash(ledger, platform)
  })
);
