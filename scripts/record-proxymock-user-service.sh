#!/usr/bin/env bash
# Record inbound HTTP + outbound Postgres for user-service into JSON rrpairs for CI (mock + replay).
#
# Prerequisites: Docker (postgres on 127.0.0.1:5432), Java 17, proxymock on PATH, built JAR.
# Usage (from repo root):
#   ./scripts/record-proxymock-user-service.sh
#
# Output: backend/user-service/proxymock/recorded-complete/ (JSON). Update PROXYMOCK_DIR in
# scripts/test-postgres-mock.sh if you change the directory name.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
US="$ROOT/backend/user-service"
OUT="${RECORD_OUT:-$US/proxymock/recorded-complete}"

if ! nc -z 127.0.0.1 5432 2>/dev/null; then
  echo "error: PostgreSQL not listening on 127.0.0.1:5432. Start it, e.g.: docker compose up -d postgres"
  exit 1
fi

if ! command -v proxymock >/dev/null 2>&1; then
  echo "error: proxymock not on PATH. Install: curl -Lfs https://downloads.speedscale.com/proxymock/install-proxymock | sh"
  exit 1
fi

cd "$US"
JAR=$(find target -name 'user-service-*.jar' -not -name '*original*' | head -1)
if [ -z "$JAR" ] || [ ! -f "$JAR" ]; then
  echo "error: build the JAR first: (cd backend/user-service && ./mvnw clean package -DskipTests)"
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"

export SPRING_DATASOURCE_URL="jdbc:postgresql://127.0.0.1:65432/banking_app?sslmode=disable"
export SPRING_DATASOURCE_DRIVER_CLASS_NAME="org.postgresql.Driver"
export DB_USERNAME=user_service_user
export DB_PASSWORD=user_service_pass
export DB_SCHEMA=user_service
export OTEL_SDK_DISABLED=true
export JAVA_TOOL_OPTIONS="-Dotel.sdk.disabled=true ${JAVA_TOOL_OPTIONS:-}"

echo "Recording to $OUT (inbound :4143 -> app :8080, Postgres map 65432 -> :5432)..."
proxymock record -v \
  --out-format json \
  --out "$OUT" \
  --app-port 8080 \
  --proxy-in-port 4143 \
  --map 65432=postgres://127.0.0.1:5432 \
  --app-log-to "$US/record-app.log" \
  --log-to "$US/record-proxymock.log" \
  -- java -jar "$JAR" &
REC_PID=$!

wait_app() {
  local n=0
  while [ "$n" -lt 90 ]; do
    if curl -sf -o /dev/null "http://127.0.0.1:4143/actuator/health/liveness" 2>/dev/null; then
      return 0
    fi
    sleep 2
    n=$((n + 1))
  done
  return 1
}

if ! wait_app; then
  echo "error: app did not become ready on http://127.0.0.1:4143 (see $US/record-app.log)"
  kill "$REC_PID" 2>/dev/null || true
  wait "$REC_PID" 2>/dev/null || true
  exit 1
fi

echo "Sending inbound HTTP through recording proxy..."
curl -sS "http://127.0.0.1:4143/actuator/health" >/dev/null
curl -sS "http://127.0.0.1:4143/actuator/health/liveness" >/dev/null
curl -sS "http://127.0.0.1:4143/actuator/health/readiness" >/dev/null
curl -sS "http://127.0.0.1:4143/api/users/check-username?username=recordprobe" >/dev/null || true

sleep 2
echo "Stopping recorder (pid $REC_PID)..."
kill -TERM "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true

HTTP_N=$(find "$OUT" -name '*.json' -exec grep -l '"l7protocol": "http' {} \; 2>/dev/null | wc -l | tr -d ' ')
PG_N=$(find "$OUT" -name '*.json' -exec grep -l '"l7protocol": "postgres"' {} \; 2>/dev/null | wc -l | tr -d ' ')
echo "Done. JSON files with HTTP l7: $HTTP_N, Postgres: $PG_N under $OUT"
if [ "${HTTP_N:-0}" -lt 1 ]; then
  echo "warning: no HTTP rrpairs found; replay in CI may skip. Check record-proxymock.log and record-app.log."
  exit 1
fi
