# Java Kafka quality loop

Run the existing Java 17/Spring Boot transactions producer with a Spring Boot ledger consumer, a private plaintext Kafka broker and recorded HTTP dependency mocks. The gate checks the API response, produced record, consumed business outcome and committed offset. HTTP success alone cannot pass it.

The local recipe runs without EKS. The optional EKS runner deploys an isolated version of the same service pattern to the dedicated AWS demo cluster and replays recorded Kafka Fetch traffic with proxymock. Neither recipe implements a required SCM check, authenticates Kafka or proves brokerless consumer replay. The consumer's assessment API is a synthetic third-party fixture recorded once and then stopped. Existing payment API recordings contain authentication failures; they are mocked dependency behavior, not successful payment integrations. The existing fraud client fails open against an unavailable service and is outside this scenario's assertions.

## Start and validate

Use Java 17, Maven, Docker, Python 3 and proxymock. Run from this repository checkout. The default Speedscale configuration is the dev environment; set `SPEEDSCALE_CONFIG` if your dev config lives elsewhere. `PROXYMOCK_BIN` can select a separately pinned CLI without replacing your installed one.

```bash
docker compose -p java-kafka-quality-loop -f replay-lab-demo/java-kafka/compose.yml up -d
mvn -f replay-lab-demo/java-kafka/consumer/pom.xml verify
mvn -f backend/transactions-service/pom.xml -DskipTests package
python3 -m unittest discover -s replay-lab-demo/java-kafka -p 'test_*.py'
python3 replay-lab-demo/java-kafka/demo.py capture
python3 replay-lab-demo/java-kafka/demo.py run baseline
```

Capture records a successful assessment response through proxymock, then stops both the recorder and the real fixture. Subsequent runs use proxymock with passthrough disabled. Each phase creates a distinct topic and consumer group and resets only the dedicated demo database. Phase names must be new so evidence is never overwritten. Ports are checked before startup; the runner refuses occupied ports and terminates only children it started. Containers remain available until explicitly stopped.

Java tests enforce at least 80 percent line coverage. The Python tests verify that missing records, changed values, wrong consumer outcomes, duplicates and uncommitted offsets cannot pass.

## Fail then repair with Kiro

Start with a passing baseline and a clean consumer source. The fixture deliberately changes only the consumer's approved-event outcome to `SETTLED`; the agreed contract requires `COMPLETED`.

```bash
git apply --check replay-lab-demo/java-kafka/consumer-regression.patch
git apply replay-lab-demo/java-kafka/consumer-regression.patch
mvn -f replay-lab-demo/java-kafka/consumer/pom.xml -DskipTests package
python3 replay-lab-demo/java-kafka/demo.py run faulty
```

The faulty runtime must exit 1 while its proxymock HTTP replay passes. Exit 2 means a setup failure and is not the intended regression proof. Tests are deliberately skipped only to build the known faulty fixture; do not describe that candidate as passing the consumer unit tests.

Use Kiro CLI with the V3 engine (tested with CLI 2.30.0). The project-local `ledger-fix` agent uses `permissions.rules`: it allows writes only to Ledger.java and explicitly denies other writes, shell execution and MCP. Ask it to inspect `output/faulty/gate.json`, preserve the contract and repair the consumer. Do not allow it to change assertions, tests, recordings or expected values.

```bash
kiro-cli chat --agent-engine v3 --agent ledger-fix --no-interactive \
  "Read replay-lab-demo/java-kafka/output/faulty/gate.json and repair only replay-lab-demo/java-kafka/consumer/src/main/java/com/banking/demo/Ledger.java. Preserve all checks and expected values. Do not execute shell commands."
mvn -f replay-lab-demo/java-kafka/consumer/pom.xml verify
python3 replay-lab-demo/java-kafka/demo.py run repaired
```

Compare `assertionsSha256` in the baseline, faulty and repaired gate files. They must match. Check the source diff and the consumer JAR hash; a successful agent message is not fix evidence. The producer JAR must be unchanged. The repaired runtime must exit 0 with the same request and checks.

The original request fixture stays byte-for-byte unchanged. Each local run and EKS seed stages a phase-local copy with a fresh, one-hour synthetic JWT in the request Authorization header. The request body, other headers and recorded response remain unchanged. Frozen fingerprints cover the original corpus, not the rotating authentication header; request copies stay in ignored output directories. This avoids replaying the fixture's expired token after January 2030.

## Read the evidence

Open the phase's `report.html` for the combined gate. It links the native proxymock HTTP report and `gate.json` with the Kafka record, ledger entry, topic, group, commit, source revision and build hashes. The HTTP replay scores status codes; the separate gate checks configured HTTP business fields and Kafka behavior. IDs and timestamps are not compared to the older recording, and this one-request scenario is not a complete API contract or load test.

