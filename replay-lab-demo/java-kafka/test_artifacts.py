from pathlib import Path
import tempfile
import unittest
from demo import resolve_jar


class ArtifactsTest(unittest.TestCase):
    def module(self, directory, final_name=""):
        root = Path(directory)
        (root / "target").mkdir()
        (root / "pom.xml").write_text(
            '<project xmlns="http://maven.apache.org/POM/4.0.0">'
            '<artifactId>transactions-service</artifactId><version>1.4.131</version>'
            + final_name + '</project>')
        return root

    def test_current_version_wins_over_stale_jar(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.module(directory)
            (root / "target/transactions-service-1.4.130.jar").write_bytes(b"stale")
            current = root / "target/transactions-service-1.4.131.jar"
            current.write_bytes(b"current")
            self.assertEqual(resolve_jar(root), current)

    def test_missing_current_artifact_never_falls_back(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.module(directory)
            (root / "target/transactions-service-1.4.130.jar").write_bytes(b"stale")
            with self.assertRaises(FileNotFoundError):
                resolve_jar(root)

    def test_explicit_final_name(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.module(directory, '<build><finalName>service</finalName></build>')
            jar = root / "target/service.jar"
            jar.write_bytes(b"current")
            self.assertEqual(resolve_jar(root), jar)

    def test_unresolved_expression_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.module(directory, '<build><finalName>${revision}</finalName></build>')
            with self.assertRaises(ValueError):
                resolve_jar(root)


if __name__ == "__main__":
    unittest.main()
