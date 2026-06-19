#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

workspace="${PROXYMOCK_WEB_WORKSPACE:-$repo_root/backend/ai-service/proxymock}"
run_name="${PROXYMOCK_WEB_RUN:-live-banking-ai-2026-06-19_12-48-06}"
port="${PROXYMOCK_WEB_PORT:-$((7788 + RANDOM % 1000))}"
log_file="/tmp/microsvc-proxymock-web.$$.log"
web_pid=""

cleanup() {
  if [ -n "${web_pid:-}" ]; then
    kill "$web_pid" 2>/dev/null || true
  fi
  rm -f "$log_file"
}
trap cleanup EXIT

proxymock web \
  --in "$workspace" \
  --host 127.0.0.1 \
  --port "$port" \
  --open=false \
  --chat=false \
  --forwarder-addr '' >"$log_file" 2>&1 &
web_pid="$!"

for _ in $(seq 1 60); do
  if ! kill -0 "$web_pid" 2>/dev/null; then
    cat "$log_file" >&2
    exit 1
  fi
  if grep -q "analysis complete" "$log_file"; then
    break
  fi
  sleep 1
done

PROXYMOCK_WEB_URL="http://127.0.0.1:$port" \
PROXYMOCK_WEB_RUN="$run_name" \
node "$repo_root/scripts/demo-story-web-check.mjs"
