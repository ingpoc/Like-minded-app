const { DBMap, getDb } = require("./db");

const architecture = {
  principle: "AI interprets, backend controls, database persists.",
  mainComponents: [
    "swiftui-app",
    "backend-api",
    "realtime-session-broker",
    "backend-tool-gateway",
    "ai-orchestration-layer",
    "matching-engine",
    "community-engine",
    "chat-service",
    "safety-and-moderation-service",
    "subscription-and-entitlement-service"
  ],
  mvpJourneys: [
    "sign-in-and-onboarding",
    "voice-or-text-profiling",
    "editable-ai-reflection",
    "community-recommendation",
    "match-recommendation",
    "consent-based-chat",
    "safety-controls"
  ],
  aiLayers: [
    {
      id: "realtime-voice-model",
      model: "gpt-realtime-2",
      transport: "webrtc",
      responsibilities: [
        "live speech turns",
        "interruptions",
        "conversational onboarding",
        "tool calling"
      ]
    },
    {
      id: "reasoning-model",
      responsibilities: [
        "profile synthesis",
        "compatibility analysis",
        "community fit reasoning",
        "nuanced safety review"
      ]
    },
    {
      id: "fast-models-and-embeddings",
      responsibilities: [
        "extraction",
        "classification",
        "semantic similarity",
        "clustering"
      ]
    }
  ],
  toolPolicy: {
    readOnly: "allowed-without-confirmation",
    lowRiskWrites: "allowed-when-intent-is-clear",
    highRiskWrites: "require-explicit-confirmation"
  }
};

// ---------------------------------------------------------------------------
// Personality framework
// ---------------------------------------------------------------------------

const PERSONALITY_DIMENSIONS = {
  bigFive: {
    openness: { low: "practical, routine-oriented", high: "curious, imaginative, exploratory" },
    conscientiousness: { low: "flexible, spontaneous", high: "organized, deliberate, plan-driven" },
    extraversion: { low: "reserved, reflective, recharges alone", high: "energetic, sociable, recharges with people" },
    agreeableness: { low: "direct, challenging, independent", high: "warm, cooperative, harmony-seeking" },
    neuroticism: { low: "steady, calm under pressure", high: "sensitive, emotionally reactive, depth-feeling" }
  },
  attachment: {
    secure: "comfortable with intimacy and independence, communicates needs clearly",
    anxious: "craves closeness, worries about rejection, expresses emotions intensely",
    avoidant: "values independence, uncomfortable with deep emotional disclosure", 
    disorganized: "mixed signals, wants closeness but fears it, unpredictable emotional responses"
  },
  socialEnergy: {
    high: "gains energy from groups, enjoys frequent interaction, broad social circle",
    medium: "enjoys social time but needs recovery, selective about company",
    low: "prefers one-on-one or small groups, needs significant alone time to recharge"
  },
  communicationStyle: {
    direct: "says what they mean, values clarity over diplomacy, comfortable with disagreement",
    warm: "leads with empathy, softens hard truths, builds rapport before business",
    analytical: "leads with logic, needs data before feelings, thinks before speaking",
    expressive: "shares freely, processes out loud, emotions visible in conversation"
  },
  trustPattern: {
    fastTrust: "opens up quickly, gives benefit of the doubt, comfortable with vulnerability",
    slowTrust: "observes before opening, earns trust through consistency, guarded until proven",
    conditionalTrust: "trusts in specific contexts, compartmentalizes relationships"
  },
  humorStyle: {
    witty: "quick wordplay, enjoys banter, humor as social currency",
    warm: "gentle humor, avoids at others' expense, laughter as connection",
    observational: "finds absurdity in everyday, dry wit, notices what others miss",
    physical: "expressive, animated, humor through timing and delivery",
    absent: "takes things literally, prefers straightforward communication"
  },
  conflictStyle: {
    engaging: "addresses issues directly, comfortable with tension, wants to resolve quickly",
    accommodating: "prioritizes harmony, yields to preserve relationship, processes later",
    avoiding: "withdraws from conflict, needs time to process, re-engages when ready",
    analytical: "steps back to analyze, seeks root cause, resolves through understanding"
  }
};

