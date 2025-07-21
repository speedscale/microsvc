# Banking Application Makefile

# Configuration
REGISTRY ?= ghcr.io/speedscale/microsvc
IMAGE_TAG ?= latest
SERVICES = user-service accounts-service transactions-service api-gateway

# Docker related targets
.PHONY: build-backend build-frontend build-all
build-backend:
	@echo "Building backend services..."
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		(cd backend/$$service && mvn clean package -DskipTests) || exit 1; \
	done

build-frontend:
	@echo "Building frontend..."
	cd frontend && npm install && npm run build

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
.PHONY: test-backend test-frontend test-all
test-backend:
	@echo "Running backend tests..."
	@for service in $(SERVICES); do \
		echo "Testing $$service..."; \
		(cd backend/$$service && mvn test) || exit 1; \
	done

test-frontend:
	@echo "Running frontend tests..."
	cd frontend && npm install && npm test -- --coverage --coverageThreshold='{}' --watchAll=false

test-all: test-backend test-frontend

# Kubernetes targets
.PHONY: deploy-k8s cleanup-k8s
deploy-k8s:
	@echo "Deploying to Kubernetes..."
	kubectl apply -k kubernetes/base/

cleanup-k8s:
	@echo "Cleaning up Kubernetes deployment..."
	kubectl delete -k kubernetes/base/ || true

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
		(cd backend/$$service && mvn clean) || true; \
	done
	(cd frontend && rm -rf .next node_modules) || true

help:
	@echo "Available targets:"
	@echo "  build-backend       - Build all backend services"
	@echo "  build-frontend      - Build frontend application"
	@echo "  build-all          - Build all services"
	@echo "  docker-build       - Build Docker images"
	@echo "  docker-push        - Push Docker images to registry"
	@echo "  docker-build-push  - Build and push Docker images"
	@echo "  test-backend       - Run backend tests"
	@echo "  test-frontend      - Run frontend tests"
	@echo "  test-all           - Run all tests"
	@echo "  deploy-k8s         - Deploy to Kubernetes"
	@echo "  cleanup-k8s        - Clean up Kubernetes deployment"
	@echo "  dev-up             - Start development environment"
	@echo "  dev-down           - Stop development environment"
	@echo "  dev-logs           - Show development logs"
	@echo "  dev-reset          - Reset development environment"
	@echo "  ci-test            - Run CI tests"
	@echo "  ci-build           - Run CI build and push"
	@echo "  ci-deploy          - Run full CI/CD pipeline"
	@echo "  clean              - Clean build artifacts"
	@echo "  help               - Show this help"
	@echo ""
	@echo "Environment variables:"
	@echo "  REGISTRY           - Docker registry (default: ghcr.io/speedscale/microsvc)"
	@echo "  IMAGE_TAG          - Docker image tag (default: latest)"