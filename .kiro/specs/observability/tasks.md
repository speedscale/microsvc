# Tasks — Observability

Tracing, propagation, export topology, metrics, log correlation and access points are
implemented (requirements 1–6). Open items, independent of each other:

- [ ] 1. Build Grafana business dashboards and Prometheus alert rules (PLAN.md Phase 10).
  _Req 4_
- [ ] 2. Fix frontend structured logs not appearing in `kubectl logs`. _Req 5_
- [ ] 3. Evaluate tail-based or probabilistic sampling for production while keeping error
  and slow-trace visibility; keep `always_on` in development. _Req 3.2_
