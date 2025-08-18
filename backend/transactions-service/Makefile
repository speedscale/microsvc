# Transactions Service Makefile

# Service-specific configuration
SERVICE_NAME = transactions-service
SERVICE_PORT = 8083
PROXY_IN_PORT = 4183
PROXY_OUT_PORT = 7483

# Java services configuration
MVN = ./mvnw
JAVA_OPTS = -Xmx512m

# Proxymock configuration
PROXYMOCK_DIR = proxymock
PROXYMOCK_RECORD_DIR = $(PROXYMOCK_DIR)/recorded-$(shell date +%Y-%m-%d_%H-%M-%S)
PROXYMOCK_MOCK_DIR = $(PROXYMOCK_DIR)/mocked-$(shell date +%Y-%m-%d_%H-%M-%S)
PROXYMOCK_REPLAY_DIR = $(PROXYMOCK_DIR)/replayed-$(shell date +%Y-%m-%d_%H-%M-%S)

# Dependencies to mock
MOCK_DEPENDENCIES = postgres:5432 accounts-service:8080 user-service:8080

.PHONY: help
help:
	@echo "$(SERVICE_NAME) Makefile - Available targets:"
	@echo ""
	@echo "Build & Run:"
	@echo "  build              - Build the service"
	@echo "  run                - Run the service locally"
	@echo "  test               - Run unit tests"
	@echo "  clean              - Clean build artifacts"
	@echo ""
	@echo "Proxymock:"
	@echo "  proxymock-record   - Record traffic (inbound and outbound)"
	@echo "  proxymock-mock     - Start mock server for dependencies"
	@echo "  proxymock-replay   - Replay recorded traffic against service"
	@echo "  proxymock-env      - Show environment variables for proxy"
	@echo "  proxymock-clean    - Clean proxymock recordings"
	@echo "  proxymock-list     - List running proxymock jobs"
	@echo "  proxymock-stop     - Stop all proxymock jobs"

# Build targets
.PHONY: build
build:
	@echo "Building $(SERVICE_NAME)..."
	$(MVN) clean package -DskipTests

.PHONY: test
test:
	@echo "Testing $(SERVICE_NAME)..."
	$(MVN) test

.PHONY: run
run:
	@echo "Running $(SERVICE_NAME) on port $(SERVICE_PORT)..."
	$(MVN) spring-boot:run -Dspring-boot.run.jvmArguments="$(JAVA_OPTS)" \
		-Dspring-boot.run.arguments="--server.port=$(SERVICE_PORT)"

.PHONY: clean
clean:
	@echo "Cleaning $(SERVICE_NAME)..."
	$(MVN) clean
	rm -rf $(PROXYMOCK_DIR)

# Proxymock targets
.PHONY: proxymock-record
proxymock-record:
	@echo "Starting proxymock recording for $(SERVICE_NAME)..."
	@echo "Inbound proxy: http://localhost:$(PROXY_IN_PORT) -> http://localhost:$(SERVICE_PORT)"
	@echo "Outbound proxy: Set HTTP(S)_PROXY=http://localhost:$(PROXY_OUT_PORT)"
	@mkdir -p $(PROXYMOCK_RECORD_DIR)
	proxymock start_recording_traffic \
		--app-port $(SERVICE_PORT) \
		--proxy-in-port $(PROXY_IN_PORT) \
		--out-directory $(PROXYMOCK_RECORD_DIR)

.PHONY: proxymock-mock
proxymock-mock:
	@echo "Starting mock server for $(SERVICE_NAME) dependencies..."
	@echo "Mock server will intercept requests to: $(MOCK_DEPENDENCIES)"
	@if [ ! -d "$(PROXYMOCK_DIR)" ]; then \
		echo "Error: No recorded traffic found in $(PROXYMOCK_DIR)"; \
		echo "Run 'make proxymock-record' first to record traffic"; \
		exit 1; \
	fi
	@mkdir -p $(PROXYMOCK_MOCK_DIR)
	proxymock start_mock_server \
		--in-directory $(PROXYMOCK_DIR) \
		--out-directory $(PROXYMOCK_MOCK_DIR)

.PHONY: proxymock-replay
proxymock-replay:
	@echo "Replaying traffic against $(SERVICE_NAME)..."
	@if [ ! -d "$(PROXYMOCK_DIR)" ]; then \
		echo "Error: No recorded traffic found in $(PROXYMOCK_DIR)"; \
		echo "Run 'make proxymock-record' first to record traffic"; \
		exit 1; \
	fi
	@mkdir -p $(PROXYMOCK_REPLAY_DIR)
	proxymock replay_traffic \
		--in-directory $(PROXYMOCK_DIR) \
		--out-directory $(PROXYMOCK_REPLAY_DIR) \
		--test-against http://localhost:$(SERVICE_PORT)

.PHONY: proxymock-env
proxymock-env:
	@echo "# Proxymock environment variables for $(SERVICE_NAME):"
	@echo "export HTTP_PROXY=http://localhost:$(PROXY_OUT_PORT)"
	@echo "export HTTPS_PROXY=http://localhost:$(PROXY_OUT_PORT)"
	@echo "export NO_PROXY=localhost,127.0.0.1"
	@echo ""
	@echo "# Service-specific overrides:"
	@echo "export ACCOUNTS_SERVICE_URL=http://accounts-service:8080"
	@echo "export USER_SERVICE_URL=http://user-service:8080"
	@echo "export DB_HOST=postgres"
	@echo ""
	@echo "# To use:"
	@echo "# 1. Start mock server: make proxymock-mock"
	@echo "# 2. Set environment: eval \$$(make proxymock-env)"
	@echo "# 3. Run your service: make run"

.PHONY: proxymock-list
proxymock-list:
	@echo "Listing proxymock jobs..."
	proxymock list_running

.PHONY: proxymock-stop
proxymock-stop:
	@echo "Stopping proxymock recording..."
	proxymock stop_recording_traffic || true
	@echo "Stopping mock server..."
	proxymock stop_mock_server || true

.PHONY: proxymock-clean
proxymock-clean:
	@echo "Cleaning proxymock recordings..."
	rm -rf $(PROXYMOCK_DIR)

# Run with mocked dependencies
.PHONY: run-mocked
run-mocked: proxymock-env
	@echo "Running $(SERVICE_NAME) with mocked dependencies..."
	eval $$(make proxymock-env) && $(MVN) spring-boot:run \
		-Dspring-boot.run.jvmArguments="$(JAVA_OPTS)" \
		-Dspring-boot.run.arguments="--server.port=$(SERVICE_PORT)"