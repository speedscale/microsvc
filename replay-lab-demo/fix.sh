#!/usr/bin/env bash
# Apply the agent's fix (fix.patch), let spring-boot devtools hot-restart the running
# service, then replay the same captured failure to prove it is GREEN.
set -euo pipefail
cd "$(dirname "$0")"
DEMO="$PWD"
ROOT="$(cd .. && pwd)"
TX="$ROOT/backend/transactions-service"

echo ">> applying fix.patch"
( cd "$ROOT" && git apply "$DEMO/fix.patch" && git --no-pager diff --stat \
    backend/transactions-service/src/main/java/com/banking/transactionsservice/service/TransactionService.java )

echo ">> recompiling (spring-boot devtools hot-restarts the running service)"
( cd "$TX" && mvn -q -o compile )

echo ">> waiting for hot-restart..."
sleep 10
PORT="${PORT:-8080}" ./reproduce.sh
