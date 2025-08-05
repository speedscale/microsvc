# Banking Application Makefile

# Configuration
REGISTRY ?= ghcr.io/speedscale/microsvc
IMAGE_TAG ?= $(shell ./scripts/version.sh tag)
NAMESPACE ?= banking-app
KUSTOMIZE_DIR ?= kubernetes/base
SERVICES = user-service accounts-service transactions-service api-gateway

# Default target
.PHONY: help
.DEFAULT_GOAL := help

# Docker related targets
.PHONY: build-backend build-frontend build-all
build-backend:
	@echo "Building backend services..."
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		cd backend/$$service && ./mvnw clean package -DskipTests && cd ../..; \
	done

build-frontend:
	@echo "Building frontend..."
	cd frontend && npm ci && npm run build

build-all: build-backend build-frontend

# Docker image targets
.PHONY: docker-build docker-push docker-build-push
docker-build:
	@echo "Building Docker images with version: $(IMAGE_TAG)..."
	@for service in $(SERVICES); do \
		echo "Building Docker image for $$service..."; \
		docker build -t $(REGISTRY)/$$service:$(IMAGE_TAG) backend/$$service/; \
	done
	@echo "Building Docker image for frontend..."
	docker build -t $(REGISTRY)/frontend:$(IMAGE_TAG) frontend/

docker-push:
	@echo "Pushing Docker images to $(REGISTRY)..."
	@for service in $(SERVICES) frontend; do \
		echo "Pushing $$service..."; \
		docker push $(REGISTRY)/$$service:$(IMAGE_TAG); \
	done

docker-build-push: docker-build docker-push

# Local development with versioned images
.PHONY: docker-build-versioned docker-clean-versioned
docker-build-versioned:
	@echo "Building versioned Docker images for local development..."
	@VERSION_TAG=$$(./scripts/version.sh tag); \
	for service in $(SERVICES); do \
		echo "Building Docker image for $$service with tag: $$VERSION_TAG..."; \
		docker build -t $(REGISTRY)/$$service:$$VERSION_TAG backend/$$service/; \
	done
	@VERSION_TAG=$$(./scripts/version.sh tag); \
	echo "Building Docker image for frontend with tag: $$VERSION_TAG..."; \
	docker build -t $(REGISTRY)/frontend:$$VERSION_TAG frontend/
	@echo "Versioned images built successfully!"
	@echo "Current version: $(shell ./scripts/version.sh get)"
	@echo "Image tag: $(shell ./scripts/version.sh tag)"

docker-clean-versioned:
	@echo "Cleaning versioned Docker images..."
	@VERSION_TAG=$$(./scripts/version.sh tag); \
	for service in $(SERVICES) frontend; do \
		echo "Removing $$service:$$VERSION_TAG..."; \
		docker rmi $(REGISTRY)/$$service:$$VERSION_TAG 2>/dev/null || true; \
	done

# Test targets
.PHONY: test-backend test-frontend test-all test-e2e validate-e2e
test-backend:
	@echo "Running backend tests..."
	@for service in $(SERVICES); do \
		echo "Testing $$service..."; \
		cd backend/$$service && ./mvnw test && cd ../..; \
	done

test-frontend:
	@echo "Running frontend tests..."
	cd frontend && npm ci && npm test -- --coverage --watchAll=false

test-e2e:
	@echo "🎭 Running Playwright E2E tests..."
	@cd frontend && ./run-e2e.sh

test-e2e-ui:
	@echo "🎭 Running Playwright E2E tests with UI..."
	@cd frontend && npm run test:e2e:ui

test-e2e-debug:
	@echo "🎭 Running Playwright E2E tests in debug mode..."
	@cd frontend && npm run test:e2e:headed

test-e2e-k8s:
	@echo "🎭 Running Playwright E2E tests against Kubernetes..."
	@echo "📡 Setting up port-forward to frontend service..."
	@kubectl port-forward -n banking-app service/frontend-nodeport 30080:80 &
	@sleep 3
	@BASE_URL=http://localhost:30080 cd frontend && ./run-e2e.sh
	@pkill -f "kubectl port-forward.*frontend-nodeport" || true

validate-e2e: test-e2e

test-all: test-backend test-frontend test-e2e

# Kubernetes targets - Consolidated
.PHONY: k8s-deploy observability-deploy speedscale-deploy k8s-cleanup k8s-status
k8s-deploy:
	@echo "Deploying banking application to Kubernetes..."
	kubectl apply -k $(KUSTOMIZE_DIR)/

observability-deploy:
	@echo "Deploying observability stack..."
	kubectl apply -k kubernetes/observability/

speedscale-deploy:
	@echo "Deploying with Speedscale overlay..."
	kubectl apply -k kubernetes/overlays/speedscale/

k8s-cleanup:
	@echo "Cleaning up all Kubernetes resources..."
	kubectl delete -k kubernetes/overlays/speedscale/ || true
	kubectl delete -k kubernetes/observability/ || true
	kubectl delete -k $(KUSTOMIZE_DIR)/ || true

k8s-status:
	@echo "Checking deployment status..."
	kubectl get all -n $(NAMESPACE)
	@echo "\nPod status:"
	kubectl get pods -n $(NAMESPACE) -o wide
	@echo "\nService endpoints:"
	kubectl get svc -n $(NAMESPACE)

# Development targets
.PHONY: dev-up dev-down dev-logs dev-reset
dev-up:
	@echo "Starting development environment..."
	docker-compose up -d

dev-down:
	@echo "Stopping development environment..."
	docker-compose down

dev-logs:
	docker-compose logs -f

dev-reset: dev-down
	@echo "Resetting development environment..."
	docker-compose down -v
	docker-compose up -d

