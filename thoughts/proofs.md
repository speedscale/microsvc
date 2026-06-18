## Traffic users have human names, mostly western locales, and localized AI prompts
- **Level**: Integration
- **Evidence**: `thoughts/scripts/verify-named-locale-users.sh`
- **Status**: PROVEN
- **Date**: 2026-06-18

## Harper Clark has exactly one funded checking account and one funded savings account in staging-decoy
- **Level**: Deployment
- **Evidence**: `thoughts/scripts/verify-staging-demo-user.sh` PASS against `do-nyc1-staging-decoy`
- **Status**: PROVEN
- **Date**: 2026-06-18

## Transfer compliance screening rejects unresolved provider risk
- **Level**: Unit
- **Evidence**: `PaymentComplianceServiceTest` and `TransactionServiceTest` PASS via `./mvnw test`
- **Status**: PROVEN
- **Date**: 2026-06-18

## The speedscale-sidecar overlay renders with the fixed seed job
- **Level**: Integration
- **Evidence**: `kubectl kustomize kubernetes/overlays/speedscale-sidecar` rendered 4,964 lines
- **Status**: PROVEN
- **Date**: 2026-06-18
