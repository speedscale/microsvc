# Tasks — Observability

Tracing, propagation, export topology, metrics, log correlation and access points are
implemented for the instrumented services listed in requirements.md, except the gaps
in tasks 1–2. Open items,
independent of each other:

- [ ] 1. Add the OTel SDK, W3C propagation, OTLP export and trace/span ids in logs to
  `user-service` (.NET), `fraud-service` and `notification-service` (Go). _Req 1, 5_
- [ ] 2. Expose a frontend Prometheus metrics endpoint and add it to `config/prometheus.yml`
  and `kubernetes/observability/prometheus-config.yaml`; neither scrapes it today. _Req 4.1_
- [ ] 3. Build Grafana business dashboards and Prometheus alert rules (PLAN.md Phase 10).
  _Req 4_
- [ ] 4. Fix frontend structured logs not appearing in `kubectl logs`. _Req 5_
- [ ] 5. Evaluate tail-based or probabilistic sampling for production while keeping error
  and slow-trace visibility; keep `always_on` in development. _Req 3.2_
