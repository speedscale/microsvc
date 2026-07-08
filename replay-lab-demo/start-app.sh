#!/usr/bin/env bash
# Bring up the app under proxymock's dependency mocks.
#
# This is the ONLY plumbing you can't avoid. The demo itself is raw `proxymock`
# commands (see README); this script just stands up the thing under test:
# Postgres, the Spring jar, and the env vars + JVM proxy flags that route the
# app's outbound calls to proxymock. It builds, starts the mock, starts the app,
# waits until it is warm, then holds (Ctrl-C stops the app and the mock).
#
#   ./start-app.sh            # buggy build: the deposit NPE is armed (the default)
#   ./start-app.sh --clean    # the build currently in prod (no bug)
#   ./start-app.sh --refactor # the agent's response-envelope change (for the gate)
#
# MOCKS=<dir> overrides the mock set (default: mocks/). PORT=<n> overrides :8087.
set -euo pipefail
cd "$(dirname "$0")"
DEMO="$PWD"; ROOT="$(cd .. && pwd)"; TX="$ROOT/backend/transactions-service"
PM="$HOME/.speedscale/proxymock"
PORT="${PORT:-8087}"; MOCKS="${MOCKS:-mocks}"
MEMO_BUG=true; CONTRACT_REFACTOR=false
case "${1:-}" in
  --clean)    MEMO_BUG=false ;;
  --refactor) MEMO_BUG=false; CONTRACT_REFACTOR=true ;;
  --bug|"")   ;;
  *) echo "usage: ./start-app.sh [--bug|--clean|--refactor]" >&2; exit 2 ;;
esac
JWT_TOKEN='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJyZXBsYXktbGFiLWRlbW8iLCJ1c2VySWQiOiIxIiwicm9sZXMiOiJVU0VSIiwiZXhwIjoxODkzNDU2MDAwfQ.ZgLN1WSTSnb4u6vvk-z4k8eX7_FIRiK_Uijb0Jkk3Ck'

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "!! something already listening on :$PORT — stop it or run with PORT=8090" >&2; exit 1
fi

echo ">> Postgres (the only real dependency)"
docker compose -f "$ROOT/docker-compose.yml" up -d postgres >/dev/null
until docker exec banking-postgres pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
docker exec banking-postgres psql -U postgres -d banking_app -q >/dev/null 2>&1 <<'SQL' || true
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='transactions_service_user') THEN
  CREATE USER transactions_service_user WITH PASSWORD 'transactions_service_pass'; END IF; END $$;
GRANT ALL ON SCHEMA transactions_service TO transactions_service_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA transactions_service GRANT ALL ON TABLES TO transactions_service_user;
SQL

echo ">> building transactions-service (picks up fix.patch if applied)"
( cd "$TX" && mvn -q -o -DskipTests package 2>/dev/null || mvn -q -DskipTests package )

echo ">> proxymock mock: serving accounts, stripe, paypal, complyadvantage from $MOCKS/ on :4140"
"$PM" mock --in "$MOCKS" --no-out >/tmp/replay-lab-mock.log 2>&1 &
MOCK_PID=$!; trap 'kill $MOCK_PID 2>/dev/null || true' EXIT

echo ">> transactions-service on :$PORT  (memo-bug=$MEMO_BUG contract-refactor=$CONTRACT_REFACTOR)"
( cd "$TX" && exec env \
  DB_HOST=localhost DB_PORT=5432 DB_NAME=banking_app \
  DB_USERNAME=transactions_service_user DB_PASSWORD=transactions_service_pass DB_SCHEMA=transactions_service \
  JWT_SECRET='banking-app-super-secret-key-change-this-in-production-256-bit' ACCOUNTS_SERVICE_URL=http://localhost:8082 \
  FRAUD_SERVICE_HOST=localhost FRAUD_SERVICE_PORT=9999 \
  OTEL_SDK_DISABLED=true SERVER_PORT="$PORT" \
  DEMO_MEMO_BUG_ENABLED="$MEMO_BUG" DEMO_CONTRACT_REFACTOR_ENABLED="$CONTRACT_REFACTOR" \
  mvn -q -o spring-boot:run \
    -Dspring-boot.run.jvmArguments="-Dhttp.proxyHost=localhost -Dhttp.proxyPort=4140 -Dhttp.nonProxyHosts= -Dspring.kafka.producer.properties.max.block.ms=1500" ) &
APP_PID=$!; trap 'kill $MOCK_PID $APP_PID 2>/dev/null || true' EXIT

# wait for health, then warm the JWT filter (the first authed request after a
# cold start can 401 while Spring finishes lazy init — this avoids a false RED)
for _ in $(seq 1 90); do curl -sf -o /dev/null "http://localhost:$PORT/actuator/health" 2>/dev/null && break; sleep 2; done
for _ in $(seq 1 10); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $JWT_TOKEN" "http://localhost:$PORT/api/transactions" 2>/dev/null)" = 200 ] && break
  sleep 1
done

echo
echo "======================================================================"
echo ">> READY — app on :$PORT, dependencies mocked on :4140."
echo ">> In another terminal, replay captured production traffic against it:"
echo "     proxymock replay --in captured --test-against http://localhost:$PORT"
echo ">> Ctrl-C here stops the app and the mock."
echo "======================================================================"
wait "$APP_PID"
