# Service schema coverage design

Use the existing proxymock CLI and the repository's integration-test entry point. Keep schema measurement in the product; do not add another schema parser or coverage calculator to the application repository.

## Inputs

Select one service, a suitable cloud snapshot or local recording with inbound traffic, the recorded outbound dependencies, and an accepted OpenAPI contract. Export a FastAPI baseline spec through the service's normal OpenAPI endpoint when applicable, review its response schemas, and freeze it before comparing candidates. Store generated results outside committed fixture directories and keep credentials out of the spec and recordings.

## Native measurements

Set SPEC to the accepted spec file, INBOUND to the selected original inbound RRPair directory, REPLAY_INBOUND to the observed inbound replay directory and RESULTS to an existing ignored result directory. Run from the application repository.

```bash
proxymock coverage --spec "$SPEC" --in "$INBOUND" --json > "$RESULTS/coverage-recorded.json"
proxymock validate --spec "$SPEC" --in "$INBOUND"
# Execute the existing service replay with recorded dependency mocks first.
proxymock coverage --spec "$SPEC" --in "$REPLAY_INBOUND" --json > "$RESULTS/coverage-replayed.json"
proxymock validate --spec "$SPEC" --in "$REPLAY_INBOUND"
```

The native JSON contains summary.operations, summary.statuses and summary.fields, each with covered/total; matched_pairs; gaps; unknown_routes; undocumented_statuses; and unsupported_bodies. Present these as separate measurements rather than one combined percentage. Keep the source JSON available for inspection. Validate invocation success and output before interpreting the measurements.

## Coverage acceptance

The existing entry point consumes the native result and checks the service's agreed coverage requirements. Keep missing properties visible even if the chosen policy permits them. Coverage is a measurement command and can succeed while gaps remain; `validate` has its own conformance result. The gateway's schema_validate.py remains a separate golden-relative check, not a replacement for the native accepted-spec measurements.

For additional cases, reuse existing traffic or approved inputs, execute them against the service with recorded dependencies, and measure the actual responses against the pinned spec. Record proposed cases separately from exercised cases. Native `proxymock generate` can supply candidate requests when appropriate; generated responses are not evidence that the application exercised those cases.

## Verification boundary

An observed coverage increase does not establish that all assertions passed or that business behavior is correct. Keep invariant and regression checks separate. Use controlled local fixtures for measurement controls; do not plant application defects or invoke live third-party providers merely to produce a demonstration result. No customer-specific orchestration or new schema engine belongs in this spec.
