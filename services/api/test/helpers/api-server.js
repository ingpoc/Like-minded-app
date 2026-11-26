// Starts the real API on a free local port with a throwaway store for black-box tests.
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const net = require("node:net");
const os = require("node:os");
const path = require("node:path");

const root = path.resolve(__dirname, "../../../..");

async function freePort() {
  const requested = Number(process.env.PORT || 8794);
  const candidates = [requested, ...[8794, 8795, 8796, 8797, 8798, 8799].filter(port => port !== requested)];
  for (const port of candidates) {
    if (port < 8794 || port > 8799) continue;
    const available = await new Promise(resolve => {
      const probe = net.createServer();
      probe.once("error", () => resolve(false));
      probe.listen(port, "127.0.0.1", () => probe.close(() => resolve(true)));
    });
    if (available) return port;
  }
  throw new Error("No local test API port available in 8794-8799");
}

async function startApi(extraEnv = {}) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "likeminded-api-test-"));
  const port = await freePort();
  const baseURL = `http://127.0.0.1:${port}`;
  const eventsFile = path.join(tmp, "events.jsonl");
  const child = spawn(process.execPath, ["services/api/src/server.js"], {
    cwd: root,
    env: {
      ...process.env,
      PORT: String(port),
      HOST: "127.0.0.1",
      DATABASE_URL: "",
      LIKEMINDED_DB_DIR: tmp,
      LIKEMINDED_EVENTS_FILE: eventsFile,
      SESSION_SECRET: "local-test-secret-minimum-24-chars",
      APPLE_AUTH_BYPASS: "1",
      GOOGLE_AUTH_BYPASS: "1",
      OPENAI_API_KEY: "",
      LIVEKIT_API_KEY: "",
      LIVEKIT_API_SECRET: "",
      LIVEKIT_URL: "",
      ...extraEnv
    },
    stdio: ["ignore", "pipe", "pipe"]
  });
  let output = "";
  child.stdout.on("data", chunk => { output += chunk; });
  child.stderr.on("data", chunk => { output += chunk; });

  const deadline = Date.now() + 10000;
  for (;;) {
    try {
      const response = await fetch(`${baseURL}/health`);
      if (response.ok) break;
    } catch {}
    if (child.exitCode !== null || Date.now() > deadline) {
      child.kill("SIGTERM");
      throw new Error(`API did not become healthy:\n${output}`);
    }
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  async function request(pathname, options = {}) {
    const response = await fetch(`${baseURL}${pathname}`, {
      method: options.method || "GET",
      headers: {
        ...(options.body || options.rawBody ? { "content-type": "application/json" } : {}),
        ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
        ...(options.headers || {})
      },
      body: options.rawBody ?? (options.body ? JSON.stringify(options.body) : undefined)
    });
    const text = await response.text();
    let body = null;
    try { body = text ? JSON.parse(text) : null; } catch { body = text; }
    return { status: response.status, headers: response.headers, body, text };
  }

  async function stop() {
    if (child.exitCode === null) {
      await new Promise(resolve => {
        child.once("exit", resolve);
        child.kill("SIGTERM");
      });
    }
    fs.rmSync(tmp, { recursive: true, force: true });
  }

  function events() {
    if (!fs.existsSync(eventsFile)) return [];
    return fs.readFileSync(eventsFile, "utf8").split("\n").filter(Boolean).map(line => JSON.parse(line));
  }

  return { baseURL, request, stop, events, eventsFile, output: () => output };
}

module.exports = { startApi, root };
