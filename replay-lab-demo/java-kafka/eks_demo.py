#!/usr/bin/env python3
import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request
from demo import HERE, ROOT, token, frozen_hash, resolve_jar, prepare_request
from checks import evaluate

CONTEXT = "arn:aws:eks:us-east-1:763455676074:cluster/eks-quality-factory"
NS = "banking-app"
TOPIC = "ihg-quality-transactions"
GROUP = "ihg-quality-ledger"
KAFKA_LOG_DIR = "/tmp/kafka-logs"
IMAGE = "763455676074.dkr.ecr.us-east-1.amazonaws.com/quality-factory/java-ledger"
OUT = HERE / "output/eks"
CLI = HERE / "output/tools/proxymock-eks"
K = ["kubectl", "--context", CONTEXT, "-n", NS]
PM = [str(CLI), "--config", str(Path.home() / ".speedscale/dev.yaml"), "--app-url", "https://dev.speedscale.com"]


def call(args, timeout=60, check=True, **kwargs):
    return subprocess.run(args, cwd=ROOT, timeout=timeout, capture_output=True,
                          text=True, check=check, **kwargs)


def apply(obj):
    call(K + ["apply", "-f", "-"], input=json.dumps(obj))


def deploy(name, image, env, port=None, volumes=None, mounts=None, command=None, args=None):
    container = {"name": "app", "image": image, "env": [{"name": k, "value": str(v)} for k, v in env.items()],
                 "resources": {"requests": {"cpu": "100m", "memory": "256Mi"},
                               "limits": {"cpu": "1", "memory": "1Gi"}}}
    if port:
        container["ports"] = [{"containerPort": port}]
        container["readinessProbe"] = {"tcpSocket": {"port": port}, "initialDelaySeconds": 5, "periodSeconds": 3}
    if mounts:
        container["volumeMounts"] = mounts
    if command:
        container["command"] = command
    if args:
        container["args"] = args
    spec = {"containers": [container], "terminationGracePeriodSeconds": 10}
    if volumes:
        spec["volumes"] = volumes
    apply({"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": name},
           "spec": {"replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"app": name}},
                    "template": {"metadata": {"labels": {"app": name, "quality-loop": "ihg"}}, "spec": spec}}})
    if port:
        apply({"apiVersion": "v1", "kind": "Service", "metadata": {"name": name},
               "spec": {"selector": {"app": name}, "ports": [{"port": port, "targetPort": port}]}})


def ready(name):
    print("Waiting for " + name, flush=True)
    call(K + ["rollout", "status", "deployment/" + name, "--timeout=240s"], timeout=250)


def admin(tool, *args, check=True):
    return call(K + ["exec", "deployment/ihg-kafka", "--", "/opt/kafka/bin/" + tool,
                     "--bootstrap-server", "localhost:9092", *args], check=check)


def topic():
    admin("kafka-topics.sh", "--create", "--if-not-exists", "--topic", TOPIC, "--partitions", "1",
          "--replication-factor", "1", "--config", "retention.ms=-1")