const CIRCLE_ARCHETYPES = [
  {
    id: "reflective-builders",
    name: "Reflective Builders",
    personalityProfile: {
      openness: [0.7, 1.0],
      conscientiousness: [0.6, 1.0],
      extraversion: [0.3, 0.6],
      agreeableness: [0.6, 0.9],
      neuroticism: [0.3, 0.6],
      attachmentPreferences: ["secure", "avoidant"],
    },
    socialEnergy: ["medium", "low"],
    communicationStyles: ["analytical", "direct"],
    trustPatterns: ["slowTrust", "conditionalTrust"],
    description: "A small circle for people who build ambitious things without emotional shortcuts. Thoughtful, honest feedback, deep work.",
    roomEnergy: "Warm, thoughtful, honest feedback without performance.",
    interactionIntent: "Creative collaboration",
    socialFormat: "Micro-circle of 4-6",
    themes: ["Founders", "Meaningful work", "Honest feedback"],
    meetingFormat: "Weekly structured check-ins with rotating facilitator"
  },
  {
    id: "gentle-romantics",
    name: "Gentle Romantics",
    personalityProfile: {
      openness: [0.7, 1.0],
      conscientiousness: [0.3, 0.7],
      extraversion: [0.3, 0.7],
      agreeableness: [0.7, 1.0],
      neuroticism: [0.5, 0.8],
      attachmentPreferences: ["anxious", "secure"],
    },
    socialEnergy: ["medium", "low"],
    communicationStyles: ["warm", "expressive"],
    trustPatterns: ["fastTrust", "conditionalTrust"],
    description: "A consent-forward room for people exploring intimacy without rush. Emotionally brave, tender, fiercely caring.",
    roomEnergy: "Soft, deliberate, and emotionally careful.",
    interactionIntent: "Romantic exploration",
    socialFormat: "1:1 intros with shared reflection",
    themes: ["Compatibility", "Rituals", "Care"],
    meetingFormat: "One deep conversation at a time, no pressure to perform"
  },
  {
    id: "longform-thinkers",
    name: "Longform Thinkers",
    personalityProfile: {
      openness: [0.8, 1.0],
      conscientiousness: [0.5, 0.8],
      extraversion: [0.2, 0.5],
      agreeableness: [0.5, 0.8],
      neuroticism: [0.3, 0.7],
      attachmentPreferences: ["secure", "avoidant"],
    },
    socialEnergy: ["low"],
    communicationStyles: ["analytical", "expressive"],
    trustPatterns: ["slowTrust"],
    description: "Bookish, introspective people who prefer layered conversation to slow trust.",
    roomEnergy: "Patient, bookish, and quietly expansive.",
    interactionIntent: "Intellectual companionship",
    socialFormat: "Recurring salon",
    themes: ["Essays", "Psychology", "Slow living"],
    meetingFormat: "Weekly reading-sharing with guided discussion"
  },
  {
    id: "bold-explorers",
    name: "Bold Explorers",
    personalityProfile: {
      openness: [0.8, 1.0],
      conscientiousness: [0.3, 0.6],
      extraversion: [0.7, 1.0],
      agreeableness: [0.4, 0.7],
      neuroticism: [0.3, 0.5],
      attachmentPreferences: ["secure", "fastTrust"],
    },
    socialEnergy: ["high"],
    communicationStyles: ["direct", "expressive"],
    trustPatterns: ["fastTrust"],
    description: "For people who want to try things, not just talk about trying things. High energy, low pretense.",
    roomEnergy: "Energetic, irreverent, action-oriented.",
    interactionIntent: "Adventure and shared experience",
    socialFormat: "Small group hangouts",
    themes: ["Travel", "Trying new things", "Spontaneous plans"],
    meetingFormat: "Monthly in-person meetups with optional mid-week chats"
  },
  {
    id: "grounded-nurturers",
    name: "Grounded Nurturers",
    personalityProfile: {
      openness: [0.4, 0.7],
      conscientiousness: [0.6, 0.9],
      extraversion: [0.3, 0.6],
      agreeableness: [0.8, 1.0],
      neuroticism: [0.2, 0.5],
      attachmentPreferences: ["secure"],
    },
    socialEnergy: ["medium"],
    communicationStyles: ["warm", "analytical"],
    trustPatterns: ["slowTrust", "conditionalTrust"],
    description: "For people who show up consistently, hold space for others, and believe in steady presence over grand gestures.",
    roomEnergy: "Steady, supportive, quietly joyful.",
    interactionIntent: "Mutual support and presence",
    socialFormat: "Small consistent circle",
    themes: ["Parenting", "Care work", "Steady presence"],
    meetingFormat: "Weekly circle sharing with rotating host"
  }
];

