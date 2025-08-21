#!/bin/bash

set -ex

# Use absolute path for proxymock directory
PROXYMOCK_DIR="${PROXYMOCK_DIR:-proxymock/recorded-2025-08-13}"

# Find the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

cd backend/user-service

# Clean up any existing processes
pkill -f user-service 2>/dev/null || true
pkill -f proxymock 2>/dev/null || true

cleanup() {
  unset JAVA_TOOL_OPTIONS
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
export JAVA_TOOL_OPTIONS="-Dspring.flyway.enabled=false -Dspring.jpa.hibernate.ddl-auto=none"
# In CI, hostname might return something unexpected, so use localhost
export DB_HOST="${DB_HOST:-localhost}"
export DB_PORT=65432
export DB_NAME=banking_app

echo "Database configuration:"
echo "  DB_HOST=$DB_HOST"
echo "  DB_PORT=$DB_PORT"
echo "  DB_NAME=$DB_NAME"

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

# Check if JAR file exists
if [ ! -f "target/user-service-1.0.0.jar" ]; then
  echo "Error: user-service JAR not found"
  echo "Available files in target:"
  ls -la target/ 2>/dev/null || echo "No target directory found"
  exit 1
fi

# Check proxymock version
echo "Proxymock version:"
proxymock --version || echo "Failed to get proxymock version"

# Start proxymock in the background and capture output
proxymock mock \
  --verbose \
  --in $PROXYMOCK_DIR/ \
  --no-out \
  --service postgres=65432 \
  --log-to proxymock.log \
  --log-app-to app.log \
  -- java -jar target/user-service-1.0.0.jar > proxymock-startup.log 2>&1 &

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

# Continue waiting for full startup
sleep 10

if ! kill -0 $PROXYMOCK_PID 2>/dev/null; then
  echo "Failed to start proxymock with user-service"
  cleanup
  exit 1
fi

# Wait for service to start
for i in {1..20}; do
  if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

if ! curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
  echo "Service failed to start"
  cleanup
  exit 1
fi

# Run replay
if proxymock replay \
  --test-against localhost:8080 \
  --in "$PROXYMOCK_DIR" \
  --no-out \
  --log-to replay.log \
  --fail-if "latency.max > 1000"; then
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
  tail -20 backend/user-service/app.log 2>/dev/null || echo "No app log file found"
  echo ""
  echo "=== Proxymock Logs ==="
  tail -20 backend/user-service/proxymock.log 2>/dev/null || echo "No proxymock log file found"
fi

echo ""
echo "=== Replay Logs ==="
tail -20 replay.log 2>/dev/null || echo "No replay log file found"

exit $([ "$REPLAY_SUCCESS" = true ] && echo 0 || echo 1)
