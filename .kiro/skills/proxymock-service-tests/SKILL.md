---
name: proxymock-service-tests
description: Add externalized, proxymock-driven integration tests to a backend service in the speedscale/microsvc banking app. The tests ARE recorded traffic (a committed golden snapshot), not code: proxymock mock serves the service's downstream dependencies while proxymock replay drives the recorded inbound requests at the running service and asserts four gates -- the recorded HTTP status is reproduced, each observed response matches a schema derived from the golden AND every golden operation is exercised (contract coverage), replayed response values satisfy agreed business invariants (property tests), and the golden is a normalized, stable fixed point (snapshot consistency). A pre-commit hook runs it. Use when asked to write/replicate proxymock integration tests, a golden snapshot, replay/mock tests, response schema/contract validation, property/invariant tests, or snapshot-consistency checks for a service like accounts-service, transactions-service, user-service, etc. Mirrors what already exists for api-gateway.
triggers: proxymock tests for, replay tests for, golden snapshot for, add proxymock to, integration tests with proxymock, mock downstreams and replay, schema validation for responses, contract coverage for, property tests for, business invariants for, snapshot consistency for, pre-commit proxymock gate, replicate the api-gateway proxymock setup, record and replay tests for the service
---

# proxymock service tests

Give a backend service integration tests that live as **recorded traffic**, not code. The
reference implementation is **api-gateway**; this skill replicates it for another service.
The shared tooling is already written and service-agnostic — most of the work is producing
a good golden snapshot and a small per-service config.

## Architecture (how it already works for api-gateway)

Two processes, one golden snapshot, **four gates** — all run by one harness and gated by a
pre-commit hook:

- `proxymock mock` starts the **real service** and acts as a forward proxy on
  `127.0.0.1:4140`. It serves the service's downstream dependencies from the golden
  (`recorded-golden/<dependency-host>/`), matching each outbound call by its original host +
  method + url + query + body. No real DB, Redis, mesh, or sibling services run.
- `proxymock replay` drives the recorded **inbound** requests (`recorded-golden/localhost/`)
  at the running service and builds a verdict.
- **Gate 1 — behavioral (status):** `--ignore-body-changes` scores STATUS codes only —
  response bodies come from the mocks and carry volatile values, so status is what the
  service owns (routing + auth + reproduced status).
- **Gate 2 — structural + contract coverage:** `schema_validate.py` derives a JSON schema
  per `(method, url-pattern, status)` from the golden responses and checks every observed
  response (dropped field or changed type fails; volatile values and additive fields pass).
  With `--require-coverage` it ALSO treats the golden as the contract and reports/fails on
  any golden **operation, status, or required field** the replay never exercised — so a
  thin or vacuous replay cannot pass by omission.
- **Gate 3 — properties (business invariants):** `property_validate.py` asserts agreed,
  declarative invariants over replayed response VALUES (e.g. `balance >= 0`, `amount > 0`,
  `status` in an allowed set). Opt in by authoring `services/<service>.invariants.json`;
  skipped (not failed) when absent.
- **Gate 4 — snapshot consistency:** `prepare_golden.py --check` confirms the committed
  golden is a normalized, stable **fixed point** — re-preparing it changes nothing. This is
  what makes the suite's verdict repeatable across machines and surfaces fixture drift.

Shared, reusable pieces at the repo root (do NOT copy per service):

```
scripts/proxymock/
  replay-service.sh            # the harness: replay-service.sh <service> (runs all 4 gates)
  prepare_golden.py            # normalize a pulled snapshot into a golden (idempotent; --check)
  schema_validate.py           # derive + validate schemas; --require-coverage for contract coverage
  property_validate.py         # assert business invariants over replayed values
  services/<service>.env             # per-service harness config (required)
  services/<service>.invariants.json # per-service business invariants (optional, gate 3)
```

Each service keeps ONLY recorded data under its own dir:

```
backend/<service>/proxymock/
  recorded-golden/
    localhost/                 # inbound requests -> the replay TEST SET
    <dep-host>/ ...            # outbound calls per dependency -> downstream MOCKS
    known-gaps/localhost/      # inbound parked out of the gate (optional)
  README.md                    # short, data-focused (copy api-gateway's and adjust)
  results/                     # generated per run, git-ignored
```

