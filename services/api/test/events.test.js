const assert = require("node:assert/strict");
const test = require("node:test");
const { startApi } = require("./helpers/api-server");

test("API writes one structured JSONL event per request without bodies or tokens", async t => {
  const api = await startApi();
  t.after(() => api.stop());

  await api.request("/health");
  await api.request("/v1/does-not-exist");
  await api.request("/v1/profiles/synthesize", { method: "POST", rawBody: "{not json", token: "secret-token-value" });
  await new Promise(resolve => setTimeout(resolve, 100));

  const rows = api.events();
  const requests = rows.filter(row => row.event === "http_request");
  const byRoute = Object.fromEntries(requests.map(row => [`${row.method} ${row.route}`, row]));

  assert.equal(byRoute["GET /health"]?.status_code, 200);
  assert.equal(byRoute["GET /v1/does-not-exist"]?.status_code, 404);
  assert.equal(byRoute["GET /v1/does-not-exist"]?.response_error, "not_found");
  assert.equal(byRoute["POST /v1/profiles/synthesize"]?.status_code, 400);
  assert.equal(byRoute["POST /v1/profiles/synthesize"]?.response_error, "invalid_json");
  assert.ok(requests.every(row => row.error_type === undefined), "expected 4xx responses are not failures");
  for (const row of requests) {
    assert.equal(row.service, "likeminded-api");
    assert.equal(typeof row.ts, "string");
    assert.equal(typeof row.duration_ms, "number");
    assert.equal(typeof row.session_id, "string");
  }
  assert.ok(rows.some(row => row.event === "server_start" && row.status === "ok"));
  const raw = JSON.stringify(rows);
  assert.ok(!raw.includes("secret-token-value"), "events must not contain bearer tokens");
  assert.ok(!raw.includes("{not json"), "events must not contain request bodies");
});

test("API events can be turned off", async t => {
  const api = await startApi({ LIKEMINDED_EVENTS: "0" });
  t.after(() => api.stop());
  await api.request("/health");
  assert.deepEqual(api.events(), []);
});
