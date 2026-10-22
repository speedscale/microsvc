# Tasks — Transaction Processing

Endpoints, fraud screening, ownership/balance rules, locked mutation with compensation,
payment fan-out, Kafka events and observability are implemented (requirements 1–8).
Open items address the known limitations in design.md and build on the locked mutation:

- [ ] 1. Serialize balance writes across replicas (distributed lock or atomic balance op
  on accounts-service), keeping fail-open fraud behavior. _Req 4.1_
- [ ] 2. Add an outbox or saga so a crash between balance update and record persistence
  cannot leave them inconsistent. _Req 4.2, 4.3_
- [ ] 3. Accept a client idempotency key so retries do not double-apply. _Req 1, 4.3_