The evidence uses a real private broker. The native proxymock report does not claim to compare Kafka outputs; that comparison is implemented by the demo's explicit checks. A console-consumer timeout after the bounded record read is normal. Missing records or nonzero consumer lag still fail the gate.

SASL, TLS, multi-consumer rebalances, large partition counts, DLQ behavior and production rollout remain separate acceptance work. The ledger is bounded, in-memory demo state with transaction-ID deduplication, not a production persistence service.

## Stop

```bash
docker compose -p java-kafka-quality-loop -f replay-lab-demo/java-kafka/compose.yml stop
```

This stops only the two dedicated local containers and preserves their data. It does not stop the AWS demo, remove recordings or delete volumes. Use a fresh phase name when rehearsing again.

## EKS consumer replay

`eks_demo.py` is a demo-account-specific adapter, not a general cluster installer. It targets account `763455676074`, cluster `eks-quality-factory` and namespace `banking-app`. It creates only `ihg-*` demo workloads: a private plaintext Kafka broker, Postgres, the unchanged producer, ledger consumer and a proxymock API mock. It uses the authorized dev config in a Kubernetes Secret, not Secrets Manager. Application capture is eBPF-based; the application pods have no capture sidecars.

Prepare the released proxymock v2.5.1179 binaries for macOS and Linux in the ignored `output/tools` directory. Verify the published SHA256 before running them. Build the consumer and producer with Maven, then use `Dockerfile.eks` with `JAR_PATH` pointing at the current module's packaged JAR. Publish separate immutable baseline, faulty and repaired consumer tags in the demo ECR repository. The Dockerfile-specific ignore file excludes recordings and credentials from the build context.

Run `python3 replay-lab-demo/java-kafka/eks_demo.py setup`, then `seed` once. Seed sends the recorded HTTP deposit to the isolated producer, validates its event and ledger outcome, and checks a zstd batch on the broker. Import only that consumer's eBPF capture from the demo BYOC bucket into `output/eks/recording`. Freeze this corpus before testing candidates. Do not rerun setup or seed during the candidate sequence.

Set `DLP_CONFIG_FILE` to the existing demo DLP JSON before the first candidate run. The runner stages those rules inline in `output/eks/ihg-kafka-local.json`, because a cloud-free replay cannot resolve a cloud-only DLP name. The config ID must match its filename. Subsequent runs reuse the same config.

```bash
python3 replay-lab-demo/java-kafka/eks_demo.py run baseline --image "$BASELINE_IMAGE"
python3 replay-lab-demo/java-kafka/eks_demo.py run faulty --image "$FAULTY_IMAGE"
kiro-cli chat --agent-engine v3 --agent ledger-fix --no-interactive \
  "Read replay-lab-demo/java-kafka/output/eks/faulty/gate.json and repair only replay-lab-demo/java-kafka/consumer/src/main/java/com/banking/demo/Ledger.java. Preserve all checks, recordings, tests and expected values. Do not execute shell commands."
mvn -f replay-lab-demo/java-kafka/consumer/pom.xml verify
# Build and publish the repaired image before running it.
python3 replay-lab-demo/java-kafka/eks_demo.py run repaired --image "$REPAIRED_IMAGE"
```

The isolated broker explicitly sets `KAFKA_LOG_DIRS=/tmp/kafka-logs`. Broker evidence uses the same configured path instead of relying on the image default. Each candidate run stops only `ihg-ledger`, restarts only the ephemeral `ihg-kafka` broker and recreates its dedicated topic. This discards that broker's previous demo events and offsets. It does not reset the existing banking Kafka broker or database. The recording and phase evidence are preserved. Use fresh phase names; existing evidence cannot be overwritten.

The native generator selects `(command IS "Fetch") AND (location IS "ihg-quality-transactions")` and produces the captured batch to the broker without modifying the consumer workload. Independent checks compare the value, key, CreateTime, zstd codec, consumed business status and committed offset. Native replay can pass while the consumer business check fails. Exit 0 is combined functional pass, exit 1 is an assertion failure, and exit 2 is native replay setup failure. Compare recording, test-config, assertion and harness fingerprints across candidates.

EKS payment dependency calls can have certificate-trust failures and are outside this gate. The demonstrated successful third-party response is the recorded assessment response. SASL, TLS, brokerless replay, Kafka-native output assertions and observability export remain separate acceptance work.

The broker configuration follows the [Apache Kafka Docker documentation](https://kafka.apache.org/40/getting-started/docker/). The restricted profile uses Kiro's [custom-agent configuration](https://kiro.dev/docs/custom-agents/configuration-reference/).
