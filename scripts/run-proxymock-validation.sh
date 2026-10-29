#!/usr/bin/env bash
# Same flow as GitHub Actions job "proxymock-validation" for user-service (.NET 8):
#   1. install proxymock (if needed) and init it (if PROXYMOCK_API_KEY is set)
#   2. build user-service
#   3. run it under `proxymock mock` (Postgres mock on 127.0.0.1:5432, from the recording)
#   4. `proxymock replay` the recorded inbound HTTP traffic against it
#
# Local: ensure proxymock is initialized (once per machine) or set PROXYMOCK_API_KEY so init can
# run non-interactively. Port 127.0.0.1:5432 must be free (proxymock binds it); if it is not, run
# `make proxymock-validation-docker` instead.
#
# CI and local: PROXYMOCK_API_KEY (GitHub secret; same key as https://app.speedscale.com/profile).
# If proxymock is uninitialized and no key is set, the script exits 0 (skip).
#
# Optional env:
#   PROXYMOCK_DIR             recording dir, relative to backend/user-service (default proxymock/recorded-complete)
#   PROXYMOCK_REPLAY_FAIL_IF  passed to `proxymock replay --fail-if`
#
# Usage:
#   ./scripts/run-proxymock-validation.sh
#   PROXYMOCK_API_KEY=... ./scripts/run-proxymock-validation.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
SERVICE_DIR="${ROOT}/backend/user-service"
PROXYMOCK_DIR="${PROXYMOCK_DIR:-proxymock/recorded-complete}"

# --- 1. install + init proxymock -------------------------------------------------------------
export PATH="${HOME}/.speedscale:${PATH}"
if ! command -v proxymock >/dev/null 2>&1; then
  echo "Installing proxymock to ${HOME}/.speedscale ..."
  curl -Lfs https://downloads.speedscale.com/proxymock/install-proxymock | sh
  export PATH="${HOME}/.speedscale:${PATH}"
fi
if ! command -v proxymock >/dev/null 2>&1; then
  echo "error: proxymock not on PATH after install"
  exit 1
fi

# Skip before a long build when CI has no API key (e.g. fork PRs) or local dev without Speedscale.
PM_VER_OUT=$(proxymock version 2>&1) || true
if echo "$PM_VER_OUT" | grep -Fq "not initialized"; then
  if [ -z "${PROXYMOCK_API_KEY:-}" ]; then
    echo "Skipping proxymock validation: proxymock is not initialized and no API key is set."
    echo "Set GitHub secret PROXYMOCK_API_KEY or run: proxymock init --api-key <key>"
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
echo "Proxymock version:"
proxymock version || echo "Failed to get proxymock version"

# proxymock's Postgres mock binds 127.0.0.1:5432; fail fast if Docker/local Postgres uses it.
if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 5432 2>/dev/null; then
  echo "error: port 127.0.0.1:5432 is in use. Stop local Postgres (e.g. docker compose stop)"
  echo "       or run: make proxymock-validation-docker"
  exit 1
fi

# --- 2. build user-service -------------------------------------------------------------------
cd "$SERVICE_DIR"
echo "Building user-service (.NET 8)..."
dotnet publish -c Release -o publish

DLL_FILE="publish/user-service-dotnet.dll"
if [ ! -f "$DLL_FILE" ]; then
  echo "error: $DLL_FILE not found in $(pwd)"
  ls -la publish/ 2>/dev/null || echo "No publish directory found"
  exit 1
fi

if [[ "$PROXYMOCK_DIR" != /* ]]; then
  PROXYMOCK_DIR="$(pwd)/$PROXYMOCK_DIR"
fi
if [ ! -d "$PROXYMOCK_DIR" ]; then
  echo "error: proxymock recording directory not found: $PROXYMOCK_DIR"
  ls -la proxymock/ 2>/dev/null || echo "No proxymock directory found"
  exit 1
fi
echo "Using proxymock recordings from: $PROXYMOCK_DIR"
echo "Using .NET app: $DLL_FILE"

# --- 3. run the service under proxymock mock -------------------------------------------------
pkill -f user-service-dotnet 2>/dev/null || true
pkill -f proxymock 2>/dev/null || true

PROXYMOCK_PID=""
cleanup() {
  if [ -n "$PROXYMOCK_PID" ]; then
    kill "$PROXYMOCK_PID" 2>/dev/null || true
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
echo "Database configuration: DB_HOST=$DB_HOST DB_PORT=$DB_PORT DB_NAME=$DB_NAME"

proxymock mock \
  --verbose \
  --in "$PROXYMOCK_DIR/" \
  --no-out \
  --log-to proxymock.log \
  --app-log-to app.log \
  -- dotnet "$DLL_FILE" > proxymock-startup.log 2>&1 &
PROXYMOCK_PID=$!

sleep 5
if ! kill -0 "$PROXYMOCK_PID" 2>/dev/null; then
  echo "Proxymock failed to start (see logs below)."
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

# --- 4. replay recorded inbound traffic ------------------------------------------------------
REPLAY_ARGS=(--test-against 127.0.0.1:8080 --rewrite-host --in "$PROXYMOCK_DIR" --no-out --log-to replay.log)
if [ -n "${PROXYMOCK_REPLAY_FAIL_IF:-}" ]; then
  REPLAY_ARGS+=(--fail-if "$PROXYMOCK_REPLAY_FAIL_IF")
fi
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  REPLAY_ARGS+=(-v)
fi

REPLAY_SUCCESS=false
if grep -rq '"l7protocol": "http' "$PROXYMOCK_DIR" --include='*.json' 2>/dev/null; then
  if proxymock replay "${REPLAY_ARGS[@]}"; then
    REPLAY_SUCCESS=true
  fi
else
  echo "Skipping proxymock replay: no HTTP rrpairs under $PROXYMOCK_DIR (mock phase already validated startup)."
  REPLAY_SUCCESS=true
fi

echo ""
echo "=== Replay Logs ==="
tail -20 replay.log 2>/dev/null || echo "No replay log file found"

if [ "$REPLAY_SUCCESS" != true ]; then
  echo "Replay failed"
  exit 1
fi
