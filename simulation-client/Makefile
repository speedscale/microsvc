# Banking Simulation Client Makefile

# Project configuration
PROJECT_NAME = simulation-client
IMAGE_NAME = ghcr.io/speedscale/microsvc/simulation-client
VERSION = $(shell cat ../VERSION 2>/dev/null || echo "1.0.0")
GIT_SHA = $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
IMAGE_TAG = v$(VERSION)-$(GIT_SHA)

# Docker configuration
DOCKER_BUILDKIT = 1
PLATFORM = linux/amd64,linux/arm64

# Kubernetes configuration
NAMESPACE = banking-app
KUSTOMIZE_DIR = ../kubernetes/base

.PHONY: help
help: ## Show this help message
	@echo "Banking Simulation Client - Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# Development targets
.PHONY: install
install: ## Install Node.js dependencies
	npm install

.PHONY: dev
dev: ## Run simulation client in development mode
	npm run dev

.PHONY: start
start: ## Run simulation client in production mode
	npm start

.PHONY: test
test: ## Run tests
	npm test

.PHONY: lint
lint: ## Run linting
	npm run lint

.PHONY: clean
clean: ## Clean node_modules and temporary files
	rm -rf node_modules coverage .nyc_output

# Docker targets
.PHONY: docker-build
docker-build: ## Build Docker image
	@echo "Building Docker image: $(IMAGE_NAME):$(IMAGE_TAG)"
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker build \
		--tag $(IMAGE_NAME):$(IMAGE_TAG) \
		--tag $(IMAGE_NAME):latest \
		--label "version=$(VERSION)" \
		--label "git-sha=$(GIT_SHA)" \
		--label "build-date=$(shell date -u +%Y-%m-%dT%H:%M:%SZ)" \
		.

.PHONY: docker-build-multiarch
docker-build-multiarch: ## Build multi-architecture Docker image
	@echo "Building multi-architecture Docker image: $(IMAGE_NAME):$(IMAGE_TAG)"
	docker buildx build \
		--platform $(PLATFORM) \
		--tag $(IMAGE_NAME):$(IMAGE_TAG) \
		--tag $(IMAGE_NAME):latest \
		--label "version=$(VERSION)" \
		--label "git-sha=$(GIT_SHA)" \
		--label "build-date=$(shell date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--push \
		.

.PHONY: docker-push
docker-push: ## Push Docker image to registry
	@echo "Pushing Docker image: $(IMAGE_NAME):$(IMAGE_TAG)"
	docker push $(IMAGE_NAME):$(IMAGE_TAG)
	docker push $(IMAGE_NAME):latest

.PHONY: docker-run
docker-run: ## Run Docker container locally
	docker run --rm \
		--name $(PROJECT_NAME) \
		--env-file .env.example \
		--env TARGET_BASE_URL=http://host.docker.internal:3000 \
		$(IMAGE_NAME):latest

.PHONY: docker-shell
docker-shell: ## Run shell in Docker container
	docker run --rm -it \
		--entrypoint /bin/sh \
		$(IMAGE_NAME):latest

# Kubernetes targets
.PHONY: k8s-apply
k8s-apply: ## Apply Kubernetes manifests (deploys entire banking app including simulation client)
	@echo "Applying Kubernetes manifests..."
	kubectl apply -k $(KUSTOMIZE_DIR)

.PHONY: k8s-delete
k8s-delete: ## Delete Kubernetes resources (simulation client only)
	@echo "Deleting simulation client resources..."
	kubectl delete deployment simulation-client -n $(NAMESPACE) --ignore-not-found=true
	kubectl delete configmap simulation-client-config -n $(NAMESPACE) --ignore-not-found=true
	kubectl delete secret simulation-client-secret -n $(NAMESPACE) --ignore-not-found=true
	kubectl delete hpa simulation-client-hpa -n $(NAMESPACE) --ignore-not-found=true

