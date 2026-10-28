# api-gateway proxymock golden snapshot

This directory holds **only recorded traffic** — the golden snapshot that the api-gateway's
externalized integration tests replay. The tooling that drives and maintains it lives at the
repo root under `scripts/proxymock/` (shared across services), and the method is documented
in the `proxymock-service-tests` skill.

```
recorded-golden/
  localhost/                # inbound requests to the gateway  -> the replay TEST SET
  banking-user/             # gateway's outbound calls          -> downstream MOCKS
  banking-accounts/         # gateway's outbound calls          -> downstream MOCKS
  banking-transactions/     # gateway's outbound calls          -> downstream MOCKS
  known-gaps/localhost/     # inbound requests parked out of the gate (see below)
results/                    # replay/mock output + reports (git-ignored, generated per run)
```

Only `recorded-golden/` is committed. Source: Speedscale cloud snapshot
`cron-dev-decoy-real-outerspace-099` (service `banking-gateway`).

## Run the tests

```
make proxymock-replay                      # from backend/api-gateway/
./scripts/proxymock/replay-service.sh api-gateway   # from the repo root
```

The harness starts the gateway behind `proxymock mock` (serving `banking-*` as the
downstream dependencies), replays `localhost/` against it, and applies two gates: the
recorded **status code** must be reproduced, and each observed response must match the
**schema** derived from the golden responses (field presence + types; volatile values may
vary). Reports land in `results/` (git-ignored).

## known-gaps/

Inbound requests parked out of the pass/fail gate because they cannot be reproduced
faithfully offline — a capture/environment limitation, not a gateway defect:

- `GET /api/transactions?accountId=<id>` — the downstream fan-out was not captured, so no
  mock can serve it.
- `GET /api/transactions` that recorded a **503** — a Redis rate-limiter rejection under
  production load; the offline replay runs with the rate limiter disabled, so it returns 200.

## Rebuilding the snapshot

See the `proxymock-service-tests` skill for the full procedure. In short: pull a fresh
snapshot, copy the inbound + downstream dirs into `recorded-golden/`, then normalize it:

```
make proxymock-prepare-golden              # from backend/api-gateway/
```
