# Frontend Makefile
# Service configuration
SERVICE_NAME := frontend
SERVICE_PORT := 3000

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help:
	@echo "Available targets for $(SERVICE_NAME):"
	@echo "  build                 - Build the frontend"
	@echo "  dev                   - Run development server"
	@echo "  test                  - Run tests"
	@echo "  clean                 - Clean build artifacts"

# Build target
.PHONY: build
build:
	@echo "Building $(SERVICE_NAME)..."
	npm run build

# Dev target
.PHONY: dev
dev:
	@echo "Starting $(SERVICE_NAME) development server on port $(SERVICE_PORT)..."
	npm run dev

# Test target
.PHONY: test
test:
	@echo "Running tests for $(SERVICE_NAME)..."
	npm test

# Clean target
.PHONY: clean
clean:
	@echo "Cleaning $(SERVICE_NAME)..."
	rm -rf build/ dist/ .next/
