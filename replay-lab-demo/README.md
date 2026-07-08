# Replay Lab: verify code against real production traffic with proxymock

This demo replays real production traffic against a service on your laptop to
reproduce a bug and prove the fix, and to gate a bad change before it ships. The
demo is **raw `proxymock` commands**. One helper script (`start-app.sh`) stands
up the app under test (Java/Spring plumbing, not proxymock).

Two independent places, traffic flows one way:

- A banking app runs in a **staging cluster** with a bug armed; a simulator drives
  it, some deposits fail, and Speedscale capture records that traffic into a cloud
  bucket. This runs on its own.
- **On your laptop** you replay that traffic against one service in local Docker.
  The laptop only reads captured traffic; it never touches the cluster.

Everything below runs offline against committed traffic. The live bucket pull is
optional (last section).

## Prereqs

Docker (for Postgres), Java 17+, Maven, and `proxymock` (`~/.speedscale/proxymock`).

## Workflow B: reproduce a production bug, prove the fix

The bug: `transactions-service` normalizes a deposit memo and trips on a null
`description`. Real clients POST deposits without one; the agent that wrote it
never tested that shape.

```bash
# terminal 1: bring up the app (buggy build) with its dependencies mocked
./start-app.sh
```

```bash
# terminal 2: replay the captured production failure against it
proxymock replay --in captured --test-against http://localhost:8087
#   -> the deposit returns HTTP 400: the production bug, reproduced on your laptop
```

Fix it and replay the same request:

```bash
# terminal 1: Ctrl-C, then apply the fix and restart
(cd .. && git apply replay-lab-demo/fix.patch)
./start-app.sh

# terminal 2: same command, now green
proxymock replay --in captured --test-against http://localhost:8087
#   -> HTTP 201. The exact production request that was failing now succeeds.

# put the bug back when you are done
(cd .. && git checkout -- backend/transactions-service)
```

The proof is the real production request, not a test written to pass.

### See it in the UI

`proxymock web` reads a workspace folder, so write the replay results into one:

```bash
proxymock replay --in captured --test-against http://localhost:8087 --out web/proxymock/run
proxymock web --in web
#   -> browse the requests and responses, status per request, request/response bodies
```

## Workflow A: the release gate

Replay recorded production traffic against a candidate build and fail on any
status-code divergence. This is a CI step: the exit code is the verdict.

```bash
# the build currently in prod: gate passes
./start-app.sh --clean
proxymock replay --in prod-suite --test-against http://localhost:8087 \
  --fail-if "requests.result-match-pct != 100"
#   -> EVALS PASSED, exit 0

# the agent's "standardize the response" refactor (200 + envelope): gate fails
# terminal 1: Ctrl-C, then
./start-app.sh --refactor
proxymock replay --in prod-suite --test-against http://localhost:8087 \
  --fail-if "requests.result-match-pct != 100"
#   -> EVALS FAILED, 33% match, exit 1 (blocked before merge)
```

## What is real vs mocked

| Dependency | In this demo |
|---|---|
| Postgres | real local container (started by `start-app.sh`) |
| accounts-service | mocked by proxymock from recorded traffic (`mocks/localhost/`) |
| Stripe / PayPal / ComplyAdvantage | mocked by proxymock (`mocks/api.*`) |
| fraud-service (gRPC) | absent; the client fails open, as in production |

The app's outbound calls route through proxymock on `:4140`; proxymock answers
each with the recorded response, so the loop runs offline and deterministically.

## Files

```
start-app.sh        stand up the app under proxymock mocks (--clean / --refactor for the gate)
captured/           the committed production failure (POST /deposit, no description)
prod-suite/         recorded good production traffic for the release gate
mocks/              recorded dependency responses proxymock serves
fix.patch           the one-line null-guard fix
pull-incident.sh    OPTIONAL: pull live failing traffic from the BYOC bucket (below)
craft-mocks.py      pull helper: account-matched mocks for the pulled traffic
refresh-tokens.py   pull helper: re-sign pulled bearer tokens to a far-future expiry
```

## Optional: pull live traffic from your BYOC bucket

Instead of the committed `captured/`, pull real failing traffic from the cluster's
bucket via the Replay Lab export (needs staging-decoy kube access):

```bash
WINDOW=6h ./pull-incident.sh
#   -> pulls the last several hours of failing deposits into incident/,
#      re-signs the tokens, and crafts matching dependency mocks in incident-mocks/

MOCKS=incident-mocks ./start-app.sh
proxymock replay --in incident/localhost --test-against http://localhost:8087
```

The pulled RRPair carries the same traceparent as the failing span in your tracing
backend, closing the loop from dashboard error to the exact request. `incident/`
and `incident-mocks/` are gitignored (they hold real captured tokens).
