# Tasks — Service Integration Tests

All open. Do the shared pattern first, then the Java services that already have targets,
then add targets to the rest, then commit recordings and wire CI. Per-service shape is in
design.md.

- [ ] 1. Shared pattern: define the `integration-test` Makefile target shape and document
  the loop in `docs/integration-testing.md`. _Req 1.1, 2.4, 7_
- [ ] 2. transactions-service: record success (deposit/withdraw/transfer) and failure
  (fraud-reject, insufficient-funds) traffic; add `integration-test`; add the thin
  JPA/Kafka assertion. _Req 1, 2, 3.1, 4.1_
- [ ] 3. accounts-service: record create/read/balance-update, ownership-denied, not-found;
  add `integration-test`. _Req 1, 2_
- [ ] 4. api-gateway: record valid-token routing, `401` cases, public routes and the rate
  limiter; add `integration-test`. _Req 1, 2, 4.2_
- [ ] 5. user-service: add Makefile targets; record register/login/profile/409/401; add
  `integration-test`; thin check that a minted token validates in a Java service with a
  shared `JWT_SECRET`. _Req 1, 2, 4.3_
- [ ] 6. fraud-service: add targets; record gRPC approve/deny and provider calls; add
  `integration-test`. _Req 1, 2, 4.1_
- [ ] 7. notification-service: add targets; record provider fan-out; add
  `integration-test` that feeds a recorded event; thin fan-out assertion. _Req 1, 2, 3.2_
- [ ] 8. ai-service: add targets; record chat happy path and one-provider-fails; add
  `integration-test`. _Req 1, 2_
- [ ] 9. frontend: add targets mocking api-gateway; record login, a core flow and an
  unauthorized redirect; add `integration-test`. _Req 1, 2_
- [ ] 10. Commit recordings and confirm every suite passes offline with no durable side
  effects. _Req 5_
- [ ] 11. Add the CI `integration-tests` job (per-service matrix, path-filtered). _Req 6_
- [ ] 12. Write per-service run/refresh docs and link them from the root README. _Req 7_
