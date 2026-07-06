#!/usr/bin/env bash
# Release gate: replay recorded production traffic (prod-suite/) against the
# candidate build and fail unless every request returns the same status code
# production returned. This is the CI step — exit code is the verdict.
#
#   ./gate.sh            # against localhost:$PORT (default 8087)
set -euo pipefail
cd "$(dirname "$0")"
PM="$HOME/.speedscale/proxymock"
PORT="${PORT:-8087}"

./warmup.sh

echo ">> replaying recorded production traffic against the candidate build"
rm -rf gate-out
if "$PM" replay --in prod-suite --test-against "http://localhost:$PORT" \
     --out gate-out --fail-if "requests.result-match-pct != 100" 2>&1 \
     | sed -n '/LATENCY \/ THROUGHPUT/,$p'; then
  echo
  echo "  GATE PASSED — candidate build matches production behavior on real traffic"
else
  echo
  echo "  GATE FAILED — candidate build diverges from production behavior (see table above)"
  exit 1
fi
