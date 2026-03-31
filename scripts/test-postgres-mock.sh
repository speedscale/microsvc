#!/bin/bash

set -ex

# Use absolute path for proxymock directory (override with PROXYMOCK_DIR)
PROXYMOCK_DIR="${PROXYMOCK_DIR:-proxymock/recorded-2025-08-13}"

# Find the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

cd backend/user-service

# Ensure proxymock is on PATH (install via scripts/run-proxymock-validation.sh or curl installer)
export PATH="${HOME}/.speedscale:${PATH}"

# Same key as CI: prefer PROXYMOCK_DEV_API_KEY, else PROXYMOCK_API_KEY (repo may define either secret).
export PROXYMOCK_DEV_API_KEY="${PROXYMOCK_DEV_API_KEY:-${PROXYMOCK_API_KEY:-}}"

if ! command -v proxymock >/dev/null 2>&1; then
  echo "error: proxymock not found. Install with:"
  echo "  curl -Lfs https://downloads.speedscale.com/proxymock/install-proxymock | sh"
  echo "Or run the full CI-equivalent script: ./scripts/run-proxymock-validation.sh"
  exit 1
fi

# proxymock's Postgres mock binds 127.0.0.1:5432; fail fast if Docker/local Postgres uses it.
if command -v nc >/dev/null 2>&1; then
  if nc -z 127.0.0.1 5432 2>/dev/null; then
    echo "error: port 5432 is already in use. proxymock must bind its Postgres mock on 127.0.0.1:5432."
    echo "Stop local PostgreSQL (e.g. docker compose stop) or run: make proxymock-validation-docker"
    exit 1
  fi
fi

# proxymock mock/replay require a one-time init (CI passes coalesced API key).
PM_VER_OUT=$(proxymock version 2>&1) || true
if echo "$PM_VER_OUT" | grep -Fq "not initialized"; then
  if [ -z "${PROXYMOCK_DEV_API_KEY:-}" ]; then
    echo "Skipping proxymock validation: not initialized and no API key (PROXYMOCK_DEV_API_KEY or PROXYMOCK_API_KEY)."
    exit 0
  fi
  proxymock init -y --app-url dev.speedscale.com --api-key "$PROXYMOCK_DEV_API_KEY"
fi

# Clean up any existing processes
pkill -f user-service 2>/dev/null || true
pkill -f proxymock 2>/dev/null || true

cleanup() {
  unset JAVA_TOOL_OPTIONS
  unset OTEL_SDK_DISABLED
  unset SPRING_DATASOURCE_URL SPRING_DATASOURCE_DRIVER_CLASS_NAME
  if [ -n "$PROXYMOCK_PID" ]; then
    kill $PROXYMOCK_PID 2>/dev/null || true
  fi
  pkill -f "java -jar target/user-service" 2>/dev/null || true
  pkill -f "proxymock mock" 2>/dev/null || true
  
  # Show startup log if it exists
  if [ -f "proxymock-startup.log" ]; then
    echo ""
    echo "=== Proxymock Startup Log ==="
    cat proxymock-startup.log
  fi
}

# Start proxymock with user-service
# Flyway off: use Hibernate ddl-auto=update so schema exists on the mocked empty DB.
# Use plain PostgreSQL JDBC (not jdbc:otel + OpenTelemetryDriver) so the app can talk to proxymock's Postgres mock.
# Disable OTel SDK for this isolated run (no collector in CI). Health probes are enabled in application.yml.
# -Dspring.profiles.active: proxymock must be set as a JVM flag so the child process spawned by proxymock inherits it (env-only SPRING_PROFILES_ACTIVE is not always forwarded).
# application-proxymock.yml: disable JDBC metadata queries that proxymock cannot match to old recordings.
export JAVA_TOOL_OPTIONS="-Dspring.flyway.enabled=false -Dspring.jpa.hibernate.ddl-auto=update -Dotel.sdk.disabled=true -Dspring.profiles.active=proxymock"
export OTEL_SDK_DISABLED=true
# In CI, hostname might return something unexpected, so use localhost
export DB_HOST="${DB_HOST:-localhost}"
# Postgres wire protocol is served on 127.0.0.1:5432 by proxymock mock (see proxymock.log: "postgres server listening").
# Do not use --map 65432=... for JDBC: that port is an HTTP reverse proxy to :5432, not the PostgreSQL protocol.
export DB_PORT=5432
export DB_NAME=banking_app
# Mock does not implement SSL negotiation the JDBC driver expects with sslmode=prefer; disable for local mock.
export SPRING_DATASOURCE_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"
export SPRING_DATASOURCE_DRIVER_CLASS_NAME="org.postgresql.Driver"

echo "Database configuration:"
echo "  DB_HOST=$DB_HOST"
echo "  DB_PORT=$DB_PORT"
echo "  DB_NAME=$DB_NAME"
echo "  SPRING_DATASOURCE_URL=$SPRING_DATASOURCE_URL"