# Testing and debugging targets
.PHONY: logs port-forward test-deployment
logs:
	@echo "Fetching logs from all services..."
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=banking-app --tail=100 -f

port-forward:
	@echo "Port forwarding API Gateway to localhost:8080..."
	kubectl port-forward -n $(NAMESPACE) service/api-gateway 8080:8080

test-deployment:
	@echo "Testing deployment with E2E test client..."
	kubectl apply -f kubernetes/testing/test-client-job.yaml
	@echo "Waiting for test job to complete..."
	kubectl wait --for=condition=complete job/banking-e2e-test -n $(NAMESPACE) --timeout=300s
	kubectl logs -n $(NAMESPACE) job/banking-e2e-test
	kubectl delete job/banking-e2e-test -n $(NAMESPACE)

# CI/CD targets
.PHONY: ci-test ci-build ci-deploy pre-commit
ci-test: test-all

ci-build: build-all docker-build-push

ci-deploy: ci-build k8s-deploy

# Pre-commit validation
pre-commit:
	@echo "🔍 Running pre-commit validation..."
	@if [ -n "$(shell git diff --cached --name-only | grep -E '^frontend/')" ] || [ -n "$(shell git diff --name-only | grep -E '^frontend/')" ]; then \
		echo "⚠️  Frontend changes detected. Running E2E validation..."; \
		$(MAKE) test-e2e; \
	else \
		echo "✅ No frontend changes detected. Skipping E2E validation."; \
	fi
	@echo "✅ Pre-commit validation completed successfully!"

# Version management targets
.PHONY: version version-info version-bump version-set update-k8s-version
version:
	@./scripts/version.sh get

version-info:
	@./scripts/version.sh info

version-bump:
	@if [ -z "$(BUMP_TYPE)" ]; then \
		echo "Usage: make version-bump BUMP_TYPE=<patch|minor|major>"; \
		exit 1; \
	fi
	@./scripts/version.sh bump $(BUMP_TYPE)

version-set:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make version-set VERSION=<version>"; \
		exit 1; \
	fi
	@./scripts/version.sh set $(VERSION)

update-k8s-version:
	@./scripts/version.sh update-k8s

# Utility targets
.PHONY: clean help
clean:
	@echo "Cleaning up..."
	@for service in $(SERVICES); do \
		cd backend/$$service && ./mvnw clean && cd ../..; \
	done
	cd frontend && rm -rf .next node_modules || true

help:
	@echo "Banking Application Makefile - Available targets:"
	@echo ""
	@echo "Build & Test:"
	@echo "  build-backend       - Build all backend services"
	@echo "  build-frontend      - Build frontend application"
	@echo "  build-all          - Build all services"
	@echo "  docker-build       - Build Docker images"
	@echo "  docker-push        - Push Docker images to registry"
	@echo "  docker-build-push  - Build and push Docker images"
	@echo "  docker-build-versioned - Build Docker images with current version tag"
	@echo "  docker-clean-versioned - Remove versioned Docker images"
	@echo "  test-backend       - Run backend tests"
	@echo "  test-frontend      - Run frontend tests"
	@echo "  test-e2e           - Run Playwright E2E tests (automated user journey)"
	@echo "  test-e2e-ui        - Run E2E tests with Playwright UI"
	@echo "  test-e2e-debug     - Run E2E tests in headed browser mode"
	@echo "  test-e2e-k8s       - Run E2E tests against Kubernetes deployment"
	@echo "  validate-e2e       - Validate E2E tests (alias for test-e2e)"
	@echo "  test-all           - Run all tests (backend, frontend, e2e)"
	@echo ""
	@echo "Kubernetes:"
	@echo "  k8s-deploy         - Deploy banking application to Kubernetes"
	@echo "  observability-deploy - Deploy observability stack (Grafana, Prometheus, Jaeger)"
	@echo "  speedscale-deploy  - Deploy with Speedscale overlay"
	@echo "  k8s-cleanup        - Clean up all Kubernetes resources"
	@echo "  k8s-status         - Check deployment status"
	@echo ""
	@echo "Testing & Debugging:"
	@echo "  logs               - Fetch logs from all services"
	@echo "  port-forward       - Port forward API Gateway to localhost:8080"
	@echo "  test-deployment    - Run E2E test against deployment"
	@echo ""
	@echo "Development:"
	@echo "  dev-up             - Start development environment (Docker Compose)"
	@echo "  dev-down           - Stop development environment"
	@echo "  dev-logs           - Show development logs"
	@echo "  dev-reset          - Reset development environment"
	@echo ""
	@echo "CI/CD:"
	@echo "  ci-test            - Run CI tests"
	@echo "  ci-build           - Run CI build and push"
	@echo "  ci-deploy          - Run full CI/CD pipeline"
	@echo "  pre-commit         - Run pre-commit validation"
	@echo ""
	@echo "Version Management:"
	@echo "  version            - Get current version"
	@echo "  version-info       - Show version information"
	@echo "  version-bump       - Bump version (BUMP_TYPE=<patch|minor|major>)"
	@echo "  version-set        - Set version (VERSION=<version>)"
	@echo "  update-k8s-version - Update Kubernetes manifests with current version"
	@echo ""
	@echo "Utilities:"
	@echo "  clean              - Clean build artifacts"
	@echo "  help               - Show this help"
	@echo ""
	@echo "Environment Variables:"
	@echo "  REGISTRY           - Docker registry (default: ghcr.io/speedscale/microsvc)"
	@echo "  IMAGE_TAG          - Docker image tag (default: latest)"
	@echo "  NAMESPACE          - Kubernetes namespace (default: banking-app)"
	@echo "  KUSTOMIZE_DIR      - Kustomize directory (default: kubernetes/base)"