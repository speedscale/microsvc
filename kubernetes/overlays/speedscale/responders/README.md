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

The `snapshotID`s and `testConfigID` below must exist in the target tenant. Push
them with `speedctl push snapshot <id>` / `speedctl push test-config banking-mock-noproxy`.
`banking-mock-noproxy` is a copy of `standard` with `responder.passthroughMode: false`
(fail-closed). The Speedscale operator must be installed in the cluster.

## Apply

```sh
kubectl apply -f kubernetes/overlays/speedscale/responders/
```

The operator provisions a responder pod + redis per service and injects `/etc/hosts`
into each SUT, redirecting that service's external hosts to its responder. Remove
with `kubectl delete -f .` to restore normal (real-egress) behavior.

> Note: each `TrafficReplay` pins a `snapshotID`. These IDs are stable across the
> `elastic` (staging) and `external` (dev) tenants where the snapshots were pushed.