// ---------------------------------------------------------------------------
// In-memory stores
// ---------------------------------------------------------------------------
// Persistent stores (local JSON-backed, survive server restarts)
const profiles = new DBMap("profiles", getDb());
const circles = new DBMap("circles", getDb());

// Seed initial circles from archetypes (only if DB is empty)
function seedCircles() {
  if (circles.size > 0) return; // already seeded
  const txn = getDb().transaction(() => {
    for (const archetype of CIRCLE_ARCHETYPES) {
      circles.set(archetype.id, {
        ...archetype,
        members: [],
        createdAt: new Date().toISOString(),
        isArchetype: true,
      });
    }
  });
  txn();
}
seedCircles();

// ---------------------------------------------------------------------------
// Profile synthesis
// ---------------------------------------------------------------------------

function generateId() {
  return `profile-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

function buildProfileFromInterview(interviewTranscript, reflectionAnswers = []) {
  const combinedInput = [
    ...reflectionAnswers,
    interviewTranscript
  ].filter(Boolean).join("\n");

  // Extract personality signals from the combined input
  const signals = extractPersonalitySignals(combinedInput);

  return {
    profileId: generateId(),
    signals,
    sourceInput: {
      reflectionAnswers,
      interviewExcerpt: interviewTranscript.slice(0, 500)
    },
    synthesizedAt: new Date().toISOString()
  };
}

function extractPersonalitySignals(text) {
  const lower = text.toLowerCase();

  const signals = {
    bigFive: {
      openness: inferDimension(lower, ["curious", "creative", "imagine", "explore", "new ideas", "abstract", "art", "books", "learning", "wonder", "possibility"], ["routine", "practical", "concrete", "traditional", "proven", "established", "familiar"]),
      conscientiousness: inferDimension(lower, ["organized", "plan", "discipline", "reliable", "responsible", "deadline", "structure", "goal", "commitment", "follow-through"], ["spontaneous", "flexible", "wing it", "go with the flow", "unplanned", "casual"]),
      extraversion: inferDimension(lower, ["people", "social", "energy", "outgoing", "group", "party", "talk", "meet", "connect", "crowd", "lively"], ["quiet", "alone", "solitude", "recharge", "small group", "one-on-one", "introspective", "reflective"]),
      agreeableness: inferDimension(lower, ["harmony", "cooperate", "care", "empathy", "kind", "help", "support", "understand", "gentle", "warm", "considerate"], ["direct", "challenge", "compete", "independent", "blunt", "honest", "critical", "disagree"]),
      neuroticism: inferDimension(lower, ["feel deeply", "sensitive", "worry", "anxious", "intense", "emotional", "reactive", "stress", "overwhelm", "passion"], ["steady", "calm", "stable", "even", "unflappable", "relaxed", "easy-going", "chill"])
    },
    attachment: inferCategory(lower, {
      secure: ["comfortable", "open", "trust", "independent", "balanced", "secure"],
      anxious: ["worry", "cling", "need reassurance", "fear rejection", "crave closeness", "anxious"],
      avoidant: ["space", "independence", "self-sufficient", "don't need", "prefers alone", "guarded"],
      disorganized: ["confused", "mixed", "push-pull", "hot-cold", "unpredictable"]
    }),
    socialEnergy: inferCategory(lower, {
      high: ["people energize", "love crowds", "social butterfly", "group energy", "being around people"],
      medium: ["some alone time", "selective", "balanced", "sometimes social", "depends on mood"],
      low: ["recharge alone", "one-on-one", "small group", "solitude", "quiet time", "introvert", "reserved"]
    }),
    communicationStyle: {
      primary: inferCategory(lower, {
        direct: ["direct", "straightforward", "say what I mean", "blunt", "honest", "no filter", "clear"],
        warm: ["warm", "empathy", "feelings", "connection", "gentle", "soft", "caring", "kind"],
        analytical: ["think", "logic", "analyze", "reason", "data", "understand", "figure out", "process"],
        expressive: ["share", "open", "talk through", "process out loud", "express", "vulnerable"]
      }),
      pace: inferDimension(lower, ["fast", "quick", "rapid", "immediate", "instant", "now"], ["slow", "thoughtful", "reflective", "take time", "consider", "pause", "deliberate"])
    },
    trustPattern: inferCategory(lower, {
      fastTrust: ["trust quickly", "give chance", "open up", "fast friends", "gut feeling", "instinct"],
      slowTrust: ["take time", "earn trust", "observe", "cautious", "guarded", "prove", "consistency"],
      conditionalTrust: ["depends", "context", "certain people", "some areas", "compartmentalize"]
    }),
    humorStyle: inferCategory(lower, {
      witty: ["witty", "wordplay", "clever", "quick", "banter", "puns", "sarcasm"],
      warm: ["gentle humor", "kind jokes", "warm", "light", "playful", "sweet"],
      observational: ["notice", "observe", "dry", "subtle", "deadpan", "absurd", "ironic"],
      physical: ["animated", "expressive", "timing", "physical", "gestures", "faces"],
      absent: ["literal", "don't get jokes", "serious", "straight", "humor not"]
    }),
    conflictStyle: inferCategory(lower, {
      engaging: ["address directly", "confront", "talk it out", "face it", "immediate", "resolve"],
      accommodating: ["yield", "harmony", "peace", "avoid conflict", "give in", "okay with"],
      avoiding: ["withdraw", "timeout", "space", "later", "not now", "need time"],
      analytical: ["analyze", "understand", "root cause", "logic", "figure out", "why"]
    })
  };

  return signals;
}

function inferDimension(text, highKeywords, lowKeywords) {
  let score = 0.5;
  for (const kw of highKeywords) {
    if (text.includes(kw)) score += 0.08;
  }
  for (const kw of lowKeywords) {
    if (text.includes(kw)) score -= 0.08;
  }
  return Math.max(0, Math.min(1, score));
}

function inferCategory(text, categories) {
  const scores = {};
  for (const [category, keywords] of Object.entries(categories)) {
    scores[category] = keywords.filter(kw => text.includes(kw)).length;
  }
  const best = Object.entries(scores).sort((a, b) => b[1] - a[1])[0];
  return best && best[1] > 0 ? best[0] : null;
}

// ---------------------------------------------------------------------------
// Circle matching
// ---------------------------------------------------------------------------

function computeCircleFit(profileSignals, circle) {
  const scores = [];

  // Big Five fit (each dimension scored 0-1)
  for (const dim of Object.keys(profileSignals.bigFive)) {
    const signal = profileSignals.bigFive[dim];
    const range = circle.personalityProfile[dim];
    if (range) {
      const [min, max] = range;
      scores.push(signal >= min && signal <= max ? 1.0 : Math.max(0, 1 - Math.min(Math.abs(signal - min), Math.abs(signal - max)) * 2));
    }
  }

  // Attachment preference fit
  const attachPref = circle.personalityProfile.attachmentPreferences;
  if (attachPref && profileSignals.attachment) {
    scores.push(attachPref.includes(profileSignals.attachment) ? 1.0 : 0.3);
  }

  // Social energy fit
  if (circle.socialEnergy && profileSignals.socialEnergy) {
    scores.push(circle.socialEnergy.includes(profileSignals.socialEnergy) ? 1.0 : 0.5);
  }

  // Communication style fit
  if (circle.communicationStyles && profileSignals.communicationStyle?.primary) {
    scores.push(circle.communicationStyles.includes(profileSignals.communicationStyle.primary) ? 1.0 : 0.4);
  }

  // Trust pattern fit
  if (circle.trustPatterns && profileSignals.trustPattern) {
    scores.push(circle.trustPatterns.includes(profileSignals.trustPattern) ? 1.0 : 0.4);
  }

  return scores.length > 0 ? scores.reduce((a, b) => a + b, 0) / scores.length : 0.5;
}

function matchCircles(profileSignals) {
  const fits = [];
  for (const [circleId, circle] of circles.entries()) {
    const score = computeCircleFit(profileSignals, circle);
    fits.push({ circle, score });
  }
  fits.sort((a, b) => b.score - a.score);
  return fits;
}

function shouldCreateNewCircle(profileSignals, fits) {
  const bestFit = fits[0];
  // If best fit is below threshold and no circle matches well enough
  if (!bestFit || bestFit.score < 0.55) return true;
  // If the best fit circle is getting large, suggest new
  const circleData = circles.get(bestFit.circle.id);
  if (circleData && circleData.members.length >= 12) return true;
  return false;
}

function generateCircleName(signals) {
  const descriptors = [];
  if (signals.bigFive?.openness > 0.7) descriptors.push("Curious");
  if (signals.bigFive?.conscientiousness > 0.6) descriptors.push("Steady");
  if (signals.socialEnergy === "low") descriptors.push("Deep");
  if (signals.communicationStyle?.primary === "warm") descriptors.push("Warm");
  if (signals.communicationStyle?.primary === "analytical") descriptors.push("Clear");
  if (signals.trustPattern === "slowTrust") descriptors.push("Patient");

  if (descriptors.length < 2) descriptors.push("Authentic", "Present");

  const noun = pick(["Circles", "Rooms", "Tables", "Salons", "Gardens"]);
  return `${descriptors.slice(0, 3).join(" ")} ${noun}`;
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function createCircleFromProfile(profileSignals) {
  const name = generateCircleName(profileSignals);
  const id = `circle-${Date.now().toString(36)}`;

  const newCircle = {
    id,
    name,
    personalityProfile: {
      openness: [Math.max(0, profileSignals.bigFive.openness - 0.2), Math.min(1, profileSignals.bigFive.openness + 0.2)],
      conscientiousness: [Math.max(0, profileSignals.bigFive.conscientiousness - 0.2), Math.min(1, profileSignals.bigFive.conscientiousness + 0.2)],
      extraversion: [Math.max(0, profileSignals.bigFive.extraversion - 0.2), Math.min(1, profileSignals.bigFive.extraversion + 0.2)],
      agreeableness: [Math.max(0, profileSignals.bigFive.agreeableness - 0.2), Math.min(1, profileSignals.bigFive.agreeableness + 0.2)],
      neuroticism: [Math.max(0, profileSignals.bigFive.neuroticism - 0.2), Math.min(1, profileSignals.bigFive.neuroticism + 0.2)],
      attachmentPreferences: profileSignals.attachment ? [profileSignals.attachment, "secure"] : ["secure"],
    },
    socialEnergy: profileSignals.socialEnergy ? [profileSignals.socialEnergy, "medium"] : ["medium"],
    communicationStyles: profileSignals.communicationStyle?.primary ? [profileSignals.communicationStyle.primary, "warm"] : ["warm"],
    trustPatterns: profileSignals.trustPattern ? [profileSignals.trustPattern, "conditionalTrust"] : ["conditionalTrust"],
    description: `A new circle for ${profileSignals.communicationStyle?.primary || "authentic"} communicators with ${profileSignals.socialEnergy || "balanced"} social energy.`,
    roomEnergy: pick(["Warm and exploratory", "Calm and curious", "Steady and open", "Reflective and real"]),
    interactionIntent: "New connections with similar personality patterns",
    socialFormat: "Small circle of 3-6",
    themes: deriveThemes(profileSignals),
    meetingFormat: "Weekly with rotating host, starting with guided introductions",
    members: [],
    createdAt: new Date().toISOString(),
    isArchetype: false,
    createdFromProfile: true
  };

  circles.set(id, newCircle);
  return newCircle;
}

function deriveThemes(signals) {
  const themes = [];
  if (signals.bigFive?.openness > 0.7) themes.push("Ideas", "Exploration");
  if (signals.bigFive?.conscientiousness > 0.6) themes.push("Growth", "Craft");
  if (signals.socialEnergy === "low") themes.push("Depth", "Presence");
  if (signals.socialEnergy === "high") themes.push("Energy", "Adventure");
  if (signals.communicationStyle?.primary === "warm") themes.push("Care", "Connection");
  if (signals.communicationStyle?.primary === "analytical") themes.push("Truth", "Clarity");
  if (themes.length < 2) themes.push("Authenticity", "Understanding");
  return themes.slice(0, 3);
}

// ---------------------------------------------------------------------------
// Placement
// ---------------------------------------------------------------------------

function buildPlacement(profile) {
  const fits = matchCircles(profile.signals);
  const createNew = shouldCreateNewCircle(profile.signals, fits);

  let primaryCircle;
  let placementReason;
  let confidenceLabel;

  if (createNew) {
    primaryCircle = createCircleFromProfile(profile.signals);
    placementReason = `Your personality pattern doesn't strongly match existing circles. We created "${primaryCircle.name}" for people with your combination of ${profile.signals.communicationStyle?.primary || "authentic"} communication and ${profile.signals.socialEnergy || "balanced"} social energy.`;
    confidenceLabel = "New circle — you're the first match";
  } else {
    primaryCircle = fits[0].circle;
    const fitScore = fits[0].score;
    confidenceLabel = fitScore > 0.7 ? "High fit" : fitScore > 0.55 ? "Good fit" : "Exploring fit";
    placementReason = `Your personality signals — especially your ${profile.signals.communicationStyle?.primary || "balanced"} communication style and ${profile.signals.socialEnergy || "steady"} energy — align well with this circle's pattern.`;
  }

  // Find secondary circles
  const secondaryCircles = fits.slice(1, 4).filter(f => f.score > 0.4).map(f => f.circle);

  // Add profile to circle members and persist
  const circleData = circles.get(primaryCircle.id);
  if (circleData) {
    circleData.members.push(profile.profileId);
    circles.set(primaryCircle.id, circleData); // persist mutation
  }

  return {
    rule: "auto-place-user-confirm",
    confidenceLabel,
    fitReasons: generateFitReasons(profile.signals, primaryCircle),
    sourceReflectionSignals: Object.entries(profile.signals.bigFive).map(([dim, val]) => `${dim}: ${val > 0.6 ? "high" : val < 0.4 ? "low" : "balanced"}`),
    primaryCircle,
    secondaryCircles,
    userState: "proposed",
    actions: {
      primaryAction: "Accept this circle",
      swapAction: "Try another circle",
      deferAction: "Defer for now"
    },
    isNewCircle: createNew
  };
}

function generateFitReasons(signals, circle) {
  const reasons = [];
  if (circle.communicationStyles?.includes(signals.communicationStyle?.primary)) {
    reasons.push(`Your ${signals.communicationStyle.primary} communication style matches this circle.`);
  }
  if (circle.socialEnergy?.includes(signals.socialEnergy)) {
    reasons.push(`Your ${signals.socialEnergy} social energy fits the circle's pace.`);
  }
  if (circle.trustPatterns?.includes(signals.trustPattern)) {
    reasons.push(`Your ${signals.trustPattern.replace("Trust", " trust")} pattern aligns with how this circle builds connection.`);
  }
  if (reasons.length === 0) {
    reasons.push("Your personality pattern shows interesting compatibility with this circle's dynamic.");
  }
  return reasons;
}

module.exports = {
  architecture,
  PERSONALITY_DIMENSIONS,
  CIRCLE_ARCHETYPES,
  profiles,
  circles,
  buildProfileFromInterview,
  matchCircles,
  shouldCreateNewCircle,
  createCircleFromProfile,
  buildPlacement,
  seedCircles,
  generateId
};