.PHONY: k8s-restart
k8s-restart: ## Restart Kubernetes deployment
	kubectl rollout restart deployment/simulation-client -n $(NAMESPACE)

.PHONY: k8s-status
k8s-status: ## Show Kubernetes deployment status
	@echo "Simulation Client deployment status:"
	kubectl get pods -l app=simulation-client -n $(NAMESPACE)
	@echo ""
	@echo "Recent events:"
	kubectl get events --field-selector involvedObject.name=simulation-client -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -5

.PHONY: k8s-logs
k8s-logs: ## Show Kubernetes pod logs
	kubectl logs -l app=simulation-client -n $(NAMESPACE) --tail=100 -f

.PHONY: k8s-describe
k8s-describe: ## Describe Kubernetes deployment
	kubectl describe deployment simulation-client -n $(NAMESPACE)

.PHONY: k8s-scale
k8s-scale: ## Scale deployment (usage: make k8s-scale REPLICAS=3)
	kubectl scale deployment simulation-client --replicas=$(REPLICAS) -n $(NAMESPACE)

# Database migration targets
.PHONY: migrate-simulation-users
migrate-simulation-users: ## Run simulation users migration
	@echo "Running simulation users migration..."
	cd ../backend/user-service && ./mvnw flyway:migrate

.PHONY: check-simulation-users
check-simulation-users: ## Check if simulation users exist
	@echo "Checking simulation users in database..."
	kubectl exec -it deployment/postgres -n $(NAMESPACE) -- \
		psql -U postgres -d banking_app -c \
		"SELECT COUNT(*) as simulation_users FROM users WHERE username LIKE 'sim_user_%';"

# Monitoring targets
.PHONY: metrics
metrics: ## Show simulation metrics from logs
	kubectl logs -l app=simulation-client -n $(NAMESPACE) --tail=50 | grep -E "(metrics|session|transaction)"

.PHONY: health
health: ## Check simulation client health
	@echo "Checking simulation client health..."
	kubectl get pods -l app=simulation-client -n $(NAMESPACE)

# Environment setup
.PHONY: env-example
env-example: ## Create example environment file
	@echo "Creating .env.example file..."
	@cat > .env.example << 'EOF'
# Application settings
NODE_ENV=development
LOG_LEVEL=info
LOG_FORMAT=json

# Target application
TARGET_BASE_URL=http://localhost:3000
REQUEST_TIMEOUT=10000

# Simulation settings
CONCURRENT_USERS=3
EXISTING_USER_PERCENTAGE=80
SESSION_DURATION_MS=300000
MIN_ACTION_DELAY=1000
MAX_ACTION_DELAY=5000
NEW_USER_DELAY=2000
MAX_RETRIES=3
RETRY_DELAY=1000

# User pool
USER_PREFIX=sim_user_
TOTAL_USERS=1000
SIM_USER_PASSWORD=SimUser123!

# Transaction simulation
DEPOSIT_PROBABILITY=0.3
WITHDRAWAL_PROBABILITY=0.2
TRANSFER_PROBABILITY=0.1
MIN_DEPOSIT=10.00
MAX_DEPOSIT=1000.00
MIN_WITHDRAWAL=5.00
MAX_WITHDRAWAL=500.00
MIN_TRANSFER=10.00
MAX_TRANSFER=250.00

# OpenTelemetry
OTEL_SERVICE_NAME=simulation-client
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
METRICS_INTERVAL=30000
EOF

# All-in-one targets
.PHONY: build-and-deploy
build-and-deploy: docker-build docker-push k8s-apply ## Build Docker image and deploy to Kubernetes

.PHONY: quick-deploy
quick-deploy: docker-build k8s-restart ## Quick build and restart (for local development)

# Version management
.PHONY: version
version: ## Show current version information
	@echo "Version: $(VERSION)"
	@echo "Git SHA: $(GIT_SHA)"
	@echo "Image: $(IMAGE_NAME):$(IMAGE_TAG)"