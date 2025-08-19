# Observability & Monitoring

This document covers the observability stack for the Banking Microservices Application, including distributed tracing, metrics, and logging.

## Overview

The application implements the three pillars of observability:
- **Traces**: OpenTelemetry with Jaeger
- **Metrics**: Micrometer with Prometheus and Grafana
- **Logs**: Centralized logging with structured output

## Architecture

```
[Services] → [OpenTelemetry] → [OTLP Collector] → [Jaeger UI]
     ↓              ↓
[Micrometer] → [Prometheus] → [Grafana]
     ↓
[Logs] → [Docker Compose Logs]
```

## Quick Start

### Starting the Observability Stack
```bash
# Start all monitoring services
docker-compose up -d prometheus grafana jaeger otel-collector

# Verify services are running
curl http://localhost:9090/api/v1/targets  # Prometheus targets
curl http://localhost:16686/api/services   # Jaeger services
curl http://localhost:3001                 # Grafana (admin/admin)
```

### Access Points
- **Jaeger UI**: http://localhost:16686 - Distributed tracing
- **Prometheus**: http://localhost:9090 - Metrics and targets
- **Grafana**: http://localhost:3001 - Dashboards and visualization
- **OTLP Collector**: http://localhost:4317 (gRPC), http://localhost:4318 (HTTP)

## Distributed Tracing

### OpenTelemetry Configuration

All services are instrumented with OpenTelemetry:

```yaml
# Environment variables for all services
OTEL_SERVICE_NAME: "user-service"  # Unique per service
OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4318"
OTEL_RESOURCE_ATTRIBUTES: "service.namespace=banking-app"
OTEL_TRACES_EXPORTER: "otlp"
OTEL_METRICS_EXPORTER: "otlp"
```

### Trace Propagation

HTTP headers automatically propagate trace context:
- `traceparent`: W3C Trace Context header
- `tracestate`: Additional trace state information

### Custom Instrumentation

**Backend Services (Java)**:
```java
@Autowired
private Tracer tracer;

// Create custom span
Span span = tracer.spanBuilder("custom-operation")
    .setAttribute("user.id", userId)
    .startSpan();
try (Scope scope = span.makeCurrent()) {
    // Your business logic here
    span.setStatus(StatusCode.OK);
} catch (Exception e) {
    span.recordException(e);
    span.setStatus(StatusCode.ERROR, e.getMessage());
} finally {
    span.end();
}
```

**Frontend (TypeScript)**:
```typescript
import { trace } from '@opentelemetry/api';

const tracer = trace.getTracer('frontend');

// Create span for API call
const span = tracer.startSpan('api-call', {
  attributes: {
    'http.method': 'POST',
    'http.url': '/api/users/register'
  }
});

try {
  const response = await fetch('/api/users/register', options);
  span.setAttributes({
    'http.status_code': response.status
  });
} finally {
  span.end();
}
```

### Viewing Traces

1. **Open Jaeger UI**: http://localhost:16686
2. **Select Service**: Choose from dropdown (user-service, accounts-service, etc.)
3. **Find Traces**: Use filters like operation name, duration, or tags
4. **Analyze Spans**: Click on traces to see detailed span information

### Common Trace Patterns

**Successful User Registration Flow**:
```
frontend → api-gateway → user-service → postgres
                      ↓
                  accounts-service → postgres
```

**Error Scenarios**:
- Database connection failures
- Service timeout errors
- Validation errors with stack traces

## Metrics

### Micrometer Integration

All backend services expose metrics via Spring Boot Actuator:

```bash
# View available metrics
curl http://localhost:8081/actuator/metrics

# View specific metric
curl http://localhost:8081/actuator/metrics/http.server.requests
curl http://localhost:8081/actuator/metrics/jvm.memory.used
```

### Prometheus Configuration

**Prometheus scrapes metrics from**:
- User Service: http://user-service:8081/actuator/prometheus
- Accounts Service: http://accounts-service:8082/actuator/prometheus  
- Transactions Service: http://transactions-service:8083/actuator/prometheus
- API Gateway: http://api-gateway:8080/actuator/prometheus

