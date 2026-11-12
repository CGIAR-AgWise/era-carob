"""Check the release archive cannot silently include unlisted data or local edits."""
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
            manifest.write_text("README.md\naudit/package-files.txt\n")
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
                                 {"sf001-v0.1-review/README.md", "sf001-v0.1-review/audit/package-files.txt"})
                self.assertEqual(archive.extractfile("sf001-v0.1-review/README.md").read(), b"reviewed")
            run("python3", str(TOOL), "HEAD", str(output))
            self.assertEqual(output.read_bytes(), original)
            manifest.write_text(manifest.read_text() + "missing\n")
            run("git", "add", "audit")
            run(*commit, "Missing file")
            self.assertNotEqual(run("python3", str(TOOL), "HEAD", str(output), check=False).returncode, 0)
            self.assertEqual(output.read_bytes(), original)