## The four gates in depth

### Contract coverage (gate 2, `--require-coverage`)

The golden IS the contract. Schema validation alone only inspects responses the replay
happened to produce, so it can pass vacuously. Coverage closes that by reporting, explicitly:

- **MISSING OPERATIONS** — a `(method, url-pattern, status)` the golden documents that the
  replay never produced (a missing operation OR a missing status for an operation).
- **MISSING FIELDS** — a required field in the golden schema for a covered operation that no
  observed response for it carried.

Coverage is always printed (`N/M golden operation(s) exercised`); `--require-coverage` makes
a missing operation fail the run, and `PROXYMOCK_STRICT_FIELD_COVERAGE=1` additionally fails
on missing fields. The harness runs with `--require-coverage` on. Legitimately-uncoverable
traffic is parked as a known-gap (step 3), which removes it from both the gate and the
golden-contract denominator — so "parked" is explicit, not silent.

Inspect coverage without a service build:
`python3 scripts/proxymock/schema_validate.py --golden <golden> --replay <last results/.../replayed> --require-coverage`.

### Property testing (gate 3, business invariants)

A property is a rule that holds for ALL valid responses, not one example: "a balance is a
non-negative number", "a transaction amount is positive", "login returns a non-empty bearer
token". Schema validation says `balance` is a number; a property says it is `>= 0`.

Invariants live in `scripts/proxymock/services/<service>.invariants.json` — declarative, so
they are **reviewed and agreed**, not buried in code — a list of rules, each a `match`
(`method`/`url`/`status`, any omitted = broader) and `assert` checks per field path
(`required`, `type`, `min`/`max`, `enum`, `pattern`, `non_empty`; `$[].field` maps over array
elements). Scope them to invariants the business actually guarantees; an invariant that is
only "usually" true will flap. See `services/api-gateway.invariants.json` for the reference
set (balances `>= 0`, amounts `> 0`, account/transaction type + status enums, well-formed
email, present token).

If a service has no agreed invariants yet, that is the scoping task: identify them with the
service owner before writing the file. Lint the file structure offline with
`property_validate.py --rules <file> --lint`. A rule that matches no replayed response is
reported (INFO) — either the invariant is dead or the traffic it guards is missing.

### Snapshot consistency (gate 4) — what "confidence" means

Confidence in this suite is: **the same golden produces the same verdict for anyone, and
nothing drifts silently.** It rests on the golden being a normalized, stable fixed point.

- **Repeatability** — `prepare_golden.py` is idempotent, so a correctly prepared golden is a
  fixed point: `prepare_golden.py --golden <golden> --check` re-derives the normalization
  without writing and must report "already normalized". If it lists files, the committed
  golden drifted (a stray DLP `$api_key`, a token re-signed to the wrong expiry, a hand-edit)
  — re-run `make proxymock-prepare-golden` and commit. The harness runs `--check` every time,
  so a drifted fixture fails the gate rather than quietly changing what the tests assert.
- **Drift visibility** — the gates themselves make service drift observable: gate 2 reports
  additive fields (INFO) and fails on removed/retyped ones; coverage reports operations that
  stopped appearing; gate 3 reports invariants that stopped matching. The verdict and
  schema/coverage report in `results/` (git-ignored) are the per-run drift record.

## Steps to add a new service

### 1. Find and pull a snapshot

The gateway golden came from a Speedscale cloud snapshot. Use the proxymock MCP tools
(load them first if deferred): `snapshot list` to find a snapshot whose `Services` is the
target (service names are like `banking-accounts`, `banking-transactions`, `banking-user`),
then `snapshot pull` into `backend/<service>/proxymock`. The pull yields
`snapshot-<id>/localhost/` (inbound) plus one dir per downstream hostname the service calls.

If no cloud snapshot exists, record one: run `proxymock record` around the service under
real traffic, or reuse an existing recording. The rest of the flow is identical.

### 2. Assemble recorded-golden/

Copy `localhost/` and each downstream dependency dir out of the pulled `snapshot-<id>/`
into `recorded-golden/`. Drop dependency dirs the service does not actually call and any
Redis dir (a Redis dir makes `proxymock mock` try to bind 6379 and fail if a local Redis
runs). Then delete the raw `snapshot-<id>/`.

