# Accounts Service Makefile
# Service configuration
SERVICE_NAME := accounts-service
SERVICE_PORT := 8082
PROXY_IN_PORT := 4182
PROXY_OUT_PORT := 7482

# Proxymock configuration
PROXYMOCK_RECORD_DIR := ../../proxymock/$(SERVICE_NAME)/recorded-$(shell date +%Y-%m-%d)
PROXYMOCK_REPLAY_DIR := ../../proxymock/$(SERVICE_NAME)/recorded-$(shell date +%Y-%m-%d)

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
	@echo ""
	@echo "Proxymock targets:"
	@echo "  proxymock-record      - Start recording traffic"
	@echo "  proxymock-mock        - Start mock server for isolated testing"
	@echo "  proxymock-replay      - Replay recorded traffic"
	@echo "  proxymock-env         - Show environment variables for outbound proxy"
	@echo "  proxymock-list        - List recorded traffic files"
	@echo "  proxymock-clean       - Clean recorded traffic"
	@echo "  proxymock-stop        - Stop all proxymock processes"

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

# Proxymock targets
.PHONY: proxymock-record
proxymock-record:
	@echo "Starting proxymock recording for $(SERVICE_NAME)..."
	@echo "This will record both inbound HTTP and outbound database traffic"
	@echo "Inbound proxy: http://localhost:$(PROXY_IN_PORT) -> http://localhost:$(SERVICE_PORT)"
	@echo "Outbound proxy: Set HTTP(S)_PROXY=http://localhost:$(PROXY_OUT_PORT)"
	@echo "Database will be proxied through $(PROXY_OUT_PORT)"
	@mkdir -p $(PROXYMOCK_RECORD_DIR)
	proxymock start_recording_traffic \
		--app-port $(SERVICE_PORT) \
		--proxy-in-port $(PROXY_IN_PORT) \
		--proxy-out-port $(PROXY_OUT_PORT) \
		--out-directory $(PROXYMOCK_RECORD_DIR)

.PHONY: proxymock-mock
proxymock-mock:
	@echo "Starting proxymock mock server for $(SERVICE_NAME)..."
	@echo "This will mock postgres and user-service dependencies"
	@if [ ! -d "$(PROXYMOCK_REPLAY_DIR)" ]; then \
		echo "No recorded traffic found. Run 'make proxymock-record' first."; \
		exit 1; \
	fi
	proxymock mock \
		--in $(PROXYMOCK_REPLAY_DIR) \
		--service postgres=5432 \
		--service user-service=8081 \
		--verbose

.PHONY: proxymock-replay
proxymock-replay:
	@echo "Replaying recorded traffic for $(SERVICE_NAME)..."
	@if [ ! -d "$(PROXYMOCK_REPLAY_DIR)" ]; then \
		echo "No recorded traffic found. Run 'make proxymock-record' first."; \
		exit 1; \
	fi
	proxymock replay \
		--test-against localhost:$(SERVICE_PORT) \
		--in $(PROXYMOCK_REPLAY_DIR)

.PHONY: proxymock-env
proxymock-env:
	@echo "Set these environment variables to route outbound traffic through proxymock:"
	@echo "export HTTP_PROXY=http://localhost:$(PROXY_OUT_PORT)"
	@echo "export HTTPS_PROXY=http://localhost:$(PROXY_OUT_PORT)"

.PHONY: proxymock-list
proxymock-list:
	@echo "Recorded traffic files for $(SERVICE_NAME):"
	@find ../../proxymock/$(SERVICE_NAME) -name "*.json" -o -name "*.md" 2>/dev/null | head -20 || echo "No recorded traffic found"

.PHONY: proxymock-clean
proxymock-clean:
	@echo "Cleaning recorded traffic for $(SERVICE_NAME)..."
	@rm -rf ../../proxymock/$(SERVICE_NAME)/recorded-*
	@echo "Cleaned recorded traffic files"

.PHONY: proxymock-stop
proxymock-stop:
	@echo "Stopping proxymock processes..."
	@pkill -f proxymock || echo "No proxymock processes found"