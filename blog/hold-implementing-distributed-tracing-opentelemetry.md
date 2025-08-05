# Implementing Distributed Tracing with OpenTelemetry in Banking Microservices

**Target Keywords**: opentelemetry spring boot, distributed tracing jaeger, spring boot observability  
**Estimated Monthly Searches**: 5,400 + 3,600 + 2,900 = 11,900

## Introduction

Debugging issues in microservices architectures can be challenging without proper observability. This comprehensive guide demonstrates implementing distributed tracing using OpenTelemetry in a banking application, providing end-to-end visibility across all services.

## Why Distributed Tracing Matters

In a banking application, a single user transaction might involve:
1. **Frontend** → Authentication request
2. **API Gateway** → Route validation  
3. **User Service** → JWT token validation
4. **Accounts Service** → Balance verification
5. **Transactions Service** → Transaction processing
6. **Database** → Data persistence

Without distributed tracing, debugging failures across this chain becomes nearly impossible.

## OpenTelemetry Architecture

### Core Components

**OpenTelemetry SDK**: Provides APIs for instrumentation
**OTLP Exporter**: Sends telemetry data to backends  
**Trace Propagation**: Maintains trace context across services
**Jaeger Backend**: Collects and visualizes traces

### Banking Application Flow

```
Client Request → Frontend → API Gateway → User Service → Accounts Service → Transactions Service
     ↓              ↓           ↓             ↓              ↓                    ↓
 Trace Start    Add Span    Add Span     Add Span       Add Span           Trace End
```

## Implementation in Spring Boot Services

### 1. Dependencies Configuration

Add OpenTelemetry dependencies to each service:

```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-api</artifactId>
    <version>1.32.0</version>
</dependency>
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-sdk</artifactId>
    <version>1.32.0</version>
</dependency>
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
    <version>1.32.0</version>
</dependency>
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-spring-boot-starter</artifactId>
    <version>1.32.0-alpha</version>
</dependency>
```

### 2. OpenTelemetry Configuration

Create standardized configuration across all services:

```java
// OtelConfig.java
@Configuration
public class OtelConfig {
    
    @Bean
    public OpenTelemetry openTelemetry() {
        return OpenTelemetrySdk.builder()
            .setTracerProvider(
                SdkTracerProvider.builder()
                    .addSpanProcessor(BatchSpanProcessor.builder(
                        OtlpGrpcSpanExporter.builder()
                            .setEndpoint("http://jaeger:4317")
                            .build())
                        .build())
                    .setResource(Resource.getDefault()
                        .merge(Resource.builder()
                            .put(ResourceAttributes.SERVICE_NAME, getServiceName())
                            .put(ResourceAttributes.SERVICE_NAMESPACE, "banking-app")
                            .put(ResourceAttributes.SERVICE_VERSION, "1.1.11")
                            .build()))
                    .setSampler(Sampler.alwaysOn())
                    .build())
            .setMeterProvider(
                SdkMeterProvider.builder()
                    .registerMetricReader(PeriodicMetricReader.builder(
                        OtlpGrpcMetricExporter.builder()
                            .setEndpoint("http://jaeger:4317")
                            .build())
                        .build())
                    .setResource(Resource.getDefault()
                        .merge(Resource.builder()
                            .put(ResourceAttributes.SERVICE_NAME, getServiceName())
                            .build()))
                    .build())
            .setPropagators(ContextPropagators.create(
                TextMapPropagator.composite(
                    TraceContext.getInstance(),
                    Baggage.getInstance()
                )))
            .build();
    }
    
    private String getServiceName() {
        return System.getProperty("spring.application.name", "banking-service");
    }
}
```

### 3. Application Configuration

Standardize OpenTelemetry settings in `application.yml`:

```yaml
# application.yml
spring:
  application:
    name: user-service
  
otel:
  service:
    name: ${spring.application.name}
  exporter:
    otlp:
      protocol: grpc
      endpoint: http://jaeger:4317
  traces:
    exporter: otlp
    propagators: tracecontext
    sampler:
      type: always_on
  metrics:
    exporter: otlp
  logs:
    exporter: otlp
  propagation:
    type: tracecontext

# Environment variables (Docker/Kubernetes)
# OTEL_SERVICE_NAME=user-service
# OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317
# OTEL_EXPORTER_OTLP_PROTOCOL=grpc
# OTEL_TRACES_EXPORTER=otlp
# OTEL_TRACES_SAMPLER=always_on
# OTEL_PROPAGATORS=tracecontext
# OTEL_RESOURCE_ATTRIBUTES=service.namespace=banking-app
```

### 4. Custom Instrumentation

Add business-specific spans to banking operations:

```java
// TransactionService.java
@Service
public class TransactionService {
    
    private final Tracer tracer;
    
    public TransactionService(OpenTelemetry openTelemetry) {
        this.tracer = openTelemetry.getTracer("banking-transactions");
    }
    
    @Transactional
    public TransactionResponse processTransfer(TransferRequest request) {
        Span span = tracer.spanBuilder("process-transfer")
            .setAttribute("transaction.type", "transfer")
            .setAttribute("transaction.amount", request.getAmount())
            .setAttribute("account.from", request.getFromAccountId())
            .setAttribute("account.to", request.getToAccountId())
            .startSpan();
        
        try (Scope scope = span.makeCurrent()) {
            // Validate account ownership
            span.addEvent("validating-account-ownership");
            validateAccountOwnership(request);
            
            // Check sufficient balance
            span.addEvent("checking-balance");
            validateSufficientBalance(request);
            
            // Process the transfer
            span.addEvent("processing-transfer");
            TransactionResponse response = executeTransfer(request);
            
            span.setStatus(StatusCode.OK);
            return response;
            
        } catch (InsufficientFundsException e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, "Insufficient funds");
            throw e;
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            throw e;
        } finally {
            span.end();
        }
    }
    
    private void validateAccountOwnership(TransferRequest request) {
        Span span = tracer.spanBuilder("validate-account-ownership")
            .setAttribute("account.from", request.getFromAccountId())
            .startSpan();
        
        try (Scope scope = span.makeCurrent()) {
            // Account validation logic
            span.addEvent("account-ownership-verified");
        } finally {
            span.end();
        }
    }
}
```

### 5. HTTP Client Instrumentation

Trace inter-service communication:

```java
// AccountsServiceClient.java
@Component
public class AccountsServiceClient {
    
    private final RestTemplate restTemplate;
    private final Tracer tracer;
    
    public AccountsServiceClient(RestTemplateBuilder builder, OpenTelemetry openTelemetry) {
        this.restTemplate = builder.build();
        this.tracer = openTelemetry.getTracer("accounts-service-client");
    }
    
    public BalanceResponse getAccountBalance(Long accountId) {
        Span span = tracer.spanBuilder("get-account-balance")
            .setAttribute("http.method", "GET")
            .setAttribute("http.url", "/accounts/" + accountId + "/balance")
            .setAttribute("account.id", accountId)
            .setSpanKind(SpanKind.CLIENT)
            .startSpan();
        
        try (Scope scope = span.makeCurrent()) {
            String url = "http://accounts-service:8082/accounts/" + accountId + "/balance";
            
            HttpHeaders headers = new HttpHeaders();
            // Inject trace context into HTTP headers
            TextMapSetter<HttpHeaders> setter = HttpHeaders::set;
            GlobalOpenTelemetry.getPropagators().getTextMapPropagator()
                .inject(Context.current(), headers, setter);
            
            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<BalanceResponse> response = restTemplate.exchange(
                url, HttpMethod.GET, entity, BalanceResponse.class);
            
            span.setAttribute("http.status_code", response.getStatusCodeValue());
            span.setStatus(StatusCode.OK);
            
            return response.getBody();
            
        } catch (HttpClientErrorException e) {
            span.setAttribute("http.status_code", e.getRawStatusCode());
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, "HTTP client error");
            throw e;
        } finally {
            span.end();
        }
    }
}
```

### 6. Database Query Instrumentation

Add database-level tracing:

```java
// AccountRepository.java
@Repository
public class AccountRepository {
    
    private final JdbcTemplate jdbcTemplate;
    private final Tracer tracer;
    
    public AccountRepository(JdbcTemplate jdbcTemplate, OpenTelemetry openTelemetry) {
        this.jdbcTemplate = jdbcTemplate;
        this.tracer = openTelemetry.getTracer("account-repository");
    }
    
    public Optional<Account> findById(Long id) {
        Span span = tracer.spanBuilder("find-account-by-id")
            .setAttribute("db.system", "postgresql")
            .setAttribute("db.name", "banking_app")
            .setAttribute("db.statement", "SELECT * FROM accounts_service.accounts WHERE id = ?")
            .setAttribute("account.id", id)
            .setSpanKind(SpanKind.CLIENT)
            .startSpan();
        
        try (Scope scope = span.makeCurrent()) {
            String sql = "SELECT * FROM accounts_service.accounts WHERE id = ?";
            List<Account> accounts = jdbcTemplate.query(sql, new Object[]{id}, accountRowMapper);
            
            span.setAttribute("db.rows_affected", accounts.size());
            span.setStatus(StatusCode.OK);
            
            return accounts.isEmpty() ? Optional.empty() : Optional.of(accounts.get(0));
            
        } catch (DataAccessException e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, "Database query failed");
            throw e;
        } finally {
            span.end();
        }
    }
}
```

## Frontend Integration (Next.js)

### 1. OpenTelemetry Web Setup

```javascript
// instrumentation.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { OTLPTraceExporter } from '@opentelemetry/exporter-otlp-grpc';

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'frontend',
    [SemanticResourceAttributes.SERVICE_NAMESPACE]: 'banking-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.1.11',
  }),
  traceExporter: new OTLPTraceExporter({
    url: 'http://jaeger:4317',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

### 2. API Route Instrumentation

```javascript
// app/api/users/login/route.ts
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('frontend-api');

export async function POST(request: Request) {
  const span = tracer.startSpan('user-login-api');
  
  try {
    span.setAttributes({
      'http.method': 'POST',
      'http.route': '/api/users/login',
      'user.action': 'login'
    });
    
    const body = await request.json();
    span.addEvent('request-body-parsed');
    
    // Call backend API
    const response = await fetch('http://api-gateway:8080/users/login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        // Inject trace context
        ...injectTraceHeaders()
      },
      body: JSON.stringify(body)
    });
    
    span.setAttributes({
      'http.status_code': response.status,
      'user.login.success': response.ok
    });
    
    if (response.ok) {
      span.setStatus({ code: SpanStatusCode.OK });
      const data = await response.json();
      return NextResponse.json(data);
    } else {
      span.setStatus({ 
        code: SpanStatusCode.ERROR, 
        message: 'Login failed' 
      });
      return NextResponse.json(
        { error: 'Login failed' }, 
        { status: response.status }
      );
    }
    
  } catch (error) {
    span.recordException(error);
    span.setStatus({ 
      code: SpanStatusCode.ERROR, 
      message: error.message 
    });
    return NextResponse.json(
      { error: 'Internal server error' }, 
      { status: 500 }
    );
  } finally {
    span.end();
  }
}

function injectTraceHeaders() {
  const headers = {};
  trace.setSpanContext(context.active(), span.spanContext());
  propagation.inject(context.active(), headers);
  return headers;
}
```

## Jaeger Backend Configuration

### Docker Compose Setup

```yaml
# docker-compose.yml
version: '3.8'
services:
  jaeger:
    image: jaegertracing/all-in-one:1.51
    ports:
      - "16686:16686"  # Jaeger UI
      - "4317:4317"    # OTLP gRPC receiver
      - "4318:4318"    # OTLP HTTP receiver
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    networks:
      - banking-network
```

### Kubernetes Deployment

```yaml
# kubernetes/observability/jaeger-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: banking-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:1.51
        ports:
        - containerPort: 16686  # UI
        - containerPort: 4317   # gRPC OTLP
        - containerPort: 4318   # HTTP OTLP
        env:
        - name: COLLECTOR_OTLP_ENABLED
          value: "true"
        - name: SPAN_STORAGE_TYPE
          value: "memory"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
