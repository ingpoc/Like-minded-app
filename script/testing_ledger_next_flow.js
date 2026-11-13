#!/usr/bin/env node
/**
 * Next open flow for testing-ledger skill (macOS bundled Computer or iOS capture).
 * Prefer testing:ledger-run for tester turns (merged card + prove).
 *
 *   npm run testing:ledger-next
 *   npm run testing:ledger-next -- --platform ios --json
 */
const { pickNextFlow } = require("./testing_ledger_pick_next");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

const platform = arg("--platform") || "macos";
const asJson = process.argv.includes("--json");
const asText = process.argv.includes("--text") || !asJson;
const includeBlocked = process.argv.includes("--include-blocked");

const { candidates, next } = pickNextFlow(platform, { includeBlocked });

if (!next) {
  if (asJson) {
    console.log(JSON.stringify({ platform, flow: null, message: "no open flows" }));
  } else {
    console.log(`testing-ledger-next: no open ${platform} flows`);
  }
  process.exit(0);
}

const proveCmd =
  platform === "ios"
    ? `npm run testing:ledger-prove-ios -- --screen ${next.screen} --flow ${next.flow_id}`
    : `@Computer: npm run dev:macos:validation -- ${next.mac_screen || next.screen}; prove ${next.screen}/${next.flow_id} in the canonical app`;
const recordMethod = platform === "ios" ? "screenshot" : "Computer-use";
const out = {
  platform,
  screen: next.screen,
  flow_id: next.flow_id,
  flow_name: next.flow_name,
  queue_result: next.result,
  mac_screen: next.mac_screen,
  proof_tier: next.packet.proof_tier,
  commands: {
    run: `npm run testing:ledger-run -- --platform ${platform} --screen ${next.screen} --flow ${next.flow_id}`,
    prove: proveCmd,
    macos_computer:
      platform === "macos"
        ? proveCmd
        : null,
    ios_capture:
      platform === "ios"
        ? `./script/testing_ledger_prove_ios.sh --screen ${next.screen} --flow ${next.flow_id}`
        : null,
    record_pass: `npm run ledger:record-flow -- --platform ${platform} --screen ${next.screen} --flow ${next.flow_id} --result pass --method ${recordMethod} --evidence "..."`
  },
  open_remaining: candidates.length
};

if (asJson) {
  out.packet = next.packet;
  console.log(JSON.stringify(out, null, 2));
  process.exit(0);
}

console.log("# testing-ledger-next");
console.log(`platform: ${platform}`);
console.log(`target: ${next.screen}/${next.flow_id} (${next.result})`);
console.log(`tier: ${next.packet.proof_tier}`);
console.log(`mac_screen: ${next.mac_screen || "(resolve from ledger:screen)"}`);
console.log(`open_queue: ${candidates.length}`);
console.log(`PRE: ${next.packet.preconditions.join(" | ")}`);
console.log(`PASS: ${next.packet.success_signals.join(" | ")}`);
console.log(`MOCKUP: ${next.packet.mockup_ref || "(none)"}`);
console.log(`BASELINE: ${next.packet.baseline_screenshot || "(none)"}`);
console.log(`RUN: ${out.commands.run}`);
console.log(`RECORD: ${out.commands.record_pass}`);
