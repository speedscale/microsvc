#!/usr/bin/env bash
# Terminal 1: start proxymock mock (serves every downstream dependency from recorded
# traffic) and the transactions-service (deps mocked, bug armed). Ctrl-C stops both.
set -euo pipefail
cd "$(dirname "$0")"
DEMO="$PWD"
ROOT="$(cd .. && pwd)"
TX="$ROOT/backend/transactions-service"
PM="$HOME/.speedscale/proxymock"
PORT="${PORT:-8080}"
JWT='banking-app-super-secret-key-change-this-in-production-256-bit'

# proxymock mock: app -> proxy :4140 -> recorded response (accounts, stripe, paypal, complyadvantage)
"$PM" mock --in mocks --no-out >/tmp/replay-lab-mock.log 2>&1 &
MOCK_PID=$!
trap 'kill $MOCK_PID 2>/dev/null || true' EXIT
echo ">> proxymock mock serving deps on :4140  (accounts, stripe, paypal, complyadvantage)"
echo ">> starting transactions-service on :$PORT  (deps mocked, bug armed)"
echo

cd "$TX"
# RestTemplate (HttpURLConnection) honors -Dhttp.proxy* -> outbound accounts calls hit proxymock.
# Postgres (JDBC) ignores the HTTP proxy and stays a real local dependency.
exec env \
  DB_HOST=localhost DB_PORT=5432 DB_NAME=banking_app \
  DB_USERNAME=transactions_service_user DB_PASSWORD=transactions_service_pass DB_SCHEMA=transactions_service \
  JWT_SECRET="$JWT" ACCOUNTS_SERVICE_URL=http://localhost:8082 \
  FRAUD_SERVICE_HOST=localhost FRAUD_SERVICE_PORT=9999 \
  OTEL_SDK_DISABLED=true DEMO_MEMO_BUG_ENABLED=true SERVER_PORT="$PORT" \
  mvn -q -o spring-boot:run \
    -Dspring-boot.run.jvmArguments="-Dhttp.proxyHost=localhost -Dhttp.proxyPort=4140 -Dhttp.nonProxyHosts= -Dspring.kafka.producer.properties.max.block.ms=1500"
