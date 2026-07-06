#!/usr/bin/env node
// Regenerate validation/README.md index from validation/screens/*.json (schema v2).

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname);
const SCREENS = path.join(ROOT, "screens");

function loadScreens() {
  if (!fs.existsSync(SCREENS)) return [];
  return fs
    .readdirSync(SCREENS)
    .filter((f) => f.endsWith(".json") && !f.startsWith("_"))
    .sort()
    .map((f) => {
      const data = JSON.parse(fs.readFileSync(path.join(SCREENS, f), "utf8"));
      return {
        id: data.logical_screen_id || f.replace(/\.json$/, ""),
        file: f,
        name: data.screen || f,
        flows: (data.flows || []).length,
        ios: data.platforms?.ios?.ledger_legacy_id || "—",
        macos: data.platforms?.macos?.ledger_legacy_id || "—"
      };
    });
}

const screens = loadScreens();

const readme = `# Validation index

**Not a status owner.** Pass/fail/stale live in \`validation/screens/*.json\` only (schema v2).

| Need | Command |
|------|---------|
| Route | \`npm run goal:next\` |
| One screen | \`npm run ledger:screen -- --platform ios\\|macos --screen <logical-id> --section flows\\|controls\\|all\` |
| Gap audit (open flows) | \`npm run ledger:open\` |
| Session brief (anti-redo) | \`npm run ledger:brief\` |
| One flow packet | \`npm run ledger:flow -- --platform ios\\|macos --screen <id> --flow <flow-id>\` |
| Stale after edits | \`npm run ledger:stale\` |
| Apply gap backlog | \`npm run ledger:apply-gaps\` |
| Apply proof packets | \`npm run ledger:apply-proof\` |
| Production gate | \`npm run verify:production-ready\` |
| Migration verify | \`npm run verify:ledger-migration\` |

**Contract:** \`production-contract.json\` (TestFlight MVP scope). **Templates:** \`screens/_template.*.json\`. Batch gaps: \`gap-flows-registry.json\`.

Regenerate this link list: \`node validation/_generate.js\` (never overwrites JSON evidence).

## Logical screens (${screens.length})

Each file owns **both platforms** + \`flows[]\` (primary status) + \`controls.{ios,macos}\` (atomic UI).

| Screen | iOS legacy | macOS legacy | Flows |
|--------|------------|--------------|-------|
${screens.map((s) => `| [${s.name}](screens/${s.file}) (\`${s.id}\`) | ${s.ios} | ${s.macos} | ${s.flows} |`).join("\n")}

Legacy ledgers archived at \`validation/_legacy/{ios,macos}/\`.

Conventions: \`docs/workflows/validation.md\`.
`;

fs.writeFileSync(path.join(ROOT, "README.md"), readme);
console.log(`README index: ${screens.length} logical screens.`);
