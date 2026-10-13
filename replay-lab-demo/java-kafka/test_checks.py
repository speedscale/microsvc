import copy
import unittest
from checks import evaluate


class ChecksTest(unittest.TestCase):
    def setUp(self):
        self.expected = {"requestCount": 1, "httpStatuses": [201], "accountId": 70668, "amount": 3.33,
                         "transactionType": "DEPOSIT", "eventStatus": "COMPLETED",
                         "ledgerOutcome": "COMPLETED", "partnerDecision": "APPROVED",
                         "maxDuplicates": 0, "maxRejected": 0}
        event = {"transaction_id": 1, "account_id": 70668, "amount": 3.33,
                 "transaction_type": "DEPOSIT", "status": "COMPLETED"}
        self.http = [{"id": 1, "toAccountId": 70668, "amount": 3.33, "type": "DEPOSIT", "status": "COMPLETED"}]
        self.records = [{"key": "1", "event": event}]
        self.ledger = {"entries": [{"transactionId": 1, "key": "1", "event": copy.deepcopy(event),
                                   "outcome": "COMPLETED", "partnerDecision": "APPROVED"}],
                       "deliveries": 1, "duplicates": 0, "rejected": 0}
        self.commits = [{"current": 1, "end": 1, "lag": 0}]

    def result(self, **changes):
        args = {"expected": self.expected, "http": self.http, "ledger": self.ledger,
                "records": self.records, "commits": self.commits, "replay": {"success": True, "statuses": [201]}}
        args.update(changes)
        return evaluate(**args)

    def test_baseline(self):
        self.assertTrue(self.result()["passed"])

    def test_wrong_business_outcome_despite_successful_http(self):
        self.ledger["entries"][0]["outcome"] = "SETTLED"
        self.assertFalse(self.result()["passed"])

    def test_wrong_produced_value(self):
        self.records[0]["event"]["amount"] = 99
        self.assertFalse(self.result()["passed"])

    def test_empty_and_extra_records(self):
        self.assertFalse(self.result(records=[])["passed"])
        self.assertFalse(self.result(records=self.records * 2)["passed"])

    def test_wrong_key_and_identity(self):
        self.records[0]["key"] = "2"
        self.assertFalse(self.result()["passed"])
        self.records[0]["event"]["transaction_id"] = 2
        self.assertFalse(self.result()["passed"])

    def test_duplicates_and_rejections(self):
        self.ledger["duplicates"] = 1
        self.assertFalse(self.result()["passed"])
        self.ledger["duplicates"] = 0
        self.ledger["rejected"] = 1
        self.assertFalse(self.result()["passed"])

    def test_empty_ledger(self):
        self.ledger["entries"] = []
        self.assertFalse(self.result()["passed"])

    def test_missing_or_uncommitted_offsets(self):
        self.assertFalse(self.result(commits=[])["passed"])
        self.commits[0]["current"] = 0
        self.commits[0]["lag"] = 1
        self.assertFalse(self.result()["passed"])

    def test_failed_http_replay(self):
        self.assertFalse(self.result(replay={"success": False})["passed"])

    def test_changed_http_body(self):
        self.http[0]["status"] = "FAILED"
        self.assertFalse(self.result()["passed"])

    def test_changed_partner_decision(self):
        self.ledger["entries"][0]["partnerDecision"] = "REVIEW"
        self.assertFalse(self.result()["passed"])


if __name__ == "__main__":
    unittest.main()
