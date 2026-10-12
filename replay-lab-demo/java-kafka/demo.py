#!/usr/bin/env python3
import argparse
import base64
import hashlib
import hmac
import html
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.request
import uuid
import xml.etree.ElementTree as ET
from http.server import BaseHTTPRequestHandler, HTTPServer
from checks import evaluate

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE_REQUEST = ROOT / "replay-lab-demo/prod-suite/localhost/2026-07-06_17-24-06.769462Z.md"
COMPOSE = ["docker", "compose", "-p", "java-kafka-quality-loop", "-f", str(HERE / "compose.yml")]
PM = os.environ.get("PROXYMOCK_BIN", str(Path.home() / ".speedscale/proxymock"))
PM_CONFIG = os.environ.get("SPEEDSCALE_CONFIG", str(Path.home() / ".speedscale/dev.yaml"))
SECRET = "banking-app-super-secret-key-change-this-in-production-256-bit"
PROCESSES = []
HANDLES = []


def token():
    def encode(value):
        return base64.urlsafe_b64encode(value).decode().rstrip("=")
    data = encode(b'{"alg":"HS256","typ":"JWT"}') + "." + encode(
        json.dumps({"sub": "replay-lab-demo", "userId": "1", "roles": "USER", "exp": 1893456000}).encode())
    return data + "." + encode(hmac.new(SECRET.encode(), data.encode(), hashlib.sha256).digest())


def command(args, **kwargs):
    return subprocess.run(args, cwd=ROOT, timeout=60, check=True, capture_output=True, text=True, **kwargs).stdout


def pm(*args):
    return [PM, "--config", PM_CONFIG, "--app-url", "https://dev.speedscale.com", *map(str, args)]


def start(args, log, env=None):
    handle = open(log, "w")
    HANDLES.append(handle)
    process = subprocess.Popen(args, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT, env=env)
    PROCESSES.append(process)
    return process


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def cleanup():
    for process in reversed(PROCESSES):
        stop(process)
    for handle in HANDLES:
        handle.close()


def request(port, route, auth=False):
    headers = {"Authorization": "Bearer " + token()} if auth else {}
    with urllib.request.urlopen(urllib.request.Request(
            f"http://127.0.0.1:{port}{route}", headers=headers), timeout=3) as response:
        return json.load(response)


def wait_for(label, condition, timeout=90):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        dead = [p.pid for p in PROCESSES if p.poll() is not None]
        if dead:
            raise RuntimeError(f"{label}: child processes exited: {dead}")
        try:
            if condition():
                return
        except (OSError, ValueError):
            pass
        time.sleep(0.5)
    raise TimeoutError(label)


def port_free(port):
    with socket.socket() as probe:
        if probe.connect_ex(("127.0.0.1", port)) == 0:
            raise RuntimeError(f"Port {port} is already in use; refusing to replace its owner")


def port_open(port):
    with socket.socket() as probe:
        return probe.connect_ex(("127.0.0.1", port)) == 0


