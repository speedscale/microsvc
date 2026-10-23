# Tasks — Transaction Processing

Endpoints, fraud screening, ownership/balance rules, locked mutation with compensation,
payment fan-out, Kafka events and observability are implemented (requirements 1–8), except
the gaps in tasks 1–2. Tasks 3–5 address the known limitations in design.md and build on the
locked mutation:

- [ ] 1. Reject a same-account transfer in the service, not only in `TransactionController.transfer`: today
  `POST /create` with `type=TRANSFER` and identical ids reaches `transfer`, which reads the
  balance twice and then writes `balance - amount` and `balance + amount`. _Req 1.2_
- [ ] 2. Persist `FAILED` records durably: `TransactionService` is class-level
  `@Transactional` and the failure handlers save `FAILED` then throw `RuntimeException`, so
  the save is rolled back. Save in an independent transaction (`REQUIRES_NEW`). Fraud,
  ownership and insufficient-balance failures throw before any entity exists, so they also
  need a record. _Req 4.3_

- [ ] 3. Serialize balance writes across replicas (distributed lock or atomic balance op
  on accounts-service), keeping fail-open fraud behavior. _Req 4.1_
- [ ] 4. Add an outbox or saga so a crash between balance update and record persistence
  cannot leave them inconsistent. _Req 4.2, 4.3_
- [ ] 5. Accept a client idempotency key so retries do not double-apply. _Req 1, 4.3_
