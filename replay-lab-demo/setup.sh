#!/usr/bin/env bash
# Single prerequisite script for the Replay Lab local demo.
# Brings up the one real dependency (Postgres) and builds the service.
# Everything else (the accounts dependency) is mocked by proxymock — see the Makefile.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # microsvc repo root
cd "$ROOT"

echo "[1/3] Postgres — the only real dependency transactions-service needs to boot"
docker compose up -d postgres
echo -n "      waiting for postgres "
until docker exec banking-postgres pg_isready -U postgres >/dev/null 2>&1; do echo -n .; sleep 1; done
echo " ready"

echo "[2/3] Service DB user + grants"
docker exec banking-postgres psql -U postgres -d banking_app -q <<'SQL'
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='transactions_service_user') THEN
    CREATE USER transactions_service_user WITH PASSWORD 'transactions_service_pass';
  END IF;
END $$;
GRANT ALL ON SCHEMA transactions_service TO transactions_service_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA transactions_service GRANT ALL ON TABLES TO transactions_service_user;
SQL

echo "[3/3] Build transactions-service"
( cd backend/transactions-service && mvn -q -o -DskipTests package 2>/dev/null || mvn -q -DskipTests package )

echo
echo "Done. Now (in this dir):"
echo "  make run         # terminal 1: start the service (bug armed)"
echo "  make reproduce   # terminal 2: replay the captured prod failure -> 400 (red)"
echo "  make fix         # apply the agent's null-guard fix; replay -> 201 (green)"
