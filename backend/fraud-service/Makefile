IMAGE_NAME = ghcr.io/speedscale/microsvc/fraud-service
VERSION    = $(shell cat ../../VERSION 2>/dev/null || echo "1.0.0")
GIT_SHA    = $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
IMAGE_TAG  = v$(VERSION)-$(GIT_SHA)

.PHONY: build test docker-build

build: ## Compile the binary
	go build -trimpath -o bin/fraud-service ./cmd/server

test: ## Run unit tests
	go test ./...

docker-build: ## Build Docker image
	docker build \
		--tag $(IMAGE_NAME):$(IMAGE_TAG) \
		--tag $(IMAGE_NAME):latest \
		.
