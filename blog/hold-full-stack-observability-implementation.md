# Full-Stack Observability: From Banking Microservices to Production Insights

**Target Keywords**: spring boot observability, prometheus grafana setup, distributed tracing jaeger  
**Estimated Monthly Searches**: 2,900 + 4,400 + 3,600 = 10,900

## Introduction

Implementing comprehensive observability in banking microservices requires more than just logging. This guide demonstrates building a complete observability stack with OpenTelemetry, Prometheus, Grafana, and Jaeger, providing end-to-end visibility from frontend user interactions to database queries.

## The Three Pillars of Observability

### 1. Metrics - The "What"
- **Application Metrics**: Request rates, response times, error rates
- **Business Metrics**: Transaction volumes, account operations, fraud detection
- **Infrastructure Metrics**: CPU, memory, network, database performance

### 2. Logs - The "Why"
- **Structured Logging**: JSON format with correlation IDs
- **Centralized Collection**: All services log to a unified system
- **Context Correlation**: Link logs with traces and metrics

### 3. Traces - The "How"
- **Distributed Tracing**: Follow requests across all services
- **Performance Analysis**: Identify bottlenecks and latencies
- **Error Attribution**: Pinpoint failure sources in complex flows

## Architecture Overview

Our banking observability stack:

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Frontend  │────│ API Gateway  │────│  Services   │
│  (Next.js)  │    │   (Spring)   │    │  (Spring)   │
└─────────────┘    └──────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
              ┌─────────────▼─────────────┐
              │    OpenTelemetry         │
              │      Collector           │
              └─────────────┬─────────────┘
                           │
      ┌────────────────────┼────────────────────┐
      │                    │                    │
┌─────▼─────┐    ┌─────────▼────────┐    ┌─────▼─────┐
│  Jaeger   │    │   Prometheus     │    │   Loki    │
│ (Traces)  │    │   (Metrics)      │    │  (Logs)   │
└───────────┘    └──────────────────┘    └───────────┘
                           │
                    ┌──────▼──────┐
                    │   Grafana   │
                    │ (Dashboard) │
                    └─────────────┘
```

## Spring Boot Observability Configuration

### 1. Dependencies Setup

Add observability dependencies to all Spring Boot services:

```xml
<!-- pom.xml -->
<dependencies>
  <!-- OpenTelemetry -->
  <dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-api</artifactId>
    <version>1.32.0</version>
  </dependency>
  <dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-spring-boot-starter</artifactId>
    <version>1.32.0-alpha</version>
  </dependency>
  
  <!-- Micrometer for metrics -->
  <dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
  </dependency>
  <dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
  </dependency>
  
  <!-- Structured logging -->
  <dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>7.4</version>
  </dependency>
</dependencies>
```

### 2. Application Configuration

Standardize observability configuration across all services:

```yaml
# application.yml
spring:
  application:
    name: user-service
  
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus,trace
  endpoint:
    health:
      show-details: always
    metrics:
      enabled: true
    prometheus:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
      environment: ${ENVIRONMENT:local}
    web:
      server:
        request:
          autotime:
            enabled: true
    distribution:
      percentiles-histogram:
        http.server.requests: true
      percentiles:
        http.server.requests: 0.5,0.9,0.95,0.99

# OpenTelemetry configuration
otel:
  service:
    name: ${spring.application.name}
  exporter:
    otlp:
      protocol: grpc
      endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:http://localhost:4317}
  traces:
    exporter: otlp
    sampler:
      type: always_on
  metrics:
    exporter: otlp
  logs:
    exporter: otlp
  propagation:
    type: tracecontext

# Logging configuration
logging:
  level:
    com.banking: INFO
    org.springframework.web: DEBUG
    org.springframework.security: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level [%X{traceId},%X{spanId}] %logger{36} - %msg%n"
```

### 3. Custom Metrics Configuration

Create banking-specific metrics:

```java
// BankingMetricsConfig.java
@Configuration
public class BankingMetricsConfig {
    
    @Bean
    public MeterRegistry meterRegistry() {
        return new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);
    }
    
    @Bean
    public TimedAspect timedAspect(MeterRegistry registry) {
        return new TimedAspect(registry);
    }
    
    @Bean
    public CountedAspect countedAspect(MeterRegistry registry) {
        return new CountedAspect(registry);
    }
}

