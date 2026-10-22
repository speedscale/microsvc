# Requirements — Observability

Distributed tracing, metrics and logs for `frontend`, `api-gateway`, `user-service`,
`accounts-service`, `transactions-service`, `fraud-service`, `notification-service`,
`ai-service` and the monitoring stack (otel-collector, Jaeger,
Prometheus, Grafana, Loki).

## Requirements

### 1. Tracing
1. Every service SHALL be instrumented with OpenTelemetry and emit spans over OTLP, with a
   unique `OTEL_SERVICE_NAME` and `service.namespace=banking-app`.
2. Context SHALL propagate with the W3C `tracecontext` propagator over HTTP and gRPC, so
   frontend → gateway → backend → database is one connected trace.

### 2. Export topology
1. Docker Compose: services export OTLP directly to Jaeger all-in-one (no collector).
2. Kubernetes: services export to `otel-collector`, whose traces pipeline is
   `otlp → filter → otlp` (to Jaeger). The filter SHALL drop health-check and
   actuator/security noise spans and keep business spans.

### 3. Configuration
1. Spring Boot services use gRPC OTLP on `4317`; the frontend uses HTTP/protobuf on `4318`.
2. Sampling is `always_on`.
3. Services SHALL NOT use the propagator name `w3c` (use `tracecontext`) or point a gRPC
   exporter at `4318`.

### 4. Metrics
1. Each service SHALL expose a Prometheus endpoint (`/actuator/prometheus` for Spring);
   Prometheus scrapes all of them and Grafana is provisioned against it.
2. transactions-service SHALL publish deposit, withdraw and transfer amount histograms.

### 5. Logs
Log lines SHALL include `traceId` and `spanId`, viewable via Compose logs locally and
Loki/Grafana in Kubernetes.

### 6. Access and verification
1. Jaeger `:16686`, Prometheus `:9090`, Grafana `:3001` SHALL be exposed.
2. A request through the app SHALL be findable as one trace in Jaeger.
