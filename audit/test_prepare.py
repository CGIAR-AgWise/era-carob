"""Check retry after interruption and fail closed on source drift."""
import hashlib
from pathlib import Path
import tempfile
import unittest

from prepare import fetch


class CacheTest(unittest.TestCase):
    def test_partial_cache_and_wrong_download(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "remote"
            archive = Path(tmp) / "cached"
            source.write_bytes(b"complete archive")
            archive.write_bytes(b"partial")
            pin = hashlib.sha256(source.read_bytes()).hexdigest()
            fetch(archive, source.as_uri(), pin)
            self.assertEqual(archive.read_bytes(), source.read_bytes())
            source.write_bytes(b"unexpected different version")
            with self.assertRaises(SystemExit):
                fetch(archive, source.as_uri(), "0" * 64)
            self.assertEqual(archive.read_bytes(), b"complete archive")
