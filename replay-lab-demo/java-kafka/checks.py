import json


def evaluate(expected, http, ledger, records, commits, replay):
    failures = []

    def check(condition, message):
        if not condition:
            failures.append(message)

    count = expected["requestCount"]
    check(len(http) == count, f"HTTP rows: expected {count}, observed {len(http)}")
    check(len(records) == count, f"Kafka records: expected {count}, observed {len(records)}")
    check(len(ledger["entries"]) == count, f"Ledger entries: expected {count}, observed {len(ledger['entries'])}")
    check(ledger["deliveries"] == count, "Unexpected or missing consumer deliveries")
    check(ledger["duplicates"] <= expected["maxDuplicates"], "Duplicate delivery")
    check(ledger["rejected"] <= expected["maxRejected"], "Rejected consumer input")
    check(replay.get("success") is True, "HTTP replay did not pass")
    check(replay.get("statuses") == expected["httpStatuses"], "HTTP response status sequence differs")
    ids = {row["id"] for row in http}
    check(len(ids) == count, "Duplicate HTTP transaction identities")
    seen = set()
    for record in records:
        event = record["event"]
        identity = event.get("transaction_id")
        check(identity in ids, f"Uncorrelated Kafka transaction {identity}")
        check(identity not in seen, f"Duplicate Kafka transaction {identity}")
        seen.add(identity)
        check(record["key"] == str(identity), "Kafka key differs from transaction identity")
        for field, want in {"account_id": expected["accountId"], "amount": expected["amount"],
                            "transaction_type": expected["transactionType"], "status": expected["eventStatus"]}.items():
            check(event.get(field) == want, f"Kafka {field}: expected {want}, observed {event.get(field)}")
    for row in http:
        for field, want in {"toAccountId": expected["accountId"], "amount": expected["amount"],
                            "type": expected["transactionType"], "status": expected["eventStatus"]}.items():
            check(row.get(field) == want, f"HTTP {field}: expected {want}, observed {row.get(field)}")
    for entry in ledger["entries"]:
        identity = entry["transactionId"]
        check(identity in ids, f"Uncorrelated ledger transaction {identity}")
        check(entry["outcome"] == expected["ledgerOutcome"],
              f"Ledger outcome: expected {expected['ledgerOutcome']}, observed {entry['outcome']}")
        check(entry["partnerDecision"] == expected["partnerDecision"], "Partner decision differs")
        matches = [r for r in records if r["key"] == entry["key"]]
        check(len(matches) == 1 and matches[0]["event"] == entry["event"], "Consumer input differs from produced record")
    check(len(commits) == 1, "Missing or unexpected consumer commit rows")
    for commit in commits:
        check(commit["current"] == count and commit["end"] == count and commit["lag"] == 0,
              f"Consumer has not committed all records: {commit}")
    return {"passed": not failures, "failures": failures, "scope": "HTTP fields, Kafka records, consumer outcome and commits"}