```

## Advanced Tracing Patterns

### 1. Correlation IDs

Link logs with traces using correlation IDs:

```java
// LogbackConfig.java
@Configuration
public class LogbackConfig {
    
    @PostConstruct
    public void addTraceIdToLogs() {
        MDC.put("traceId", Span.current().getSpanContext().getTraceId());
        MDC.put("spanId", Span.current().getSpanContext().getSpanId());
    }
}
```

```xml
<!-- logback-spring.xml -->
<configuration>
    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level [%X{traceId},%X{spanId}] %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>
    <root level="INFO">
        <appender-ref ref="STDOUT"/>
    </root>
</configuration>
```

### 2. Business Metrics

Add custom metrics to banking operations:

```java
// TransactionMetrics.java
@Component
public class TransactionMetrics {
    
    private final Meter meter;
    private final Counter transactionCounter;
    private final Histogram transactionAmount;
    
    public TransactionMetrics(OpenTelemetry openTelemetry) {
        this.meter = openTelemetry.getMeter("banking-transactions");
        this.transactionCounter = meter.counterBuilder("transactions_total")
            .setDescription("Total number of transactions")
            .build();
        this.transactionAmount = meter.histogramBuilder("transaction_amount")
            .setDescription("Transaction amounts")
            .setUnit("USD")
            .build();
    }
    
    public void recordTransaction(String type, double amount, String status) {
        transactionCounter.add(1, 
            Attributes.builder()
                .put("transaction.type", type)
                .put("transaction.status", status)
                .build());
        
        transactionAmount.record(amount,
            Attributes.builder()
                .put("transaction.type", type)
                .build());
    }
}
```

### 3. Error Tracking

Implement comprehensive error tracking:

```java
// GlobalExceptionHandler.java
@ControllerAdvice
public class GlobalExceptionHandler {
    
    private final Tracer tracer;
    
    public GlobalExceptionHandler(OpenTelemetry openTelemetry) {
        this.tracer = openTelemetry.getTracer("error-handler");
    }
    
    @ExceptionHandler(InsufficientFundsException.class)
    public ResponseEntity<ErrorResponse> handleInsufficientFunds(InsufficientFundsException e) {
        Span span = Span.current();
        span.setAttribute("error.type", "insufficient_funds");
        span.setAttribute("error.account_id", e.getAccountId());
        span.setAttribute("error.requested_amount", e.getRequestedAmount());
        span.setAttribute("error.available_balance", e.getAvailableBalance());
        span.recordException(e);
        span.setStatus(StatusCode.ERROR, "Insufficient funds");
        
        return ResponseEntity.badRequest()
            .body(new ErrorResponse("Insufficient funds", e.getMessage()));
    }
}
```

## Speedscale Integration with Tracing

### Trace-Aware Traffic Capture

Speedscale can capture traces along with API traffic:

```bash
# Capture traffic with trace context
speedscale record --service banking-app --trace-headers --duration 10m

# Replay with trace propagation
speedscale replay --recording banking-traces-001 --preserve-traces
```

### Correlation with Performance Testing

```yaml
# speedscale-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: speedscale-config
data:
  config.yaml: |
    tracing:
      enabled: true
      headers:
        - traceparent
        - tracestate
      jaeger:
        endpoint: http://jaeger:16686
```

## Troubleshooting Common Issues

### 1. Traces Not Appearing

**Check OpenTelemetry Configuration**:
```bash
# Verify environment variables
kubectl exec deployment/user-service -n banking-app -- env | grep OTEL

# Check Jaeger connectivity
kubectl exec deployment/user-service -n banking-app -- curl -v http://jaeger:4317
```

**Verify Trace Propagation**:
```java
// Add debug logging
@GetMapping("/debug/trace")
public ResponseEntity<String> debugTrace() {
    Span span = Span.current();
    String traceId = span.getSpanContext().getTraceId();
    String spanId = span.getSpanContext().getSpanId();
    
    return ResponseEntity.ok(
        "TraceId: " + traceId + ", SpanId: " + spanId
    );
}
```

### 2. Performance Impact

**Sampling Configuration**:
```yaml
# Reduce sampling for high-volume services
otel:
  traces:
    sampler:
      type: traceidratio
      ratio: 0.1  # Sample 10% of traces
