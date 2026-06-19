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

profile="${MINIKUBE_PROFILE:-speedscale-demo-mini}"
context="${KUBE_CONTEXT:-$profile}"
namespace="${NAMESPACE:-banking-app}"
registry="${REGISTRY:-ghcr.io/speedscale/microsvc}"
tag="${IMAGE_TAG:-local}"
frontend_port="${FRONTEND_PORT:-3000}"
overlay="${KUSTOMIZE_OVERLAY:-$repo_root/kubernetes/overlays/minikube-loop}"

services=(
  "accounts-service:backend/accounts-service"
  "ai-service:backend/ai-service"
  "api-gateway:backend/api-gateway"
  "fraud-service:backend/fraud-service"
  "frontend:frontend"
  "notification-service:backend/notification-service"
  "simulation-client:simulation-client"
  "transactions-service:backend/transactions-service"
  "user-service:backend/user-service"
)

deployments=(
  banking-postgres
  redis
  mongodb
  banking-kafka
  banking-user
  banking-accounts
  banking-transactions
  banking-fraud
  banking-notification
  banking-ai
  banking-gateway
  banking-frontend
  banking-sim
)

usage() {
  cat <<'USAGE'
Usage: scripts/demo-story-loop.sh <command> [service...]

Commands:
  start-minikube       Start minikube if it is stopped
  build [service...]   Build all images, or only named services, into minikube
  deploy [service...]  Apply the local overlay, restart services, and wait for rollouts
  api-check            Verify Harper Clark and the transfer review path in-cluster
  browser-check        Port-forward frontend and run the browser story check
  traffic-check [dir]  Verify proxymock capture evidence for the demo story
  web-check            Verify proxymock web can display the live capture
  replay-check [dir]   Replay captured gateway login traffic against the local gateway
  transfer-replay-check Record and replay the transfer-review request locally
  fresh-capture-check  Record fresh transfer traffic, replay it, and view it in web
  once [service...]    start-minikube, build, deploy, api-check, browser-check
  loop [service...]    Repeat one-service repair loops until stopped or failed
  port-forward         Forward local :3000 to the frontend service
  status               Show local pods and services
  clean                Delete the local banking app namespace resources

Examples:
  scripts/demo-story-loop.sh once frontend
  scripts/demo-story-loop.sh loop frontend api-gateway transactions-service
  scripts/demo-story-loop.sh build frontend api-gateway
  scripts/demo-story-loop.sh deploy
  scripts/demo-story-loop.sh browser-check
  scripts/demo-story-loop.sh traffic-check
  scripts/demo-story-loop.sh web-check
  scripts/demo-story-loop.sh replay-check
  scripts/demo-story-loop.sh transfer-replay-check
  scripts/demo-story-loop.sh fresh-capture-check

Defaults:
  DEMO_LOOP_CONFIG=$HOME/spd-workspace/speedstack/instances/microsvc-demo-mini/minikube.env
  MINIKUBE_PROFILE=speedscale-demo-mini
  KUBE_CONTEXT=$MINIKUBE_PROFILE
  NAMESPACE=banking-app
  KUSTOMIZE_OVERLAY=kubernetes/overlays/minikube-loop
USAGE
}

run_kubectl() {
  kubectl --context "$context" "$@"
}

start_minikube() {
  if minikube -p "$profile" status >/dev/null 2>&1; then
    return
  fi

  minikube start -p "$profile" --cpus="${MINIKUBE_CPUS:-4}" --memory="${MINIKUBE_MEMORY:-6144}"
}

selected_services() {
  if [ "$#" -eq 0 ]; then
    printf '%s\n' "${services[@]}"
    return
  fi

  local wanted service name found
  for wanted in "$@"; do
    found=false
    for service in "${services[@]}"; do
      name="${service%%:*}"
      if [ "$wanted" = "$name" ]; then
        printf '%s\n' "$service"
        found=true
      fi
    done
    if [ "$found" = false ]; then
      echo "unknown service: $wanted" >&2
      exit 2
    fi
  done
}

build_images() {
  start_minikube
  eval "$(minikube -p "$profile" docker-env)"

  local service name context_dir
  while IFS= read -r service; do
    name="${service%%:*}"
    context_dir="${service#*:}"
    echo "Building $registry/$name:$tag"
    docker build -t "$registry/$name:$tag" "$repo_root/$context_dir"
  done < <(selected_services "$@")
}

