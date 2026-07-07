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
# The errors fire in ~10 minute bursts. Pass WINDOW to widen the export scan
# past the newest few minutes (deployed since replay-lab v0.0.44) so the pull is
# not sensitive to burst timing; a 404 or mocks-only result means no matching
# failures in that window.
set -euo pipefail
cd "$(dirname "$0")"

CTX="${CTX:-do-nyc1-staging-decoy}"
SERVICE="${SERVICE:-banking-transactions}"
ROUTE="${ROUTE:-/api/transactions/deposit}"
STATUS="${STATUS:-400}"
WINDOW="${WINDOW:-45m}"
BATCHES="${BATCHES:-2000}"
LOCAL_PORT="${LOCAL_PORT:-28080}"
SNAP=/tmp/incident-snapshot.tar.gz

command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
kubectl --context "$CTX" get ns replay-lab >/dev/null 2>&1 \
  || { echo "no access to context $CTX / namespace replay-lab"; exit 1; }

# A stale port-forward (or anything) on the port answers /healthz but then drops
# the export mid-stream, which is exactly the confusing failure to avoid.
if lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo ":$LOCAL_PORT is already in use (stale port-forward?). Free it or set LOCAL_PORT=..." >&2
  lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >&2
  exit 1
fi

kubectl --context "$CTX" -n replay-lab port-forward svc/replay-lab-control "$LOCAL_PORT:80" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT

# wait for the tunnel; curl -w prints 000 until it is up
for _ in $(seq 1 15); do
  READY=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$LOCAL_PORT/healthz" || true)
  [ "$READY" != "000" ] && [ -n "$READY" ] && break
  sleep 1
done
[ "${READY:-000}" = "000" ] && { echo "port-forward to replay-lab-control never came up"; exit 1; }

URL="http://localhost:$LOCAL_PORT/api/snapshots/export?service=$SERVICE&route=$ROUTE&status=$STATUS&mocks=true&window=$WINDOW&batches=$BATCHES"
echo ">> exporting failing traffic: service=$SERVICE route=$ROUTE status=$STATUS window=$WINDOW"
CODE=$(curl -s -o "$SNAP" -w '%{http_code}' "$URL" || true)   # -w already yields 000 on failure

if [ "${CODE:-000}" = "000" ]; then
  echo "  export request failed (tunnel dropped before it completed)"
  exit 1
elif [ "$CODE" = "404" ]; then
  echo
  echo "  no failing traffic in the export scan right now."
  echo "  widen the scan with a larger WINDOW=... (e.g. WINDOW=6h), or rerun a few"
  echo "  minutes after the next burst (watch the Grafana errors dashboard)."
  exit 1
elif [ "$CODE" != "200" ]; then
  # a non-200 body is a JSON error; only print it if it is actually text so a
  # stray gzip never dumps binary to the terminal
  echo "  export failed: HTTP $CODE"
  if LC_ALL=C grep -Iq . "$SNAP" 2>/dev/null; then head -c 300 "$SNAP"; echo; fi
  exit 1
fi

rm -rf incident && mkdir -p incident
tar xzf "$SNAP" -C incident
# a mocks-only tarball (no localhost/) means the scan found downstream traffic
# but no inbound requests matching route+status - same "between bursts" case as
# a 404, the export just had mocks to return
N=$(find incident/localhost -name '*.md' 2>/dev/null | wc -l | tr -d ' ' || true)
if [ "$N" = "0" ]; then
  echo
  echo "  the scan window has no failing $ROUTE requests right now (mocks only)."
  echo "  widen the scan with a larger WINDOW=... (e.g. WINDOW=6h), or rerun a few"
  echo "  minutes after the next burst (watch the Grafana errors dashboard)."
  exit 1
fi
echo ">> pulled $N failing request(s) into incident/ ($(du -sh incident | cut -f1))"

python3 ./craft-mocks.py incident incident-mocks

echo
echo "Next:"
echo "  terminal 1:  make run MOCKS=incident-mocks"
echo "  terminal 2:  make reproduce IN=incident/localhost   ->  RED  (prod failure, on your laptop)"
echo "               make fix                                ->  GREEN (same request, 201)"
