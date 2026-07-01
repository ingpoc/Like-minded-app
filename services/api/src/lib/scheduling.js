const crypto = require("node:crypto");

function nextWeekendAt(day, hour = 19) {
  const now = new Date();
  const result = new Date(now);
  const daysUntil = (day - now.getDay() + 7) % 7 || 7;
  result.setDate(now.getDate() + daysUntil);
  result.setHours(hour, 0, 0, 0);
  return result.toISOString();
}

function shuffleStable(items, seed) {
  return [...items].sort((a, b) => {
    const left = crypto.createHash("sha256").update(`${seed}:${a.userId}`).digest("hex");
    const right = crypto.createHash("sha256").update(`${seed}:${b.userId}`).digest("hex");
    return left.localeCompare(right);
  });
}

function genderBalancedGroups(participants, size = 10, minRemainder = 6) {
  const male = participants.filter((item) => item.profile?.basicInfo?.gender === "male");
  const female = participants.filter((item) => item.profile?.basicInfo?.gender === "female");
  const other = participants.filter((item) => !["male", "female"].includes(item.profile?.basicInfo?.gender));
  const ordered = [];
  while (male.length || female.length || other.length) {
    for (let i = 0; i < 5 && male.length; i += 1) ordered.push(male.shift());
    for (let i = 0; i < 5 && female.length; i += 1) ordered.push(female.shift());
    if (ordered.length % size === 0 && (male.length || female.length)) continue;
    while (other.length && ordered.length % size !== 0) ordered.push(other.shift());
    if (!male.length && !female.length) ordered.push(...other.splice(0));
  }
  const groups = [];
  for (let index = 0; index < ordered.length; index += size) {
    const group = ordered.slice(index, index + size);
    if (group.length === size || group.length >= minRemainder) groups.push(group);
  }
  return groups;
}

function dominanceLow(signals = {}) {
  return signals.communicationStyle?.primary !== "direct" && signals.conflictStyle !== "engaging";
}

function scoreCircleHost(profile = {}) {
  const signals = profile.signals || {};
  const bigFive = signals.bigFive || {};
  let score = 0;
  if (["high", "medium"].includes(signals.socialEnergy)) score += 1;
  if (["warm", "expressive"].includes(signals.communicationStyle?.primary)) score += 1;
  if ((bigFive.agreeableness || 0) > 0.6) score += 1;
  if ((bigFive.extraversion || 0) > 0.6) score += 1;
  if ((bigFive.neuroticism || 1) < 0.6) score += 1;
  if (dominanceLow(signals)) score += 1;
  if (signals.trustPattern === "fastTrust") score += 1;
  return score + ((profile.meetupsAttended || 0) / 100);
}

function scoreCommunityHost(profile = {}) {
  const signals = profile.signals || {};
  const bigFive = signals.bigFive || {};
  let score = 0;
  if ((bigFive.openness || 0) > 0.7) score += 1;
  if ((bigFive.agreeableness || 0) > 0.6) score += 1;
  if ((bigFive.extraversion || 0) >= 0.4 && (bigFive.extraversion || 0) <= 0.8) score += 1;
  if (signals.communicationStyle?.primary === "warm") score += 1;
  if ((bigFive.neuroticism || 1) < 0.5) score += 1;
  if (["high", "medium"].includes(signals.socialEnergy)) score += 1;
  if (dominanceLow(signals)) score += 1;
  return score + ((profile.meetupsAttended || 0) / 100);
}

function pickHost(group, scorer) {
  return [...group].sort((a, b) => scorer(b.profile) - scorer(a.profile))[0];
}

function buildMeetings({ kind, targetId, targetName, participants, scheduledAt }) {
  const scorer = kind === "circle" ? scoreCircleHost : scoreCommunityHost;
  return genderBalancedGroups(shuffleStable(participants, `${kind}:${targetId}`)).map((group, index) => {
    const host = pickHost(group, scorer);
    const id = `mtg_${kind}_${targetId}_${scheduledAt.slice(0, 10)}_${index + 1}`;
    return {
      id,
      kind,
      targetId,
      title: targetName,
      scheduledAt,
      hostUserId: host.userId,
      hostName: host.profile?.basicInfo?.name || "Host",
      participantIds: group.map((item) => item.userId),
      groupSize: group.length,
      status: "upcoming",
      compositionSummary: summarizeGroup(kind, group)
    };
  });
}

function summarizeGroup(kind, group) {
  if (kind === "circle") return `${group.length} people. You share slow-trust patterns and analytical communication.`;
  const counts = group.reduce((acc, item) => {
    const energy = item.profile?.signals?.socialEnergy;
    if (energy === "high") acc.extroverts += 1;
    else acc.introverts += 1;
    return acc;
  }, { extroverts: 0, introverts: 0 });
  return `${group.length} people from nearby circles. ${counts.extroverts} extroverts, ${counts.introverts} introverts.`;
}

module.exports = {
  nextWeekendAt,
  buildMeetings,
  scoreCircleHost,
  scoreCommunityHost,
  genderBalancedGroups
};