**Key Metrics**:
- `http_server_requests_total` - HTTP request counts
- `http_server_requests_duration_seconds` - Request latency
- `jvm_memory_used_bytes` - Memory usage
- `database_connections_active` - Database connection pool
- `custom_business_metrics_total` - Custom business metrics

### Custom Metrics

**Counter Example**:
```java
@Component
public class UserMetrics {
    private final Counter userRegistrations;
    
    public UserMetrics(MeterRegistry meterRegistry) {
        this.userRegistrations = Counter.builder("user.registrations")
            .description("Number of user registrations")
            .tag("service", "user-service")
            .register(meterRegistry);
    }
    
    public void incrementRegistrations() {
        userRegistrations.increment();
    }
}
```

**Timer Example**:
```java
@Timed(value = "user.registration.duration", description = "User registration duration")
public User registerUser(UserRegistrationRequest request) {
    // Implementation
}
```

### PromQL Queries

**Common Queries**:
```promql
# Request rate per service
rate(http_server_requests_total[5m])

# 95th percentile response time
histogram_quantile(0.95, rate(http_server_requests_duration_seconds_bucket[5m]))

# Error rate
rate(http_server_requests_total{status=~"5.."}[5m])

# Memory usage by service
jvm_memory_used_bytes{area="heap"}

# Database connections
hikaricp_connections_active{pool="banking_app"}
```

## Grafana Dashboards

### Pre-built Dashboards

1. **JVM Dashboard**: JVM metrics for all Java services
2. **HTTP Dashboard**: Request rates, latencies, error rates
3. **Database Dashboard**: Connection pools, query metrics
4. **Business Metrics**: Custom business KPIs

### Creating Custom Dashboards

