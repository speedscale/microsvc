# Frontend Logging Guide

## Overview

The frontend application has been configured with comprehensive logging to help with debugging and monitoring.

## Logging Configuration

### 1. Instrumentation Hook

The frontend uses Next.js instrumentation hook to enable server-side logging. This is configured in `frontend/next.config.ts`:

```typescript
experimental: {
  instrumentationHook: true,
} as any,
```

### 2. Logging Sources

The following components provide logging:

- **`src/instrumentation.ts`**: OpenTelemetry instrumentation logging
- **`src/app/layout.tsx`**: Server-side layout rendering logs
- **`src/app/page.tsx`**: Client-side page component logs

### 3. Environment Variables

All environment variables are managed through Kubernetes ConfigMaps:

- **Base Configuration** (`kubernetes/base/configmaps/app-config.yaml`): Uses `localhost:8080` for local development
- **Speedscale Overlay** (`kubernetes/overlays/speedscale/frontend-config-patch.yaml`): Uses production domain (edit to set your actual domain)

## Expected Log Messages

When the frontend starts and receives requests, you should see:

1. **Instrumentation logs** (server-side):
   ```
   🔍 Registering OpenTelemetry instrumentation for frontend server...
   ✅ OpenTelemetry instrumentation registered successfully for frontend server
   ```

2. **Layout rendering logs** (server-side):
   ```
   🚀 Frontend layout component rendered on server
   ```

3. **Page component logs** (client-side):
   ```
   🏠 Home page component mounted, auth status: { isAuthenticated: false, isLoading: true }
   🔓 User not authenticated, redirecting to login
   ```

## Troubleshooting

### No Logs Appearing

If you're not seeing any log messages when port forwarding:

1. **Check if instrumentation is enabled**:
   ```bash
   kubectl exec -n banking-app <frontend-pod> -- cat /app/.next/server/instrumentation.js
   ```

2. **Check pod logs**:
   ```bash
   kubectl logs -n banking-app <frontend-pod> -f
   ```

3. **Verify environment variables**:
   ```bash
   kubectl exec -n banking-app <frontend-pod> -- env | grep -E "(NODE_ENV|OTEL_)"
   ```

4. **Test with the provided script**:
   ```bash
   ./scripts/test-frontend-logs.sh
   ```

### Common Issues

1. **Instrumentation not loading**: Ensure `experimental.instrumentationHook: true` is set in `next.config.ts`
2. **Build issues**: The instrumentation file is only loaded in production mode with proper environment variables
3. **Client vs Server logs**: Some logs only appear on the server side, others on the client side

## Testing Logging

Use the provided test script to verify logging is working:

```bash
./scripts/test-frontend-logs.sh
```

## Rebuilding the Frontend

After making changes to the logging configuration, rebuild the frontend:

```bash
# Build the frontend
cd frontend
npm run build

# Rebuild the Docker image
docker build -t ghcr.io/speedscale/microsvc/frontend:latest .

# Redeploy to Kubernetes
kubectl rollout restart deployment/frontend -n banking-app
```

## Monitoring

The frontend sends OpenTelemetry traces to Jaeger for monitoring. You can access the Jaeger UI to view traces and spans from the frontend application. 