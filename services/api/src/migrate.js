const fs = require("node:fs");
const path = require("node:path");
const { migrateMvpStore, isPostgres } = require("./lib/mvp-store");

function loadLocalEnv() {
  const envPath = path.resolve(process.cwd(), ".env.local");
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
    const separator = trimmed.indexOf("=");
    const key = trimmed.slice(0, separator).trim();
    const value = trimmed.slice(separator + 1).trim().replace(/^['"]|['"]$/g, "");
    if (key && process.env[key] === undefined) process.env[key] = value;
  }
}

loadLocalEnv();

migrateMvpStore()
  .then(() => {
    console.log(`MVP database ready: ${isPostgres ? "postgres" : "local-json"}`);
  })
  .catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
