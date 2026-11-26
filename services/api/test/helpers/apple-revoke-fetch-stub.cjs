const fs = require("node:fs");
const originalFetch = globalThis.fetch.bind(globalThis);
const capturePath = process.env.APPLE_REVOKE_TEST_CAPTURE;
const controlPath = process.env.APPLE_REVOKE_TEST_RELEASE;
const mode = process.env.APPLE_REVOKE_TEST_MODE || "success";

globalThis.fetch = async (input, init = {}) => {
  const url = String(input);
  if (!url.endsWith("/auth/revoke")) return originalFetch(input, init);
  const body = String(init.body || "");
  fs.appendFileSync(capturePath, `${JSON.stringify({ url, method: init.method, body })}\n`);
  if (mode === "hold") {
    while (!fs.existsSync(controlPath)) await new Promise(resolve => setTimeout(resolve, 10));
  }
  return { ok: mode !== "failure", status: mode === "failure" ? 503 : 200 };
};
