# AGENTS.md

This file is the **single** place for AI coding assistants and other automated agents working in this repository. It is intentionally tool-agnostic (no vendor-specific duplicate instruction files).

## Essential Reading

Before working on this codebase, read:

- `README.md` — Project overview, architecture, and development commands
- `PLAN.md` — Implementation plan with phases and testing criteria for each sub-phase
- `architecture.md` — System architecture and design decisions

## Development Workflow

This project follows a phased implementation approach. Each phase must be completed and tested before moving to the next:

1. **Phase 1**: Project Setup & Infrastructure
2. **Phase 2**: Backend Services Development
3. **Phase 3**: Frontend Development
4. **Phase 4**: Testing
5. **Phase 5**: Observability & Monitoring
6. **Phase 6**: Containerization
7. **Phase 7**: Kubernetes Deployment
8. **Phase 8**: Documentation & Maintenance

## Key Commands Reference

**Start development environment**: `docker-compose up -d`  
**Build service**: `./mvnw clean package` (from service directory)  
**Run tests**: `./mvnw test` (backend) or `npm test` (frontend)  
**Database migrations**: `./mvnw flyway:migrate`

## Implementation Guidelines

- Always implement testing criteria for each sub-phase before proceeding
- All services except user-service must implement JWT validation middleware
- Use OpenTelemetry instrumentation in all Java services
- Maintain >80% test coverage for all services
- Follow atomic transaction patterns in transactions-service
- Store JWT tokens in HttpOnly cookies on frontend

## Version Bump Policy

The project uses a two-tier versioning model:

**Global version** — stored in the root `VERSION` file (e.g. `1.4.1`). This is the canonical source of truth for Docker image tags and all non-Java package versions.

**Per-service version** — each Java backend service tracks its own `<version>` in `backend/<service>/pom.xml`.

### Rules for agents and developers

| File | Who bumps it? | When? |
|------|--------------|-------|
| `backend/<service>/pom.xml` | Agent / developer | Required in any PR that modifies code under `backend/<service>/` |
| `VERSION` | Agent / developer | When a global release version change is needed (e.g. a minor or major bump) |
| `frontend/package.json` | **CI only — do not touch** | Auto-synced from `VERSION` on every merge to `master` |
| `simulation-client/package.json` | **CI only — do not touch** | Auto-synced from `VERSION` on every merge to `master` |
| `kubernetes/base/deployments/*.yaml` | **CI only — do not touch** | Auto-updated from `VERSION` on every merge to `master` |

### How CI handles versioning (on merge to `master`)

The `update-k8s-manifests` CI job runs `make update-frontend-version` followed by `make update-k8s-version` and commits any resulting changes back to the branch. This is implemented via:

- `scripts/version.sh update-frontend` — syncs `frontend/package.json` and `simulation-client/package.json` to `VERSION`
- `scripts/version.sh update-k8s` — updates image tags in `kubernetes/base/deployments/`

**Do NOT manually bump `frontend/package.json` or `simulation-client/package.json`.** Doing so creates merge conflicts across concurrent branches because multiple agents will all bump from the same base version independently. Let CI handle it.

Docs-only or infra-only changes can skip a `pom.xml` version bump. CI is the final enforcement gate.

## Current Status

Check `PLAN.md` for the current implementation phase and specific tasks. Each sub-phase includes both implementation tasks and testing requirements that must be completed.
