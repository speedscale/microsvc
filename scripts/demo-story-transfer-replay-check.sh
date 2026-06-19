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
gateway_port="${TRANSFER_REPLAY_GATEWAY_PORT:-$((23000 + RANDOM % 1000))}"
record_port="${TRANSFER_REPLAY_RECORD_PORT:-$((24000 + RANDOM % 1000))}"
health_port="${TRANSFER_REPLAY_HEALTH_PORT:-$((25000 + RANDOM % 1000))}"
capture_dir="${TRANSFER_REPLAY_CAPTURE_DIR:-$(mktemp -d "/tmp/microsvc-transfer-capture.XXXXXX")}"
replay_out="${TRANSFER_REPLAY_OUT_DIR:-$(mktemp -d "/tmp/microsvc-transfer-replay.XXXXXX")}"
gateway_log="/tmp/microsvc-gateway-port-forward.$$.log"
record_log="/tmp/microsvc-proxymock-record.$$.log"
gateway_pid=""
record_pid=""

cleanup() {
  if [ -n "${record_pid:-}" ]; then
    kill "$record_pid" 2>/dev/null || true
  fi
  if [ -n "${gateway_pid:-}" ]; then
    kill "$gateway_pid" 2>/dev/null || true
  fi
  rm -f "$gateway_log" "$record_log"
}
trap cleanup EXIT

kubectl --context "$context" -n "$namespace" port-forward service/banking-gateway "$gateway_port:80" >"$gateway_log" 2>&1 &
gateway_pid="$!"

for _ in $(seq 1 20); do
  if ! kill -0 "$gateway_pid" 2>/dev/null; then
    cat "$gateway_log" >&2
    exit 1
  fi
  if grep -q "Forwarding from" "$gateway_log"; then
    break
  fi
  sleep 0.5
done

proxymock record \
  --app-port "$gateway_port" \
  --proxy-in-port "$record_port" \
  --health-port "$health_port" \
  --out "$capture_dir" \
  --svc-name banking-gateway \
  --out-format markdown >"$record_log" 2>&1 &
record_pid="$!"

for _ in $(seq 1 30); do
  if ! kill -0 "$record_pid" 2>/dev/null; then
    cat "$record_log" >&2
    exit 1
  fi
  if curl -fsS "http://127.0.0.1:$health_port" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

RECORD_BASE_URL="http://127.0.0.1:$record_port" node --input-type=module - <<'NODE'
const base = process.env.RECORD_BASE_URL;
const username = process.env.DEMO_USER || "harper.clark.001";
const password = process.env.DEMO_PASSWORD || "SimUser123!";

async function request(path, opts = {}) {
  const response = await fetch(base + path, opts);
  const text = await response.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { response, text, data };
}

async function post(path, body, token) {
  return request(path, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

const login = await post("/api/users/login", { usernameOrEmail: username, password });
if (login.response.status !== 200 || !login.data?.token) {
  throw new Error(`login returned ${login.response.status}: ${login.text}`);
}

const accounts = await request("/api/accounts", {
  headers: { authorization: `Bearer ${login.data.token}` },
});
if (accounts.response.status !== 200 || !Array.isArray(accounts.data)) {
  throw new Error(`accounts returned ${accounts.response.status}: ${accounts.text}`);
}

const checking = accounts.data.find((account) => account.accountType === "CHECKING");
const savings = accounts.data.find((account) => account.accountType === "SAVINGS");
if (!checking || !savings) {
  throw new Error("checking/savings accounts not found");
}

const transfer = await post("/api/transactions/transfer", {
  fromAccountId: checking.id,
  toAccountId: savings.id,
  amount: 125,
  description: "Emergency fund transfer",
}, login.data.token);
if (transfer.response.status !== 400) {
  throw new Error(`expected transfer review status 400, got ${transfer.response.status}: ${transfer.text}`);
}

console.error(JSON.stringify({
  recorded: true,
  user: username,
  checking: checking.id,
  savings: savings.id,
  transferStatus: transfer.response.status,
}, null, 2));
NODE

sleep 1
kill "$record_pid" 2>/dev/null || true
record_pid=""

if ! find "$capture_dir" -type f | grep -q .; then
  cat "$record_log" >&2
  echo "proxymock record wrote no files to $capture_dir" >&2
  exit 1
fi

replay_json="$(proxymock replay \
  --in "$capture_dir" \
  --test-against "http://127.0.0.1:$gateway_port" \
  --rewrite-host \
  --fail-if "requests.failed!=0" \
  --out "$replay_out" \
  --output json)"

REPLAY_JSON="$replay_json" CAPTURE_DIR="$capture_dir" REPLAY_OUT="$replay_out" node --input-type=module - <<'NODE'
const replay = JSON.parse(process.env.REPLAY_JSON);
const transfer = replay.endpoints?.find((endpoint) => endpoint.url === "/api/transactions/transfer");
if (!transfer) {
  throw new Error("replay output did not include /api/transactions/transfer");
}
if (transfer.metrics?.["requests.failed"] !== 0 || transfer.metrics?.["requests.succeeded"] < 1) {
  throw new Error(`transfer replay failed: ${JSON.stringify(transfer.metrics)}`);
}

console.log(JSON.stringify({
  ok: true,
  captureDir: process.env.CAPTURE_DIR,
  replayOut: process.env.REPLAY_OUT,
  transfer: transfer.metrics,
}, null, 2));
NODE
