"""Check the release archive cannot silently include unlisted data or local edits."""
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

TOOL = Path(__file__).with_name("package_review.py").resolve()


class PackageTest(unittest.TestCase):
    def test_committed_allowlist_and_atomic_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            repo = Path(folder)

            def run(*cmd, check=True):
                return subprocess.run(cmd, cwd=repo, check=check, capture_output=True)

            run("git", "init", "-q")
            (repo / "audit").mkdir()
            manifest = repo / "audit/package-files.txt"
            manifest.write_text("README.md\naudit/package-files.txt\naudit/packages.json\n")
            (repo / "audit/packages.json").write_text(json.dumps({
                "sf001": {"manifest": "audit/package-files.txt", "archive_prefix": "sf001-v0.1-review/"},
                "sf003": {"manifest": "audit/schema-package-files.txt", "archive_prefix": "sf003-docs-v0.1-review/"}
            }))
            (repo / "audit/schema-package-files.txt").write_text(
                "schema.csv\naudit/schema-package-files.txt\naudit/packages.json\n")
            (repo / "schema.csv").write_text("field,unit\nyield,kg/ha\n")
            (repo / "README.md").write_text("reviewed")
            (repo / "source.rds").write_text("excluded")
            run("git", "add", ".")
            commit = ["git", "-c", "user.email=test@example.org", "-c", "user.name=Test", "commit", "-qm"]
            run(*commit, "Reviewed")
            (repo / "README.md").write_text("uncommitted")
            output = repo / "package.tar.gz"
            run("python3", str(TOOL), "HEAD", str(output))
            original = output.read_bytes()
            with tarfile.open(output) as archive:
                self.assertEqual({m.name for m in archive if m.isfile()},
                                 {"sf001-v0.1-review/README.md", "sf001-v0.1-review/audit/package-files.txt", "sf001-v0.1-review/audit/packages.json"})
                self.assertEqual(archive.extractfile("sf001-v0.1-review/README.md").read(), b"reviewed")
            run("python3", str(TOOL), "HEAD", str(output))
            self.assertEqual(output.read_bytes(), original)
            docs = repo / "docs.tar.gz"
            run("python3", str(TOOL), "HEAD", str(docs), "--product", "sf003")
            with tarfile.open(docs) as archive:
                self.assertEqual({m.name for m in archive if m.isfile()}, {
                    "sf003-docs-v0.1-review/schema.csv",
                    "sf003-docs-v0.1-review/audit/schema-package-files.txt",
                    "sf003-docs-v0.1-review/audit/packages.json"})
                self.assertEqual(archive.extractfile("sf003-docs-v0.1-review/schema.csv").read(),
                                 b"field,unit\nyield,kg/ha\n")
            manifest.write_text(manifest.read_text() + "missing\n")
            run("git", "add", "audit")
            run(*commit, "Missing file")
            self.assertNotEqual(run("python3", str(TOOL), "HEAD", str(output), check=False).returncode, 0)
            self.assertEqual(output.read_bytes(), original)
