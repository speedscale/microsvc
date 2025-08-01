# Banking Application Makefile

# Configuration
REGISTRY ?= ghcr.io/speedscale/microsvc
IMAGE_TAG ?= latest
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
	@echo "Building Docker images..."
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
	@echo "Running E2E tests..."
	./scripts/validate-e2e.sh

validate-e2e: test-e2e

test-all: test-backend test-frontend test-e2e

# Kubernetes targets
.PHONY: k8s-deploy k8s-deploy-local k8s-undeploy k8s-redeploy k8s-status k8s-cleanup deploy undeploy redeploy status deploy-k8s cleanup-k8s
k8s-deploy:
	@echo "Deploying to Kubernetes..."
	kubectl apply -k $(KUSTOMIZE_DIR)/

k8s-undeploy:
	@echo "Removing application from Kubernetes..."
	kubectl delete -k $(KUSTOMIZE_DIR)/ || true

k8s-redeploy: k8s-undeploy k8s-deploy

k8s-status:
	@echo "Checking deployment status..."
	kubectl get all -n $(NAMESPACE)
	@echo "\nPod status:"
	kubectl get pods -n $(NAMESPACE) -o wide
	@echo "\nService endpoints:"
	kubectl get svc -n $(NAMESPACE)

k8s-cleanup: k8s-undeploy

k8s-deploy-local:
	@echo "Deploying to Kubernetes..."
	kubectl apply -k $(KUSTOMIZE_DIR)/

# Production deployment
deploy:
	@echo "Deploying banking application to Kubernetes..."
	kubectl apply -k $(KUSTOMIZE_DIR)/

# Legacy aliases
undeploy: k8s-undeploy
redeploy: k8s-redeploy  
status: k8s-status
deploy-k8s: deploy
cleanup-k8s: k8s-undeploy


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

# Legacy minikube aliases (deprecated)
.PHONY: minikube-deploy minikube-cleanup
minikube-deploy: k8s-deploy-local
minikube-cleanup: k8s-cleanup

# CI/CD targets
.PHONY: ci-test ci-build ci-deploy
ci-test: test-all

ci-build: build-all docker-build-push

ci-deploy: ci-build deploy-k8s

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
	@echo "  test-backend       - Run backend tests"
	@echo "  test-frontend      - Run frontend tests"
	@echo "  test-e2e           - Run E2E tests with CI configuration"
	@echo "  validate-e2e       - Validate E2E tests (alias for test-e2e)"
	@echo "  test-all           - Run all tests (backend, frontend, e2e)"
	@echo ""
	@echo "Kubernetes:"
	@echo "  k8s-deploy         - Deploy to Kubernetes (registry images)"
	@echo "  k8s-deploy-local   - Deploy to Kubernetes (local images)"
	@echo "  k8s-undeploy       - Remove application from Kubernetes"
	@echo "  k8s-redeploy       - Remove and redeploy application"
	@echo "  k8s-status         - Check deployment status"
	@echo "  k8s-cleanup        - Cleanup Kubernetes deployment"
	@echo "  deploy             - Deploy to Kubernetes (registry images)"
	@echo ""
	@echo "Image Management:"
	@echo "  update-images      - Update manifests to use registry images"
	@echo "  restore-local-images - Restore local image references"
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