#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

config_file="${DEMO_LOOP_CONFIG:-$HOME/spd-workspace/speedstack/instances/microsvc-demo-mini/minikube.env}"
if [ -f "$config_file" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$config_file"
  set +a
fi

context="${KUBE_CONTEXT:-${MINIKUBE_PROFILE:-speedscale-demo-mini}}"
namespace="${NAMESPACE:-banking-app}"
capture_dir="${1:-${PROXYMOCK_CAPTURE_DIR:-}}"
local_port="${REPLAY_GATEWAY_PORT:-$((18080 + RANDOM % 1000))}"
tmp_dir="$(mktemp -d "/tmp/microsvc-proxymock-replay.XXXXXX")"
port_forward_pid=""
log_file="/tmp/microsvc-gateway-port-forward.$$.log"

cleanup() {
  if [ -n "${port_forward_pid:-}" ]; then
    kill "$port_forward_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp_dir" "$log_file"
}
trap cleanup EXIT

SOURCE_CAPTURE="$capture_dir" OUT_DIR="$tmp_dir" REPO_ROOT="$repo_root" node --input-type=module - <<'NODE'
import fs from "fs";
import path from "path";

const repoRoot = process.env.REPO_ROOT;
const proxymockRoot = path.join(repoRoot, "backend", "ai-service", "proxymock");
const out = process.env.OUT_DIR;

function newestCaptureDir() {
  if (!fs.existsSync(proxymockRoot)) {
    return null;
  }
  return fs.readdirSync(proxymockRoot)
    .map((name) => path.join(proxymockRoot, name))
    .filter((entry) => fs.statSync(entry).isDirectory())
    .filter((entry) => /^(live|imported-s3)-/.test(path.basename(entry)))
    .map((entry) => ({ entry, mtime: fs.statSync(entry).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime)[0]?.entry || null;
}

function readRRPair(file) {
  const text = fs.readFileSync(file, "utf8");
  if (file.endsWith(".json")) {
    return JSON.parse(text);
  }
  const line = text.split("\n").reverse().find((entry) => entry.startsWith("json: "));
  return line ? JSON.parse(line.slice("json: ".length)) : null;
}

const capture = process.env.SOURCE_CAPTURE || newestCaptureDir();
if (!capture) {
  throw new Error("no proxymock capture directory found");
}

const localhost = path.join(capture, "localhost");
if (!fs.existsSync(localhost)) {
  throw new Error(`capture has no localhost replay directory: ${capture}`);
}

const replayHostDir = path.join(out, "localhost");
fs.mkdirSync(replayHostDir, { recursive: true });

let copied = 0;
for (const name of fs.readdirSync(localhost).sort()) {
  if (!name.endsWith(".md") && !name.endsWith(".json")) {
    continue;
  }
  const file = path.join(localhost, name);
  let rrpair;
  try {
    rrpair = readRRPair(file);
  } catch {
    continue;
  }
  if (rrpair?.service === "banking-gateway" && rrpair.command === "POST" && rrpair.location === "/api/users/login") {
    fs.copyFileSync(file, path.join(replayHostDir, name));
    copied += 1;
    if (copied >= Number(process.env.REPLAY_SAMPLE_SIZE || 3)) {
      break;
    }
  }
}

console.error(JSON.stringify({ capture, replayDir: out, copied }, null, 2));
if (copied === 0) {
  throw new Error("no captured banking-gateway /api/users/login requests found");
}
NODE

kubectl --context "$context" -n "$namespace" port-forward service/banking-gateway "$local_port:80" >"$log_file" 2>&1 &
port_forward_pid="$!"

for _ in $(seq 1 20); do
  if ! kill -0 "$port_forward_pid" 2>/dev/null; then
    cat "$log_file" >&2
    exit 1
  fi
  if grep -q "Forwarding from" "$log_file"; then
    break
  fi
  sleep 0.5
done

proxymock replay \
  --in "$tmp_dir" \
  --test-against "http://127.0.0.1:$local_port" \
  --rewrite-host \
  --fail-if "requests.failed!=0" \
  --fail-if "requests.result-match-pct<100" \
  --output json \
  --no-out
