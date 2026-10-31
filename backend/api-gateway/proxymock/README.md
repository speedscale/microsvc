# api-gateway proxymock golden snapshot

This directory holds the recorded traffic that the api-gateway's integration tests replay. The tooling lives at the repo root under `scripts/proxymock/`. For generating tests for other services, install the [shared Speedscale skills](https://docs.speedscale.com/proxymock/agent-skills/); no repository-specific skill is required.

```
recorded-golden/
  localhost/                # inbound requests to the gateway  -> the replay TEST SET
  banking-user/             # gateway's outbound calls          -> downstream MOCKS
  banking-accounts/         # gateway's outbound calls          -> downstream MOCKS
  banking-transactions/     # gateway's outbound calls          -> downstream MOCKS
  known-gaps/localhost/     # parked inbound requests (git-ignored, local only; see below)
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
downstream dependencies), replays `localhost/` against it, and applies four gates:

1. **status** — the recorded status code must be reproduced.
2. **schema + contract coverage** — each observed response must match the schema derived
   from the golden (field presence + types; volatile values may vary), AND every golden
   operation must be exercised (missing operations/statuses/fields are reported and fail).
3. **properties** — replayed response values must satisfy the agreed business invariants in
   `scripts/proxymock/services/api-gateway.invariants.json` (e.g. balances `>= 0`, amounts
   `> 0`, type/status enums, well-formed email, present token).
4. **snapshot consistency** — the committed golden must be a normalized, stable fixed point
   (`prepare_golden.py --check` changes nothing), so the verdict is repeatable and fixture
   drift is visible.

**Auth tokens are redacted.** Every JWT in `recorded-golden/` has its signature replaced with
`REDACTED` (header and claims kept), so nothing committed is a usable credential. At replay
time the blueprint `scripts/proxymock/services/api-gateway.blueprint.json` re-signs each
recorded bearer with `jwt_resign` using the replay's test key and a fresh expiry, and the
harness requires that blueprint to run. Replaying without it turns every authenticated request
into a 401.

Reports land in `results/` (git-ignored). Quick offline checks without a build:
`make proxymock-check-golden` and `make proxymock-lint-invariants`.

## Known gaps (not committed)

Inbound requests parked out of the pass/fail gate because they cannot be reproduced
faithfully offline — a capture/environment limitation, not a gateway defect. No test consumes
them, so the recordings are **not committed**: `make proxymock-prepare-golden` moves them to
`recorded-golden/known-gaps/`, which is git-ignored (local inspection only), and the downstream
mocks only they would need are pruned. The gaps are:

- `GET /api/transactions?accountId=<id>` — the downstream fan-out was not captured, so no
  mock can serve it.
- `GET /api/transactions` that recorded a **503** — a Redis rate-limiter rejection under
  production load; the offline replay runs with the rate limiter disabled, so it returns 200.

## Rebuilding the snapshot

Pull a fresh snapshot with `proxymock cloud pull snapshot <snapshot-id>`, check it for credentials and personal data, and copy the inbound and downstream directories into `recorded-golden/`. Then normalize it:

```
make proxymock-prepare-golden              # from backend/api-gateway/
```
