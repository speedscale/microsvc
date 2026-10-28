#!/usr/bin/env bash
# Shared proxymock replay harness for any backend service.
#
# A service's integration tests live as recorded traffic (a committed golden snapshot), not
# as code. This harness starts the real service behind `proxymock mock` -- which serves the
# service's downstream dependencies from the golden -- then replays the recorded inbound
# requests at it and asserts four things:
#   1. behavioral: the service routes each request and reproduces the recorded STATUS code
#      (proxymock replay --ignore-body-changes; bodies come from mocks and carry volatile data)
#   2. structural + coverage: each observed response conforms to the SCHEMA derived from the
#      golden responses, AND every golden operation was exercised -- missing operations are
#      reported and fail the run (scripts/proxymock/schema_validate.py --require-coverage)
#   3. properties: replayed response VALUES satisfy agreed business invariants, if the service
#      ships scripts/proxymock/services/<service>.invariants.json (property_validate.py)
#   4. snapshot consistency: the golden is a normalized, stable fixed point -- re-preparing it
#      changes nothing (prepare_golden.py --check)
# The run fails if any gate fails. No real dependencies, DB, Redis, or mesh are needed.
#
# Per-service specifics live in scripts/proxymock/services/<service>.env; optional business
# invariants in scripts/proxymock/services/<service>.invariants.json.
#
# Usage:   scripts/proxymock/replay-service.sh <service>
# Example: scripts/proxymock/replay-service.sh api-gateway
# Env:     PROXYMOCK_REPLAY_FAIL_IF            override the replay pass/fail condition
#          PROXYMOCK_STRICT_FIELD_COVERAGE=1   also fail on missing field-level coverage

set -euo pipefail

SERVICE="${1:-}"
if [ -z "$SERVICE" ]; then
  echo "usage: $0 <service>   (config: scripts/proxymock/services/<service>.env)" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"            # scripts/proxymock
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${SCRIPT_DIR}/services/${SERVICE}.env"

if [ ! -f "$CONFIG" ]; then
  echo "error: no config for service '$SERVICE' at $CONFIG" >&2
  exit 2
fi

export PATH="${HOME}/.speedscale:${PATH}"

# Public test key (not a real credential). The golden's tokens are committed REDACTED; the
# service's blueprint re-signs them with this key at replay time, and the app is started with
# it (service config: JWT_SECRET=${PROXYMOCK_JWT_SECRET}) so it accepts the refreshed tokens.
export PROXYMOCK_JWT_SECRET="proxymock-golden-test-secret-key-change-this-32bytes-min-0987654321"

# shellcheck source=/dev/null
source "$CONFIG"

SERVICE_DIR="${PROJECT_ROOT}/${SERVICE_DIR_REL}"
GOLD="${SERVICE_DIR}/proxymock/recorded-golden"

if ! command -v proxymock >/dev/null 2>&1; then
  echo "error: proxymock not found. Install with:"
  echo "  curl -Lfs https://downloads.speedscale.com/proxymock/install-proxymock | sh"
  exit 1
fi

# proxymock mock/replay require a one-time init; skip gracefully if not set up (fork PRs,
# contributors without Speedscale) so the hook/CI stays non-blocking there.
PM_VER_OUT=$(proxymock version 2>&1) || true
if echo "$PM_VER_OUT" | grep -Fq "not initialized"; then
  if [ -z "${PROXYMOCK_API_KEY:-}" ]; then
    echo "Skipping $SERVICE replay: proxymock not initialized and no PROXYMOCK_API_KEY."
    exit 0
  fi
  proxymock init -y --app-url app.speedscale.com --api-key "$PROXYMOCK_API_KEY"
fi

if [ ! -d "$GOLD/localhost" ]; then
  echo "error: golden snapshot not found at $GOLD" >&2
  echo "Build it per the proxymock-service-tests skill (pull snapshot + prepare_golden.py)." >&2
  exit 1
fi

cd "$SERVICE_DIR"

# Build the app artifact if the jar is missing.
JAR=$(ls -1 $JAR_GLOB 2>/dev/null | head -1 || true)
if [ -z "$JAR" ]; then
  echo "Building $SERVICE..."
  eval "$BUILD_CMD"
  JAR=$(ls -1 $JAR_GLOB | head -1)
fi
echo "Using artifact: $JAR"

if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 "$APP_PORT" 2>/dev/null; then
  echo "error: port $APP_PORT is in use; stop whatever listens there and retry." >&2
  exit 1
