# Replay Lab: verify AI-generated code against production reality

Coding agents make shipping code cheap. Shipped code still has to survive production
traffic, and new code fails there more often than code review or dashboards catch.
This demo shows the two loops that close that gap, on your laptop, with **proxymock**
and traffic captured from a production-like banking app. No cluster, no staging
environment, no hand-written tests.

- **Workflow A, the release gate.** Replay yesterday's production traffic against a
  candidate build before it merges. A change that passes its own unit tests but
  breaks real request shapes goes RED in CI, not in prod.
- **Workflow B, incident reproduction.** A captured production failure replays
  locally with every dependency mocked: reproduce (RED), fix, prove (GREEN) with the
  exact request that hurt a real customer.

Both loops run against `transactions-service` from this repo, with every downstream
dependency (accounts-service, Stripe, PayPal, ComplyAdvantage) served by proxymock
from recorded traffic. Postgres is the only real dependency.

## Setup (once)

Prereqs: Docker (for Postgres), Java 17+, Maven, and `proxymock`
(`~/.speedscale/proxymock`).

```bash
make setup        # start Postgres, create the service DB user, build the jar
```

Every target takes `PORT=…` if 8087 is busy (`make run PORT=8090`, `make gate PORT=8090`).
`make run` refuses to start if anything else is listening on the port. A half-claimed
port (say, a container publishing the same port on IPv4 only) answers some clients and
not others, which is much worse than a clean failure.

## Workflow A: the release gate

The story: an agent "standardized" the deposit API response. It wrapped the body in a
`{"status", "data"}` envelope and returned `200 OK` instead of `201 Created`. It
updated the unit tests to match, so CI is green. Every existing consumer of the API
is now broken. The gate replays recorded production traffic against the candidate
build and fails unless every request gets the status code production gave it.

```bash
# terminal 1: the build currently in prod
make run MEMO_BUG=false
# terminal 2: gate passes — traffic-proven safe
make gate

# terminal 1 (Ctrl-C, then): the agent's candidate build
make run MEMO_BUG=false CONTRACT_REFACTOR=true
# terminal 2: gate fails — 33% match, both deposits flagged, exit code 1
make gate
```

The same gate catches the workflow-B bug before release (`make run` with the memo
bug armed fails the gate on exactly the request shape that triggers it). In CI this
is one step: build, start, `./gate.sh`, and the exit code blocks the merge.

The suite in `prod-suite/` ships with the demo. To re-record it against a healthy
build: `make run MEMO_BUG=false` then `make record-suite`.

## Workflow B: reproduce the production incident

The story: deposits from one client are failing in production right now.
Observability shows a `NullPointerException` count going up; it does not hand you
the request that causes it. The captured RRPair does:

```java
String memo = request.getDescription().trim().toUpperCase();   // NPE when description is null
```

Real clients sometimes POST a deposit with no `description`. The agent that wrote
the memo feature never sent one that way, and neither did its tests.

**Live pull** (staging-decoy access required): grab the actual failing requests
from the BYOC bucket via the Replay Lab export, with dependency mocks crafted to
match whatever account the incident hit:

```bash
make incident     # port-forward, export failing traffic, craft matched mocks
# terminal 1: the prod build, bug armed, deps from the incident pull
make run MOCKS=incident-mocks
# terminal 2: replay the pulled prod failure
make reproduce IN=incident/localhost   #  RED   — the production 400, on your laptop
make fix IN=incident/localhost         #  GREEN — null-guard applied, same request now 201
make reset && make down
```

The pulled RRPair carries the same `traceparent` as the failing span in the
tracing backend, so the evidence chain is: dashboard shows the error rate, the
trace shows a 48-byte request body it cannot give you, the RRPair is those 48
bytes. Errors fire in bursts, so if `make incident` reports no failing traffic,
widen the scan with `WINDOW=6h make incident` (or rerun a few minutes after the
next burst).

**Offline fallback**: a committed capture of the same failure ships in
`captured/`, so the loop also runs with no cluster access at all:

```bash
make run          # terminal 1
make reproduce    #  RED   — HTTP 400
make fix          #  GREEN — HTTP 201
make reset        #  put the bug back for the next run
make down         # stop the service + mock
```

