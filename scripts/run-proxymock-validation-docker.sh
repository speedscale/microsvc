#!/usr/bin/env bash
# Run the same proxymock validation as CI inside Docker so host port 5432 can stay in use
# (proxymock binds its Postgres mock on 127.0.0.1:5432 inside the container).
#
# Requires Docker and PROXYMOCK_DEV_API_KEY in the environment (same as GitHub Actions).
#
# Usage:
#   export PROXYMOCK_DEV_API_KEY=...
#   ./scripts/run-proxymock-validation-docker.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

if [ -z "${PROXYMOCK_DEV_API_KEY:-}" ]; then
  echo "error: set PROXYMOCK_DEV_API_KEY (same secret as CI proxymock-validation job)"
  exit 1
fi

exec docker run --rm \
  -e PROXYMOCK_DEV_API_KEY \
  -e HOME=/root \
  -v "${ROOT}:/work" \
  -w /work \
  eclipse-temurin:17-jdk-jammy \
  bash -lc 'set -euo pipefail
    apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null
    curl -Lfs https://downloads.speedscale.com/proxymock/install-proxymock | sh
    export PATH="$HOME/.speedscale:$PATH"
    ./scripts/run-proxymock-validation.sh'
