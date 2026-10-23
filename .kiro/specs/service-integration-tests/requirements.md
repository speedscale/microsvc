# Requirements — Service Integration Tests

A repeatable integration suite per service, built on **proxymock** (record → mock →
replay). Dependencies are served from committed recordings; the language-native runner is
used only for thin assertions traffic can't express (a DB row, an emitted Kafka message).

| Service | Runtime | proxymock targets | Dependencies served from recordings |
|---|---|---|---|
| api-gateway | Java | yes | user, accounts, transactions services |
| accounts-service | Java | yes | postgres, user-service |
| transactions-service | Java | yes | postgres, accounts, user, fraud (gRPC), Stripe/PayPal/ComplyAdvantage |
| user-service | .NET 8 | partial (script) | postgres, Socure/Jumio/HIBP |
| ai-service | Python | add | 5 LLM provider APIs |
| fraud-service | Go | add | Sift/MaxMind/Stripe-Radar |
| notification-service | Go | add | Kafka (inbound event), Slack/SendGrid/Twilio |
| frontend | Next.js | add | api-gateway |

"add" = no proxymock Makefile targets yet; the Java gateway, accounts and transactions
services have them. user-service has only `scripts/run-proxymock-validation.sh` (CI job
`proxymock-validation`, Postgres mock) and needs Makefile targets. mongo-service has no
source in the repo and is out of scope until it does.

## Requirements

### 1. Per-service suite
1. Each service SHALL have an integration suite separate from its unit tests, runnable
   with one documented command: `make integration-test`.
2. Tests SHALL drive the service's real HTTP/gRPC entry points and cover the main success
   path and key failure paths.

### 2. Dependency isolation
1. All dependencies (other banking services, third parties, Postgres, Mongo, Kafka) SHALL
   be served by `proxymock mock` from committed recordings, not live systems,
   Testcontainers or hand-written mocks. Banking-service dependencies use
   `--service <name>=<port>`.
2. Services without targets SHALL gain record/mock/replay targets following the Java
   Makefile pattern (unique app/inbound/outbound ports; recordings under
   `proxymock/<service>/recorded-<date>/`).
3. The driver SHALL be `proxymock replay --test-against localhost:<app-port> --in
   <recorded-dir>`; a replay mismatch SHALL fail the test.
4. `make integration-test` SHALL start the mock, start the service, replay, and tear down.

### 3. Data and event flows
Thin native tests (outside the proxymock run) SHALL assert that:
1. a completed transactions-service transaction is persisted and a `transaction-events`
   message is produced;
2. notification-service consuming a `transaction-events` message fans out to its
   providers.

### 4. Contract coverage
1. transactions-service: the gRPC fraud request/response and the accounts-service REST
   contract (ownership check, balance read/update).
2. api-gateway: routing and edge auth (public vs protected; `401` on missing/invalid
   token).
3. A user-service-issued token is accepted by a Java service with a shared `JWT_SECRET`.

### 5. Fixtures
1. Recordings under `proxymock/<service>/recorded-<date>/` are the source of truth, are
   refreshed with `make proxymock-record` against a running stack, and are reviewed before
   commit.
2. Suites SHALL pass offline and leave no durable side effects.

### 6. CI
1. CI SHALL run each service's suite at least on changes under its path; a replay
   mismatch fails the build.
2. CI needs only the proxymock CLI and the service runtime.

### 7. Documentation
Each service SHALL document how to run its suite and refresh recordings; the root
`README.md` testing section SHALL link to them.
