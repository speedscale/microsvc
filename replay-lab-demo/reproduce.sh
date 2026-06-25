#!/usr/bin/env bash
# Replay the captured production failure against the local service and report the result.
set -euo pipefail
cd "$(dirname "$0")"
PM="$HOME/.speedscale/proxymock"
PORT="${PORT:-8080}"

rm -rf out
"$PM" replay --in captured --test-against "http://localhost:$PORT" --out out >/dev/null 2>&1 || true
code=$(grep -rohE '"statusCode":[0-9]+' out 2>/dev/null | grep -oE '[0-9]+' | head -1)

echo
case "$code" in
  400) echo "  RED   — the captured deposit reproduces the production failure (HTTP 400)";;
  201) echo "  GREEN — the captured deposit now succeeds (HTTP 201) — bug fixed";;
  "")  echo "  no response — is 'make run' up in terminal 1?";;
  *)   echo "  replay returned HTTP $code";;
esac
echo