// BankingMetrics.java
@Component
public class BankingMetrics {
    
    private final Counter loginAttempts;
    private final Counter transactionCount;
    private final Timer transactionProcessingTime;
    private final Gauge accountBalanceGauge;
    
    public BankingMetrics(MeterRegistry meterRegistry) {
        this.loginAttempts = Counter.builder("banking_login_attempts_total")
            .description("Total login attempts")
            .tag("service", "user-service")
            .register(meterRegistry);
        
        this.transactionCount = Counter.builder("banking_transactions_total")
            .description("Total banking transactions")
            .register(meterRegistry);
        
        this.transactionProcessingTime = Timer.builder("banking_transaction_duration")
            .description("Time spent processing transactions")
            .register(meterRegistry);
        
        this.accountBalanceGauge = Gauge.builder("banking_account_balance")
            .description("Current account balances")
            .register(meterRegistry, this, BankingMetrics::getTotalBalance);
    }
    
    public void recordLoginAttempt(String result) {
        loginAttempts.increment(Tags.of("result", result));
    }
    
    public void recordTransaction(String type, double amount) {
        transactionCount.increment(
            Tags.of("type", type, "amount_range", getAmountRange(amount))
        );
    }
    
    public Timer.Sample startTransactionTimer() {
        return Timer.start(transactionProcessingTime);
    }
    
    private String getAmountRange(double amount) {
        if (amount < 100) return "small";
        if (amount < 1000) return "medium";
        if (amount < 10000) return "large";
        return "xlarge";
    }
    
    private double getTotalBalance() {
        // Implementation to calculate total balance across all accounts
        return 0.0; // Placeholder
    }
}
```

### 4. Service-Level Instrumentation

Add custom instrumentation to banking operations:

```java
// UserController.java
@RestController
@RequestMapping("/users")
public class UserController {
    
    private final UserService userService;
    private final BankingMetrics bankingMetrics;
    private final Tracer tracer;
    
    public UserController(UserService userService, BankingMetrics bankingMetrics, 
                         OpenTelemetry openTelemetry) {
        this.userService = userService;
        this.bankingMetrics = bankingMetrics;
        this.tracer = openTelemetry.getTracer("user-controller");
    }
    
    @PostMapping("/login")
    @Timed(value = "banking_login_duration", description = "Time spent on login")
    public ResponseEntity<UserLoginResponse> login(@RequestBody UserLoginRequest request) {
        Span span = tracer.spanBuilder("user-login")
            .setAttribute("user.login_attempt", request.getUsername())
            .startSpan();
        
        try (Scope scope = span.makeCurrent()) {
            span.addEvent("login-attempt-started");
            
            UserLoginResponse response = userService.authenticateUser(request);
            
            span.setAttribute("user.login_success", response.isSuccess());
            bankingMetrics.recordLoginAttempt(response.isSuccess() ? "success" : "failure");
            
            if (response.isSuccess()) {
                span.setStatus(StatusCode.OK);
                return ResponseEntity.ok(response);
            } else {
                span.setStatus(StatusCode.ERROR, "Authentication failed");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(response);
            }
            
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            bankingMetrics.recordLoginAttempt("error");
            throw e;
        } finally {
            span.end();
        }
    }
}

// TransactionService.java
@Service
public class TransactionService {
    
    private final BankingMetrics bankingMetrics;
    private final Tracer tracer;
    