deploy_local() {
  start_minikube
  local wait_all
  wait_all=false
  if [ "$#" -eq 0 ] || ! cluster_ready; then
    wait_all=true
  fi

  run_kubectl delete job seed-user-pool -n "$namespace" --ignore-not-found
  run_kubectl apply -k "$overlay"
  restart_deployments "$@"
  if [ "$wait_all" = true ]; then
    wait_rollouts
  else
    wait_rollouts "$@"
  fi
}

deployment_for_service() {
  case "$1" in
    accounts-service) echo banking-accounts ;;
    ai-service) echo banking-ai ;;
    api-gateway) echo banking-gateway ;;
    fraud-service) echo banking-fraud ;;
    frontend) echo banking-frontend ;;
    notification-service) echo banking-notification ;;
    simulation-client) echo banking-sim ;;
    transactions-service) echo banking-transactions ;;
    user-service) echo banking-user ;;
    *)
      echo "unknown service: $1" >&2
      exit 2
      ;;
  esac
}

restart_deployments() {
  local service name deployment
  while IFS= read -r service; do
    name="${service%%:*}"
    deployment="$(deployment_for_service "$name")"
    run_kubectl rollout restart "deployment/$deployment" -n "$namespace"
  done < <(selected_services "$@")
}

cluster_ready() {
  local deployment desired available
  for deployment in "${deployments[@]}"; do
    desired="$(run_kubectl get "deployment/$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
    available="$(run_kubectl get "deployment/$deployment" -n "$namespace" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)"
    if [ -z "$desired" ] || [ "${available:-0}" -lt "$desired" ]; then
      return 1
    fi
  done
}

wait_rollouts() {
  local deployment service name
  if [ "$#" -eq 0 ]; then
    for deployment in "${deployments[@]}"; do
      run_kubectl rollout status "deployment/$deployment" -n "$namespace" --timeout="${ROLLOUT_TIMEOUT:-300s}"
    done
  else
    while IFS= read -r service; do
      name="${service%%:*}"
      deployment="$(deployment_for_service "$name")"
      run_kubectl rollout status "deployment/$deployment" -n "$namespace" --timeout="${ROLLOUT_TIMEOUT:-300s}"
    done < <(selected_services "$@")
  fi
  run_kubectl wait --for=condition=complete job/seed-user-pool -n "$namespace" --timeout="${JOB_TIMEOUT:-300s}"
}

api_check() {
  DEMO_USER="${DEMO_USER:-harper.clark.001}" \
  DEMO_PASSWORD="${DEMO_PASSWORD:-SimUser123!}" \
  EXPECT_TRANSFER_REVIEW=true \
  kubectl --context "$context" -n "$namespace" exec deploy/banking-sim -- \
    env DEMO_USER="${DEMO_USER:-harper.clark.001}" DEMO_PASSWORD="${DEMO_PASSWORD:-SimUser123!}" EXPECT_TRANSFER_REVIEW=true \
    node --input-type=module -e '
const base = "http://banking-gateway:80";
const username = process.env.DEMO_USER;
const password = process.env.DEMO_PASSWORD;
const maxAttempts = Number(process.env.API_CHECK_ATTEMPTS || 20);
const retryDelayMs = Number(process.env.API_CHECK_RETRY_DELAY_MS || 1000);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function call(path, opts = {}) {
  let lastError = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const response = await fetch(base + path, opts);
      const text = await response.text();
      let data = null;
      try { data = text ? JSON.parse(text) : null; } catch { data = text; }

      if (response.status < 500 || attempt === maxAttempts) {
        return { status: response.status, data, text };
      }
      lastError = new Error(`${path} returned ${response.status}: ${text}`);
    } catch (error) {
      lastError = error;
      if (attempt === maxAttempts) {
        throw error;
      }
    }

    await sleep(retryDelayMs);
  }

  throw lastError || new Error(`failed to call ${path}`);
}

