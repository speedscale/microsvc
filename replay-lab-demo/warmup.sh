#!/usr/bin/env bash
# Wait until the service is ready AND its security chain has served one real request.
# The very first authenticated request after a cold start can 401 while Spring
# finishes lazy init; replaying before that produces a false RED. Sourced by the
# replay scripts, or run standalone.
set -euo pipefail
PORT="${PORT:-8087}"
JWT_TOKEN='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJyZXBsYXktbGFiLWRlbW8iLCJ1c2VySWQiOiIxIiwicm9sZXMiOiJVU0VSIiwiZXhwIjoxODkzNDU2MDAwfQ.ZgLN1WSTSnb4u6vvk-z4k8eX7_FIRiK_Uijb0Jkk3Ck'

for _ in $(seq 1 60); do
  curl -sf -o /dev/null "http://localhost:$PORT/actuator/health" && break
  sleep 2
done

# one throwaway authenticated request warms the JWT filter chain
for _ in $(seq 1 10); do
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $JWT_TOKEN" "http://localhost:$PORT/api/transactions")
  [ "$code" = "200" ] && exit 0
  sleep 1
done
echo "warmup: service on :$PORT never served an authenticated request (last: $code)" >&2
exit 1