    @Transactional
    @Timed(value = "banking_transaction_processing", description = "Transaction processing time")
    public TransactionResponse processTransfer(TransferRequest request) {
        Timer.Sample timer = bankingMetrics.startTransactionTimer();
        
        Span span = tracer.spanBuilder("process-transfer")
            .setAttribute("transaction.type", "transfer")
            .setAttribute("transaction.amount", request.getAmount())
            .setAttribute("account.from", request.getFromAccountId())
            .setAttribute("account.to", request.getToAccountId())
            .startSpan();
        
        try (Scope scope = span.makeCurrent()) {
            // Validate accounts
            span.addEvent("validating-accounts");
            validateAccounts(request);
            
            // Check balance
            span.addEvent("checking-balance");
            validateBalance(request);
            
            // Process transfer
            span.addEvent("processing-transfer");
            TransactionResponse response = executeTransfer(request);
            
            // Record metrics
            bankingMetrics.recordTransaction("transfer", request.getAmount());
            
            span.setStatus(StatusCode.OK);
            return response;
            
        } catch (InsufficientFundsException e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, "Insufficient funds");
            bankingMetrics.recordTransaction("transfer_failed", request.getAmount());
            throw e;
        } finally {
            timer.stop();
            span.end();
        }
    }
}
```

## Frontend Observability (Next.js)

### 1. OpenTelemetry Web Setup

```javascript
// instrumentation.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { OTLPTraceExporter } from '@opentelemetry/exporter-otlp-grpc';
import { OTLPMetricExporter } from '@opentelemetry/exporter-otlp-grpc';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'frontend',
    [SemanticResourceAttributes.SERVICE_NAMESPACE]: 'banking-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.npm_package_version,
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4317',
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4317',
    }),
    exportIntervalMillis: 10000,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

### 2. Custom Frontend Metrics

```javascript
// lib/metrics.ts
import { metrics, trace } from '@opentelemetry/api';

const meter = metrics.getMeter('banking-frontend', '1.0.0');
const tracer = trace.getTracer('banking-frontend');

// Custom metrics
const pageViewCounter = meter.createCounter('page_views_total', {
  description: 'Total number of page views',
});

const apiRequestCounter = meter.createCounter('api_requests_total', {
  description: 'Total number of API requests',
});

const apiRequestDuration = meter.createHistogram('api_request_duration', {
  description: 'API request duration in milliseconds',
  unit: 'ms',
});

export class FrontendMetrics {
  static recordPageView(page: string, userId?: string) {
    pageViewCounter.add(1, {
      page,
      user_id: userId || 'anonymous',
    });
  }
  
  static recordApiRequest(endpoint: string, method: string, status: number, duration: number) {
    apiRequestCounter.add(1, {
      endpoint,
      method,
      status: status.toString(),
      status_class: `${Math.floor(status / 100)}xx`,
    });
    
    apiRequestDuration.record(duration, {
      endpoint,
      method,
    });
  }
  
  static createSpan(name: string, attributes?: Record<string, string | number>) {
    return tracer.startSpan(name, { attributes });
  }
}

// middleware.ts - Track page views and API calls
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { FrontendMetrics } from './lib/metrics';

export function middleware(request: NextRequest) {
  const start = Date.now();
  
  // Track page views
  if (!request.nextUrl.pathname.startsWith('/api/')) {
    FrontendMetrics.recordPageView(request.nextUrl.pathname);
  }
  
  const response = NextResponse.next();
  
  // Track API requests
  if (request.nextUrl.pathname.startsWith('/api/')) {
    const duration = Date.now() - start;
    FrontendMetrics.recordApiRequest(
      request.nextUrl.pathname,
      request.method,
      response.status,
      duration
    );
  }
  
  return response;
}
```

### 3. User Journey Tracking

```javascript
// components/UserJourneyTracker.tsx
import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { FrontendMetrics } from '../lib/metrics';

export function UserJourneyTracker() {
  const router = useRouter();
  
  useEffect(() => {
    const handleRouteChange = (url: string) => {
      const span = FrontendMetrics.createSpan('page-navigation', {
        'page.url': url,
        'page.previous': router.asPath,
      });
      
      // Track common banking flows
      if (url.includes('/transfer')) {
        FrontendMetrics.createSpan('banking-flow-start', {
          'flow.type': 'money-transfer',
        });
      } else if (url.includes('/accounts')) {
        FrontendMetrics.createSpan('banking-flow-start', {
          'flow.type': 'account-management',
        });
      }
      
      span.end();
    };
    
    router.events.on('routeChangeComplete', handleRouteChange);
    return () => router.events.off('routeChangeComplete', handleRouteChange);
  }, [router]);
  
  return null;
}
```

## Prometheus Configuration

### 1. Prometheus Setup

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Banking services
  - job_name: 'banking-services'
    kubernetes_sd_configs:
      - role: service
        namespaces:
          names: ['banking-app']
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'banking_.*'
        action: keep

  # Frontend metrics
  - job_name: 'frontend'
    static_configs:
      - targets: ['frontend:3000']
    metrics_path: '/api/metrics'

  # Database metrics
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

