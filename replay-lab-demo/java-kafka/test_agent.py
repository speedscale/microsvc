import json
from pathlib import Path
import unittest


class AgentTest(unittest.TestCase):
    def test_write_permissions_are_confined_to_consumer_source(self):
        root = Path(__file__).resolve().parents[2]
        agent = json.loads((root / ".kiro/agents/ledger-fix.json").read_text())
        target = "replay-lab-demo/java-kafka/consumer/src/main/java/com/banking/demo/Ledger.java"
        rules = agent["permissions"]["rules"]
        writes = [rule for rule in rules if rule["capability"] == "fs_write"]
        self.assertEqual([r["match"] for r in writes if r["effect"] == "allow"], [[target]])
        self.assertIn({"capability": "fs_write", "match": ["**"], "exclude": [target], "effect": "deny"}, writes)
        self.assertEqual(agent["tools"], ["read", "write"])
        self.assertNotIn("allowedTools", agent)
        self.assertNotIn("toolsSettings", agent)
        self.assertFalse(agent["includeMcpJson"])
        self.assertFalse(agent["includePowers"])
        self.assertEqual(agent["mcpServers"], {})


if __name__ == "__main__":
    unittest.main()
