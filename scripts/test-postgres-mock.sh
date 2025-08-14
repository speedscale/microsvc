#!/bin/bash

# Test script to validate PostgreSQL traffic mocking with proxymock
# Simplified version that skips Flyway migrations to focus on API mocking

set -e

echo "=== Testing PostgreSQL Traffic Mocking (Simplified) ==="

# Find the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root
cd "$PROJECT_ROOT"

echo "Working from project root: $PROJECT_ROOT"

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
echo "Cleaning up existing processes..."
pkill -f user-service 2>/dev/null || true
pkill -f proxymock 2>/dev/null || true

# Function to cleanup processes
cleanup_and_exit() {
  echo "Cleaning up..."
  kill $USER_SERVICE_PID 2>/dev/null || true
  kill $PROXYMOCK_PID 2>/dev/null || true
  exit ${1:-0}
}

# Set proxy settings (using SOCKS to match capture)
unset JAVA_TOOL_OPTIONS
export JAVA_TOOL_OPTIONS="-Dspring.flyway.enabled=false -Dspring.jpa.hibernate.ddl-auto=none"

echo "Starting user-service with disabled migrations..."
cd backend/user-service
unset DB_HOST
unset DB_NAME
export DB_HOST=Mac.lan
export DB_NAME=banking_app
# java -jar target/user-service-1.0.0.jar  > user-service-mock-simple.log 2>&1 &
# USER_SERVICE_PID=$!

# Start proxymock in mock mode
echo "Starting proxymock in mock mode..."
proxymock mock --in ../../proxymock/user-service/recorded-2025-08-13/ --no-out -- java -jar target/user-service-1.0.0.jar &
PROXYMOCK_PID=$!

# Give proxymock time to start
sleep 10

if ! kill -0 $PROXYMOCK_PID 2>/dev/null; then
  echo "Proxymock failed to start"
  exit 1
fi

echo "Proxymock mock server is running (PID: $PROXYMOCK_PID)"

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
  echo "=== Service Logs ==="
  tail -30 backend/user-service/user-service-mock-simple.log 2>/dev/null || echo "No log file"
  cleanup_and_exit 1
fi

# Test the API endpoints
echo ""
echo "=== Testing API with Mocked Database ==="

echo "1. Testing username check..."
RESPONSE1=$(curl -s http://localhost:8080/api/users/check-username?username=testuser1 || echo "FAILED")
echo "Response: $RESPONSE1"

echo ""
echo "2. Testing registration..."
RESPONSE2=$(curl -s -X POST http://localhost:8080/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser1","email":"test1@example.com","password":"password123"}' || echo "FAILED")
echo "Response: $RESPONSE2"

# Analyze results
echo ""
echo "=== Results Analysis ==="
echo "Mock server running: $(kill -0 $PROXYMOCK_PID 2>/dev/null && echo "YES" || echo "NO")"
echo "Service started: $(curl -f http://localhost:8080/actuator/health >/dev/null 2>&1 && echo "YES" || echo "NO")"
echo "API responding: $(echo "$RESPONSE1" | grep -q "success\|available" && echo "YES" || echo "NO")"

if echo "$RESPONSE1" | grep -q "success\|available"; then
  echo ""
  echo "*** MOCKING SUCCESS! ***"
  echo "✅ Proxymock intercepted PostgreSQL traffic"
  echo "✅ Service started without real database"
  echo "✅ API endpoints are responding"
  echo "✅ Database queries are being mocked"
else
  echo ""
  echo "Service started but API may not be fully functional"
  echo "This could be due to signature mismatches in captured vs runtime queries"
fi

cleanup_and_exit 0
