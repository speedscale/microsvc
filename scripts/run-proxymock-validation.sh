#!/usr/bin/env bash
# Same flow as GitHub Actions job "proxymock-validation": install proxymock (if needed),
# build user-service, run scripts/test-postgres-mock.sh.
#
# Local: ensure proxymock is initialized (once per machine) or set an API key env var
# so init can run non-interactively. Port 127.0.0.1:5432 must be free (proxymock binds it).
#
# CI and local: set PROXYMOCK_API_KEY (GitHub secret PROXYMOCK_API_KEY; same key as https://app.speedscale.com/profile).
#
# Usage:
#   ./scripts/run-proxymock-validation.sh
#   PROXYMOCK_API_KEY=... ./scripts/run-proxymock-validation.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
cd "$ROOT"

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

# Skip before a long Maven build when CI has no API key (e.g. fork PRs) or local dev without Speedscale.
PM_VER_OUT=$(proxymock version 2>&1) || true
if echo "$PM_VER_OUT" | grep -Fq "not initialized"; then
  if [ -z "${PROXYMOCK_API_KEY:-}" ]; then
    echo "Skipping proxymock validation: proxymock is not initialized and no API key is set."
    echo "Set GitHub secret PROXYMOCK_API_KEY or run: proxymock init --api-key <key>"
    exit 0
  fi
  proxymock init -y --app-url app.speedscale.com --api-key "$PROXYMOCK_API_KEY"
fi

# Fail fast if host port 5432 is taken (proxymock Postgres mock needs it); nc is optional.
if command -v nc >/dev/null 2>&1; then
  if nc -z 127.0.0.1 5432 2>/dev/null; then
    echo "error: port 127.0.0.1:5432 is in use. Stop local Postgres or run: make proxymock-validation-docker"
    exit 1
  fi
fi

echo "Building user-service JAR..."
cd "${ROOT}/backend/user-service"
chmod +x ./mvnw
./mvnw clean package -DskipTests

cd "${ROOT}"
exec "${ROOT}/scripts/test-postgres-mock.sh"
