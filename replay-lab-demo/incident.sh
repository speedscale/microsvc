#!/usr/bin/env bash
# Pull the live production incident from the Replay Lab and stage it locally:
#
#   1. port-forward the replay-lab control service (staging-decoy)
#   2. export the failing traffic window from the BYOC bucket (RRPairs + mocks)
#   3. craft account-matched accounts-service mocks for the post-fix replay
#
# Then, in two terminals:
#   make run MOCKS=incident-mocks            # buggy build + incident deps
#   make reproduce IN=incident/localhost     # RED  (the captured prod 400)
#   make fix                                 # GREEN (same request, 201)
#
# The errors fire in ~10 minute bursts and the deployed export scans only the
# newest few minutes of a busy service, so a 404 here usually means "between
# bursts" - wait for the next burst (watch the Grafana errors dashboard) and
# rerun. Once replay-lab !61 is deployed the window/batches params below make
# the pull time-insensitive.
set -euo pipefail
cd "$(dirname "$0")"

CTX="${CTX:-do-nyc1-staging-decoy}"
SERVICE="${SERVICE:-banking-transactions}"
ROUTE="${ROUTE:-/api/transactions/deposit}"
STATUS="${STATUS:-400}"
WINDOW="${WINDOW:-45m}"     # inert until replay-lab !61 deploys, then honored
BATCHES="${BATCHES:-2000}"
LOCAL_PORT=28080

command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
kubectl --context "$CTX" get ns replay-lab >/dev/null 2>&1 \
  || { echo "no access to context $CTX / namespace replay-lab"; exit 1; }

kubectl --context "$CTX" -n replay-lab port-forward svc/replay-lab-control "$LOCAL_PORT:80" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT

# wait for the tunnel; curl 000 = not up yet
for _ in $(seq 1 15); do
  READY=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$LOCAL_PORT/healthz" || echo 000)
  [ "$READY" != "000" ] && break
  sleep 1
done
[ "$READY" = "000" ] && { echo "port-forward to replay-lab-control never came up"; exit 1; }

URL="http://localhost:$LOCAL_PORT/api/snapshots/export?service=$SERVICE&route=$ROUTE&status=$STATUS&mocks=true&window=$WINDOW&batches=$BATCHES"
echo ">> exporting failing traffic: service=$SERVICE route=$ROUTE status=$STATUS"
CODE=$(curl -s -o /tmp/incident-snapshot.tar.gz -w '%{http_code}' "$URL" || echo 000)
[ "$CODE" = "000" ] && { echo "export request failed (tunnel dropped?)"; exit 1; }

if [ "$CODE" = "404" ]; then
  echo
  echo "  no failing traffic in the export scan right now."
  echo "  errors fire in ~10-minute bursts; watch the errors dashboard and rerun"
  echo "  this within a few minutes of a burst (or widen WINDOW=... once the"
  echo "  replay-lab window param is deployed)."
  exit 1
elif [ "$CODE" != "200" ]; then
  echo "  export failed: HTTP $CODE"; head -c 300 /tmp/incident-snapshot.tar.gz; echo
  exit 1
fi

rm -rf incident && mkdir -p incident
tar xzf /tmp/incident-snapshot.tar.gz -C incident
# a mocks-only tarball (no localhost/) means the scan found downstream traffic
# but no inbound requests matching route+status - same "between bursts" case as
# a 404, the export just had mocks to return
N=$(find incident/localhost -name '*.md' 2>/dev/null | wc -l | tr -d ' ' || true)
if [ "$N" = "0" ]; then
  echo
  echo "  the scan window has no failing $ROUTE requests right now (mocks only)."
  echo "  errors fire in ~10-minute bursts; rerun within a few minutes of a burst"
  echo "  (watch the errors dashboard), or widen WINDOW=... once the replay-lab"
  echo "  window param is deployed."
  exit 1
fi
echo ">> pulled $N failing request(s) into incident/ ($(du -sh incident | cut -f1))"

python3 ./craft-mocks.py incident incident-mocks

echo
echo "Next:"
echo "  terminal 1:  make run MOCKS=incident-mocks"
echo "  terminal 2:  make reproduce IN=incident/localhost   ->  RED  (prod failure, on your laptop)"
echo "               make fix                                ->  GREEN (same request, 201)"
