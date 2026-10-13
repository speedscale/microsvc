import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import eks_demo


class BrokerEvidenceTests(unittest.TestCase):
    def test_broker_and_dump_share_explicit_log_directory(self):
        captured = {}
        def remember(name, image, env, *args):
            captured[name] = env
        with patch.object(eks_demo, "call", return_value=SimpleNamespace(stdout='{"Account":"763455676074"}')), \
                patch.object(eks_demo, "apply"), patch.object(eks_demo, "deploy", side_effect=remember), \
                patch.object(eks_demo, "ready"), patch.object(eks_demo, "topic"), patch("sys.stdout", new_callable=io.StringIO):
            eks_demo.setup()
        self.assertEqual(captured["ihg-kafka"]["KAFKA_LOG_DIRS"], eks_demo.KAFKA_LOG_DIR)

    def read(self, offsets):
        value = json.dumps({"transaction_id": 1, "status": "COMPLETED"})
        results = [SimpleNamespace(stdout="CreateTime:123\t1\t" + value + "\n"),
                   SimpleNamespace(stdout=offsets)]
        with TemporaryDirectory() as directory, patch.object(eks_demo, "admin", side_effect=results), \
                patch.object(eks_demo, "call", return_value=SimpleNamespace(stdout="baseOffset: 0 compresscodec: zstd\n")) as invoked:
            result = eks_demo.broker_evidence(Path(directory))
            self.assertIn(eks_demo.KAFKA_LOG_DIR + "/" + eks_demo.TOPIC + "-0/*.log", invoked.call_args.args[0][-1])
            return result

    def test_keeps_record_timestamp_and_codec(self):
        records, commits, codecs = self.read("ihg-quality-ledger ihg-quality-transactions 0 1 1 0\n")
        self.assertEqual(records[0]["timestamp"], "CreateTime:123")
        self.assertEqual(records[0]["key"], "1")
        self.assertEqual(records[0]["event"]["status"], "COMPLETED")
        self.assertEqual(commits, [{"partition": 0, "current": 1, "end": 1, "lag": 0}])
        self.assertEqual(codecs, ["zstd"])

    def test_missing_commit_remains_missing(self):
        _, commits, _ = self.read("ihg-quality-ledger ihg-quality-transactions 0 - 0 -\n")
        self.assertIsNone(commits[0]["current"])
        self.assertIsNone(commits[0]["lag"])

    def test_missing_group_has_no_commits(self):
        _, commits, _ = self.read("GROUP TOPIC PARTITION CURRENT-OFFSET LOG-END-OFFSET LAG\n")
        self.assertEqual(commits, [])


if __name__ == "__main__":
    unittest.main()
