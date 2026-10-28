---
name: proxymock-service-tests
description: Add externalized, proxymock-driven integration tests to a backend service in the speedscale/microsvc banking app. The tests ARE recorded traffic (a committed golden snapshot), not code: proxymock mock serves the service's downstream dependencies while proxymock replay drives the recorded inbound requests at the running service and asserts two gates -- the recorded HTTP status is reproduced, and each observed response matches a schema derived from the golden. Use when asked to write/replicate proxymock integration tests, a golden snapshot, replay/mock tests, or response schema validation for a service like accounts-service, transactions-service, user-service, etc. Mirrors what already exists for api-gateway.
triggers: proxymock tests for, replay tests for, golden snapshot for, add proxymock to, integration tests with proxymock, mock downstreams and replay, schema validation for responses, replicate the api-gateway proxymock setup, record and replay tests for the service
---

# proxymock service tests

Give a backend service integration tests that live as **recorded traffic**, not code. The
reference implementation is **api-gateway**; this skill replicates it for another service.
The shared tooling is already written and service-agnostic — most of the work is producing
a good golden snapshot and a small per-service config.

## Architecture (how it already works for api-gateway)

Two processes, one golden snapshot, two gates:

- `proxymock mock` starts the **real service** and acts as a forward proxy on
  `127.0.0.1:4140`. It serves the service's downstream dependencies from the golden
  (`recorded-golden/<dependency-host>/`), matching each outbound call by its original host +
  method + url + query + body. No real DB, Redis, mesh, or sibling services run.
- `proxymock replay` drives the recorded **inbound** requests (`recorded-golden/localhost/`)
  at the running service and builds a verdict.
- **Gate 1 (behavioral):** `--ignore-body-changes` scores STATUS codes only — response
  bodies come from the mocks and carry volatile values, so status is what the service owns
  (routing + auth + reproduced status).
- **Gate 2 (structural):** `schema_validate.py` derives a JSON schema per
  `(method, url-pattern, status)` from the golden responses and checks every observed
  response — dropped field or changed type fails; volatile values and additive fields pass.

Shared, reusable pieces at the repo root (do NOT copy per service):

```
scripts/proxymock/
  replay-service.sh            # the harness: replay-service.sh <service>
  prepare_golden.py            # normalize a pulled snapshot into a golden (idempotent)
  schema_validate.py           # derive + validate response schemas
  services/<service>.env       # the ONLY per-service file you author
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

### 5. Run and iterate

```
scripts/proxymock/replay-service.sh <service>        # or: make proxymock-replay in the service dir
```

Iterate until the replay verdict is `pass` and schema validation PASSES. Common failures and
fixes (all seen on api-gateway):

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

### 6. Wire it in

- Add `proxymock-replay` / `proxymock-prepare-golden` targets to the service Makefile
  (copy api-gateway's, swap `$(SERVICE_NAME)` and the gap flags).
- The root `.gitignore` already force-tracks `backend/*/proxymock/recorded-golden/` and
  ignores `results/` — no change needed.
- The pre-commit hook (`.githooks/pre-commit`) auto-discovers any
  `scripts/proxymock/services/<service>.env`, so a new service is gated as soon as its config
  exists. Enable hooks once with `make install-git-hooks`.
- Bump the service's `pom.xml` `<version>` if you changed code under `backend/<service>/`
  (AGENTS.md policy). The gateway needed one prod code change — a
  `gateway.rate-limiter.enabled` flag so it routes without Redis; a service may need an
  analogous small, production-safe toggle to run a dependency offline. Keep such changes
  minimal and default-on in production.

## Guardrails

- A service's `proxymock/` dir holds ONLY recorded data + its README. Tooling stays in
  `scripts/proxymock/`.
- Commit only `recorded-golden/` (and README); never commit `results/` or the `.replay/`
  marker `proxymock replay` drops into the input dir.
- Keep the golden small: prune to the mocks the inbound set drives (prepare_golden does this).
- Status-only + schema is deliberate: bodies come from mocks, so asserting exact bodies is
  noise; schema catches real shape/type regressions while letting values vary.
