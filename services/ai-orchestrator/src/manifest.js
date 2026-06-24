const orchestratorManifest = {
  service: "likeminded-ai-orchestrator",
  version: "0.1.0",
  boundaries: [
    "broker-realtime-sessions-through-backend",
    "route-tool-calls-to-backend-authority",
    "prepare-profile-synthesis",
    "separate-safety-judgment-from-irreversible-writes"
  ],
  modelLayers: [
    "realtime-voice-model",
    "reasoning-model",
    "fast-models-and-embeddings"
  ],
  currentMode: "placeholder-with-contracts"
};

module.exports = {
  orchestratorManifest
};
