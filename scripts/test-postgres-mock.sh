#!/bin/bash

set -ex

# Use absolute path for proxymock directory (override with PROXYMOCK_DIR)
PROXYMOCK_DIR="${PROXYMOCK_DIR:-proxymock/recorded-complete}"

# Find the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

cd backend/user-service

# Ensure proxymock is on PATH (install via scripts/run-proxymock-validation.sh or curl installer)
export PATH="${HOME}/.speedscale:${PATH}"

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

# proxymock mock/replay require a one-time init when not already initialized (PROXYMOCK_API_KEY).
PM_VER_OUT=$(proxymock version 2>&1) || true
if echo "$PM_VER_OUT" | grep -Fq "not initialized"; then
  if [ -z "${PROXYMOCK_API_KEY:-}" ]; then
    echo "Skipping proxymock validation: not initialized and no API key (set PROXYMOCK_API_KEY)."
    exit 0
  fi
  for attempt in 1 2 3; do
    if proxymock init -y --app-url app.speedscale.com --api-key "$PROXYMOCK_API_KEY"; then
      break
    fi
    if [ "$attempt" -eq 3 ]; then
      echo "error: proxymock init failed after 3 attempts"
      exit 1
    fi
    echo "proxymock init attempt $attempt failed, retrying in 10s..."
    sleep 10
  done
fi

# Clean up any existing processes
pkill -f user-service-dotnet 2>/dev/null || true
pkill -f proxymock 2>/dev/null || true

PROXYMOCK_PID=""

cleanup() {
  if [ -n "$PROXYMOCK_PID" ]; then
    kill $PROXYMOCK_PID 2>/dev/null || true
  fi
  pkill -f "user-service-dotnet" 2>/dev/null || true
  pkill -f "proxymock mock" 2>/dev/null || true

  for logf in proxymock-startup.log app.log proxymock.log; do
    if [ -f "$logf" ]; then
      echo ""
      echo "=== $logf (tail) ==="
      tail -120 "$logf" 2>/dev/null || cat "$logf"
    fi
  done
}

trap cleanup EXIT

export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT=5432
export DB_NAME=banking
export DB_USERNAME=user_service
export DB_PASSWORD=password
export ASPNETCORE_URLS="http://127.0.0.1:8080"

echo "Database configuration:"
echo "  DB_HOST=$DB_HOST"
echo "  DB_PORT=$DB_PORT"
echo "  DB_NAME=$DB_NAME"

# Make PROXYMOCK_DIR absolute if it's relative
if [[ ! "$PROXYMOCK_DIR" = /* ]]; then
  PROXYMOCK_DIR="$(pwd)/$PROXYMOCK_DIR"
fi

if [ ! -d "$PROXYMOCK_DIR" ]; then
  echo "Error: Proxymock recording directory not found: $PROXYMOCK_DIR"
  echo "Current directory: $(pwd)"
  echo "Available directories:"
  ls -la proxymock/ 2>/dev/null || echo "No proxymock directory found"
  exit 1
fi

echo "Using proxymock recordings from: $PROXYMOCK_DIR"

# Find the published .NET app
PUBLISH_DIR="publish"
DLL_FILE="${PUBLISH_DIR}/user-service-dotnet.dll"
if [ ! -f "$DLL_FILE" ]; then
  echo "Error: user-service-dotnet.dll not found in $PUBLISH_DIR"
  echo "Available files:"
  ls -la "$PUBLISH_DIR"/ 2>/dev/null || echo "No publish directory found"
  exit 1
fi

echo "Using .NET app: $DLL_FILE"

echo "Proxymock version:"
proxymock version || echo "Failed to get proxymock version"

proxymock mock \
  --verbose \
  --in $PROXYMOCK_DIR/ \
  --no-out \
  --log-to proxymock.log \
  --app-log-to app.log \
  -- dotnet "$DLL_FILE" > proxymock-startup.log 2>&1 &

PROXYMOCK_PID=$!

sleep 5

if ! kill -0 $PROXYMOCK_PID 2>/dev/null; then
  echo "Proxymock failed to start. Startup log:"
  cat proxymock-startup.log 2>/dev/null || echo "No startup log found"
  echo ""
  echo "Proxymock log:"
  cat proxymock.log 2>/dev/null || echo "No proxymock log found"
  exit 1
fi

wait_for_tcp_8080() {
  local n=0
  while [ "$n" -lt 60 ]; do
    if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 8080 2>/dev/null; then
      return 0
    fi
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
  exit 1
fi

HEALTH_URL="http://127.0.0.1:8080/actuator/health"
READY=false
for _i in $(seq 1 30); do
  code=$(curl -sS -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || echo 000)
  if [ "$code" = "200" ]; then
    READY=true
    echo "Health OK: $HEALTH_URL"
    break
  fi
  sleep 1
done

if [ "$READY" != true ]; then
  echo "Service failed to become ready (tried $HEALTH_URL)"
  exit 1
fi

REPLAY_FAIL_IF="${PROXYMOCK_REPLAY_FAIL_IF:-}"
REPLAY_EXTRA=()
if [ -n "$REPLAY_FAIL_IF" ]; then
  REPLAY_EXTRA=(--fail-if "$REPLAY_FAIL_IF")
fi
REPLAY_V=""
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  REPLAY_V="-v"
fi

REPLAY_SUCCESS=false
if grep -rq '"l7protocol": "http' "$PROXYMOCK_DIR" --include='*.json' 2>/dev/null; then
  if proxymock replay $REPLAY_V \
    --test-against 127.0.0.1:8080 \
    --rewrite-host \
    --in "$PROXYMOCK_DIR" \
    --no-out \
    --log-to replay.log \
    "${REPLAY_EXTRA[@]}"; then
    REPLAY_SUCCESS=true
  fi
else
  echo "Skipping proxymock replay: no HTTP rrpairs under $PROXYMOCK_DIR (mock phase already validated startup)."
  REPLAY_SUCCESS=true
fi

echo ""
if [ "$REPLAY_SUCCESS" != true ]; then
  echo "Replay failed"
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