async function post(path, body, token) {
  return call(path, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

const login = await post("/api/users/login", { usernameOrEmail: username, password });
if (login.status !== 200 || !login.data?.token) throw new Error(`login returned ${login.status}: ${login.text}`);
const token = login.data.token;
const accountsResponse = await call("/api/accounts", { headers: { authorization: `Bearer ${token}` } });
if (accountsResponse.status !== 200) throw new Error(`accounts returned ${accountsResponse.status}: ${accountsResponse.text}`);

const accounts = accountsResponse.data;
const checking = accounts.filter((account) => account.accountType === "CHECKING");
const savings = accounts.filter((account) => account.accountType === "SAVINGS");
if (checking.length !== 1 || savings.length !== 1) throw new Error(`expected one checking and one savings, got checking=${checking.length} savings=${savings.length}`);
if (Number(checking[0].balance) < 1000 || Number(savings[0].balance) < 500) throw new Error("demo accounts are not funded enough");

const transfer = await post("/api/transactions/transfer", {
  fromAccountId: checking[0].id,
  toAccountId: savings[0].id,
  amount: 125,
  description: "Emergency fund transfer",
}, token);
if (transfer.status !== 400) throw new Error(`expected transfer compliance review status 400, got ${transfer.status}: ${transfer.text}`);

console.log(JSON.stringify({ ok: true, user: username, checking: checking[0], savings: savings[0], transferStatus: transfer.status }, null, 2));
'
}

port_forward() {
  run_kubectl port-forward -n "$namespace" service/banking-frontend "$frontend_port:80"
}

browser_check() {
  port_forward_pid=""
  local frontend_pod local_port log_file

  frontend_pod="$(run_kubectl get pod -n "$namespace" -l app=banking-frontend --field-selector=status.phase=Running --sort-by=.metadata.creationTimestamp -o name | tail -n 1)"
  if [ -z "$frontend_pod" ]; then
    echo "frontend pod not found" >&2
    exit 1
  fi
  run_kubectl wait --for=condition=Ready "$frontend_pod" -n "$namespace" --timeout="${FRONTEND_READY_TIMEOUT:-120s}"

  local_port="${BROWSER_FRONTEND_PORT:-$((3100 + RANDOM % 1000))}"
  log_file="/tmp/microsvc-frontend-port-forward.$$.log"
  run_kubectl port-forward -n "$namespace" "$frontend_pod" "$local_port:3000" >"$log_file" 2>&1 &
  port_forward_pid="$!"
  trap 'if [ -n "${port_forward_pid:-}" ]; then kill "$port_forward_pid" 2>/dev/null || true; fi' EXIT

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

  BASE_URL="http://127.0.0.1:$local_port" node "$repo_root/scripts/demo-story-browser-check.mjs"
}

traffic_check() {
  node "$repo_root/scripts/demo-story-traffic-check.mjs" "$@"
}

web_check() {
  "$repo_root/scripts/demo-story-web-check.sh" "$@"
}

replay_check() {
  "$repo_root/scripts/demo-story-replay-check.sh" "$@"
}

transfer_replay_check() {
  "$repo_root/scripts/demo-story-transfer-replay-check.sh" "$@"
}

fresh_capture_check() {
  bash "$repo_root/scripts/demo-story-fresh-capture-check.sh" "$@"
}

run_once() {
  start_minikube
  build_images "$@"
  deploy_local "$@"
  api_check
  browser_check
}

loop_forever() {
  local iteration service name delay
  iteration=1
  delay="${LOOP_DELAY_SECONDS:-0}"

  while true; do
    while IFS= read -r service; do
      name="${service%%:*}"
      echo "Loop $iteration: $name"
      run_once "$name"
      iteration=$((iteration + 1))
      if [ "$delay" -gt 0 ]; then
        sleep "$delay"
      fi
    done < <(selected_services "$@")
  done
}

status() {
  run_kubectl get pods,svc -n "$namespace"
}

clean() {
  run_kubectl delete -k "$overlay" --ignore-not-found
}

cmd="${1:-}"
if [ -z "$cmd" ]; then
  usage
  exit 2
fi
shift || true

case "$cmd" in
  start-minikube) start_minikube ;;
  build) build_images "$@" ;;
  deploy) deploy_local "$@" ;;
  api-check) api_check ;;
  browser-check) browser_check ;;
  traffic-check) traffic_check "$@" ;;
  web-check) web_check "$@" ;;
  replay-check) replay_check "$@" ;;
  transfer-replay-check) transfer_replay_check "$@" ;;
  fresh-capture-check) fresh_capture_check "$@" ;;
  once) run_once "$@" ;;
  loop) loop_forever "$@" ;;
  port-forward) port_forward ;;
  status) status ;;
  clean) clean ;;
  -h|--help|help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