fi

RESULTS_DIR="${SERVICE_DIR}/proxymock/results/replay-$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$RESULTS_DIR"

# proxymock mock serves ONLY the downstream dependency dirs; the inbound localhost set is
# the replay TEST SET, not a mock. Assemble a mock-only input dir under results/.
MOCK_DIR="${RESULTS_DIR}/downstream-mocks"
mkdir -p "$MOCK_DIR"
for d in "${DOWNSTREAM_DIRS[@]}"; do
  [ -d "$GOLD/$d" ] && cp -R "$GOLD/$d" "$MOCK_DIR/"
done

# The golden stores auth tokens REDACTED (no usable credential is committed); they are
# refreshed at replay time by the service's proxymock blueprint. proxymock replay only
# discovers blueprints next to its --in dir (<in>/blueprints or <parent>/blueprints), and the
# service's proxymock/ dir holds only recorded data, so assemble a replay workspace under
# results/: a copy of the inbound set plus the blueprint, with its key placeholder rendered
# from the same test key the app is started with (JWT_SECRET=${PROXYMOCK_JWT_SECRET}).
REPLAY_WS="${RESULTS_DIR}/replay-workspace"
mkdir -p "$REPLAY_WS"
cp -R "$GOLD/localhost" "$REPLAY_WS/localhost"
BLUEPRINT="${SCRIPT_DIR}/services/${SERVICE}.blueprint.json"
REQUIRE_BLUEPRINT=()
if [ -f "$BLUEPRINT" ]; then
  mkdir -p "$REPLAY_WS/blueprints"
  BLUEPRINT_NAME=$(python3 - "$BLUEPRINT" "$REPLAY_WS/blueprints/$(basename "$BLUEPRINT")" <<'PY'
import json, os, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f:
    text = f.read()
# Render as a JSON string value so any character in the key stays valid JSON.
key = json.dumps(os.environ["PROXYMOCK_JWT_SECRET"])[1:-1]
with open(dst, "w", encoding="utf-8") as f:
    f.write(text.replace("__PROXYMOCK_JWT_SECRET__", key))
print(json.loads(text)["name"])
PY
  )
  # Fail the replay if the token-refresh blueprint is not loaded or none of its chains ran,
  # rather than silently replaying redacted tokens into a wall of 401s.
  REQUIRE_BLUEPRINT=(--require-blueprint "$BLUEPRINT_NAME")
  echo "Token refresh blueprint: $BLUEPRINT_NAME"
else
  echo "No ${SERVICE}.blueprint.json; replaying recorded tokens as-is."
fi

pkill -f "proxymock mock" 2>/dev/null || true
pkill -f "$JAR" 2>/dev/null || true