def setup():
    identity = json.loads(call(["aws", "--profile", "demo", "sts", "get-caller-identity"]).stdout)
    if identity["Account"] != "763455676074":
        raise RuntimeError("Wrong AWS demo account")
    OUT.mkdir(parents=True, exist_ok=True)
    secret = call(K + ["create", "secret", "generic", "ihg-proxymock-config", "--from-file=config.yaml="
        + str(Path.home() / ".speedscale/dev.yaml"), "--dry-run=client", "-o", "json"]).stdout
    call(K + ["apply", "-f", "-"], input=secret)
    apply({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "ihg-db-init"},
           "data": {"01-create-schemas.sql": (ROOT / "database/init/01-create-schemas.sql").read_text()}})
    recordings = sorted((ROOT / "replay-lab-demo/mocks").rglob("*.md")) + sorted((HERE / "output/partner-recording").rglob("*.json"))
    apply({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "ihg-api-recordings"},
           "data": {str(i) + p.suffix: p.read_text() for i, p in enumerate(recordings)}})
    deploy("ihg-kafka", "apache/kafka:4.0.2", {
        "KAFKA_NODE_ID": "1", "KAFKA_PROCESS_ROLES": "broker,controller",
        "KAFKA_LISTENERS": "PLAINTEXT://:9092,CONTROLLER://:9093",
        "KAFKA_ADVERTISED_LISTENERS": "PLAINTEXT://ihg-kafka.banking-app.svc:9092",
        "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP": "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT",
        "KAFKA_CONTROLLER_LISTENER_NAMES": "CONTROLLER", "KAFKA_CONTROLLER_QUORUM_VOTERS": "1@localhost:9093",
        "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR": "1", "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR": "1",
        "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR": "1", "KAFKA_AUTO_CREATE_TOPICS_ENABLE": "false",
        "KAFKA_LOG_DIRS": KAFKA_LOG_DIR, "KAFKA_HEAP_OPTS": "-Xms256m -Xmx512m"}, 9092)
    deploy("ihg-postgres", "postgres:16-alpine", {"POSTGRES_DB": "banking_app", "POSTGRES_USER": "postgres",
        "POSTGRES_PASSWORD": "quality-loop-local-only"}, 5432,
        [{"name": "init", "configMap": {"name": "ihg-db-init"}}],
        [{"name": "init", "mountPath": "/docker-entrypoint-initdb.d"}])
    deploy("ihg-mock", IMAGE + ":baseline-8cff21d", {}, 14141,
        [{"name": "recordings", "configMap": {"name": "ihg-api-recordings"}},
         {"name": "config", "secret": {"secretName": "ihg-proxymock-config"}}],
        [{"name": "recordings", "mountPath": "/recordings"}, {"name": "config", "mountPath": "/config", "readOnly": True}],
        ["/bin/sh", "-c"], ["cp /config/config.yaml /work/config.yaml && exec /usr/local/bin/proxymock --config /work/config.yaml --app-url https://dev.speedscale.com mock --in /recordings --proxy-out-port 14141 --health-port 14145 --no-passthrough --no-out"])
    for name in ["ihg-kafka", "ihg-postgres", "ihg-mock"]:
        ready(name)
    topic()
    common = {"KAFKA_BROKERS": "ihg-kafka.banking-app.svc:9092", "KAFKA_TOPIC": TOPIC,
              "OTEL_SDK_DISABLED": "true", "JAVA_TOOL_OPTIONS": "-Xmx512m -Duser.timezone=UTC -Dhttp.proxyHost=ihg-mock -Dhttp.proxyPort=14141 -Dhttps.proxyHost=ihg-mock -Dhttps.proxyPort=14141 -Dhttp.nonProxyHosts="}
    deploy("ihg-ledger", IMAGE + ":baseline-8cff21d", dict(common, KAFKA_GROUP=GROUP, SERVER_PORT="8080",
        SERVER_ADDRESS="0.0.0.0", PARTNER_API_URL="http://localhost:18098"), 8080)
    deploy("ihg-producer", IMAGE + ":producer-8cff21d", dict(common, SERVER_PORT="8080", DB_HOST="ihg-postgres",
        DB_PORT="5432", DB_NAME="banking_app", ACCOUNTS_SERVICE_URL="http://localhost:8082",
        FRAUD_SERVICE_HOST="localhost", FRAUD_SERVICE_PORT="19991", DEMO_MEMO_BUG_ENABLED="false",
        DEMO_CONTRACT_REFACTOR_ENABLED="false", SPRING_KAFKA_PRODUCER_COMPRESSION_TYPE="zstd"), 8080)
    for name in ["ihg-ledger", "ihg-producer"]:
        ready(name)
        print(call(PM + ["cluster", "capture", "inject", "--kube-context", CONTEXT, "-n", NS, "--workload", name]).stdout)
    print("Isolated Java producer, ledger, Kafka, Postgres and recorded API mocks ready.", flush=True)


def http(port, route):
    req = urllib.request.Request(f"http://127.0.0.1:{port}{route}", headers={"Authorization": "Bearer " + token()})
    with urllib.request.urlopen(req, timeout=5) as response:
        return json.load(response)


def forward(name, port):
    log = open(OUT / (name + "-forward.log"), "a")
    p = subprocess.Popen(K + ["port-forward", "service/" + name, str(port) + ":8080", "--address", "127.0.0.1"],
                         stdout=log, stderr=log)
    time.sleep(2)
    if p.poll() is not None:
        raise RuntimeError("Port-forward failed; inspect its log")
    return p, log


def reset(image):
    call(K + ["scale", "deployment/ihg-ledger", "--replicas=0"])
    call(K + ["wait", "--for=delete", "pod", "-l", "app=ihg-ledger", "--timeout=90s"], timeout=100)
    call(K + ["rollout", "restart", "deployment/ihg-kafka"])
    ready("ihg-kafka")
    topic()
    call(K + ["set", "image", "deployment/ihg-ledger", "app=" + image])
    call(K + ["scale", "deployment/ihg-ledger", "--replicas=1"])
    ready("ihg-ledger")


