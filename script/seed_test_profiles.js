#!/usr/bin/env node
const assert = require("node:assert/strict");

const baseURL = process.env.LIKEMINDED_API_BASE_URL || "http://127.0.0.1:8787";

const cases = [
  {
    id: "warm-direct-reader",
    name: "Warm Direct Reader",
    transcript: "I want honest conversations, small warm circles, steady trust, books, design, and people who communicate directly.",
    reflectionAnswers: [
      "Slow, honest conversations.",
      "Warm, direct friendships.",
      "I want closeness with clear pacing and room to reflect."
    ]
  },
  {
    id: "high-energy-explorer",
    name: "High Energy Explorer",
    transcript: "I want spontaneous plans, travel, new restaurants, energetic people, and groups that actually go do things.",
    reflectionAnswers: ["I like momentum.", "I open up quickly when people are playful.", "I want shared experiences."]
  },
  {
    id: "steady-care-builder",
    name: "Steady Care Builder",
    transcript: "I want consistent people, mutual support, care work, practical help, and a small group that shows up every week.",
    reflectionAnswers: ["Consistency matters.", "I prefer calm rooms.", "I build trust slowly."]
  },
  {
    id: "romantic-slow-intimacy",
    name: "Romantic Slow Intimacy",
    transcript: "I am exploring romantic compatibility, but only with clear consent, emotional care, and one deep conversation at a time.",
    reflectionAnswers: ["Intimacy should not be rushed.", "I value tenderness.", "Consent and pacing are important."]
  }
];

async function request(pathname, options = {}) {
  const response = await fetch(`${baseURL}${pathname}`, {
    ...options,
    headers: {
      ...(options.body ? { "content-type": "application/json" } : {}),
      ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
      ...(options.headers || {})
    },
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  return { response, body };
}

(async () => {
  const health = await request("/health");
  assert.equal(health.response.status, 200, `API must be running at ${baseURL}`);

  for (const profileCase of cases) {
    const auth = await request("/v1/auth/apple", {
      method: "POST",
      body: { identityToken: `seed-${profileCase.id}`, fullName: profileCase.name }
    });
    assert.equal(auth.response.status, 200, `${profileCase.id}: auth failed ${JSON.stringify(auth.body)}`);

    const discovered = await request("/v1/discover", {
      method: "POST",
      token: auth.body.sessionToken,
      body: {
        interviewTranscript: profileCase.transcript,
        reflectionAnswers: profileCase.reflectionAnswers
      }
    });
    assert.equal(discovered.response.status, 200, `${profileCase.id}: discover failed ${JSON.stringify(discovered.body)}`);
    console.log(JSON.stringify({
      id: profileCase.id,
      mode: discovered.body.synthesisMode,
      profileId: discovered.body.profileId,
      circle: discovered.body.placement.primaryCircle.name,
      reasons: discovered.body.placement.fitReasons
    }));
  }
})().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
