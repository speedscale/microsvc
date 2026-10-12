# Java Kafka quality loop

Run the existing Java 17/Spring Boot transactions producer with a Spring Boot ledger consumer, a private plaintext Kafka broker and recorded HTTP dependency mocks. The gate checks the API response, produced record, consumed business outcome and committed offset. HTTP success alone cannot pass it.

This is an isolated local rehearsal for an AWS/EKS service pattern. It does not deploy to EKS, implement a required SCM check, authenticate Kafka or prove brokerless consumer replay. The consumer's assessment API is a synthetic third-party fixture recorded once and then stopped. Existing payment API recordings contain authentication failures; they are mocked dependency behavior, not successful payment integrations. The existing fraud client fails open against an unavailable service and is outside this scenario's assertions.

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

The project-local `ledger-fix` Kiro agent has no shell or MCP tools and is configured to write only the consumer source. Ask it to inspect `output/faulty/gate.json`, preserve the contract and repair `Ledger.java`. Do not allow it to change assertions, tests, recordings or expected values.

```bash
kiro-cli chat --agent-engine v2 --agent ledger-fix --no-interactive \
  "Read replay-lab-demo/java-kafka/output/faulty/gate.json and repair only replay-lab-demo/java-kafka/consumer/src/main/java/com/banking/demo/Ledger.java. Preserve all checks and expected values. Do not execute shell commands."
mvn -f replay-lab-demo/java-kafka/consumer/pom.xml verify
python3 replay-lab-demo/java-kafka/demo.py run repaired
```

Compare `assertionsSha256` in the baseline, faulty and repaired gate files. They must match. Check the source diff and the consumer JAR hash; a successful agent message is not fix evidence. The producer JAR must be unchanged. The repaired runtime must exit 0 with the same request and checks.

## Read the evidence

Open the phase's `report.html` for the combined gate. It links the native proxymock HTTP report and `gate.json` with the Kafka record, ledger entry, topic, group, commit, source revision and build hashes. The HTTP replay scores status codes; the separate gate checks configured HTTP business fields and Kafka behavior. IDs and timestamps are not compared to the older recording, and this one-request scenario is not a complete API contract or load test.

The evidence uses a real private broker. The native proxymock report does not claim to compare Kafka outputs; that comparison is implemented by the demo's explicit checks. A console-consumer timeout after the bounded record read is normal. Missing records or nonzero consumer lag still fail the gate.

SASL, TLS, multi-consumer rebalances, large partition counts, DLQ behavior and production rollout remain separate acceptance work. The ledger is bounded, in-memory demo state with transaction-ID deduplication, not a production persistence service.

## Stop

```bash
docker compose -p java-kafka-quality-loop -f replay-lab-demo/java-kafka/compose.yml stop
```

This stops only the two dedicated local containers and preserves their data. It does not stop the AWS demo, remove recordings or delete volumes. Use a fresh phase name when rehearsing again.

The broker configuration follows the [Apache Kafka Docker documentation](https://kafka.apache.org/40/getting-started/docker/). The restricted profile uses Kiro's [custom-agent configuration](https://kiro.dev/docs/custom-agents/configuration-reference/).