1. **Access Grafana**: http://localhost:3001 (admin/admin)
2. **Add Data Source**: Prometheus (http://prometheus:9090)
3. **Import Dashboard**: Use dashboard ID or JSON
4. **Create Panel**: Add PromQL queries and visualizations

### Dashboard Variables

```
# Service variable
label_values(http_server_requests_total, service)

# Instance variable  
label_values(http_server_requests_total{service="$service"}, instance)
```

### Alert Rules

**High Error Rate Alert**:
```yaml
groups:
  - name: banking_app
    rules:
      - alert: HighErrorRate
        expr: rate(http_server_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Service {{ $labels.service }} has error rate above 10%"
```

## Logging

### Structured Logging

All services use structured JSON logging:

```json
{
  "timestamp": "2025-01-20T10:30:00.123Z",
  "level": "INFO",
  "thread": "http-nio-8081-exec-1",
  "logger": "com.banking.userservice.controller.UserController",
  "message": "User registration successful",
  "trace_id": "80f198ee56343ba864fe8b2a57d3eff7",
  "span_id": "e457b5a2e4d86bd1",
  "user_id": "12345",
  "username": "john_doe"
}
```

### Log Levels

**Configuration in application.yml**:
```yaml
logging:
  level:
    com.banking: INFO
    org.springframework.web: DEBUG
    org.hibernate.SQL: DEBUG
```

**Runtime Configuration**:
```bash
# Change log level without restart
curl -X POST "http://localhost:8081/actuator/loggers/com.banking.userservice" \
  -H "Content-Type: application/json" \
  -d '{"configuredLevel": "DEBUG"}'
```

### Centralized Logging

**View logs across all services**:
```bash
# All services
docker-compose logs -f

# Specific services
docker-compose logs -f user-service accounts-service

# Filter by log level
docker-compose logs | grep '"level":"ERROR"'

# Search for specific user
docker-compose logs | grep '"user_id":"12345"'
```

### Log Correlation

Logs are automatically correlated with traces using:
- `trace_id`: Links log entries to distributed traces
- `span_id`: Links to specific span within trace
- `user_id`: Business context correlation

## Performance Monitoring

### SLA/SLI Definitions

**Service Level Indicators**:
- Availability: 99.9% uptime
- Latency: 95% of requests < 500ms
- Error Rate: < 1% error rate
- Throughput: Support 1000 req/min per service

**Monitoring Queries**:
```promql
# Availability
up{job=~".*-service"}

# Latency SLI
histogram_quantile(0.95, 
  rate(http_server_requests_duration_seconds_bucket[5m])
) < 0.5

# Error Rate SLI  
(
  rate(http_server_requests_total{status=~"5.."}[5m]) / 
  rate(http_server_requests_total[5m])
) < 0.01
```

### Resource Monitoring

**JVM Metrics**:
- Heap memory usage and GC activity
- Thread pool utilization
- CPU usage per service

**Database Metrics**:
- Connection pool usage
- Query execution time
- Lock wait time
- Active connections

**Infrastructure Metrics**:
- Container CPU/Memory usage
- Network I/O
- Disk space utilization

## Debugging with Observability

### Trace-Driven Debugging

1. **Identify Slow Requests**: Use Jaeger to find high-latency traces
2. **Analyze Span Details**: Look at span attributes and events
3. **Find Root Cause**: Identify bottleneck spans in the trace
4. **Correlate with Logs**: Use trace_id to find related log entries

### Error Investigation

1. **Error Detection**: Prometheus alerts or Grafana dashboards
2. **Trace Analysis**: Find failing requests in Jaeger
3. **Log Correlation**: Search logs using trace_id
4. **Root Cause**: Analyze exception stack traces and context

### Performance Analysis

```promql
# Top slowest endpoints
topk(5, 
  histogram_quantile(0.95, 
    rate(http_server_requests_duration_seconds_bucket[5m])
  )
)

# Database query performance
histogram_quantile(0.95, 
  rate(database_query_duration_seconds_bucket[5m])
) by (query_type)
```

## Best Practices

### Instrumentation

1. **Meaningful Span Names**: Use descriptive operation names
2. **Rich Attributes**: Add business context to spans
3. **Error Handling**: Always record exceptions in spans
4. **Sampling**: Use appropriate sampling rates for production

### Metrics

1. **Cardinality Control**: Avoid high-cardinality tags
2. **Business Metrics**: Track KPIs relevant to business
3. **SLI Metrics**: Focus on user-facing indicators
4. **Resource Metrics**: Monitor system health

### Logging

1. **Structured Format**: Use JSON for machine readability
2. **Context Propagation**: Include trace IDs in all logs
3. **Log Levels**: Use appropriate levels (DEBUG, INFO, WARN, ERROR)
4. **Sensitive Data**: Never log passwords or PII

## Troubleshooting Observability

### No Traces in Jaeger

1. **Check Service Configuration**:
   ```bash
   docker-compose exec user-service env | grep OTEL
   ```

2. **Verify OTLP Collector**:
   ```bash
   curl http://localhost:4318/v1/traces
   docker-compose logs otel-collector
   ```

3. **Enable Debug Logging**:
   ```bash
   export OTEL_LOG_LEVEL=DEBUG
   docker-compose restart user-service
   ```

### Missing Metrics in Prometheus

1. **Check Actuator Endpoints**:
   ```bash
   curl http://localhost:8081/actuator/health
   curl http://localhost:8081/actuator/prometheus
   ```

2. **Verify Prometheus Targets**:
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

3. **Check Service Discovery**:
   ```bash
   docker-compose logs prometheus
   ```

### Grafana Dashboard Issues

1. **Data Source Configuration**: Ensure Prometheus URL is correct
2. **Query Validation**: Test PromQL queries in Prometheus UI
3. **Time Range**: Verify dashboard time range settings
4. **Variable Values**: Check dashboard variable configurations

## Production Considerations

### Sampling

Configure appropriate sampling rates:
```yaml
# 10% sampling for high-throughput services
OTEL_TRACES_SAMPLER: "traceidratio"
OTEL_TRACES_SAMPLER_ARG: "0.1"
```

### Retention

Configure data retention policies:
- **Jaeger**: 7 days for traces
- **Prometheus**: 15 days for metrics  
- **Logs**: 30 days with rotation

### Security

- Enable authentication for Grafana
- Secure Prometheus and Jaeger endpoints
- Use TLS for OTLP communication
- Sanitize sensitive data in traces/logs