def broker_evidence(out):
    read = admin("kafka-console-consumer.sh", "--topic", TOPIC, "--from-beginning", "--timeout-ms", "10000",
        "--property", "print.key=true", "--property", "print.timestamp=true", check=False)
    (out / "broker-records.txt").write_text(read.stdout)
    records = []
    for line in read.stdout.splitlines():
        timestamp, key, value = line.split("\t", 2)
        records.append({"timestamp": timestamp, "key": key, "event": json.loads(value)})
    description = admin("kafka-consumer-groups.sh", "--describe", "--group", GROUP).stdout
    (out / "offsets.txt").write_text(description)
    commits = []
    for line in description.splitlines():
        fields = line.split()
        if len(fields) >= 6 and fields[0] == GROUP and fields[1] == TOPIC:
            commits.append({"partition": int(fields[2]), "current": int(fields[3]) if fields[3] != "-" else None,
                            "end": int(fields[4]) if fields[4] != "-" else None,
                            "lag": int(fields[5]) if fields[5] != "-" else None})
    dump = call(K + ["exec", "deployment/ihg-kafka", "--", "sh", "-c",
        f'for f in {KAFKA_LOG_DIR}/{TOPIC}-0/*.log; do /opt/kafka/bin/kafka-dump-log.sh --files "$f"; done']).stdout
    (out / "batch-dump.txt").write_text(dump)
    codecs = [line.split("compresscodec: ", 1)[1].split()[0] for line in dump.splitlines() if "baseOffset:" in line and "compresscodec: " in line]
    return records, commits, codecs


def seed():
    out = OUT / "seed"
    out.mkdir(exist_ok=False)
    forwards = [forward("ihg-ledger", 18188), forward("ihg-producer", 18187)]
    try:
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            if http(18188, "/ready")["assigned"]:
                break
            time.sleep(1)
        request_dir = prepare_request(out / "request")
        result = call(PM + ["replay", "--in", str(request_dir), "--test-against", "http://localhost:18187",
            "--ignore-body-changes", "--fail-if", "requests.result-match-pct != 100", "--out", str(out / "http-replay"),
            "--out-format", "json", "--timeout", "90s"], timeout=120, check=False)
        (out / "replay.log").write_text(result.stdout + result.stderr)
        deadline = time.monotonic() + 45
        ledger = http(18188, "/ledger")
        while not ledger["entries"] and time.monotonic() < deadline:
            time.sleep(1)
            ledger = http(18188, "/ledger")
        rows = http(18187, "/api/transactions")
        records, commits, codecs = broker_evidence(out)
        verdict = json.loads((out / "http-replay/replay-verdict.json").read_text())
        gate = evaluate(json.loads((HERE / "expectations.json").read_text()), rows, ledger, records, commits,
            {"success": result.returncode == 0, "statuses": [p["observedStatus"] for p in verdict["pairs"]]})
        gate.update(http=rows, ledger=ledger, records=records, codecs=codecs, commits=commits)
        if codecs != ["zstd"]:
            gate["failures"].append("Seed event was not one zstd batch")
            gate["passed"] = False
        (out / "gate.json").write_text(json.dumps(gate, indent=2) + "\n")
        print(json.dumps(gate, indent=2), flush=True)
        return 0 if gate["passed"] else 1
    finally:
        for process, handle in forwards:
            process.terminate()
            process.wait(timeout=10)
            handle.close()


