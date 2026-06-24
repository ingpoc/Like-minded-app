# AI Orchestrator

Placeholder service boundary for AI-specific workflows.

## Intended Responsibilities

- Request and broker OpenAI Realtime voice sessions through the backend using `gpt-realtime-2`.
- Route AI tool calls to backend-owned deterministic tools.
- Prepare profile synthesis requests for a reasoning model.
- Keep safety reasoning auditable and separate from irreversible backend actions.

## Current Status

The API service now owns realtime client-secret creation for `gpt-realtime-2`. The orchestrator executable still prints an architecture manifest and does not hold secrets or call models directly.
