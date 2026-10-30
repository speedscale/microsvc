# Service schema coverage requirements

Status: specification for the integration-test workflow. Native proxymock commands exist; a service-specific coverage run and its gate wiring still require verification.

## Contract and measurement

1. When schema coverage is requested, the workflow SHALL use native `proxymock coverage` against an accepted, versioned OpenAPI spec. It SHALL run native `proxymock validate` to check observed responses against that same spec.
2. The accepted spec SHALL be reviewed independently of the selected recording. A baseline FastAPI OpenAPI export can supply the draft contract; incomplete response models and unconstrained properties SHALL remain explicit limitations. Missing contract input SHALL be reported as unavailable coverage, not full coverage.
3. The workflow SHALL report separate covered/total counts for operations, documented response statuses and response properties. It SHALL list missing operations, status variants and field paths, plus unknown routes, undocumented statuses and unsupported bodies.
4. The workflow SHALL distinguish schema conformance, observed schema coverage, recorded replay accuracy and source-code coverage. Golden-derived schemas and golden-operation coverage SHALL be labeled as recording-relative checks.

## Execution and evidence

5. The workflow SHALL save native coverage JSON for the original inbound recording and the observed inbound replay output, using the same spec bytes and denominator. It SHALL retain the spec hash, recording/snapshot identity, application revision and CLI version with those results.
6. Unexecuted generated cases SHALL add no observed coverage. Exclusions and unsupported scenarios SHALL remain visible; the workflow SHALL NOT delete spec entries or weaken expectations to improve the result.
7. Incomplete coverage SHALL be reported even when validation and replay pass. The agreed acceptance policy SHALL determine whether the existing test/pre-commit entry point blocks it; `coverage` exit zero alone SHALL NOT mean complete coverage. A command error, malformed JSON or zero matched pairs SHALL prevent a successful coverage assessment.
8. Verification SHALL include a valid but incomplete recording, a schema violation, an empty/unmatched recording and a supplemental executed case. The incomplete recording SHALL expose gaps; the violating case SHALL fail validation; empty/unmatched input SHALL NOT pass acceptance; a supplemental case SHALL change coverage only after observation against the fixed spec.
9. Runtime support SHALL be verified per service. The existing Java gateway harness SHALL NOT be described as a working Python service runner without an actual run.