# Alerting rules
rule_files:
  - "banking-alerts.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

### 2. Banking-Specific Alerting Rules

```yaml
# banking-alerts.yml
groups:
  - name: banking-application
    rules:
      - alert: HighErrorRate
        expr: rate(banking_transactions_total{result="error"}[5m]) / rate(banking_transactions_total[5m]) > 0.05
        for: 2m
        labels:
          severity: warning
          service: "{{ $labels.service }}"
        annotations:
          summary: "High error rate in banking transactions"
          description: "Error rate is {{ $value | humanizePercentage }} for service {{ $labels.service }}"
      
      - alert: SlowTransactionProcessing
        expr: histogram_quantile(0.95, rate(banking_transaction_duration_bucket[5m])) > 5
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: "Slow transaction processing"
          description: "95th percentile transaction time is {{ $value }}s"
      
      - alert: LoginFailureSpike
        expr: increase(banking_login_attempts_total{result="failure"}[5m]) > 10
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High number of login failures"
          description: "{{ $value }} failed login attempts in the last 5 minutes"
      
      - alert: DatabaseConnectionIssues
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database is down"
          description: "PostgreSQL database is not responding"
      
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is above 85%"
```

## Grafana Dashboard Configuration

### 1. Banking Services Overview Dashboard

```json
{
  "dashboard": {
    "id": null,
    "title": "Banking Services Overview",
    "tags": ["banking", "microservices"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_server_requests_seconds_count[5m])) by (service)",
            "legendFormat": "{{service}}",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "label": "Requests/sec",
            "min": 0
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Error Rate",
        "type": "singlestat",
        "targets": [
          {
            "expr": "sum(rate(http_server_requests_seconds_count{status=~\"4..|5..\"}[5m])) / sum(rate(http_server_requests_seconds_count[5m]))",
            "refId": "A"
          }
        ],
        "format": "percentunit",
        "colorBackground": true,
        "thresholds": "0.01,0.05",
        "colors": ["#299c46", "#e24d42", "#d44a3a"],
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Response Time P95",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[5m])) by (le, service))",
            "legendFormat": "{{service}}",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "label": "Seconds",
            "min": 0
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Banking Transactions",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(banking_transactions_total[5m])) by (type)",
            "legendFormat": "{{type}}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
```

### 2. Business Metrics Dashboard

```json
{
  "dashboard": {
    "title": "Banking Business Metrics",
    "panels": [
      {
        "title": "Daily Transaction Volume",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(increase(banking_transactions_total[1d])) by (type)",
            "legendFormat": "{{type}}"
          }
        ]
      },
      {
        "title": "Transaction Success Rate",
        "type": "singlestat",
        "targets": [
          {
            "expr": "sum(rate(banking_transactions_total{result=\"success\"}[5m])) / sum(rate(banking_transactions_total[5m]))"
          }
        ],
        "format": "percentunit"
      },
      {
        "title": "Average Transaction Amount",
        "type": "singlestat",
        "targets": [
          {
            "expr": "avg(banking_transaction_amount)"
          }
        ],
        "format": "currencyUSD"
      },
      {
        "title": "Active Users",
        "type": "graph",
        "targets": [
          {
            "expr": "count(increase(banking_login_attempts_total{result=\"success\"}[1h]) > 0)"
          }
        ]
      }
    ]
  }
}
```

### 3. Infrastructure Dashboard

```json
{
  "dashboard": {
    "title": "Banking Infrastructure",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "Memory Usage %"
          }
        ]
      },
      {
        "title": "Database Connections",
        "type": "graph",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends",
            "legendFormat": "{{datname}}"
          }
        ]
      },
      {
        "title": "Network I/O",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total[5m])",
            "legendFormat": "Received"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total[5m])",
            "legendFormat": "Transmitted"
          }
        ]
      }
    ]
  }
}
```

## Jaeger Tracing Configuration

### 1. Jaeger Deployment

```yaml
# jaeger-deployment.yaml
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
          value: "elasticsearch"
        - name: ES_SERVER_URLS
          value: "http://elasticsearch:9200"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
```

