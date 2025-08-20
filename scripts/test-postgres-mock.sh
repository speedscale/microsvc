#!/bin/bash

set -ex

PROXYMOCK_DIR="proxymock/recorded-2025-08-13"

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
  kill $PROXYMOCK_PID 2>/dev/null || true
  pkill -f "java -jar target/user-service" 2>/dev/null || true
  pkill -f "proxymock mock" 2>/dev/null || true
}

# Start proxymock with user-service
export JAVA_TOOL_OPTIONS="-Dspring.flyway.enabled=false -Dspring.jpa.hibernate.ddl-auto=none"
export DB_HOST=$(hostname)
export DB_PORT=65432
export DB_NAME=banking_app

proxymock mock \
  --verbose \
  --in $PROXYMOCK_DIR/ \
  --no-out \
  --service postgres=65432 \
  --log-to proxymock.log \
  --log-app-to app.log \
  -- java -jar target/user-service-1.0.0.jar &

PROXYMOCK_PID=$!

sleep 15

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
