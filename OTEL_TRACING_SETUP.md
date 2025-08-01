# OpenTelemetry Tracing Setup and Configuration

## Overview

This document explains the OpenTelemetry (OTEL) tracing configuration for the banking microservices application and the fixes implemented to resolve trace linking issues between services.

## Issues Identified and Fixed

### 1. API Gateway Missing OpenTelemetry Configuration

**Problem**: The API Gateway had OpenTelemetry dependencies but no configuration in `application.yml`, preventing it from participating in distributed tracing.

**Solution**: Added comprehensive OpenTelemetry configuration to `backend/api-gateway/src/main/resources/application.yml`:

```yaml
# OpenTelemetry Configuration
otel:
  service:
    name: ${spring.application.name}
  exporter:
    otlp:
      protocol: http/protobuf
      endpoint: http://localhost:4318
  traces:
    exporter: otlp
    propagators: w3c
    sampler:
      type: always_on
  metrics:
    exporter: otlp
  logs:
    exporter: otlp
  propagation:
    type: w3c
```

### 2. Missing Environment Variables in Docker Compose

**Problem**: Docker Compose services lacked OpenTelemetry environment variables, preventing proper trace propagation and service identification.

**Solution**: Added OpenTelemetry environment variables to all services in `docker-compose.yml`:

```yaml
# OpenTelemetry Configuration
- OTEL_SERVICE_NAME=service-name
- OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318
- OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
- OTEL_TRACES_EXPORTER=otlp
- OTEL_METRICS_EXPORTER=otlp
- OTEL_LOGS_EXPORTER=otlp
- OTEL_TRACES_SAMPLER=always_on
- OTEL_PROPAGATORS=w3c
- OTEL_RESOURCE_ATTRIBUTES=service.namespace=banking-app
```

### 3. Inconsistent OpenTelemetry Endpoints

**Problem**: Services were configured to use different OpenTelemetry endpoints (4317 vs 4318), causing trace data to be sent to different collectors.

**Solution**: Standardized all services to use `http://jaeger:4318` as the OTLP endpoint.

### 4. Missing Trace Propagation Configuration

**Problem**: Services lacked explicit trace propagation configuration, preventing proper trace context propagation between services.

**Solution**: Added explicit trace propagation configuration:
- Set `OTEL_PROPAGATORS=w3c` for W3C trace context propagation
- Configured `otel.propagation.type: w3c` in application.yml files
- Set `otel.traces.propagators: w3c` for explicit propagator configuration

## Current Architecture

### Services and Their Tracing Configuration

1. **Frontend** (`frontend`)
   - Service Name: `frontend`
   - Endpoint: `http://jaeger:4318/v1/traces`
   - Instrumentation: Custom Next.js instrumentation in `frontend/src/instrumentation.ts`

2. **API Gateway** (`api-gateway`)
   - Service Name: `api-gateway`
   - Endpoint: `http://jaeger:4318`
   - Instrumentation: Spring Boot OpenTelemetry starter

3. **User Service** (`user-service`)
   - Service Name: `user-service`
   - Endpoint: `http://jaeger:4318`
   - Instrumentation: Spring Boot OpenTelemetry starter

4. **Accounts Service** (`accounts-service`)
   - Service Name: `accounts-service`
   - Endpoint: `http://jaeger:4318`
   - Instrumentation: Spring Boot OpenTelemetry starter

5. **Transactions Service** (`transactions-service`)
   - Service Name: `transactions-service`
   - Endpoint: `http://jaeger:4318`
   - Instrumentation: Spring Boot OpenTelemetry starter

### Observability Stack

- **Jaeger**: Trace collection and visualization (port 16686)
- **Prometheus**: Metrics collection (port 9090)
- **Grafana**: Metrics visualization (port 3001)

## Trace Flow

With the current configuration, traces should flow as follows:

1. **Frontend** → **API Gateway**: Frontend makes HTTP requests to API Gateway
2. **API Gateway** → **Backend Services**: API Gateway routes requests to appropriate backend services
3. **Backend Services** → **Database**: Backend services make database queries
4. **All Services** → **Jaeger**: All services send trace data to Jaeger collector

