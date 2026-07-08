#!/usr/bin/env bash
# UI-driven demo helper: stage the pulled incident as a proxymock web workspace,
# and drive reproduce/fix so the RESULTS render in the browser (proxymock web),
# not the terminal. proxymock web is a traffic explorer + diff view; it does not
# run replays itself, so this script triggers the replay and web shows the
# outcome. Grafana carries the observability half; this carries the traffic half.
#
#   ./uidemo.sh setup       # pull incident + build the web workspace + start the buggy service
#   ./uidemo.sh web         # launch proxymock web on the workspace (browser opens)
#   ./uidemo.sh reproduce   # replay the failing deposits -> web shows 400s (reproduced)
#   ./uidemo.sh fix         # apply the fix, replay -> web shows 201s (green)
#   ./uidemo.sh reset       # restore the bug
#   ./uidemo.sh down        # stop service + web
set -euo pipefail
cd "$(dirname "$0")"
PM="$HOME/.speedscale/proxymock"
PORT="${PORT:-8087}"
WS="uidemo/proxymock"
ROOT="$(cd .. && pwd)"

case "${1:-}" in
  setup)
    [ -d incident/localhost ] || WINDOW="${WINDOW:-6h}" scripts/incident.sh
    rm -rf uidemo && mkdir -p "$WS"
    # the pulled PRODUCTION traffic (failing deposits, as captured = 400) is the
    # opening view: "here is your production traffic, from your own bucket"
    cp -R incident/localhost "$WS/captured-production"
    cp -R incident/banking-accounts "$WS/dependencies" 2>/dev/null || true
    make down >/dev/null 2>&1 || true
    MOCKS=incident-mocks scripts/run.sh > /tmp/uidemo-run.log 2>&1 &
    echo ">> workspace built at $WS ; buggy service starting (see /tmp/uidemo-run.log)"
    echo ">> next: ./uidemo.sh web"
    ;;
  web)
    echo ">> opening proxymock web on the workspace (traffic explorer)"
    exec "$PM" web --in uidemo --forwarder-addr "" --port 7799
    ;;
  reproduce)
    scripts/warmup.sh
    rm -rf "$WS/reproduced"
    "$PM" replay --in incident/localhost --test-against "http://localhost:$PORT" --out "$WS/reproduced" >/dev/null 2>&1 || true
    n=$(grep -rl '"statusCode":400' "$WS/reproduced" 2>/dev/null | wc -l | tr -d ' ')
    echo ">> reproduced: $n deposits returned 400 (refresh proxymock web -> the reproduced/ set)"
    ;;
  fix)
    ( cd "$ROOT" && git apply replay-lab-demo/fix.patch && ( cd backend/transactions-service && mvn -q -o compile ) )
    echo ">> fix applied, hot-restarting"; sleep 12
    scripts/warmup.sh
    rm -rf "$WS/fixed"
    "$PM" replay --in incident/localhost --test-against "http://localhost:$PORT" --out "$WS/fixed" >/dev/null 2>&1 || true
    n=$(grep -rl '"statusCode":201' "$WS/fixed" 2>/dev/null | wc -l | tr -d ' ')
    echo ">> fixed: $n deposits returned 201 (refresh proxymock web -> the fixed/ set)"
    ;;
  reset)
    ( cd "$ROOT" && git checkout -- backend/transactions-service ) && echo ">> bug restored"
    ;;
  down)
    pkill -f "proxymock web" 2>/dev/null || true
    make down >/dev/null 2>&1 || true
    echo ">> stopped web + service"
    ;;
  *)
    grep -E '^#   \./uidemo\.sh' "$0" | sed 's/^#   //'
    ;;
esac