def run(phase, image):
    out = OUT / phase
    out.mkdir(exist_ok=False)
    config_file = OUT / "ihg-kafka-local.json"
    if not config_file.exists():
        dlp_path = os.environ.get("DLP_CONFIG_FILE")
        if not dlp_path:
            raise RuntimeError("DLP_CONFIG_FILE must reference the demo's existing DLP rules")
        config = json.loads(call(PM + ["test-config", "compile", "regression"]).stdout)
        config["id"] = "ihg-kafka-local"
        config["protected"] = False
        config["generator"]["dlpConfig"] = json.loads(Path(dlp_path).read_text())
        config["generator"]["dlpConfigId"] = config["generator"]["dlpConfig"]["id"]
        config_file.write_text(json.dumps(config, indent=2) + "\n")
    reset(image)
    p, log = forward("ihg-ledger", 18188)
    try:
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            if http(18188, "/ready")["assigned"]:
                break
            time.sleep(1)
        else:
            raise RuntimeError("Consumer was never assigned")
        result = call(PM + ["cluster", "replay", "start", "--kube-context", CONTEXT, "-n", NS,
            "--target", "kafka://ihg-kafka.banking-app.svc:9092", "--snapshot-source", "local",
            "--test-config", str(config_file),
            "--in", str(OUT / "recording"), "--tests-filter", f'(command IS "Fetch") AND (location IS "{TOPIC}")',
            "--wait"], timeout=600, check=False)
        (out / "replay.log").write_text(result.stdout + result.stderr)
        if result.returncode:
            (out / "setup-failure.json").write_text(json.dumps({"phase": phase, "nativeKafkaReplayPassed": False,
                "exit": result.returncode, "reason": "Native replay did not complete successfully"}, indent=2) + "\n")
            print("Native replay setup failed; inspect " + str(out / "replay.log"), flush=True)
            return 2
        deadline = time.monotonic() + 30
        ledger = http(18188, "/ledger")
        while not ledger["entries"] and time.monotonic() < deadline:
            time.sleep(1)
            ledger = http(18188, "/ledger")
        records, commits, codecs = broker_evidence(out)
        (out / "consumer.log").write_text(call(K + ["logs", "deployment/ihg-ledger"]).stdout)
        seed_gate = json.loads((OUT / "seed/gate.json").read_text())
        functional = evaluate(json.loads((HERE / "expectations.json").read_text()), seed_gate["http"], ledger,
            records, commits, {"success": seed_gate["passed"], "statuses": [201]})
        failures = functional["failures"]
        if result.returncode:
            failures.append("Native Kafka replay failed or did not complete")
        if len(ledger["entries"]) != 1:
            failures.append(f"Expected one consumed event, observed {len(ledger['entries'])}")
        for entry in ledger["entries"]:
            if entry["outcome"] != "COMPLETED":
                failures.append("Ledger outcome: expected COMPLETED, observed " + entry["outcome"])
            if entry["partnerDecision"] != "APPROVED":
                failures.append("Recorded assessment response was not APPROVED")
        if ledger["duplicates"] or ledger["rejected"]:
            failures.append("Unexpected duplicate or rejected input")
        if records != seed_gate["records"]:
            failures.append("Replayed keys, values or CreateTime differ from the recorded seed")
        if codecs != seed_gate["codecs"] or codecs != ["zstd"]:
            failures.append("Replayed batch did not preserve the recorded zstd codec")
        sha = hashlib.sha256()
        for file in sorted(p for p in (OUT / "recording").rglob("*") if p.suffix in {".md", ".json"}):
            sha.update(file.read_bytes())
        gate = {"phase": phase, "passed": not failures, "failures": failures, "image": image,
                "nativeKafkaReplayPassed": result.returncode == 0, "ledger": ledger,
                "records": records, "commits": commits, "codecs": codecs,
                "recordingSha256": sha.hexdigest(), "assertionsSha256": frozen_hash(),
                "eksHarnessSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "testConfigSha256": hashlib.sha256(config_file.read_bytes()).hexdigest(),
                "cliVersion": "v2.5.1179", "kafkaSecurity": "PLAINTEXT"}
        (out / "gate.json").write_text(json.dumps(gate, indent=2) + "\n")
        (out / "report.html").write_text('<!doctype html><meta charset="utf-8"><style>body{font:18px system-ui;max-width:900px;margin:40px auto}pre{white-space:pre-wrap}</style>'
            + '<h1>' + ("PASS" if gate["passed"] else "FAIL") + ': EKS Java Kafka validation</h1><p>'
            + html.escape("; ".join(failures) or "Recorded Kafka event reproduced and consumed correctly.")
            + '</p><p><a href="replay.log">Native replay</a> · <a href="gate.json">Checks</a> · <a href="broker-records.txt">Broker evidence</a></p><pre>'
            + html.escape(json.dumps(gate, indent=2)) + '</pre>')
        print(json.dumps(gate, indent=2), flush=True)
        return 0 if gate["passed"] else 1
    finally:
        p.terminate()
        p.wait(timeout=10)
        log.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["setup", "seed", "run"])
    parser.add_argument("phase", nargs="?")
    parser.add_argument("--image")
    options = parser.parse_args()
    if options.command == "setup":
        setup()
    elif options.command == "seed":
        raise SystemExit(seed())
    else:
        if not options.phase or not options.image:
            parser.error("run requires a new phase and --image")
        raise SystemExit(run(options.phase, options.image))