MOCK_PID=""
cleanup() {
  [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null || true
  pkill -f "proxymock mock" 2>/dev/null || true
  pkill -f "$JAR" 2>/dev/null || true
}
trap cleanup EXIT

# Start the app behind proxymock mock. proxymock mock is a FORWARD PROXY on 127.0.0.1:4140
# that matches the app's outbound calls by their ORIGINAL downstream host and returns the
# recorded mock. The app keeps the recorded downstream hostnames as its service URLs and
# routes its http client through the proxy (see <service>.env APP_ENV/APP_FLAGS).
echo "Starting proxymock mock + $SERVICE..."
env "${APP_ENV[@]}" \
proxymock mock \
  --in "$MOCK_DIR" \
  --out "${RESULTS_DIR}/mock-observed" \
  --no-passthrough \
  --log-to "${RESULTS_DIR}/proxymock-mock.log" \
  --app-log-to "${RESULTS_DIR}/app.log" \
  -- java "${APP_FLAGS[@]}" -jar "$JAR" > "${RESULTS_DIR}/startup.log" 2>&1 &
MOCK_PID=$!

# Wait for the app to answer health on one of HEALTH_PATHS.
READY=false
for _ in $(seq 1 60); do
  if ! kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "proxymock mock / $SERVICE exited early. Logs:"
    tail -40 "${RESULTS_DIR}/app.log" 2>/dev/null || true
    tail -40 "${RESULTS_DIR}/proxymock-mock.log" 2>/dev/null || true
    exit 1
  fi
  for path in "${HEALTH_PATHS[@]}"; do
    code=$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:${APP_PORT}${path}" 2>/dev/null || echo 000)
    if [ "$code" = "200" ]; then READY=true; echo "$SERVICE healthy at ${path}"; break 2; fi
  done
  sleep 1
done
if [ "$READY" != true ]; then
  echo "$SERVICE failed to become ready. App log:"
  tail -60 "${RESULTS_DIR}/app.log" 2>/dev/null || true
  exit 1
fi

# --- Gate 1: behavioral replay (routing + status) ---------------------------------------
REPLAY_FAIL_IF="${PROXYMOCK_REPLAY_FAIL_IF:-requests.result-match-pct != 100}"
echo "Replaying inbound golden traffic against $SERVICE..."
set +e
proxymock replay \
  --in "$REPLAY_WS/localhost" \
  --test-against "127.0.0.1:${APP_PORT}" \
  --rewrite-host \
  --ignore-body-changes \
  --out "${RESULTS_DIR}/replayed" \
  --log-to "${RESULTS_DIR}/replay.log" \
  --fail-if "$REPLAY_FAIL_IF" \
  ${REQUIRE_BLUEPRINT[@]+"${REQUIRE_BLUEPRINT[@]}"}
REPLAY_RC=$?
set -e

echo ""
echo "=== Replay verdict ==="
[ -f "${RESULTS_DIR}/replayed/replay-verdict.json" ] && cat "${RESULTS_DIR}/replayed/replay-verdict.json" && echo ""
if [ "$REPLAY_RC" -ne 0 ]; then
  echo ""
  echo "Replay FAILED (exit $REPLAY_RC). Recent app log:"; tail -30 "${RESULTS_DIR}/app.log" 2>/dev/null || true
  echo "Recent replay log:"; tail -30 "${RESULTS_DIR}/replay.log" 2>/dev/null || true
fi

# --- Gate 2: schema validation + contract coverage (response shape) ---------------------
# schema_validate derives a schema per (method, url-pattern, status) from the golden and
# checks every observed response against it. --require-coverage adds the contract-coverage
# gate: every golden OPERATION must be exercised by the replay (missing operations/statuses
# are reported and fail the run), so a vacuous replay cannot pass. Field-level coverage is
# reported for visibility; opt into failing on it with PROXYMOCK_STRICT_FIELD_COVERAGE=1.
STRICT_FIELD=""
[ "${PROXYMOCK_STRICT_FIELD_COVERAGE:-}" = "1" ] && STRICT_FIELD="--strict-field-coverage"
echo ""
echo "=== Schema validation + contract coverage ==="
set +e
python3 "${SCRIPT_DIR}/schema_validate.py" --golden "$GOLD" --replay "${RESULTS_DIR}/replayed" \
  --require-coverage $STRICT_FIELD
SCHEMA_RC=$?
set -e

# --- Gate 3: property / business-invariant validation (response VALUES) -----------------
# If the service ships an agreed invariants file, assert business properties (e.g. balance
# >= 0, amount > 0, status in the allowed set) over the replayed VALUES. Skipped (not
# failed) when no invariants file exists, so a service opts in by authoring one.
INVARIANTS="${SCRIPT_DIR}/services/${SERVICE}.invariants.json"
PROP_RC=0
if [ -f "$INVARIANTS" ]; then
  echo ""
  echo "=== Property / business-invariant validation ==="
  set +e
  python3 "${SCRIPT_DIR}/property_validate.py" --rules "$INVARIANTS" \
    --golden "$GOLD" --replay "${RESULTS_DIR}/replayed"
  PROP_RC=$?
  set -e
else
  echo ""
  echo "=== Property validation: skipped (no ${SERVICE}.invariants.json) ==="
fi

# --- Gate 4: snapshot consistency (repeatability + drift visibility) --------------------
# Confidence in this suite rests on the golden being a STABLE, normalized fixed point: two
# people running it get the same verdict, and nothing silently drifts between runs. Verify
# that by re-preparing the golden in --check mode -- it must change nothing. (Behavioral and
# shape drift in the service itself are already caught by gates 1-2; this guards the fixture.)
echo ""
echo "=== Snapshot consistency (golden is normalized + stable) ==="
set +e
python3 "${SCRIPT_DIR}/prepare_golden.py" --golden "$GOLD" --check
SNAP_RC=$?
set -e

echo ""
echo "Reports and observed traffic: ${RESULTS_DIR} (git-ignored)"

if [ "$REPLAY_RC" -ne 0 ] || [ "$SCHEMA_RC" -ne 0 ] || [ "$PROP_RC" -ne 0 ] || [ "$SNAP_RC" -ne 0 ]; then
  exit 1
fi
exit 0