### 3. Normalize with prepare_golden.py

```
python3 scripts/proxymock/prepare_golden.py --golden backend/<service>/proxymock/recorded-golden \
  [--known-gap-pattern '<regex on inbound rrpair text>' ...] \
  [--known-gap-status '<url-substring>:<status>' ...]
```

It is idempotent and does four things: strips the DLP `$api_key` artifact (from request
bodies AND the INTERNAL json `signature.http:requestBodyJSON` that proxymock matches on),
re-signs expiring JWTs to 2030 with the shared public test secret, relocates known gaps,
and prunes redundant/huge downstream mocks to one smallest file per needed signature.
Downstream dirs are auto-detected (everything except `localhost`/`known-gaps`/`results`).

**Known gaps** are inbound requests that cannot replay faithfully offline — park them so the
gate stays 100% on coverable traffic. Two kinds: a downstream fan-out the snapshot did not
capture (match with `--known-gap-pattern`, e.g. a query param that has no mock), and an
environment-specific status such as a load-dependent 503 (match with `--known-gap-status`,
e.g. `/api/transactions:503`). Only add a gap rule once a replay run shows the request can't
be served — do not pre-emptively park things.

### 4. Write scripts/proxymock/services/<service>.env

Copy `services/api-gateway.env` and adjust. Fields:

- `SERVICE_DIR_REL`, `APP_PORT`, `BUILD_CMD`, `JAR_GLOB`
- `HEALTH_PATHS` — a LOCAL health endpoint (not a self-route that passes through the
  proxied http client)
- `DOWNSTREAM_DIRS` — the dependency dirs in the golden the mock should serve
- `APP_ENV` — env the app starts with. Point each downstream service URL at its RECORDED
  hostname (e.g. `http://banking-accounts:80`), set `JWT_SECRET=${PROXYMOCK_JWT_SECRET}`,
  and route the app's outbound HTTP through the mock proxy (see APP_FLAGS).
- `APP_FLAGS` — JVM/app flags for a deterministic offline boot. Per-service concerns differ:
  disable any Redis-backed feature (rate limiter) if the service has one, pin off random
  fault injection, exclude the OTel starter autoconfigs that crash offline startup
  (`OpenTelemetryAutoConfiguration` + the web/webflux instrumentation ones), and route
  outbound HTTP through the proxy. Note: Spring Cloud Gateway uses
  `-Dspring.cloud.gateway.httpclient.proxy.host/port`; a plain Spring Boot WebClient/RestTemplate
  service instead honors the `http_proxy`/`https_proxy` env vars (add them to `APP_ENV`), and
  a .NET service respects `HTTP_PROXY`/`HTTPS_PROXY`. Pick the mechanism the service's HTTP
  client actually reads.
- `KNOWN_GAP_PATTERNS`, `KNOWN_GAP_STATUS` — the same values you passed in step 3 (kept here
  for `make proxymock-prepare-golden` reproducibility).

### 5. Author business invariants (optional, gate 3)

Copy `services/api-gateway.invariants.json` and scope it to THIS service's agreed invariants
(see "Property testing" above). Skip the file to skip the gate. Lint it with
`make proxymock-lint-invariants` (or `property_validate.py --rules <file> --lint`).

### 6. Run and iterate

```
scripts/proxymock/replay-service.sh <service>        # or: make proxymock-replay in the service dir
```

Iterate until ALL gates pass: the replay verdict is `pass`, schema validation PASSES with
full contract coverage, property validation PASSES, and the snapshot-consistency check
reports the golden is already normalized. Common failures and fixes (all seen on
api-gateway):

- **CONTRACT COVERAGE FAILED / MISSING OPERATIONS** — the replay did not exercise a golden
  operation. Either the inbound request for it is missing from `localhost/` (re-record or
  copy it in) or it was legitimately parked — make it an explicit known-gap (step 3) so it
  leaves the contract denominator, don't ignore the report.
- **PROPERTY VALIDATION FAILED** — a replayed value violated an agreed invariant. Either the
  service regressed (fix it) or the invariant is too strict / wrong (correct the rules file
  with the owner). A rule reported as matching no response means its traffic is missing.
