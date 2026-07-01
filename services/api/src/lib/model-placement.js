const { CIRCLE_ARCHETYPES, buildPlacement, buildProfileFromInterview, generateId } = require("./architecture");

const DEFAULT_MODEL = process.env.OPENAI_PROFILE_MODEL || "gpt-5.4-mini";

function circleSummary(circle) {
  return {
    id: circle.id,
    name: circle.name,
    description: circle.description,
    roomEnergy: circle.roomEnergy,
    interactionIntent: circle.interactionIntent,
    socialFormat: circle.socialFormat,
    themes: circle.themes,
    meetingFormat: circle.meetingFormat
  };
}

function fallbackProfilePlacement({ interviewTranscript, reflectionAnswers }) {
  const profile = buildProfileFromInterview(interviewTranscript || "", reflectionAnswers || []);
  const placement = buildPlacement(profile);
  return { profile, placement, allCircleFits: null, synthesisMode: "deterministic_fallback" };
}

function clamp01(value, fallback = 0.5) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(0, Math.min(1, number));
}

function normalizeSignals(signals = {}) {
  return {
    bigFive: {
      openness: clamp01(signals.bigFive?.openness),
      conscientiousness: clamp01(signals.bigFive?.conscientiousness),
      extraversion: clamp01(signals.bigFive?.extraversion),
      agreeableness: clamp01(signals.bigFive?.agreeableness),
      neuroticism: clamp01(signals.bigFive?.neuroticism)
    },
    attachment: signals.attachment || null,
    socialEnergy: signals.socialEnergy || null,
    communicationStyle: {
      primary: signals.communicationStyle?.primary || null,
      pace: clamp01(signals.communicationStyle?.pace)
    },
    trustPattern: signals.trustPattern || null,
    humorStyle: signals.humorStyle || null,
    conflictStyle: signals.conflictStyle || null
  };
}

function stringArray(value) {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string") : [];
}

function parseModelJson(body) {
  if (body.output_parsed) return body.output_parsed;
  const text = body.output_text || body.output?.flatMap((item) => item.content || [])
    .map((content) => content.text || "")
    .join("");
  if (!text) throw new Error("model_response_missing_text");
  return JSON.parse(text);
}

function placementFromModel(profile, modelResult) {
  const circleIds = new Set(CIRCLE_ARCHETYPES.map((circle) => circle.id));
  const primaryId = circleIds.has(modelResult.primaryCircleId) ? modelResult.primaryCircleId : CIRCLE_ARCHETYPES[0].id;
  const primaryCircle = CIRCLE_ARCHETYPES.find((circle) => circle.id === primaryId);
  const secondaryCircles = stringArray(modelResult.secondaryCircleIds)
    .filter((id) => id !== primaryId && circleIds.has(id))
    .map((id) => CIRCLE_ARCHETYPES.find((circle) => circle.id === id))
    .slice(0, 3);

  return {
    rule: "model-place-user-confirm",
    confidenceLabel: modelResult.confidenceLabel || "Model fit",
    fitReasons: stringArray(modelResult.fitReasons).slice(0, 4),
    sourceReflectionSignals: stringArray(modelResult.sourceReflectionSignals).slice(0, 6),
    primaryCircle,
    secondaryCircles,
    userState: "proposed",
    actions: {
      primaryAction: "Accept this circle",
      swapAction: "Try another circle",
      deferAction: "Defer for now"
    },
    isNewCircle: false
  };
}

function profilePlacementFromModelResult({ modelResult, interviewTranscript = "", reflectionAnswers = [] }) {
  const profile = {
    profileId: generateId(),
    signals: normalizeSignals(modelResult.signals),
    sourceInput: {
      reflectionAnswers,
      interviewExcerpt: interviewTranscript.slice(0, 500)
    },
    profileSummary: modelResult.profileSummary || "",
    synthesizedAt: new Date().toISOString()
  };
  const placement = placementFromModel(profile, modelResult);
  return { profile, placement };
}

async function modelBackedProfilePlacement({ interviewTranscript = "", reflectionAnswers = [] }) {
  if (!process.env.OPENAI_API_KEY) return fallbackProfilePlacement({ interviewTranscript, reflectionAnswers });

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: DEFAULT_MODEL,
      input: [
        {
          role: "system",
          content: "You create private social-placement profiles for Likeminded. Decide from the whole interview, not keyword matches. Prefer the circle whose room energy, pacing, trust pattern, and interaction intent best match the person. Return only valid JSON."
        },
        {
          role: "user",
          content: JSON.stringify({
            interviewTranscript,
            reflectionAnswers,
            availableCircles: CIRCLE_ARCHETYPES.map(circleSummary),
            outputContract: {
              signals: "Big Five 0..1 plus attachment, socialEnergy, communicationStyle, trustPattern, humorStyle, conflictStyle",
              primaryCircleId: "one available circle id",
              secondaryCircleIds: "0-3 available circle ids",
              fitReasons: "short user-facing reasons grounded in the interview",
              sourceReflectionSignals: "short evidence bullets from the interview",
              profileSummary: "one concise private profile summary"
            }
          })
        }
      ],
      text: {
        format: {
          type: "json_object"
        }
      }
    })
  });

  const body = await response.json();
  if (!response.ok) throw new Error(body.error?.message || "openai_profile_placement_failed");
  const modelResult = parseModelJson(body);
  const { profile, placement } = profilePlacementFromModelResult({ modelResult, interviewTranscript, reflectionAnswers });
  return {
    profile,
    placement,
    allCircleFits: CIRCLE_ARCHETYPES.map((circle) => ({
      circleId: circle.id,
      name: circle.name,
      score: circle.id === placement.primaryCircle.id ? 1 : 0
    })),
    synthesisMode: "model_backed"
  };
}

module.exports = {
  modelBackedProfilePlacement,
  fallbackProfilePlacement,
  profilePlacementFromModelResult
};
