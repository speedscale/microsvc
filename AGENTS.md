# AGENTS.md

This file provides guidance for AI coding assistants and other automated agents working in this repository.

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

## Current Status

Check `PLAN.md` for the current implementation phase and specific tasks. Each sub-phase includes both implementation tasks and testing requirements that must be completed.
