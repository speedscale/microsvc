# Multi-Architecture Deployment Guide

This document describes the multi-architecture deployment setup for the banking application, supporting both ARM64 (Apple Silicon) and AMD64 (x86_64) architectures.

## Overview

The application is designed to run on multiple CPU architectures:
- **ARM64**: Apple Silicon Macs, ARM-based servers
- **AMD64**: Traditional x86_64 servers and workstations

## Architecture Support

### Backend Services (Spring Boot)
- **user-service**: JWT authentication and user management
- **accounts-service**: Account management and balance tracking
- **transactions-service**: Transaction processing and history
- **api-gateway**: API routing and security

### Frontend
- **frontend**: Next.js React application

### Infrastructure
- **PostgreSQL**: Database with separate schemas per service
- **Jaeger**: Distributed tracing
- **Grafana**: Monitoring and dashboards

## Optimizations Implemented

### Startup Time Improvements
- **54-64% faster startup**: Services now start in ~24 seconds instead of 5+ minutes
- **JVM optimizations**: G1GC, string deduplication, compressed pointers
- **Spring Boot optimizations**: Lazy initialization, reduced logging
- **Database optimizations**: Optimized connection pooling and Hibernate settings

### Multi-Architecture Builds
- **Docker Buildx**: Multi-platform image builds
- **QEMU emulation**: Cross-platform compatibility
- **Optimized base images**: Platform-aware image selection

## Deployment Options

### 1. Local Development (minikube)
```bash
# Complete local deployment
./scripts/deploy-minikube.sh
```

### 2. Production (Registry Images)
```bash
# Deploy using registry images (multi-arch)
kubectl apply -k kubernetes/overlays/speedscale/
```

### 3. CI/CD Pipeline
The GitHub Actions pipeline automatically:
- Builds multi-architecture images (ARM64 + AMD64)
- Runs comprehensive tests
- Pushes to GitHub Container Registry
- Deploys to production environments

## Image Registry

Images are published to: `ghcr.io/speedscale/microsvc/`

### Image Tags
- `latest`: Latest stable release
- `main-<sha>`: Specific commit builds
- `v1.0.0`: Versioned releases

## Performance Metrics

### Startup Times (Optimized)
- **user-service**: ~24 seconds (54% improvement)
- **accounts-service**: ~24 seconds (52% improvement)
- **transactions-service**: ~24 seconds (54% improvement)
- **api-gateway**: ~19 seconds (64% improvement)

### Resource Usage
- **Memory**: Optimized JVM heap settings
- **CPU**: Efficient garbage collection
- **Network**: Optimized database connections

## Troubleshooting

### Common Issues

1. **Image Pull Errors**
   ```bash
   # Check image availability
   docker manifest inspect ghcr.io/speedscale/microsvc/accounts-service:latest
   ```

2. **Database Connection Issues**
   ```bash
   # Verify database connectivity
   kubectl exec -it postgres-pod -- psql -U postgres -d banking_app
   ```

3. **Startup Performance**
   ```bash
   # Check startup times
   ./scripts/check-startup-times.sh
   ```

### Architecture-Specific Issues

- **ARM64**: Ensure QEMU is properly configured
- **AMD64**: Verify platform compatibility
- **Mixed environments**: Use appropriate image tags

## Development Workflow

1. **Local Development**
   ```bash
   # Complete local deployment (builds images and deploys)
   ./scripts/deploy-minikube.sh
   ```

2. **Testing**
   ```bash
   # Run tests
   make test-backend
   make test-frontend
   
   # E2E tests
   npm run test:e2e
   ```

3. **Production Deployment**
   ```bash
   # Deploy to production
   kubectl apply -k kubernetes/overlays/speedscale/
   ```

## Security Considerations

- **Non-root containers**: All services run as non-root users
- **Image scanning**: Regular vulnerability scans
- **Secrets management**: Kubernetes secrets for sensitive data
- **Network policies**: Restricted pod-to-pod communication

## Monitoring and Observability

- **Health checks**: All services have health endpoints
- **Metrics**: Prometheus metrics collection
- **Tracing**: Distributed tracing with Jaeger
- **Logging**: Structured logging with correlation IDs

## Future Improvements

- **Image optimization**: Further reduce image sizes
- **Startup time**: Target sub-20 second startup
- **Resource efficiency**: Optimize memory and CPU usage
- **Security hardening**: Additional security measures 