### 2. Custom Trace Analysis

```javascript
// trace-analysis.js
const jaeger = require('jaegertracing');

class BankingTraceAnalyzer {
  constructor(jaegerEndpoint) {
    this.jaegerClient = new jaeger.Client(jaegerEndpoint);
  }
  
  async analyzeTransactionFlow(traceId) {
    const trace = await this.jaegerClient.getTrace(traceId);
    
    const analysis = {
      totalDuration: 0,
      serviceBreakdown: {},
      bottlenecks: [],
      errors: []
    };
    
    trace.spans.forEach(span => {
      const serviceName = span.process.serviceName;
      const duration = span.duration;
      
      // Service breakdown
      if (!analysis.serviceBreakdown[serviceName]) {
        analysis.serviceBreakdown[serviceName] = 0;
      }
      analysis.serviceBreakdown[serviceName] += duration;
      
      // Identify bottlenecks (spans taking >1s)
      if (duration > 1000000) { // 1s in microseconds
        analysis.bottlenecks.push({
          service: serviceName,
          operation: span.operationName,
          duration: duration / 1000, // Convert to ms
        });
      }
      
      // Identify errors
      if (span.tags.some(tag => tag.key === 'error' && tag.value)) {
        analysis.errors.push({
          service: serviceName,
          operation: span.operationName,
          error: span.tags.find(tag => tag.key === 'error.message')?.value
        });
      }
    });
    
    analysis.totalDuration = Math.max(...trace.spans.map(s => s.startTime + s.duration)) - 
                            Math.min(...trace.spans.map(s => s.startTime));
    
    return analysis;
  }
  
  async getServiceDependencies() {
    const dependencies = await this.jaegerClient.getDependencies();
    
    return dependencies.map(dep => ({
      parent: dep.parent,
      child: dep.child,
      callCount: dep.callCount,
      errorCount: dep.errorCount,
      errorRate: dep.errorCount / dep.callCount
    }));
  }
}
```

## Log Aggregation with Structured Logging

### 1. Logback Configuration

```xml
<!-- logback-spring.xml -->
<configuration>
  <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
      <providers>
        <timestamp/>
        <logLevel/>
        <loggerName/>
        <mdc/>
        <arguments/>
        <stackTrace/>
        <pattern>
          <pattern>
            {
              "service": "${spring.application.name:-unknown}",
              "traceId": "%X{traceId:-}",
              "spanId": "%X{spanId:-}",
              "level": "%level",
              "timestamp": "%date{ISO8601}",
              "logger": "%logger",
              "message": "%message",
              "thread": "%thread"
            }
          </pattern>
        </pattern>
      </providers>
    </encoder>
  </appender>
  
  <root level="INFO">
    <appender-ref ref="STDOUT"/>
  </root>
</configuration>
```

### 2. Correlation ID Filter

```java
// CorrelationIdFilter.java
@Component
@Order(1)
public class CorrelationIdFilter implements Filter {
    
    private static final String CORRELATION_ID_HEADER = "X-Correlation-ID";
    private static final String CORRELATION_ID_MDC_KEY = "correlationId";
    
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        
        String correlationId = httpRequest.getHeader(CORRELATION_ID_HEADER);
        if (correlationId == null || correlationId.isEmpty()) {
            correlationId = UUID.randomUUID().toString();
        }
        
        // Add to MDC for logging
        MDC.put(CORRELATION_ID_MDC_KEY, correlationId);
        
        // Add to response headers
        httpResponse.setHeader(CORRELATION_ID_HEADER, correlationId);
        
        // Add trace context to MDC
        Span currentSpan = Span.current();
        MDC.put("traceId", currentSpan.getSpanContext().getTraceId());
        MDC.put("spanId", currentSpan.getSpanContext().getSpanId());
        
        try {
            chain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
}
```

## Speedscale Integration with Observability

### 1. Enhanced Traffic Capture

Capture observability data along with API traffic:

```yaml
# speedscale-observability.yaml
apiVersion: speedscale.com/v1
kind: SpeedscaleConfig
metadata:
  name: banking-observability
spec:
  capture:
    include_headers:
      - x-trace-id
      - x-correlation-id
      - x-span-id
    include_metrics: true
    include_logs: true
  
  replay:
    preserve_trace_context: true
    generate_metrics: true
    
  analysis:
    performance_comparison: true
    trace_correlation: true
```

