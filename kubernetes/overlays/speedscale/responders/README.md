# Speedscale responder mocks

In-cluster Speedscale **responder-only** `TrafficReplay` CRs that serve every
third-party outbound call for each service from recorded snapshots — fail-closed
(404 on no-match, no passthrough), so the app exercises its real integration code
paths with zero external egress.

Coverage (≈20 third-party APIs across 6 services):

| Service | Snapshot | Third-party calls |
|---|---|---|
| accounts | `banking-accounts-mocks` | Plaid (create→exchange→balance), OpenExchangeRates, Moody's |
| transactions | `banking-transactions-mocks` | Stripe PaymentIntents, PayPal, ComplyAdvantage |
| fraud | `banking-fraud-mocks` | Sift, Stripe Radar, MaxMind minFraud |
| notification | `banking-notification-mocks` | SendGrid, Twilio, Slack |
| user | `banking-user-mocks` | Socure, Jumio, HaveIBeenPwned |
| ai | `banking-ai-mocks` | Anthropic, OpenAI, Gemini, xAI, OpenRouter |

## Prerequisites (per Speedscale tenant)

The `snapshotID`s and the `banking-mock-fail-closed` test config below must
exist in the target tenant. Push them:

```sh
speedctl push snapshot <id>
speedctl push test-config banking-mock-fail-closed.json
```

`banking-mock-fail-closed.json` (in this directory) is a fail-closed mock
config: `responder.passthrough_mode: false` (404 on no-match, no real egress)
plus `cluster.sidecar_tls_out: true` so the operator still injects the
`speedscale-goproxy` sidecar. With the sidecar in path goproxy captures each
outbound rrpair and surfaces it in the live tap. The previous
`banking-mock-noproxy` config skipped the sidecar, which is why outbound was
invisible to capture.

The Speedscale operator must be installed in the cluster.

## Apply

```sh
kubectl apply -f kubernetes/overlays/speedscale/responders/
```

The operator provisions a responder pod + redis per service, injects the
`speedscale-goproxy` sidecar into each SUT, and routes outbound to the
responder. Remove with `kubectl delete -f .` to restore normal (real-egress)
behavior.

> Note: each `TrafficReplay` pins a `snapshotID`. These IDs are stable across the
> `elastic` (staging) and `external` (dev) tenants where the snapshots were pushed.
