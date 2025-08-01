# OpenTelemetry Configuration for Kubernetes

## Overview

This document explains the OpenTelemetry (OTEL) tracing configuration for the banking microservices application deployed on Kubernetes and the fixes implemented to resolve trace linking issues.

## Issues Fixed in Kubernetes Manifests

### 1. Inconsistent OpenTelemetry Endpoints

**Problem**: Services were configured to use different OpenTelemetry endpoints (4317 vs 4318), causing trace data to be sent to different collectors.

**Solution**: Standardized all services to use `http://jaeger:4318` as the OTLP endpoint.

### 2. Missing OpenTelemetry Environment Variables

**Problem**: Individual service ConfigMaps lacked comprehensive OpenTelemetry environment variables, preventing proper trace propagation and service identification.

**Solution**: Added complete OpenTelemetry environment variables to all service ConfigMaps in `kubernetes/base/configmaps/app-config.yaml`.

### 3. Missing Trace Propagation Configuration

**Problem**: Services lacked explicit trace propagation configuration, preventing proper trace context propagation between services.

**Solution**: Added explicit trace propagation configuration to all services.

## Configuration Details

### Global Configuration (app-config ConfigMap)

The main `app-config` ConfigMap contains shared OpenTelemetry configuration:

```yaml
# Observability
OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger:4318"
OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
OTEL_TRACES_EXPORTER: "otlp"
OTEL_METRICS_EXPORTER: "otlp"
OTEL_LOGS_EXPORTER: "otlp"
OTEL_TRACES_SAMPLER: "always_on"
OTEL_PROPAGATORS: "w3c"
OTEL_RESOURCE_ATTRIBUTES: "service.namespace=banking-app"
```

### Service-Specific Configuration

Each service has its own ConfigMap with service-specific settings:

#### User Service
```yaml
OTEL_SERVICE_NAME: "user-service"
OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger:4318"
OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
OTEL_TRACES_EXPORTER: "otlp"
OTEL_METRICS_EXPORTER: "otlp"
OTEL_LOGS_EXPORTER: "otlp"
OTEL_TRACES_SAMPLER: "always_on"
OTEL_PROPAGATORS: "w3c"
```

#### Accounts Service
```yaml
OTEL_SERVICE_NAME: "accounts-service"
OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger:4318"
OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
OTEL_TRACES_EXPORTER: "otlp"
OTEL_METRICS_EXPORTER: "otlp"
OTEL_LOGS_EXPORTER: "otlp"
OTEL_TRACES_SAMPLER: "always_on"
OTEL_PROPAGATORS: "w3c"
```

#### Transactions Service
```yaml
OTEL_SERVICE_NAME: "transactions-service"
OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger:4318"
OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
OTEL_TRACES_EXPORTER: "otlp"
OTEL_METRICS_EXPORTER: "otlp"
OTEL_LOGS_EXPORTER: "otlp"
OTEL_TRACES_SAMPLER: "always_on"
OTEL_PROPAGATORS: "w3c"
```

#### API Gateway
```yaml
OTEL_SERVICE_NAME: "api-gateway"
OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger:4318"
OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
OTEL_TRACES_EXPORTER: "otlp"
OTEL_METRICS_EXPORTER: "otlp"
OTEL_LOGS_EXPORTER: "otlp"
OTEL_TRACES_SAMPLER: "always_on"
OTEL_PROPAGATORS: "w3c"
MANAGEMENT_TRACING_ENABLED: "true"
MANAGEMENT_TRACING_SAMPLING_PROBABILITY: "1.0"
```

#### Frontend
```yaml
OTEL_SERVICE_NAME: "frontend"
OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger:4318/v1/traces"
OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
OTEL_TRACES_EXPORTER: "otlp"
OTEL_METRICS_EXPORTER: "otlp"
OTEL_LOGS_EXPORTER: "otlp"
OTEL_TRACES_SAMPLER: "always_on"
OTEL_PROPAGATORS: "w3c"
OTEL_RESOURCE_ATTRIBUTES: "service.namespace=banking-app"
```

## Deployment Architecture

### Services and Their Tracing Configuration

1. **Frontend** (`frontend`)
   - Service Name: `frontend`
   - Endpoint: `http://jaeger:4318/v1/traces`
   - Instrumentation: Custom Next.js instrumentation

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

- **Jaeger**: Trace collection and visualization
  - UI: Port 16686
  - OTLP HTTP: Port 4318
  - OTLP gRPC: Port 4317
  - Legacy Collector: Port 14268

- **Prometheus**: Metrics collection (port 9090)
- **Grafana**: Metrics visualization (port 3000)

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

## Deployment Configuration

### ConfigMap Usage

All deployments use `envFrom` to load environment variables from ConfigMaps:

```yaml
envFrom:
- configMapRef:
    name: app-config
- configMapRef:
    name: service-specific-config
```

### Jaeger Configuration

The Jaeger deployment is configured with OTLP support:

```yaml
env:
- name: COLLECTOR_OTLP_ENABLED
  value: "true"
ports:
- containerPort: 4318
  name: otlp-http
- containerPort: 4317
  name: otlp-grpc
```

## Trace Flow in Kubernetes

With the current configuration, traces should flow as follows:

1. **Frontend** → **API Gateway**: Frontend makes HTTP requests to API Gateway
2. **API Gateway** → **Backend Services**: API Gateway routes requests to appropriate backend services
3. **Backend Services** → **Database**: Backend services make database queries
4. **All Services** → **Jaeger**: All services send trace data to Jaeger collector

## Verification Steps

To verify that trace linking is working in Kubernetes:

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

4. **Look for traces** that span multiple services:
   - Frontend → API Gateway → Backend Service → Database
   - Consistent trace IDs across related spans

5. **Check service logs** for trace IDs:
   ```bash
   kubectl logs -f deployment/api-gateway -n banking-app | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'
   kubectl logs -f deployment/accounts-service -n banking-app | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'
   ```

## Troubleshooting

### If traces are not linking:

1. **Check ConfigMaps**: Ensure all services have the correct OpenTelemetry environment variables
   ```bash
   kubectl get configmap -n banking-app
   kubectl describe configmap app-config -n banking-app
   ```

2. **Verify Jaeger connectivity**: Check that services can reach the Jaeger collector
   ```bash
   kubectl exec -it deployment/api-gateway -n banking-app -- curl -v http://jaeger:4318
   ```

3. **Check propagation**: Ensure `OTEL_PROPAGATORS=w3c` is set on all services
   ```bash
   kubectl exec -it deployment/api-gateway -n banking-app -- env | grep OTEL
   ```

4. **Verify sampling**: Ensure `OTEL_TRACES_SAMPLER=always_on` is set for 100% sampling

### If database traces are missing:

1. **Check database instrumentation**: The `opentelemetry-spring-boot-starter` includes JDBC and HikariCP instrumentation
2. **Verify database connection**: Ensure database connections are working
3. **Check log levels**: Set `LOGGING_LEVEL_ORG_HIBERNATE_SQL=DEBUG` to see SQL queries

## Key Files Modified

1. `kubernetes/base/configmaps/app-config.yaml` - Updated with comprehensive OpenTelemetry configuration
2. All service-specific ConfigMaps - Added missing OpenTelemetry environment variables

## Next Steps

1. **Monitor trace performance**: Watch for any performance impact from 100% sampling
2. **Add custom spans**: Consider adding custom spans for business logic
3. **Configure sampling**: Adjust sampling rates based on production needs
4. **Add metrics correlation**: Correlate traces with metrics and logs
5. **Consider distributed tracing**: Implement more sophisticated trace sampling strategies 