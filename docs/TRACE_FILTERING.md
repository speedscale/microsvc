# Trace Filtering Configuration Guide

This document describes the OpenTelemetry trace filtering configuration for the Banking App to ensure only business transactions are captured while filtering out health checks and monitoring endpoints.

## Overview

The application is configured to:
1. **INCLUDE** all business API traffic (user operations, accounts, transactions)
2. **EXCLUDE** all health check and monitoring endpoints
3. **VALIDATE** trace content systematically

## Filtered Endpoints (Excluded from Traces)

The following endpoints are filtered out by the OpenTelemetry collector:

| Pattern | Purpose | Used By |
|---------|---------|---------|
| `/actuator/health` | Spring Boot health check | Kubernetes probes, monitoring |
| `/actuator/prometheus` | Prometheus metrics endpoint | Prometheus scraping |
| `/actuator/info` | Application info endpoint | Monitoring |
| `/actuator/metrics` | Spring Boot metrics | Monitoring |
| `/api/healthz` | Frontend health check | Kubernetes probes |
| `/healthz` | Generic health endpoint | Various services |
| `/metrics` | Generic metrics endpoint | Frontend metrics |
| `/-/ready` | Prometheus readiness | Prometheus internal |
| `/-/healthy` | Prometheus liveness | Prometheus internal |
| `/api/health` | Grafana health check | Grafana internal |

## Business Endpoints (Included in Traces)

The following business endpoints SHOULD appear in traces:

### User Service
- `POST /api/users/register` - User registration
- `POST /api/users/login` - User authentication
- `GET /api/users/profile` - Get user profile
- `GET /api/users/check-username` - Check username availability
- `GET /api/users/check-email` - Check email availability

### Accounts Service
- `GET /api/accounts` - List user accounts
- `POST /api/accounts` - Create new account
- `GET /api/accounts/{id}` - Get account details
- `GET /api/accounts/{id}/balance` - Get account balance
- `PUT /api/accounts/{id}/balance` - Update balance (internal)

### Transactions Service
- `GET /api/transactions` - List transactions
- `POST /api/transactions/deposit` - Make deposit
- `POST /api/transactions/withdraw` - Make withdrawal
- `POST /api/transactions/transfer` - Transfer between accounts

## Configuration Files

### 1. OpenTelemetry Collector Configuration
**File:** `kubernetes/observability/otel-collector.yaml`

The collector uses regex filters to exclude health/monitoring endpoints:
```yaml
processors:
  filter:
    spans:
      exclude:
        match_type: regexp
        attributes:
          - key: url.path
            value: "^(/actuator/.*|/api/healthz|/healthz|/metrics|-/ready|-/healthy)$"
```

### 2. Frontend Health Endpoint
**File:** `frontend/src/app/api/healthz/route.ts`

Standardized health endpoint for frontend:
```typescript
export async function GET() {
  return Response.json(
    { 
      status: 'UP',
      timestamp: new Date().toISOString(),
      service: 'frontend'
    },
    { status: 200 }
  );
}
```

### 3. Kubernetes Deployments
All deployments updated to use consistent health check endpoints:
- Frontend: `/api/healthz`
- Backend services: `/actuator/health`

## Testing Scripts

### 1. Generate Business Traffic
```bash
./scripts/generate-business-traffic.sh
```
Generates real business API traffic including:
- User registration and login
- Account creation
- Deposits, withdrawals, and transfers

### 2. Validate Traces
```bash
./scripts/validate-traces.sh
```
Validates that:
- Business endpoints appear in traces
- Health check endpoints are filtered out
- Database operations are captured

### 3. Comprehensive Testing
```bash
./scripts/test-trace-filtering.sh
```
Interactive menu-driven testing that allows:
- Applying configuration changes
- Resetting environment
- Generating test traffic
- Validating trace content
- Full test cycle automation

## Testing Workflow

### Quick Test
```bash
# 1. Apply the configuration changes
kubectl apply -f kubernetes/observability/otel-collector.yaml
kubectl apply -f kubernetes/base/deployments/frontend-deployment.yaml

# 2. Wait for rollouts
kubectl rollout status deployment/otel-collector -n banking-app
kubectl rollout status deployment/frontend -n banking-app

# 3. Generate business traffic
./scripts/generate-business-traffic.sh

# 4. Wait 10-15 seconds for traces to be processed

# 5. Validate traces
./scripts/validate-traces.sh
```

### Comprehensive Test
```bash
# Run the interactive test script
./scripts/test-trace-filtering.sh

# Select option 9 for full test cycle
# This will:
# - Reset environment
# - Apply configurations
# - Generate traffic
# - Validate traces
```

## Verification Checklist

After configuration:

- [ ] Frontend health checks use `/api/healthz`
- [ ] Backend services use `/actuator/health`
- [ ] OTel collector filters all health/monitoring endpoints
- [ ] Business API calls appear in Jaeger
- [ ] Database operations appear in traces
- [ ] No `/actuator/*` endpoints in traces
- [ ] No `/healthz` or `/metrics` in traces
- [ ] Login/register operations are captured
- [ ] Account operations are captured
- [ ] Transaction operations are captured

## Troubleshooting

### Unwanted Traces Still Appearing
1. Check OTel collector logs:
   ```bash
   kubectl logs -n banking-app deployment/otel-collector
   ```

2. Verify filter configuration is applied:
   ```bash
   kubectl get configmap otel-collector-conf -n banking-app -o yaml
   ```

3. Restart OTel collector:
   ```bash
   kubectl rollout restart deployment/otel-collector -n banking-app
   ```

### Business Traces Missing
1. Ensure services are running:
   ```bash
   kubectl get pods -n banking-app
   ```

2. Generate test traffic:
   ```bash
   ./scripts/generate-business-traffic.sh
   ```

3. Check Jaeger is receiving traces:
   ```bash
   kubectl port-forward -n banking-app service/jaeger 16686:16686
   # Open http://localhost:16686
   ```

### Port Forwarding Issues
If using Colima, standard port forwarding should work:
```bash
kubectl port-forward -n banking-app service/api-gateway 8080:80
kubectl port-forward -n banking-app service/jaeger 16686:16686
```

## Notes

1. **Filter Regex**: The OTel filter uses regex patterns. Ensure patterns match exactly what appears in span attributes.

2. **Trace Processing Delay**: Allow 10-15 seconds after generating traffic for traces to be processed and appear in Jaeger.

3. **Service Dependencies**: Ensure all services are healthy before generating test traffic.

4. **Prometheus Scraping**: Prometheus continues to scrape metrics endpoints, but these requests won't appear in traces.

5. **Kubernetes Probes**: Health check probes continue to function but won't generate trace spans.