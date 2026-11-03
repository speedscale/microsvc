# Readiness scorecard demo

Files for the walkthrough [Did that change make it better?](https://speedscale.com/blog/did-that-change-make-it-better/), which grades three builds of `api-gateway` with Speedscale's readiness scorecard.

- `cleanup.patch` removes `/api/users/check-email` from the gateway's open endpoints. It looks harmless and breaks that endpoint.
- `retry.patch` retries GET requests that get a 503 on the three service routes.
- `test-config-regression.json` uses the default readiness roles.
- `test-config-chaos.json` makes 15 percent of mocked dependency calls answer 503, blocks on Resilience below B and makes Regression advisory.
- `snapshot/proxymock` is a small hand-built fixture set of 27 inbound requests, not recorded production traffic. Its tokens belong to fixture users and expire in 2030.

Apply a patch, build the image, then reverse the patch:

```bash
git apply readiness-demo/retry.patch
docker build -t ghcr.io/speedscale/microsvc/api-gateway:v3-retry backend/api-gateway
git apply -R readiness-demo/retry.patch
```
