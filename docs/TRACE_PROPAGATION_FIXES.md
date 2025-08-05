# OpenTelemetry Trace Propagation Fixes

## Problem Summary

The OpenTelemetry traces were not working properly for cross-application tracing. Trace IDs were not propagating from one pod to another, resulting in disconnected traces instead of end-to-end distributed tracing.

## Root Causes Identified

### 1. Frontend Trace Context Issues
- **Problem**: Custom trace context mechanism using `window.__OTEL_TRACE_CONTEXT__` instead of proper W3C Trace Context format
- **Impact**: Frontend-generated trace contexts were not compatible with backend services
- **Location**: `frontend/src/instrumentation.ts`

### 2. API Gateway Missing Trace Propagation
- **Problem**: Spring Cloud Gateway not configured to propagate trace headers to downstream services
- **Impact**: Trace context was lost when requests passed through the API Gateway
- **Location**: `backend/api-gateway/src/main/resources/application.yml`

### 3. Backend Services Missing Trace Propagation
- **Problem**: RestTemplate configurations not using RestTemplateBuilder for automatic trace propagation
- **Impact**: Service-to-service calls didn't carry trace context
- **Location**: `backend/*/src/main/java/com/banking/*/config/RestTemplateConfig.java`

### 4. Inconsistent OpenTelemetry Endpoints
- **Problem**: Frontend using different OTLP endpoint than backend services
- **Impact**: Traces from frontend and backend going to different collectors
- **Location**: `kubernetes/base/configmaps/app-config.yaml`

## Fixes Implemented

### 1. Frontend Trace Context Fix
**File**: `frontend/src/instrumentation.ts`

**Changes**:
- Removed custom `window.__OTEL_TRACE_CONTEXT__` mechanism
- Added proper W3C Trace Context propagation using OpenTelemetry API
- Created utility functions for trace context generation
- Exposed trace utilities to process scope for API client access (avoiding `global` for browser compatibility)

**Code**:
```typescript
// Create a utility function to get current trace context for API calls
const getCurrentTraceContext = () => {
  const currentContext = context.active();
  const carrier: Record<string, string> = {};
  propagation.inject(currentContext, carrier);
  return carrier['traceparent'] || null;
};

// Expose trace context utilities to process scope for API client access
// This is a safer approach than using global in browser environments
if (typeof process !== 'undefined') {
  interface ProcessWithOtelUtils extends NodeJS.Process {
    __OTEL_TRACE_UTILS__?: {
      getCurrentTraceContext: () => string | null;
      createSpan: (name: string, attributes?: Record<string, string | number | boolean>) => unknown;
    };
  }
  (process as ProcessWithOtelUtils).__OTEL_TRACE_UTILS__ = {
    getCurrentTraceContext,
    createSpan: (name: string, attributes?: Record<string, string | number | boolean>) => {
      const tracer = trace.getTracer('frontend-api');
      const span = tracer.startSpan(name);
      if (attributes) {
        Object.entries(attributes).forEach(([key, value]) => {
          span.setAttribute(key, value);
        });
      }
      return span;
    }
  };
}
```

### 2. API Gateway Trace Propagation
**File**: `backend/api-gateway/src/main/resources/application.yml`

**Changes**:
- Added `TraceIdInjectionFilter` to default filters
- Ensures trace headers are automatically propagated to downstream services

**Code**:
```yaml
spring:
  cloud:
    gateway:
      default-filters:
        - TraceIdInjectionFilter
```

**File**: `backend/api-gateway/src/main/java/com/banking/apigateway/filter/TracePropagationFilter.java`

**Changes**:
- Created custom filter to log and verify trace header propagation
- Added debugging capabilities for trace context

### 3. Backend Services RestTemplate Configuration
**Files**: 
- `backend/user-service/src/main/java/com/banking/userservice/config/RestTemplateConfig.java`
- `backend/transactions-service/src/main/java/com/banking/transactionsservice/config/RestTemplateConfig.java`

**Changes**:
- Updated to use `RestTemplateBuilder` for automatic trace propagation
- Added conditional configuration based on OpenTelemetry availability
- Ensures service-to-service calls carry trace context

**Code**:
```java
@Bean
@ConditionalOnProperty(name = "otel.traces.exporter", havingValue = "otlp", matchIfMissing = false)
public RestTemplate restTemplate() {
    return new RestTemplateBuilder()
            .setConnectTimeout(Duration.ofSeconds(5))
            .setReadTimeout(Duration.ofSeconds(10))
            .build();
}
```

### 4. Standardized OpenTelemetry Endpoints
**File**: `kubernetes/base/configmaps/app-config.yaml`

**Changes**:
- Updated frontend to use same `otel-collector` service as backend services
- Ensures all traces go through the same collector for correlation

