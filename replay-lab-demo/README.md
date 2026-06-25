# Replay Lab — local reproduce → fix → validate loop

This package reproduces a real production bug **on your laptop**, fixes it, and proves
the fix — using a **captured production request** and Speedscale **proxymock** to mock
every downstream dependency. No cluster, no staging, no hand-written test.

It is the [Replay Lab](#where-the-replay-lab-fits) loop shrunk to a single service so you
can watch every step.

```
 captured prod request ──▶  reproduce (RED)  ──▶  fix  ──▶  validate (GREEN)
   real RRPair               replay → 400          patch       replay → 201
                             deps mocked by proxymock
```

## The bug

`transactions-service` normalizes a deposit's memo for a downstream ledger feed:

```java
String memo = request.getDescription().trim().toUpperCase();   // NPE when description is null
```

Real clients sometimes POST a deposit with **no `description`**. In production that throws a
`NullPointerException`, the controller traces it and returns an error to the customer — the
deposit silently fails. Observability shows you the exception; it does **not** hand you the
exact request that triggered it. The captured RRPair does.

The bug is gated behind `DEMO_MEMO_BUG_ENABLED` so it only arms for this demo.

## Run it

Prereqs: Docker (for Postgres), Java 17+, Maven, and `proxymock` (`~/.speedscale/proxymock`).

```bash
make setup        # one-time: start Postgres, create the service DB user, build the jar
make run          # terminal 1: starts the service + proxymock mock (deps), bug armed
make reproduce    # terminal 2: replays the captured prod failure   ->  RED   (HTTP 400)
make fix          #             applies the agent's fix, hot-restarts ->  GREEN (HTTP 201)
make reset        #             puts the bug back
make down         # stop the service + mock
```

`make run` overrides the port with `PORT=…` if 8080 is taken (e.g. `make run PORT=8090`,
`make reproduce PORT=8090`).

## What is real vs mocked

| Dependency | In this demo |
|---|---|
| **Postgres** | **real** — local container (`make setup`). JDBC ignores the HTTP proxy, so it stays live. |
| accounts-service | **mocked** by proxymock from recorded traffic (`mocks/localhost/`) |
| Stripe / PayPal / ComplyAdvantage | **mocked** by proxymock (`mocks/api.*`) — the deposit's payment/compliance fan-out |
| fraud-service (gRPC) | absent → the client **fails open**, exactly as in production |

The service talks to its dependencies through proxymock on `:4140`
(`-Dhttp.proxyHost=localhost -Dhttp.proxyPort=4140`). proxymock answers each outbound call
with the **recorded** response, so the whole loop runs offline and deterministically.

## What's in the box

```
captured/deposit-failure.md   the real captured production failure (POST /deposit, no description -> 400)
mocks/localhost/*.md          recorded accounts-service responses (validate, get-balance, update-balance)
mocks/api.*/*.md              recorded payment/compliance responses
fix.patch                     the one-line null-guard fix (applied by `make fix`)
setup.sh run.sh reproduce.sh fix.sh   the steps, as plain scripts (make just calls them)
```

The mocks were produced by recording one successful deposit against the real services:

```bash
proxymock record --app-port 8080 -- java -Dhttp.proxyHost=localhost -Dhttp.proxyPort=4140 -jar <service>.jar
# drive one good deposit through :4143, then reuse the recorded OUT pairs as mocks
```

Because they are real recordings (not hand-written), proxymock matches them by signature with
no fix-ups.

## Where the Replay Lab fits

- **proxymock** is the **replay engine** — the thing you just ran on your laptop. It captures
  traffic, mocks dependencies, and replays a request against your code.
- **Replay Lab** is the **product** that runs this exact loop **continuously, in a cluster,
  against live production traffic**: the forwarder streams captured traffic in, a work queue
  picks failing requests, each one is replayed in an isolated runner (deps mocked, just like
  here), and the result is bug evidence + release confidence — reproduce, fix, validate, repeat.

This demo is that loop, by hand, on one bug: **capture → reproduce → fix → validate**. The
Replay Lab is the same four steps, automated and always-on.
