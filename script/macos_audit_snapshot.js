#!/usr/bin/env node
"use strict";

const { execFileSync } = require("child_process");
const fs = require("fs");
const http = require("http");
const path = require("path");

const root = path.resolve(__dirname, "..");
const screen = process.argv[2] || "unknown";
const port = process.env.PORT || "8787";

function run(command, args) {
  try {
    return execFileSync(command, args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
  } catch (error) {
    return String(error.stderr || error.message).trim();
  }
}

function runOrEmpty(command, args) {
  try {
    return execFileSync(command, args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return "";
  }
}

function readJson(file) {
  const absolute = path.join(root, file);
  if (!fs.existsSync(absolute)) return null;
  return JSON.parse(fs.readFileSync(absolute, "utf8"));
}

function counts(data) {
  if (!data || typeof data !== "object") return {};
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => Array.isArray(value))
      .map(([key, value]) => [key, value.length])
  );
}

function apiHealth() {
  return new Promise((resolve) => {
    const req = http.get(`http://127.0.0.1:${port}/health`, (res) => {
      res.resume();
      resolve({ ok: res.statusCode >= 200 && res.statusCode < 300, status: res.statusCode });
    });
    req.on("error", (error) => resolve({ ok: false, error: error.message }));
    req.setTimeout(1000, () => {
      req.destroy();
      resolve({ ok: false, error: "timeout" });
    });
  });
}

function windowFrame() {
  const script = [
    'tell application "System Events"',
    '  if exists process "LikemindedMac" then',
    '    tell process "LikemindedMac"',
    "      if (count of windows) > 0 then",
    "        set windowPosition to position of window 1",
    "        set windowSize to size of window 1",
    '        return "x=" & (item 1 of windowPosition as text) & ", y=" & (item 2 of windowPosition as text) & ", width=" & (item 1 of windowSize as text) & ", height=" & (item 2 of windowSize as text)',
    "      end if",
    "    end tell",
    "  end if",
    '  return "not-running"',
    "end tell",
  ].join("\n");
  return run("osascript", ["-e", script]);
}

function ledgerForScreen() {
  const dir = path.join(root, "validation", "macos");
  if (!fs.existsSync(dir)) return null;
  for (const name of fs.readdirSync(dir).filter((item) => item.endsWith(".json"))) {
    const file = path.join(dir, name);
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    if ((data.source_files || []).some((source) => source.includes(`(${screen})`))) {
      return {
        file: path.relative(root, file),
        screen: data.screen,
        mockup_ref: data.mockup_ref,
        mockup_missing: Boolean(data.mockup_missing),
        controls: (data.controls || []).length,
      };
    }
  }
  return null;
}

(async () => {
  const snapshot = {
    screen,
    captured_at: new Date().toISOString(),
    note: "Support evidence only. Manual Computer Use decides control pass/fail.",
    git_status_short: run("git", ["status", "--short"]),
    api: await apiHealth(),
    app_pids: runOrEmpty("pgrep", ["-x", "LikemindedMac"]).split(/\s+/).filter(Boolean),
    window_frame: windowFrame(),
    ledger: ledgerForScreen(),
    validation_db: {
      mvp_store: counts(readJson("data/validation-db/mvp-store.json")),
      likeminded: counts(readJson("data/validation-db/likeminded.json")),
    },
  };

  const outDir = path.join(root, "validation", "macos", "runs");
  fs.mkdirSync(outDir, { recursive: true });
  const safeScreen = screen.replace(/[^A-Za-z0-9_-]+/g, "-");
  const stamp = snapshot.captured_at.replace(/[:.]/g, "-");
  const outFile = path.join(outDir, `${stamp}-${safeScreen}.json`);
  fs.writeFileSync(outFile, `${JSON.stringify(snapshot, null, 2)}\n`);
  console.log(path.relative(root, outFile));
})();