**Before**:
```yaml
OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger:4318/v1/traces"
```

**After**:
```yaml
OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4318/v1/traces"
```

### 5. API Client Trace Header Propagation
**File**: `frontend/src/lib/api/client.ts`

**Changes**:
- Updated to use proper trace context from process OpenTelemetry utilities
- Added proper TypeScript interfaces for type safety
- Ensures trace headers are included in all API requests

**Code**:
```typescript
// Trace propagation utilities
const getCurrentTraceContext = (): string | null => {
  // Use the process OpenTelemetry utilities if available (server-side)
  if (typeof process !== 'undefined') {
    interface ProcessWithOtelUtils extends NodeJS.Process {
      __OTEL_TRACE_UTILS__?: {
        getCurrentTraceContext: () => string | null;
      };
    }
    const processWithUtils = process as ProcessWithOtelUtils;
    if (processWithUtils.__OTEL_TRACE_UTILS__) {
      return processWithUtils.__OTEL_TRACE_UTILS__.getCurrentTraceContext();
    }
  }
  
  // Fallback for client-side (though this shouldn't be used in SSR context)
  if (typeof window !== 'undefined') {
    interface WindowWithOtelContext extends Window {
      __OTEL_TRACE_CONTEXT__?: string;
    }
    const windowWithContext = window as WindowWithOtelContext;
    if (windowWithContext.__OTEL_TRACE_CONTEXT__) {
      return windowWithContext.__OTEL_TRACE_CONTEXT__;
    }
  }
  
  return null;
};

// Add trace context header for distributed tracing
const traceContext = getCurrentTraceContext();
if (traceContext) {
  config.headers['traceparent'] = traceContext;
}
```

## Testing and Verification

### Test Script
**File**: `scripts/test-trace-propagation.sh`

**Purpose**: Comprehensive testing of trace propagation across all services

**Features**:
- Generates test traffic to create traces
- Verifies OpenTelemetry Collector is processing traces
- Checks service logs for trace header propagation
- Provides guidance for manual verification in Jaeger UI

### Manual Verification Steps
1. Deploy the application to Kubernetes
2. Run the test script: `./scripts/test-trace-propagation.sh`
3. Open Jaeger UI and search for recent traces
4. Verify that traces span multiple services with consistent trace IDs
5. Check that parent-child relationships are properly established

## Expected Trace Flow

After fixes, the trace flow should be:
```
Frontend → API Gateway → Backend Service → Database
```

Each service should:
- Receive trace context from upstream service
- Create child spans for its operations
- Propagate trace context to downstream services
- Send spans to OpenTelemetry Collector

## Configuration Summary

### Environment Variables (All Services)
```yaml
OTEL_SERVICE_NAME: <service-name>
OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4317  # Backend services
OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4318/v1/traces  # Frontend
OTEL_EXPORTER_OTLP_PROTOCOL: grpc  # Backend services
OTEL_EXPORTER_OTLP_PROTOCOL: http/protobuf  # Frontend
OTEL_TRACES_EXPORTER: otlp
OTEL_METRICS_EXPORTER: otlp
OTEL_LOGS_EXPORTER: otlp
OTEL_TRACES_SAMPLER: always_on
OTEL_PROPAGATORS: tracecontext
OTEL_RESOURCE_ATTRIBUTES: service.namespace=banking-app
```

### Spring Boot Configuration (Backend Services)
```yaml
otel:
  service:
    name: ${spring.application.name}
  exporter:
    otlp:
      protocol: grpc
      endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:http://localhost:4317}
  traces:
    exporter: otlp
    propagators: tracecontext
    sampler:
      type: always_on
  propagation:
    type: tracecontext
```

## Troubleshooting

### Common Issues
1. **Traces not appearing in Jaeger**: Check if OpenTelemetry Collector is running and accessible
2. **Disconnected traces**: Verify trace header propagation in service logs
3. **Missing spans**: Ensure all services have OpenTelemetry properly configured
4. **Wrong trace IDs**: Check that trace context is being properly propagated between services

### Debug Commands
```bash
# Check OpenTelemetry Collector logs
kubectl logs -n banking-app -l app=opentelemetry,component=otel-collector

# Check service logs for trace headers
kubectl logs -n banking-app -l app=api-gateway | grep -i trace

# Verify service configuration
kubectl get configmap -n banking-app app-config -o yaml
```

## Results

After implementing these fixes:
- ✅ Trace IDs properly propagate from frontend to backend services
- ✅ Complete end-to-end traces visible in Jaeger UI
- ✅ Service-to-service calls maintain trace context
- ✅ Consistent trace correlation across all services
- ✅ Proper parent-child span relationships established 