def frozen_hash():
    files = [HERE / "checks.py", HERE / "expectations.json", HERE / "test_checks.py",
             *sorted((HERE / "traffic").rglob("*.md")),
             *sorted((HERE / "output/partner-recording").rglob("*.json")),
             *sorted((HERE / "consumer/src/test").rglob("*.java"))]
    digest = hashlib.sha256()
    for path in files:
        digest.update(str(path.relative_to(HERE)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def resolve_jar(module):
    pom = ET.parse(module / "pom.xml").getroot()
    ns = {"m": "http://maven.apache.org/POM/4.0.0"}
    artifact = pom.findtext("m:artifactId", namespaces=ns)
    version = pom.findtext("m:version", namespaces=ns) or pom.findtext("m:parent/m:version", namespaces=ns)
    final_name = pom.findtext("m:build/m:finalName", namespaces=ns) or f"{artifact}-{version}"
    if not artifact or not version or "${" in final_name or Path(final_name).name != final_name:
        raise ValueError("Unsupported Maven artifact name; package with an explicit finalName")
    jar = module / "target" / (final_name + ".jar")
    if not jar.is_file():
        raise FileNotFoundError(f"Current artifact is missing: {jar}; run Maven package")
    return jar


class Fixture(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/assessment/70668":
            self.send_error(404)
            return
        body = b'{"decision":"APPROVED"}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def capture():
    out = HERE / "output"
    corpus = out / "partner-recording"
    if corpus.exists():
        raise RuntimeError("Partner recording already exists; reuse it or select a fresh worktree")
    out.mkdir(exist_ok=True)
    for port in [18098, 18099, 14140, 14143, 14144]:
        port_free(port)
    fixture = start([sys.executable, str(__file__), "fixture"], out / "partner-fixture.log")
    wait_for("partner fixture", lambda: request(18098, "/assessment/70668")["decision"] == "APPROVED")
    recorder = start(pm("record", "--app-port", "18088", "--proxy-in-port", "14143",
                        "--proxy-out-port", "14140", "--health-port", "14144",
                        "--map", "18099=http://localhost:18098", "--out", corpus, "--out-format", "json"),
                     out / "partner-record.log")
    wait_for("record proxy", lambda: port_open(18099))
    request(18099, "/assessment/70668")
    wait_for("recorded partner response", lambda: any(corpus.rglob("*.json")))
    stop(recorder)
    stop(fixture)
    print("Captured one synthetic approved partner response; live fixture is stopped.", flush=True)


def run(phase):
    request_path = HERE / "traffic/localhost/deposit.md"
    if request_path.exists() and request_path.read_bytes() != SOURCE_REQUEST.read_bytes():
        raise RuntimeError("Runtime request differs from the existing approved fixture")
    request_path.parent.mkdir(parents=True, exist_ok=True)
    if not request_path.exists():
        request_path.write_bytes(SOURCE_REQUEST.read_bytes())
    expected = json.loads((HERE / "expectations.json").read_text())
    corpus = HERE / "output/partner-recording"
    if not corpus.exists():
        raise RuntimeError("Run capture first")
    out = HERE / "output" / phase
    out.mkdir(parents=True, exist_ok=False)
    for port in [18087, 18088, 18099, 14141, 14145]:
        port_free(port)
    topic = "quality-loop-" + phase + "-" + uuid.uuid4().hex[:8]
    group = topic + "-ledger"
    command(COMPOSE + ["exec", "-T", "broker", "/opt/kafka/bin/kafka-topics.sh",
                      "--bootstrap-server", "localhost:19092", "--create", "--topic", topic,
                      "--partitions", "1", "--replication-factor", "1"])
    mock = start(pm("mock", "--in", ROOT / "replay-lab-demo/mocks", "--in", corpus,
                    "--proxy-out-port", "14141", "--health-port", "14145",
                    "--no-passthrough", "--no-out"), out / "mock.log")
    wait_for("mock proxy", lambda: urllib.request.urlopen("http://127.0.0.1:14145", timeout=2).status == 200)
    env = dict(os.environ, KAFKA_BROKERS="localhost:19092", KAFKA_TOPIC=topic, KAFKA_GROUP=group,
               OTEL_SDK_DISABLED="true", JWT_SECRET=SECRET, SERVER_PORT="18088",
               PARTNER_API_URL="http://localhost:18098")
    consumer_jar = resolve_jar(HERE / "consumer")
    consumer_hash = hashlib.sha256(consumer_jar.read_bytes()).hexdigest()
    start(["java", "-Duser.timezone=UTC", "-Dhttp.proxyHost=localhost", "-Dhttp.proxyPort=14141", "-Dhttp.nonProxyHosts=",
           "-jar", str(consumer_jar)], out / "consumer.log", env)
    wait_for("consumer assignment", lambda: request(18088, "/ready", True)["assigned"])
    producer_jar = resolve_jar(ROOT / "backend/transactions-service")
    env.update(SERVER_PORT="18087", DB_HOST="localhost", DB_PORT="15439", DB_NAME="banking_app",
               ACCOUNTS_SERVICE_URL="http://localhost:8082", FRAUD_SERVICE_HOST="localhost",
               FRAUD_SERVICE_PORT="19991", DEMO_MEMO_BUG_ENABLED="false",
               DEMO_CONTRACT_REFACTOR_ENABLED="false")
    start(["java", "-Duser.timezone=UTC", "-Dhttp.proxyHost=localhost", "-Dhttp.proxyPort=14141",
           "-Dhttps.proxyHost=localhost", "-Dhttps.proxyPort=14141", "-Dhttp.nonProxyHosts=",
           "-jar", str(producer_jar)], out / "producer.log", env)
    wait_for("producer health", lambda: request(18087, "/actuator/health")["status"] == "UP")
    wait_for("producer authentication", lambda: isinstance(request(18087, "/api/transactions", True), list), 10)
    command(COMPOSE + ["exec", "-T", "postgres", "psql", "-U", "postgres", "-d", "banking_app",
                      "-c", "TRUNCATE transactions_service.transactions RESTART IDENTITY"])
    replay_result = subprocess.run(pm("replay", "--in", HERE / "traffic", "--test-against",
                                     "http://localhost:18087", "--ignore-body-changes",
                                     "--fail-if", "requests.result-match-pct != 100",
                                     "--out", out / "proxymock", "--out-format", "json", "--timeout", "90s"),
                                   cwd=ROOT, capture_output=True, text=True, timeout=120)
    (out / "replay.log").write_text(replay_result.stdout + replay_result.stderr)
    wait_for("ledger delivery", lambda: len(request(18088, "/ledger", True)["entries"]) >= expected["requestCount"], 30)
    http = request(18087, "/api/transactions", True)
    ledger = request(18088, "/ledger", True)
    read = subprocess.run(COMPOSE + ["exec", "-T", "broker", "/opt/kafka/bin/kafka-console-consumer.sh",
                          "--bootstrap-server", "localhost:19092", "--topic", topic, "--from-beginning",
                          "--timeout-ms", "10000", "--property", "print.key=true"],
                          capture_output=True, text=True, timeout=30)
    (out / "broker-records.txt").write_text(read.stdout)
    (out / "broker-consumer.log").write_text(read.stderr)
    records = []
    for line in read.stdout.splitlines():
        key, value = line.split("\t", 1)
        records.append({"key": key, "event": json.loads(value)})
    commits = []
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        description = command(COMPOSE + ["exec", "-T", "broker", "/opt/kafka/bin/kafka-consumer-groups.sh",
                                        "--bootstrap-server", "localhost:19092", "--group", group, "--describe"])
        commits = []
        for line in description.splitlines():
            fields = line.split()
            if len(fields) >= 6 and fields[0] == group and fields[1] == topic:
                commits.append({"partition": int(fields[2]), "current": int(fields[3]),
                                "end": int(fields[4]), "lag": int(fields[5])})
        if commits and all(c["lag"] == 0 for c in commits):
            break
        time.sleep(0.5)
    verdict = json.loads((out / "proxymock/replay-verdict.json").read_text())
    gate = evaluate(expected, http, ledger, records, commits,
                    {"success": replay_result.returncode == 0, "statuses": [p["observedStatus"] for p in verdict["pairs"]]})
    gate.update(phase=phase, topic=topic, group=group, assertionsSha256=frozen_hash(),
                consumerJarSha256=consumer_hash, producerJarSha256=hashlib.sha256(producer_jar.read_bytes()).hexdigest(),
                sourceRevision=command(["git", "rev-parse", "HEAD"]).strip(),
                sourceDiff=command(["git", "diff", "--", "replay-lab-demo/java-kafka/consumer"]).strip(),
                httpReplayPassed=replay_result.returncode == 0, http=http,
                ledger=ledger, records=records, commits=commits, replayVerdict=verdict)
    (out / "gate.json").write_text(json.dumps(gate, indent=2) + "\n")
    report = subprocess.run(pm("report", "--in", out / "proxymock", "--format", "html",
                               "--out", out / "proxymock-report.html"),
                            cwd=ROOT, capture_output=True, text=True, timeout=30)
    if report.returncode != 0:
        raise RuntimeError("proxymock HTML report generation failed: " + report.stderr)
    badge = "PASS" if gate["passed"] else "FAIL"
    details = "<br>".join(html.escape(f) for f in gate["failures"]) or "All configured checks passed."
    (out / "report.html").write_text(
        '<!doctype html><html><head><meta charset="utf-8"><title>Java Kafka validation</title>'
        '<style>body{font:18px system-ui;max-width:900px;margin:40px auto;padding:20px}'
        'pre{white-space:pre-wrap;font-size:14px}a{color:#006b62}</style></head><body>'
        f'<h1>{badge}: Java Kafka validation</h1><p>{details}</p>'
        '<p>HTTP replay and explicit Kafka/ledger checks are separate. This is a local plaintext demo, not a native Kafka output assertion.</p>'
        '<p><a href="proxymock-report.html">proxymock HTTP report</a> · <a href="gate.json">Full Kafka evidence</a></p>'
        f'<pre>{html.escape(json.dumps(gate, indent=2))}</pre></body></html>')
    print(json.dumps({k: gate[k] for k in ["phase", "passed", "httpReplayPassed", "failures", "assertionsSha256"]}), flush=True)
    return 0 if gate["passed"] else 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["fixture", "capture", "run"])
    parser.add_argument("phase", nargs="?")
    args = parser.parse_args()
    try:
        if args.action == "fixture":
            HTTPServer(("127.0.0.1", 18098), Fixture).serve_forever()
        elif args.action == "capture":
            capture()
        else:
            if not args.phase or not args.phase.replace("-", "").isalnum():
                parser.error("run requires a simple phase name")
            return run(args.phase)
    except Exception as error:
        print(f"SETUP FAILED: {error}", file=sys.stderr)
        return 2
    finally:
        cleanup()
    return 0


if __name__ == "__main__":
    sys.exit(main())