- **SNAPSHOT NOT NORMALIZED** — the committed golden drifted; run
  `make proxymock-prepare-golden` and commit the result.
- **400 "direct request to the proxy-out port"** — the app addressed `:4140` as a plain
  server. Keep the recorded downstream hostnames as the service URLs and route the http
  client THROUGH the proxy instead.
- **404 NO MATCH on a downstream call** — the mock's signature doesn't match the forwarded
  request. Usually the DLP `$api_key` still in the INTERNAL signature (re-run prepare_golden),
  or the pruner kept a wrong-body mock (the prune key includes the request body), or the
  downstream fan-out genuinely wasn't captured (make it a known-gap).
- **401 where a 200 was recorded** — expired/mis-signed JWT. Confirm prepare_golden re-signed
  the tokens and the app runs with `JWT_SECRET` = the shared test secret.
- **500 on startup / NoSuchMethodError HttpSpanNameExtractor.builder** — the OTel starter;
  add the three autoconfigure excludes to APP_FLAGS.
- **Recorded 503 flips to 200** — a load/rate-limiter-dependent status; park it via
  `--known-gap-status`.

### 7. Wire it in

- Add `proxymock-replay`, `proxymock-check-golden`, `proxymock-lint-invariants`, and
  `proxymock-prepare-golden` targets to the service Makefile (copy api-gateway's, swap
  `$(SERVICE_NAME)` and the gap flags).
- The root `.gitignore` already force-tracks `backend/*/proxymock/recorded-golden/` and
  ignores `results/`; `scripts/proxymock/` (including the `.invariants.json` files) is
  tracked — no change needed.
- The pre-commit hook (`.githooks/pre-commit`) auto-discovers any
  `scripts/proxymock/services/<service>.env`, so a new service is gated as soon as its config
  exists. Enable hooks once with `make install-git-hooks`.
- Bump the service's `pom.xml` `<version>` if you changed code under `backend/<service>/`
  (AGENTS.md policy). The gateway needed one prod code change — a
  `gateway.rate-limiter.enabled` flag so it routes without Redis; a service may need an
  analogous small, production-safe toggle to run a dependency offline. Keep such changes
  minimal and default-on in production.

### 8. Demonstrate the pre-commit gate (passing vs failing change)

The hook (`.githooks/pre-commit`) runs the full four-gate harness for any service whose tree
the commit touches. Demonstrate both outcomes once hooks are enabled (`make install-git-hooks`):

- **A passing change** — a change that keeps the contract: edit something under
  `backend/<service>/` that does not alter response shape, values, or routed statuses (a
  comment, a log line, a safe refactor). `git add` it and commit: the hook builds the
  service, replays the golden, all four gates pass, and the commit succeeds —
  `pre-commit: <service> proxymock replay passed.`
- **A failing change** — a change that breaks the contract: e.g. make an endpoint drop a
  response field or return a different status, or violate an invariant (return a negative
  balance). `git add` and commit: the hook replays and a gate fails (schema/coverage,
  property, or status), the hook prints the failing gate, and the commit is **blocked**
  (non-zero exit). Fix the service (or, if the golden is genuinely stale, re-record and
  `make proxymock-prepare-golden`), or bypass once with `SKIP_PROXYMOCK_REPLAY=1 git commit`.

This is the point of externalizing the tests as traffic: a contract-breaking change can't be
committed without either fixing it or consciously updating the committed golden.

## Guardrails

- A service's `proxymock/` dir holds ONLY recorded data + its README. Tooling stays in
  `scripts/proxymock/`.
- Commit only `recorded-golden/` (and README); never commit `results/` or the `.replay/`
  marker `proxymock replay` drops into the input dir.
- Keep the golden small: prune to the mocks the inbound set drives (prepare_golden does this).
- The gates are layered on purpose, each asserting a different thing while letting volatile
  values vary: status (behavior), schema + coverage (shape and that the whole contract is
  exercised), invariants (values that must make business sense), consistency (the fixture
  itself is stable). Asserting exact bodies would be noise — bodies come from mocks; these
  gates catch real regressions instead.
- Business invariants are declarative and agreed (`<service>.invariants.json`), not assertions
  hidden in code — review them like any contract. Keep them to properties that truly always
  hold, or they flap.