### 2. Performance Baseline Validation

```bash
# Capture performance baseline with full observability
speedscale record --service banking-app \
  --include-traces \
  --include-metrics \
  --duration 1h \
  --tag baseline-performance

# Replay and compare performance
speedscale replay --recording baseline-performance \
  --target http://staging-banking-app \
  --compare-traces \
  --generate-performance-report
```

## Deployment and Configuration

### 1. Complete Docker Compose Stack

```yaml
# docker-compose.observability.yml
version: '3.8'
services:
  # Jaeger
  jaeger:
    image: jaegertracing/all-in-one:1.51
    ports:
      - "16686:16686"
      - "4317:4317"
      - "4318:4318"
    environment:
      - COLLECTOR_OTLP_ENABLED=true
  
  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./config/banking-alerts.yml:/etc/prometheus/banking-alerts.yml
  
  # Grafana
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - ./config/grafana/provisioning:/etc/grafana/provisioning
      - ./config/grafana/dashboards:/var/lib/grafana/dashboards
  
  # OpenTelemetry Collector
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otelcol-contrib/otel-collector.yml"]
    volumes:
      - ./config/otel-collector.yml:/etc/otelcol-contrib/otel-collector.yml
    ports:
      - "4317:4317"   # OTLP gRPC receiver
      - "4318:4318"   # OTLP HTTP receiver
    depends_on:
      - jaeger
      - prometheus
```

### 2. Kubernetes Observability Stack

```bash
# Deploy complete observability stack
kubectl apply -k kubernetes/observability/

# Verify deployment
kubectl get pods -n banking-app | grep -E "(jaeger|prometheus|grafana)"

# Port forward to access dashboards
kubectl port-forward -n banking-app svc/grafana 3001:3000 &
kubectl port-forward -n banking-app svc/prometheus 9090:9090 &
kubectl port-forward -n banking-app svc/jaeger 16686:16686 &
```

## Monitoring Best Practices

### 1. SLI/SLO Definition

```yaml
# banking-slos.yaml
service_level_objectives:
  user_service:
    availability: 99.9%
    latency_p95: 500ms
    error_rate: <1%
  
  transactions_service:
    availability: 99.95%
    latency_p95: 2s
    error_rate: <0.1%
    
  accounts_service:
    availability: 99.9%
    latency_p95: 300ms
    error_rate: <0.5%
```

### 2. Runbook Integration

```markdown
# Banking Services Runbook

## High Error Rate Alert

### Symptoms
- Error rate > 5% for 2 minutes
- Users experiencing failed transactions

### Investigation Steps
1. Check Grafana dashboard for affected services
2. Review Jaeger traces for error patterns
3. Check application logs for error details
4. Verify database connectivity

### Resolution
1. If database issues: Restart database connection pool
2. If service issues: Check recent deployments, consider rollback
3. If external dependency: Enable circuit breaker

### Escalation
- Page on-call engineer if error rate > 10%
- Notify business team if affecting transactions
```

## Conclusion

Implementing full-stack observability in banking microservices provides:

1. **Complete Visibility**: From user interactions to database queries
2. **Proactive Monitoring**: Identify issues before they impact users
3. **Performance Optimization**: Pinpoint bottlenecks and optimize accordingly
4. **Business Insights**: Track transaction patterns and user behavior
5. **Compliance Support**: Detailed audit trails for regulatory requirements

Combined with Speedscale's traffic capture and replay capabilities, this observability stack enables confident deployments and comprehensive testing with real production data.

### Implementation Checklist

- [ ] Configure OpenTelemetry in all services
- [ ] Set up Prometheus metrics collection
- [ ] Deploy Jaeger for distributed tracing
- [ ] Create Grafana dashboards
- [ ] Implement structured logging
- [ ] Define SLIs and SLOs
- [ ] Set up alerting rules
- [ ] Create runbooks for common issues
- [ ] Integrate with Speedscale for enhanced testing

Ready to implement comprehensive observability? Start with our banking microservices example and build a production-ready observability stack.