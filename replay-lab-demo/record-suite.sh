#!/usr/bin/env bash
# Re-record the release-gate suite (prod-suite/) from the running service.
#
# Run this against the CLEAN build (make run MEMO_BUG=false) — the suite is
# "yesterday's good production traffic", so every request must succeed the way
# production did. A committed suite ships with the demo; you only need this to
# regenerate it.
#
# proxymock record puts an inbound proxy on :4143 in front of the app; requests
# driven through it are captured as localhost RRPairs, which become the suite.
set -euo pipefail
cd "$(dirname "$0")"
PM="$HOME/.speedscale/proxymock"
PORT="${PORT:-8087}"
JWT_TOKEN='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJyZXBsYXktbGFiLWRlbW8iLCJ1c2VySWQiOiIxIiwicm9sZXMiOiJVU0VSIiwiZXhwIjoxODkzNDU2MDAwfQ.ZgLN1WSTSnb4u6vvk-z4k8eX7_FIRiK_Uijb0Jkk3Ck'

./warmup.sh

REC=$(mktemp -d)
# --proxy-out-port: the mock already owns :4140 (the app's outbound proxy); the
# recorder's own outbound listener is unused here, park it on :4141
"$PM" record --app-port "$PORT" --proxy-out-port 4141 --out "$REC" >/tmp/replay-lab-record.log 2>&1 &
REC_PID=$!
trap 'kill $REC_PID 2>/dev/null || true' EXIT
sleep 3

req() { # method path [json-body]
  local method=$1 path=$2 body=${3:-}
  local args=(-s -o /dev/null -w "%{http_code}" -X "$method"
              -H "Authorization: Bearer $JWT_TOKEN" -H 'Content-Type: application/json')
  [ -n "$body" ] && args+=(-d "$body")
  local code
  code=$(curl "${args[@]}" "http://localhost:4143$path")
  echo "  $method $path -> $code"
}

echo ">> driving the suite through the recording proxy :4143"
req GET  /api/transactions
# amount must stay 3.33 on account 70668: the recorded accounts-service mock
# matches the downstream PUT /balance by exact body ({"balance":1003.33})
req POST /api/transactions/deposit '{"accountId":70668,"amount":3.33,"description":"payroll deposit"}'
req POST /api/transactions/deposit '{"accountId":70668,"amount":3.33}'

sleep 2
kill $REC_PID 2>/dev/null || true; wait $REC_PID 2>/dev/null || true

[ -d "$REC/localhost" ] || { echo "recording produced no inbound traffic (see /tmp/replay-lab-record.log)"; exit 1; }
rm -rf prod-suite
mkdir -p prod-suite
cp -R "$REC/localhost" prod-suite/localhost
rm -rf "$REC"
echo ">> suite written to prod-suite/ ($(ls prod-suite/localhost | wc -l | tr -d ' ') requests)"