# Make PROXYMOCK_DIR absolute if it's relative
if [[ ! "$PROXYMOCK_DIR" = /* ]]; then
  PROXYMOCK_DIR="$(pwd)/$PROXYMOCK_DIR"
fi

# Check if proxymock recording directory exists
if [ ! -d "$PROXYMOCK_DIR" ]; then
  echo "Error: Proxymock recording directory not found: $PROXYMOCK_DIR"
  echo "Current directory: $(pwd)"
  echo "Available directories:"
  ls -la proxymock/ 2>/dev/null || echo "No proxymock directory found"
  exit 1
fi

echo "Using proxymock recordings from: $PROXYMOCK_DIR"

# Find the JAR file dynamically
JAR_FILE=$(find target/ -name "user-service-*.jar" -not -name "*original*" | head -1)
if [ -z "$JAR_FILE" ] || [ ! -f "$JAR_FILE" ]; then
  echo "Error: user-service JAR not found"
  echo "Available files in target:"
  ls -la target/ 2>/dev/null || echo "No target directory found"
  exit 1
fi

echo "Using JAR file: $JAR_FILE"

# Check proxymock version (subcommand, not --version flag)
echo "Proxymock version:"
proxymock version || echo "Failed to get proxymock version"

# Start proxymock in the background and capture output
proxymock mock \
  --verbose \
  --in $PROXYMOCK_DIR/ \
  --no-out \
  --log-to proxymock.log \
  --app-log-to app.log \
  -- java -jar "$JAR_FILE" > proxymock-startup.log 2>&1 &

PROXYMOCK_PID=$!

# Give proxymock time to start and check if it's still running
sleep 5

if ! kill -0 $PROXYMOCK_PID 2>/dev/null; then
  echo "Proxymock failed to start. Startup log:"
  cat proxymock-startup.log 2>/dev/null || echo "No startup log found"
  echo ""
  echo "Proxymock log:"
  cat proxymock.log 2>/dev/null || echo "No proxymock log found"
  cleanup
  exit 1
fi

# Continue waiting for JVM to bind :8080 (faster than fixed sleeps on slow CI)
if ! kill -0 $PROXYMOCK_PID 2>/dev/null; then
  echo "Failed to start proxymock with user-service"
  cleanup
  exit 1
fi

wait_for_tcp_8080() {
  local n=0
  while [ "$n" -lt 120 ]; do
    if (echo >/dev/tcp/127.0.0.1/8080) 2>/dev/null; then
      return 0
    fi
    sleep 1
    n=$((n + 1))
  done
  return 1
}

if ! wait_for_tcp_8080; then
  echo "Timed out waiting for something to listen on 127.0.0.1:8080"
  cleanup
  exit 1
fi

# Prefer liveness (200 without aggregate DB noise); fall back to aggregate /actuator/health
http_200() {
  local url=$1
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo 000)
  [ "$code" = "200" ]
}

HEALTH_LIVENESS="${HEALTH_LIVENESS:-http://localhost:8080/actuator/health/liveness}"
HEALTH_AGG="${HEALTH_AGG:-http://localhost:8080/actuator/health}"
READY=false
for _i in $(seq 1 60); do
  if http_200 "$HEALTH_LIVENESS"; then
    READY=true
    echo "Health OK: $HEALTH_LIVENESS"
    break
  fi
  if http_200 "$HEALTH_AGG"; then
    READY=true
    echo "Health OK: $HEALTH_AGG"
    break
  fi
  sleep 2
done

if [ "$READY" != true ]; then
  echo "Service failed to become ready (tried $HEALTH_LIVENESS and $HEALTH_AGG)"
  cleanup
  exit 1
fi

# Replay: optional latency gate via PROXYMOCK_REPLAY_FAIL_IF; --rewrite-host helps Host header mismatches
REPLAY_FAIL_IF="${PROXYMOCK_REPLAY_FAIL_IF:-}"
REPLAY_EXTRA=()
if [ -n "$REPLAY_FAIL_IF" ]; then
  REPLAY_EXTRA=(--fail-if "$REPLAY_FAIL_IF")
fi
REPLAY_V=""
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  REPLAY_V="-v"
fi

# Run replay
if proxymock replay $REPLAY_V \
  --test-against localhost:8080 \
  --rewrite-host \
  --in "$PROXYMOCK_DIR" \
  --no-out \
  --log-to replay.log \
  "${REPLAY_EXTRA[@]}"; then
  REPLAY_SUCCESS=true
else
  REPLAY_SUCCESS=false
fi

cleanup

echo ""
if [ "$REPLAY_SUCCESS" != true ]; then
  echo "❌ Replay failed"
  echo ""
  echo "=== App Logs ==="
  tail -20 app.log 2>/dev/null || echo "No app log file found"
  echo ""
  echo "=== Proxymock Logs ==="
  tail -20 proxymock.log 2>/dev/null || echo "No proxymock log file found"
fi

echo ""
echo "=== Replay Logs ==="
tail -20 replay.log 2>/dev/null || echo "No replay log file found"

exit $([ "$REPLAY_SUCCESS" = true ] && echo 0 || echo 1)