The fix is proven with the exact production request, not a test someone wrote to
pass. That distinction is the point: an agent grading its own homework proves
nothing; recorded production traffic is ground truth neither the agent nor the
author can bend.

## Where the traffic comes from

`make incident` does the pull for real — this is the BYOC model end to end:

1. Speedscale capture (sidecar or eBPF tap) records traffic in the cluster.
2. Traffic lands in **your** object-storage bucket, DLP-redacted before it is
   written, so keys and PII never leave your account in the clear.
3. The Replay Lab export endpoint filters that bucket by service, route, and
   status and streams back a tar.gz of RRPairs plus downstream mocks —
   `incident.sh` is a port-forward and one `curl` around it.

The committed `captured/` and `prod-suite/` files are earlier pulls of the same
traffic, kept so the loops run offline. Nothing in either loop touches
Speedscale's cloud: capture, storage, and replay all run on infrastructure you
own. Incident pulls land in `incident/` and `incident-mocks/`, which are
gitignored — they carry live (short-lived) bearer tokens from the capture.

## What is real vs mocked

| Dependency | In this demo |
|---|---|
| **Postgres** | **real**: local container (`make setup`). JDBC ignores the HTTP proxy, so it stays live. |
| accounts-service | **mocked** by proxymock from recorded traffic (`mocks/localhost/`) |
| Stripe / PayPal / ComplyAdvantage | **mocked** by proxymock (`mocks/api.*`), the deposit's payment/compliance fan-out |
| fraud-service (gRPC) | absent → the client **fails open**, exactly as in production |

The service talks to its dependencies through proxymock on `:4140`
(`-Dhttp.proxyHost=localhost -Dhttp.proxyPort=4140`). proxymock answers each outbound
call with the **recorded** response, so both loops run offline and deterministically.

## What's in the box

```
captured/deposit-failure.md   the captured production failure (POST /deposit, no description -> 400)
prod-suite/localhost/*.md     recorded production traffic for the release gate (3 requests)
mocks/localhost/*.md          recorded accounts-service responses (validate, get-balance, update-balance)
mocks/api.*/*.md              recorded payment/compliance responses
fix.patch                     the one-line null-guard fix (applied by `make fix`)
gate.sh                       the CI release gate (replay + --fail-if, exit code = verdict)
incident.sh                   pull the live failing traffic from the replay-lab BYOC export
craft-mocks.py                derive account-matched accounts mocks for a pulled incident
record-suite.sh               re-record prod-suite/ from a healthy build
warmup.sh                     readiness probe shared by the replay scripts
setup.sh run.sh reproduce.sh fix.sh   the steps, as plain scripts (make just calls them)
```

Both staged defects are env-gated so the same jar plays every role:
`DEMO_MEMO_BUG_ENABLED` (workflow B's NPE) and `DEMO_CONTRACT_REFACTOR_ENABLED`
(workflow A's envelope change). `run.sh` exposes them as `MEMO_BUG` / `CONTRACT_REFACTOR`.

The mocks were produced by recording one successful deposit against the real services:

```bash
proxymock record --app-port 8087 -- java -Dhttp.proxyHost=localhost -Dhttp.proxyPort=4140 -jar <service>.jar
# drive one good deposit through :4143, then reuse the recorded OUT pairs as mocks
```

Because they are real recordings (not hand-written), proxymock matches them by
signature with no fix-ups. One constraint that keeps the suite deterministic: the
recorded accounts-service mock matches the downstream balance update by exact body,
so suite deposits stay at amount `3.33` on account `70668`.

## Where the Replay Lab fits

- **proxymock** is the **replay engine**, the thing you just ran on your laptop. It
  captures traffic, mocks dependencies, and replays requests against your code.
- **Replay Lab** is the **product** that runs these exact loops **continuously,
  against live production traffic**: capture streams into your bucket, a work queue
  picks failing requests, each one replays in an isolated runner (deps mocked, just
  like here), and the release gate runs on every merge request.

This demo is both loops, by hand, on one service: **gate before release, reproduce
when something slips through**. The Replay Lab is the same two loops, automated and
always-on.
