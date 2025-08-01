# System Architecture & Traffic Flow

## Traffic Flow Design
All external traffic flows through the frontend service, which acts as the single entry point:

```
Client → Frontend Service → API Gateway → Backend Services
```

## Architecture Principles

- **Frontend as Proxy**: Frontend contains Next.js API routes that proxy requests to the API Gateway
- **No Direct Backend Access**: Clients never directly access backend services or API Gateway
- **Server-Side Communication**: Backend communication uses internal Kubernetes service URLs (e.g., `http://api-gateway:8080`)
- **Relative Client URLs**: Frontend client code uses relative URLs (`/api/users/login`) that route to Next.js API handlers
- **Environment Agnostic**: No hardcoded URLs in client-side code, eliminating `NEXT_PUBLIC_API_URL` configuration issues

## Benefits

- Simplified client configuration (no environment-specific URLs)
- Proper separation of concerns between client and server
- Security through single entry point
- Consistent request/response handling and logging

## Observability

The application is instrumented with OpenTelemetry (OTEL) for comprehensive observability, including distributed tracing, metrics, and logs.

### Monitoring Stack

- **Jaeger**: For distributed trace collection and visualization.
- **Prometheus**: For collecting and storing time-series metrics.
- **Grafana**: For visualizing metrics and creating dashboards.

### Distributed Tracing

Distributed tracing is configured across all services (frontend, API Gateway, and all backend microservices) to provide end-to-end visibility of requests.

- **Trace Propagation**: Uses the W3C Trace Context (`tracecontext`) propagation format to ensure traces are linked across service boundaries.
- **Exporter**: All services use the OTLP (OpenTelemetry Protocol) exporter to send trace data to the Jaeger collector over HTTP/protobuf.
- **Sampling**: Configured for 100% sampling (`always_on`) in development and testing environments for complete visibility.
- **Endpoint**: The Jaeger OTLP HTTP endpoint is `http://jaeger:4318`.

The trace flow follows the application's traffic flow:
`Frontend → API Gateway → Backend Service → Database`

This setup allows for debugging and performance analysis by visualizing the entire lifecycle of a request as it travels through the different components of the system.

## Known Issues & Future Improvements

- **Frontend Pod Logging**: Implemented structured logging with custom logger but logs don't appear in `kubectl logs` output. The logging middleware and API client logging are implemented but may be getting filtered by Next.js internal routing or Edge Runtime limitations. Consider investigating:
  - Server-side API route logging vs middleware logging
  - Alternative logging approaches for containerized Next.js applications