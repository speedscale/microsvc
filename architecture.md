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

## Known Issues & Future Improvements

- **Frontend Pod Logging**: Implemented structured logging with custom logger but logs don't appear in `kubectl logs` output. The logging middleware and API client logging are implemented but may be getting filtered by Next.js internal routing or Edge Runtime limitations. Consider investigating:
  - Server-side API route logging vs middleware logging
  - OpenTelemetry integration for request tracing
  - Alternative logging approaches for containerized Next.js applications 