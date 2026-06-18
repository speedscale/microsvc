#!/usr/bin/env bash
# Proves: kubernetes/overlays/replay renders an isolated banking-replay app without organic sim traffic.
# Created: 2026-06-18 after adding the replay namespace overlay.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

kubectl kustomize "$ROOT/kubernetes/overlays/replay" > "$out"

grep -q '^  name: banking-replay$' "$out" || {
  echo "FAIL: banking-replay namespace missing"
  exit 1
}

if grep -Eq 'namespace: banking-app|name: banking-sim|simulation-client-hpa|banking-sim-config|banking-sim-secret' "$out"; then
  echo "FAIL: replay overlay still contains live namespace or simulation resources"
  exit 1
fi

grep -q '^  name: banking-ai$' "$out" || {
  echo "FAIL: banking-ai deployment/service missing"
  exit 1
}

echo "PASS: replay overlay renders in banking-replay without simulation traffic"
