#!/usr/bin/env bash
# Proves: simulation DB seed pins PostgreSQL random output before generating replay data.
# Created: 2026-06-19 after transaction replays failed against non-deterministic account state.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
seed="$ROOT/database/migrations/user-service/V2__Seed_simulation_users.sql"

test -f "$seed" || {
  echo "FAIL: missing seed migration"
  exit 1
}

setseed_line=$(awk 'tolower($0) ~ /select[[:space:]]+setseed/ {print NR; exit}' "$seed")
first_random_line=$(awk 'index(tolower($0), "random()") > 0 {print NR; exit}' "$seed")

if [ -z "$setseed_line" ]; then
  echo "FAIL: seed migration does not call setseed"
  exit 1
fi

if [ -z "$first_random_line" ]; then
  echo "FAIL: seed migration does not generate randomized demo data"
  exit 1
fi

if [ "$setseed_line" -gt "$first_random_line" ]; then
  echo "FAIL: setseed must run before the first RANDOM() call"
  exit 1
fi

echo "PASS: simulation seed pins PostgreSQL RANDOM() before generating replay data"
