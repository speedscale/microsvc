#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_name="${FRESH_CAPTURE_RUN:-local-transfer-$(date -u +%Y-%m-%d_%H-%M-%S)}"
capture_dir="${FRESH_CAPTURE_DIR:-$repo_root/backend/ai-service/proxymock/$run_name}"
replay_out="${FRESH_CAPTURE_REPLAY_OUT:-$(mktemp -d "/tmp/microsvc-fresh-replay.XXXXXX")}"

rm -rf "$capture_dir"
mkdir -p "$capture_dir"

TRANSFER_REPLAY_CAPTURE_DIR="$capture_dir" \
TRANSFER_REPLAY_OUT_DIR="$replay_out" \
"$repo_root/scripts/demo-story-transfer-replay-check.sh"

PROXYMOCK_WEB_RUN="$run_name" \
PROXYMOCK_WEB_MIN_ROWS="${FRESH_CAPTURE_MIN_ROWS:-3}" \
PROXYMOCK_WEB_REQUIRED_TEXT="${FRESH_CAPTURE_REQUIRED_TEXT:-$run_name,Pull,Replay,banking-gateway,/api/users/login,/api/accounts,/api/transactions/transfer}" \
"$repo_root/scripts/demo-story-web-check.sh"

echo "fresh capture run: $run_name"
echo "fresh capture dir: $capture_dir"