## Key Configuration Files Modified

1. `backend/api-gateway/src/main/resources/application.yml` - Added OpenTelemetry configuration
2. `docker-compose.yml` - Added OpenTelemetry environment variables for all services
3. `config/application-docker.yml` - Updated OpenTelemetry configuration for consistency
4. `kubernetes/base/configmaps/app-config.yaml` - Updated with comprehensive OpenTelemetry configuration for Kubernetes deployment

## Environment Variables Explained

- `OTEL_SERVICE_NAME`: Identifies the service in traces
- `OTEL_EXPORTER_OTLP_ENDPOINT`: OTLP collector endpoint
- `OTEL_EXPORTER_OTLP_PROTOCOL`: Protocol for sending traces (http/protobuf)
- `OTEL_TRACES_EXPORTER`: Trace exporter type (otlp)
- `OTEL_METRICS_EXPORTER`: Metrics exporter type (otlp)
- `OTEL_LOGS_EXPORTER`: Logs exporter type (otlp)
- `OTEL_TRACES_SAMPLER`: Sampling strategy (always_on for 100% sampling)
- `OTEL_PROPAGATORS`: Trace context propagation format (w3c)
- `OTEL_RESOURCE_ATTRIBUTES`: Additional resource attributes for service identification

## Verification Steps

### Docker Compose

To verify that trace linking is working with Docker Compose:

1. **Start the application**:
   ```bash
   docker-compose up -d
   ```

2. **Generate some traffic** by accessing the frontend at `http://localhost:3000`

3. **Check Jaeger UI** at `http://localhost:16686`:
   - Look for traces that span multiple services
   - Verify that API Gateway traces show calls to backend services
   - Verify that backend service traces show database calls

4. **Check service logs** for trace IDs:
   - All services should log trace IDs in the format `[traceId,spanId]`
   - Trace IDs should be consistent across related log entries

5. **Run the test script**:
   ```bash
   ./scripts/test-trace-linking.sh
   ```

### Kubernetes

To verify that trace linking is working with Kubernetes:

1. **Deploy the application**:
   ```bash
   kubectl apply -k kubernetes/base
   kubectl apply -k kubernetes/observability
   ```

2. **Generate some traffic** by accessing the frontend service

3. **Check Jaeger UI**:
   ```bash
   kubectl port-forward svc/jaeger 16686:16686 -n banking-app
   ```
   Then open `http://localhost:16686`

4. **Check service logs** for trace IDs:
   ```bash
   kubectl logs -f deployment/api-gateway -n banking-app | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'
   kubectl logs -f deployment/accounts-service -n banking-app | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'
   ```

5. **Run the test script**:
   ```bash
   ./scripts/test-k8s-trace-linking.sh
   ```

## Troubleshooting

### If traces are not linking:

1. **Check environment variables**: Ensure all services have the correct OpenTelemetry environment variables
2. **Verify Jaeger connectivity**: Check that services can reach the Jaeger collector
3. **Check propagation**: Ensure `OTEL_PROPAGATORS=w3c` is set on all services
4. **Verify sampling**: Ensure `OTEL_TRACES_SAMPLER=always_on` is set for 100% sampling

### If database traces are missing:

1. **Check database instrumentation**: The `opentelemetry-spring-boot-starter` includes JDBC and HikariCP instrumentation
2. **Verify database connection**: Ensure database connections are working
3. **Check log levels**: Set `logging.level.org.hibernate.SQL=DEBUG` to see SQL queries

## Next Steps

1. **Monitor trace performance**: Watch for any performance impact from 100% sampling
2. **Add custom spans**: Consider adding custom spans for business logic
3. **Configure sampling**: Adjust sampling rates based on production needs
4. **Add metrics correlation**: Correlate traces with metrics and logs
5. **Kubernetes-specific considerations**: 
   - Consider using OpenTelemetry Operator for more advanced configuration
   - Implement distributed tracing with service mesh (Istio, Linkerd)
   - Add trace sampling based on request patterns and error rates 