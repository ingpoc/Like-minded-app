# Project Spine

Likeminded is split into explicit implementation surfaces so product, AI, safety, and infrastructure decisions can evolve without being hidden in one app layer.

## Surfaces

- Native app: SwiftUI shell for iOS/macOS user workflows.
- API service: deterministic authority for allowed actions, persistence, auth, and moderation.
- AI orchestrator: boundary for realtime session brokering, tool-call routing, and deep profile synthesis.
- Shared schemas: durable profile and matching contracts.
- Infra: deployment, database, secrets, and environment contracts.

## Operating Rule

Realtime AI talks with the user and supports in-app meetings. Reasoning models synthesize profiles, circle fit, community fit, host fit, and group chemistry. The backend validates permissions and writes durable state. The database remembers.

## Open Decision

The MVP backend framework remains open. The current API uses Node's built-in HTTP server only to make the health endpoint runnable without committing to a framework.
