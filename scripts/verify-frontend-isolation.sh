#!/usr/bin/env bash
# Proves the public staging overlays exclude the frontend NodePort while the local overlay retains it.
# Created: 2026-08-17 after a public NodePort exposed the staging frontend.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

render_overlay() {
  kubectl kustomize "$repo_root/kubernetes/overlays/$1"
}

assert_nodeport_absent() {
  local overlay=$1
  if render_overlay "$overlay" | grep -q 'name: banking-frontend-nodeport'; then
    echo "FAIL: $overlay renders banking-frontend-nodeport"
    exit 1
  fi
  echo "PASS: $overlay excludes banking-frontend-nodeport"
}

assert_nodeport_absent speedscale
assert_nodeport_absent speedscale-sidecar
assert_nodeport_absent replay

local_manifest=$(render_overlay local)
if ! grep -q 'name: banking-frontend-nodeport' <<<"$local_manifest"; then
  echo "FAIL: local overlay does not render banking-frontend-nodeport"
  exit 1
fi
if ! grep -q 'nodePort: 30080' <<<"$local_manifest"; then
  echo "FAIL: local overlay does not retain nodePort 30080"
  exit 1
fi
echo "PASS: local overlay retains banking-frontend-nodeport on 30080"

deployment_count=$(grep -c '^kind: Deployment$' <<<"$local_manifest")
protected_deployment_count=$(grep -c 'automountServiceAccountToken: false' <<<"$local_manifest")
if [[ "$deployment_count" -ne "$protected_deployment_count" ]]; then
  echo "FAIL: $protected_deployment_count of $deployment_count base deployments disable service-account tokens"
  exit 1
fi
echo "PASS: all $deployment_count base deployments disable service-account tokens"

if grep -q -- '- secrets' <<<"$local_manifest"; then
  echo "FAIL: banking-app-sa retains namespace secret access"
  exit 1
fi
echo "PASS: banking-app-sa cannot read namespace secrets"

node - "$repo_root/frontend/package-lock.json" <<'NODE'
const lock = require(process.argv[2]);
const expected = {
  next: '16.2.6',
  react: '19.2.7',
  'react-dom': '19.2.7',
};
for (const [name, version] of Object.entries(expected)) {
  const actual = lock.packages[`node_modules/${name}`]?.version;
  if (actual !== version) {
    console.error(`FAIL: ${name} resolved to ${actual ?? 'missing'}, expected ${version}`);
    process.exit(1);
  }
  console.log(`PASS: ${name} resolves to ${version}`);
}
NODE
