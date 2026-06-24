# Infrastructure

Infrastructure is intentionally not provisioned in the project spine.

## Expected Future Pieces

- PostgreSQL with pgvector for profiles and semantic matching.
- Backend runtime for deterministic APIs and tool gateway.
- Secret storage for OpenAI and auth provider credentials.
- Environment-specific configuration for local, staging, and production.

## Current Local Contract

- API defaults to `127.0.0.1:8787`.
- No secrets are required.
- No external network calls are made by the skeleton.
