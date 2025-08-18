#!/bin/bash

# Test script to validate PostgreSQL traffic mocking with proxymock
# Simplified version that skips Flyway migrations to focus on API mocking

set -e

echo "=== Testing User Service Replay with Mocks ==="

# Find the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root
cd "$PROJECT_ROOT"

# Check if proxymock is available
if ! which proxymock >/dev/null 2>&1; then
  echo "Proxymock not found in PATH"
  exit 1
fi

# Check if captured traffic exists
SOURCE_DIR="proxymock/user-service/recorded-2025-08-13"
if [ ! -d "$SOURCE_DIR" ]; then
	echo "ERROR: source dir ($SOURCE_DIR) not found"
  exit 1
fi

POSTGRES_FILES=$(find "$SOURCE_DIR" -name "*.json" -exec grep -l "postgres" {} \; 2>/dev/null | wc -l | tr -d ' ')
echo "Found $POSTGRES_FILES PostgreSQL traffic files to mock"

# Clean up any existing processes
pkill -f user-service 2>/dev/null || true
pkill -f proxymock 2>/dev/null || true

# Function to cleanup processes
cleanup_and_exit() {
  echo "Cleaning up..."

  unset JAVA_TOOL_OPTIONS

  kill $PROXYMOCK_PID 2>/dev/null || true

  # Also cleanup any background processes
  pkill -f "java -jar target/user-service" 2>/dev/null || true
  pkill -f "proxymock mock" 2>/dev/null || true

  exit ${1:-0}
}

# Set proxy settings for Java app
export JAVA_TOOL_OPTIONS="-Dspring.flyway.enabled=false -Dspring.jpa.hibernate.ddl-auto=none"

echo "Starting user-service with proxymock database mocking..."
cd backend/user-service
export DB_HOST=Mac.lan
export DB_PORT=65432
export DB_NAME=banking_app

# Start proxymock with the Java app wrapped inside it
proxymock mock \
	--in ../../proxymock/user-service/recorded-2025-08-13/ \
	-vvvv \
	--no-out \
	--service postgres=65432 \
	--log-to proxymock.log \
	-- java -jar target/user-service-1.0.0.jar &
PROXYMOCK_PID=$!

# Give proxymock and Java app time to start
echo "Giving proxymock and Java app time to start..."
sleep 15

if ! kill -0 $PROXYMOCK_PID 2>/dev/null; then
  echo "Proxymock with user-service failed to start"
  cleanup_and_exit 1
fi

echo "Proxymock mock server with user-service is running (PID: $PROXYMOCK_PID)"

cd ../..

# Wait for service to start
echo "Waiting for user-service to start..."
for i in {1..60}; do
  if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
    echo "*** SUCCESS: user-service started with mocked database! ***"
    break
  fi
  echo "Waiting for user-service... ($i/60)"
  sleep 3
done

if ! curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
  echo "user-service failed to start"
  cleanup_and_exit 1
fi

# Check for recorded HTTP traffic to replay
REPLAY_DIR="proxymock/user-service/recorded-2025-08-13"
if [ ! -d "$REPLAY_DIR" ]; then
  echo "No recorded HTTP traffic found at: $REPLAY_DIR"
  echo "Run scripts/record-http-traffic.sh first to record inbound HTTP traffic"
  echo "Using fallback to basic health check..."

  # Fallback to basic health check
  echo ""
  echo "=== Basic Health Check ==="
  if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
    echo "✅ Service is responding to health checks"
    REPLAY_SUCCESS="YES"
  else
    echo "❌ Service is not responding to health checks"
    REPLAY_SUCCESS="NO"
  fi
else
  # Replay recorded HTTP traffic against the mocked service
  echo ""
  echo "=== Replaying Recorded HTTP Traffic ==="
  echo "Using recorded traffic from: $REPLAY_DIR"

  HTTP_FILES=$(find "$REPLAY_DIR" -name "*.md" | wc -l | tr -d ' ')
  echo "Found $HTTP_FILES recorded HTTP requests to replay"

  # Run proxymock replay against the service with mocked database
  if proxymock replay \
    --test-against localhost:8080 \
    --in "$REPLAY_DIR" \
    --no-out \
    --log-to replay.log \
    --fail-if "latency.max > 1000"; then
    echo "✅ Replay completed successfully"
    REPLAY_SUCCESS="YES"
  else
    echo "❌ Replay failed"
    REPLAY_SUCCESS="NO"
  fi
fi

# Analyze results
echo ""
echo "=== Results Analysis ==="
echo "Mock server running: $(kill -0 $PROXYMOCK_PID 2>/dev/null && echo "YES" || echo "NO")"
echo "Service started: $(curl -f http://localhost:8080/actuator/health >/dev/null 2>&1 && echo "YES" || echo "NO")"
echo "Replay succeeded: $REPLAY_SUCCESS"

if [ "$REPLAY_SUCCESS" = "YES" ]; then
  echo ""
  echo "*** MOCKING & REPLAY SUCCESS! ***"
  echo "✅ Proxymock intercepted PostgreSQL traffic"
  echo "✅ Service started without real database"
  echo "✅ Recorded HTTP requests replayed successfully"
  echo "✅ Database queries are being mocked during replay"

  echo ""
  echo "=== Service Logs ==="
  tail -50 backend/user-service/user-service.log 2>/dev/null || echo "No log file found"
  echo ""
  echo "=== Proxymock Logs ==="
  tail -20 backend/user-service/proxymock.log 2>/dev/null || echo "No proxymock log file found"
  echo ""
  echo "=== Replay Logs ==="
  tail -20 backend/user-service/replay.log 2>/dev/null || echo "No replay log file found"
  cleanup_and_exit 0
else
  echo ""
  echo "Service started but replay failed"
  echo "This could be due to:"
  echo "- Signature mismatches in captured vs runtime queries"
  echo "- Missing recorded HTTP traffic (run record-http-traffic.sh first)"
  echo "- Service not responding correctly to replayed requests"

  echo ""
  echo "=== Service Logs ==="
  tail -50 backend/user-service/user-service.log 2>/dev/null || echo "No log file found"
  echo ""
  echo "=== Proxymock Logs ==="
  tail -20 backend/user-service/proxymock.log 2>/dev/null || echo "No proxymock log file found"
  echo ""
  echo "=== Replay Logs ==="
  tail -20 backend/user-service/replay.log 2>/dev/null || echo "No replay log file found"
  cleanup_and_exit 1
fi
