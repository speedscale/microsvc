# Accounts Service Makefile
# Service configuration
SERVICE_NAME := accounts-service
SERVICE_PORT := 8082

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help:
	@echo "Available targets for $(SERVICE_NAME):"
	@echo "  build                 - Build the service"
	@echo "  run                   - Run the service locally"
	@echo "  test                  - Run tests"
	@echo "  clean                 - Clean build artifacts"

# Build target
.PHONY: build
build:
	@echo "Building $(SERVICE_NAME)..."
	./mvnw clean package -DskipTests

# Run target
.PHONY: run
run:
	@echo "Running $(SERVICE_NAME) on port $(SERVICE_PORT)..."
	java -jar target/accounts-service-1.0.0.jar

# Test target
.PHONY: test
test:
	@echo "Running tests for $(SERVICE_NAME)..."
	./mvnw test

# Clean target
.PHONY: clean
clean:
	@echo "Cleaning $(SERVICE_NAME)..."
	./mvnw clean