```

**Batch Processing**:
```java
// Optimize span processor
BatchSpanProcessor.builder(exporter)
    .setMaxExportBatchSize(512)
    .setExportTimeout(Duration.ofSeconds(2))
    .setScheduleDelay(Duration.ofSeconds(5))
    .build()
```

### 3. Missing Service Dependencies

**Service Map Verification**:
1. Open Jaeger UI at http://localhost:16686
2. Go to "Dependencies" tab
3. Verify all services appear in the service map
4. Check for missing connections between services

## Monitoring and Alerting

### Grafana Dashboard Integration

```json
{
  "dashboard": {
    "title": "Banking Services Tracing",
    "panels": [
      {
        "title": "Request Rate by Service",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(traces_total[5m])",
            "legendFormat": "{{service_name}}"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "singlestat",
        "targets": [
          {
            "expr": "rate(traces_total{status=\"error\"}[5m]) / rate(traces_total[5m])"
          }
        ]
      },
      {
        "title": "P95 Latency",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(trace_duration_bucket[5m]))"
          }
        ]
      }
    ]
  }
}
```

### Alerting Rules

```yaml
# prometheus-alerts.yaml
groups:
- name: banking-tracing
  rules:
  - alert: HighErrorRate
    expr: rate(traces_total{status="error"}[5m]) / rate(traces_total[5m]) > 0.05
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High error rate in banking services"
      description: "Error rate is {{ $value | humanizePercentage }} for service {{ $labels.service_name }}"
  
  - alert: HighLatency
    expr: histogram_quantile(0.95, rate(trace_duration_bucket[5m])) > 2
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High latency in banking services"
      description: "P95 latency is {{ $value }}s for service {{ $labels.service_name }}"
```

## Best Practices

### 1. Span Naming Conventions

```java
// Good span names - use operation names
"process-transfer"
"validate-account"
"update-balance"

// Avoid - don't include variable data
"process-transfer-account-123"
"validate-account-for-user-john"
```

### 2. Attribute Guidelines

```java
// Use semantic conventions
span.setAttribute(SemanticAttributes.HTTP_METHOD, "POST");
span.setAttribute(SemanticAttributes.HTTP_STATUS_CODE, 200);
span.setAttribute(SemanticAttributes.DB_SYSTEM, "postgresql");

// Add business context
span.setAttribute("banking.account.id", accountId);
span.setAttribute("banking.transaction.type", "transfer");
span.setAttribute("banking.amount", amount);
```

### 3. Error Handling

```java
// Always record exceptions
try {
    // Business logic
} catch (Exception e) {
    span.recordException(e);
    span.setStatus(StatusCode.ERROR, e.getMessage());
    throw e;
} finally {
    span.end();  // Always end spans
}
```

## Conclusion

Implementing distributed tracing with OpenTelemetry in banking microservices provides:

1. **End-to-end visibility** across all services and databases
2. **Performance optimization** through detailed latency analysis
3. **Error debugging** with complete request context
4. **Business insights** through custom metrics and attributes
5. **Production readiness** with proper sampling and performance optimization

Combined with Speedscale's traffic capture and replay capabilities, you can correlate real production traces with testing scenarios, ensuring your banking application performs reliably under real-world conditions.

### Next Steps

1. **Implement the configuration**: Start with basic OpenTelemetry setup across all services
2. **Add custom instrumentation**: Include business-specific spans and metrics
3. **Deploy observability stack**: Set up Jaeger, Prometheus, and Grafana
4. **Integrate with Speedscale**: Capture and replay traffic with trace context
5. **Set up monitoring**: Create dashboards and alerts for proactive monitoring

Ready to implement distributed tracing in your microservices? The complete OpenTelemetry configuration and observability stack are available in our banking microservices repository.