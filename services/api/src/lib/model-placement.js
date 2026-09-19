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

function normalizeInterests(value) {
  if (!Array.isArray(value)) return [];
  return value
    .slice(0, 10)
    .map((item) => {
      if (typeof item === "string") return { area: "general", label: item, depth: "active" };
      if (!item || typeof item !== "object" || typeof item.label !== "string") return null;
      return {
        area: typeof item.area === "string" && item.area.trim() ? item.area.trim() : "general",
        label: item.label.trim(),
        depth: ["casual", "active", "deep"].includes(item.depth) ? item.depth : "active"
      };
    })
    .filter((item) => item && item.label);
}

function normalizeHiddenSignals(value) {
  if (!value || typeof value !== "object") return null;
  return {
    shyness: value.shyness == null ? null : clamp01(value.shyness),
    languageComfort: typeof value.languageComfort === "string" ? value.languageComfort : null,
    warmth: value.warmth == null ? null : clamp01(value.warmth),
    vulnerabilityOpenness: value.vulnerabilityOpenness == null ? null : clamp01(value.vulnerabilityOpenness),
    dominanceTendency: value.dominanceTendency == null ? null : clamp01(value.dominanceTendency),
    energyTrajectory: typeof value.energyTrajectory === "string" ? value.energyTrajectory : null
  };
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
    selectedSecondaryCircleId: null,
    userState: "proposed",
    actions: {
      primaryAction: "Accept this circle",
      secondaryAction: "Make this my second circle",
      deferAction: "Defer for now"
    },
    isNewCircle: false
  };
}

function profilePlacementFromModelResult({ modelResult, interviewTranscript = "", reflectionAnswers = [] }) {
  const profile = {
    profileId: generateId(),
    signals: normalizeSignals(modelResult.signals),
    basicInfo: modelResult.basicInfo && typeof modelResult.basicInfo === "object" ? modelResult.basicInfo : null,
    interests: normalizeInterests(modelResult.interests),
    hiddenSignals: normalizeHiddenSignals(modelResult.hiddenSignals),
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
              profileSummary: "one concise private profile summary",
              interests: "array of { area, label, depth: casual|active|deep }",
              hiddenSignals: "private placement-only fields: shyness, languageComfort, warmth, vulnerabilityOpenness, dominanceTendency, energyTrajectory"
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

function fallbackInterviewTurn(messages = []) {
  const answerCount = messages.filter((message) => message?.role === "user").length;
  const prompts = [
    "What has felt most energizing in your social life lately?",
    "When you meet someone new, what helps you feel comfortable enough to open up?",
    "What kinds of conversations or shared activities make you lose track of time?"
  ];
  return {
    assistantMessage: prompts[Math.min(answerCount, prompts.length - 1)],
    readyToComplete: answerCount >= prompts.length,
    synthesisMode: "deterministic_fallback"
  };
}

async function modelBackedInterviewTurn({ messages = [] }) {
  const safeMessages = Array.isArray(messages)
    ? messages.slice(-12).filter((message) =>
      message && ["assistant", "user"].includes(message.role) && typeof message.content === "string"
    ).map((message) => ({ role: message.role, content: message.content.trim().slice(0, 1200) }))
    : [];
  if (!process.env.OPENAI_API_KEY) return fallbackInterviewTurn(safeMessages);

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
          content: "You are the private Likeminded social-profile interviewer. Ask exactly one short, warm follow-up at a time. Use the whole conversation, not keywords. Learn social energy, trust pace, communication style, conflict style, interests, and what kind of room helps this person connect. Do not expose psychological labels. Set readyToComplete after at least three meaningful user answers cover enough evidence for placement, and always after five meaningful answers. Return only valid JSON."
        },
        {
          role: "user",
          content: JSON.stringify({
            conversation: safeMessages,
            outputContract: {
              assistantMessage: "one concise empathetic question or, when complete, a short completion acknowledgement",
              readyToComplete: "boolean"
            }
          })
        }
      ],
      text: { format: { type: "json_object" } }
    })
  });
  const body = await response.json();
  if (!response.ok) throw new Error(body.error?.message || "openai_profile_interview_failed");
  const result = parseModelJson(body);
  const userAnswerCount = safeMessages.filter((message) => message.role === "user").length;
  const mustComplete = userAnswerCount >= 5;
  return {
    assistantMessage: mustComplete
      ? "Thank you — I have enough to build your private profile and place you thoughtfully."
      : typeof result.assistantMessage === "string" && result.assistantMessage.trim()
      ? result.assistantMessage.trim()
      : "Tell me a little more about what helps you feel at ease with new people.",
    readyToComplete: mustComplete || (userAnswerCount >= 3 && Boolean(result.readyToComplete)),
    synthesisMode: "model_backed"
  };
}

module.exports = {
  modelBackedInterviewTurn,
  modelBackedProfilePlacement,
  fallbackProfilePlacement,
  profilePlacementFromModelResult
};
