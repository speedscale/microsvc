# API Gateway Makefile
# Service configuration
SERVICE_NAME := api-gateway
SERVICE_PORT := 8080

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help:
	@echo "Available targets for $(SERVICE_NAME):"
	@echo "  build                 - Build the service"
	@echo "  run                   - Run the service locally"
	@echo "  test                  - Run unit tests"
	@echo "  proxymock-replay      - Run proxymock replay integration tests (status + schema + coverage + properties)"
	@echo "  proxymock-check-golden   - Verify the golden is normalized + stable (snapshot consistency)"
	@echo "  proxymock-lint-invariants - Validate the business-invariants rules file"
	@echo "  proxymock-prepare-golden - Rebuild golden snapshot from a pulled Speedscale snapshot"
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
	java -jar target/api-gateway-1.0.0.jar

# Test target
.PHONY: test
test:
	@echo "Running tests for $(SERVICE_NAME)..."
	./mvnw test

# proxymock replay: externalized integration tests driven by the checked-in golden
# snapshot (proxymock/recorded-golden). Builds the gateway, runs it behind `proxymock mock`,
# replays recorded inbound traffic, and asserts four gates: recorded response STATUS,
# response SCHEMA + contract COVERAGE, business INVARIANTS (properties), and golden
# snapshot CONSISTENCY. See the proxymock-service-tests skill.
.PHONY: proxymock-replay
proxymock-replay:
	@echo "Running proxymock replay for $(SERVICE_NAME)..."
	../../scripts/proxymock/replay-service.sh $(SERVICE_NAME)

# Snapshot consistency: confirm the committed golden is a normalized, stable fixed point
# (re-preparing it would change nothing). Fast, offline, no service build.
.PHONY: proxymock-check-golden
proxymock-check-golden:
	python3 ../../scripts/proxymock/prepare_golden.py --golden proxymock/recorded-golden --check

# Lint the agreed business-invariants rules file (structure only; offline).
.PHONY: proxymock-lint-invariants
proxymock-lint-invariants:
	python3 ../../scripts/proxymock/property_validate.py \
	  --rules ../../scripts/proxymock/services/$(SERVICE_NAME).invariants.json --lint

# Rebuild the golden snapshot from a freshly pulled Speedscale snapshot (see proxymock/README.md
# and the proxymock-service-tests skill).
.PHONY: proxymock-prepare-golden
proxymock-prepare-golden:
	python3 ../../scripts/proxymock/prepare_golden.py --golden proxymock/recorded-golden \
	  --known-gap-pattern 'http:queryparams:accountId is' \
	  --known-gap-status '/api/transactions:503'

# Clean target
.PHONY: clean
clean:
	@echo "Cleaning $(SERVICE_NAME)..."
	./mvnw clean
