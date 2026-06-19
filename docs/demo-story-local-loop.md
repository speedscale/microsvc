# Demo Story Local Loop

Use this loop to test the observability demo locally before waiting on staging.

## First Run

```bash
scripts/demo-story-loop.sh start-minikube
scripts/demo-story-loop.sh build
scripts/demo-story-loop.sh deploy
scripts/demo-story-loop.sh api-check
scripts/demo-story-loop.sh browser-check
scripts/demo-story-loop.sh traffic-check
scripts/demo-story-loop.sh web-check
scripts/demo-story-loop.sh replay-check
scripts/demo-story-loop.sh transfer-replay-check
scripts/demo-story-loop.sh fresh-capture-check
```

The first `build` is slow because it warms Docker, Maven, npm, and Python caches inside the `speedscale-demo-mini` minikube profile.

## Repair Loop

After the first run, rebuild only the services you changed:

```bash
scripts/demo-story-loop.sh build frontend
scripts/demo-story-loop.sh deploy frontend
scripts/demo-story-loop.sh api-check
scripts/demo-story-loop.sh browser-check
```

For a frontend-only bug, this is usually enough:

```bash
scripts/demo-story-loop.sh once frontend
```

To keep cycling a set of workloads until one fails:

```bash
scripts/demo-story-loop.sh loop frontend api-gateway transactions-service
```

## What The Checks Prove

`api-check` logs in as `harper.clark.001`, verifies funded checking and savings accounts, and confirms the transfer-review request returns the expected compliance-review response.

`browser-check` opens the local frontend through a temporary port-forward, verifies the homepage shows Harper Clark, logs in with the prefilled demo user, starts the transfer review, and fails if the transfer page crashes.

`traffic-check` verifies that a proxymock capture directory contains the demo evidence: frontend, gateway, accounts, transactions, user, fraud gRPC, notification, Postgres, Redis, Kafka, and external API traffic. Pass a capture directory explicitly or set `PROXYMOCK_CAPTURE_DIR`; otherwise the newest `live-*` or `imported-s3-*` capture under `backend/ai-service/proxymock` is used.

`web-check` starts proxymock web against the local proxymock workspace, selects the live banking run, and verifies that Pull, Replay, the live run row count, and banking traffic rows are visible.

`replay-check` extracts captured `banking-gateway` login requests, port-forwards the local gateway, and runs `proxymock replay` with failure and result-match checks.

`transfer-replay-check` records the transfer-review request through proxymock's inbound proxy, confirms the live app returns the expected `400`, then replays that captured request against the local gateway and fails if replay does not include a successful `/api/transactions/transfer` result.

`fresh-capture-check` writes a new `local-transfer-*` run under the local proxymock workspace, replays it against the gateway, then starts proxymock web and verifies that exact fresh run is visible with login, accounts, and transfer traffic rows.

`deploy [service...]` restarts the selected workloads after applying the overlay. This matters because local images reuse the `:local` tag, so an unchanged Kubernetes manifest is not enough to prove a rebuilt container is running.

After the cluster is healthy, `deploy [service...]` waits only for the selected workload plus the seed job. A fresh or unhealthy cluster still gets a full rollout wait.

`loop [service...]` runs one workload at a time and stops on the first failing build, rollout, API check, or browser check. Set `LOOP_DELAY_SECONDS` if you want a pause between iterations.

The minikube loop overlay uses a short local pod termination grace period so repeated restarts do not wait on the production defaults.

## Defaults

- config: `~/spd-workspace/speedstack/instances/microsvc-demo-mini/minikube.env`
- minikube profile: `speedscale-demo-mini`
- Kubernetes context: `speedscale-demo-mini`
- namespace: `banking-app`
- overlay: `kubernetes/overlays/minikube-loop`
- manual frontend port-forward: `http://127.0.0.1:3000`
- browser-check port: random local port, or `BROWSER_FRONTEND_PORT` if set
