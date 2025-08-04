# Kubernetes Deployment

This directory contains Kubernetes manifests for deploying the banking application.

## Quick Start

Deploy the application using the Makefile:

```bash
# Deploy core application
make k8s-deploy

# Deploy observability stack (optional)
make observability-deploy

# Deploy with Speedscale overlay (optional)
make speedscale-deploy

# Check status
make k8s-status

# Clean up everything
make k8s-cleanup
```

## Architecture

- **Database**: PostgreSQL with persistent storage
- **Microservices**: User, Accounts, Transactions, and API Gateway services
- **Observability**: Grafana, Prometheus, and Jaeger (optional)
- **Speedscale**: Traffic recording and replay capabilities (optional)

## Access

### Port Forwarding
```bash
# API Gateway
make port-forward

# Or manually
kubectl port-forward -n banking-app service/api-gateway 8080:8080
```

### NodePort (if using minikube/Colima)
```bash
# Get frontend URL
kubectl get svc frontend-nodeport -n banking-app -o jsonpath='{.spec.ports[0].nodePort}'
# Access at http://localhost:<nodePort>
```

## Testing

```bash
# Run E2E tests against deployment
make test-deployment

# View logs
make logs
```

## Directory Structure

```
kubernetes/
├── base/                    # Core application manifests
├── observability/           # Grafana, Prometheus, Jaeger
├── overlays/
│   ├── local/              # Local development overrides
│   └── speedscale/         # Speedscale annotations
└── testing/                # Test client and utilities
```