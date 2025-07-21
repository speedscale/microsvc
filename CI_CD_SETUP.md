# CI/CD Pipeline Setup

This document describes the CI/CD pipeline setup for the banking application microservices.

## Overview

The CI/CD pipeline uses GitHub Actions for automated building, testing, and deployment. The pipeline includes:

1. **Continuous Integration (CI)**: Automated testing and building
2. **Container Registry**: Docker images pushed to GitHub Container Registry
3. **Continuous Deployment (CD)**: Automated deployment to Kubernetes

## Pipeline Structure

### CI Pipeline (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main`, `develop`, or `feature/*` branches
- Pull requests to `main` or `develop`

**Jobs:**
1. `test-backend`: Tests all Java microservices
2. `test-frontend`: Tests Next.js frontend application  
3. `build-and-push`: Builds and pushes Docker images to registry
4. `e2e-test`: Runs end-to-end Playwright tests (main branch only)

### Deployment Pipeline (`.github/workflows/deploy.yml`)

**Triggers:**
- Push to `main` branch
- Git tags matching `v*`
- Manual workflow dispatch

**Jobs:**
1. Updates Kubernetes manifests with registry image references
2. Deploys to staging/production environments

## Container Registry

Images are pushed to GitHub Container Registry (GHCR) at:
- `ghcr.io/speedscale/microsvc/user-service`
- `ghcr.io/speedscale/microsvc/accounts-service`
- `ghcr.io/speedscale/microsvc/transactions-service`
- `ghcr.io/speedscale/microsvc/api-gateway`
- `ghcr.io/speedscale/microsvc/frontend`

## Makefile Commands

The project includes comprehensive Makefiles for development and deployment:

### Root Makefile Commands

**Build & Test:**
```bash
make build-all          # Build all services
make test-all           # Run all tests
make docker-build       # Build Docker images
make docker-push        # Push to registry
```

**Development:**
```bash
make dev-up            # Start dev environment
make dev-down          # Stop dev environment  
make dev-reset         # Reset dev environment
```

**CI/CD:**
```bash
make ci-test           # Run CI tests
make ci-build          # Build and push images
make ci-deploy         # Full CI/CD pipeline
```

### Kubernetes Makefile Commands

```bash
cd kubernetes
make deploy            # Deploy to Kubernetes
make update-images     # Update manifests with registry images
make status            # Check deployment status
make logs              # View service logs
make test-deployment   # Run E2E tests against deployment
```

## Environment Variables

**CI/CD Configuration:**
- `REGISTRY`: Docker registry URL (default: `ghcr.io/speedscale/microsvc`)
- `IMAGE_TAG`: Docker image tag (default: `latest`)

**GitHub Secrets Required:**
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

## Image Tagging Strategy

- **Latest**: `latest` tag for main branch builds
- **Branch**: `feature-branch-name` for feature branches
- **SHA**: `main-abc1234` for commit-specific builds
- **Release**: `v1.0.0` for tagged releases

## Deployment Environments

### Staging
- Triggered on push to `main` branch
- Uses latest images from main branch
- Deployed to staging Kubernetes cluster

### Production  
- Triggered on git tags (`v*`) or manual dispatch
- Uses tagged release images
- Deployed to production Kubernetes cluster

## Local Development with Registry Images

To test with registry images locally:

```bash
# Update manifests to use registry images
make update-k8s-images REGISTRY=ghcr.io/speedscale/microsvc IMAGE_TAG=latest

# Deploy to minikube
cd kubernetes
make deploy

# Restore local images for development
make restore-local-images
```

## Troubleshooting

### Authentication Issues
If you encounter registry authentication issues:
1. Ensure `GITHUB_TOKEN` has `packages:write` permission
2. Check that the repository has GitHub Packages enabled

### Image Pull Failures
If Kubernetes can't pull images:
1. Verify the image exists in the registry
2. Check `imagePullPolicy` is set to `Always` for registry images
3. Ensure Kubernetes has access to pull from GHCR

### Build Failures
If tests fail in CI:
1. Run tests locally: `make test-all`
2. Check test database setup in GitHub Actions
3. Verify all environment variables are set correctly