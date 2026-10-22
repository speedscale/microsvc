# Tasks — Observability

Tracing, propagation, export topology, metrics, log correlation and access points are
implemented for the instrumented services listed in requirements.md. Open items,
independent of each other:

- [ ] 1. Add the OTel SDK, W3C propagation, OTLP export and trace/span ids in logs to
  `user-service` (.NET), `fraud-service` and `notification-service` (Go). _Req 1, 5_
- [ ] 2. Build Grafana business dashboards and Prometheus alert rules (PLAN.md Phase 10).
  _Req 4_
- [ ] 3. Fix frontend structured logs not appearing in `kubectl logs`. _Req 5_
- [ ] 4. Evaluate tail-based or probabilistic sampling for production while keeping error
  and slow-trace visibility; keep `always_on` in development. _Req 3.2_
