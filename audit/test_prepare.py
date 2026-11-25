"""Check retry after interruption and fail closed on source drift."""
import hashlib
import io
import json
import tarfile
from unittest.mock import patch
from pathlib import Path
import tempfile
import unittest

from prepare import fetch, prepare, verify


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


    def test_successor_cache_isolation_and_hold_integrity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "bundle.tar.gz"
            members = {"agronomic_issue94.json": b"{}", "era_master_codes.json": b"{}",
                       "issue94-date-audit.csv": b"audit", "issue94-date-holds.csv": b"holds",
                       "issue94-manifest.json": b"{}"}
            with tarfile.open(source, "w:gz") as archive:
                for name, data in members.items():
                    info = tarfile.TarInfo(name); info.size = len(data)
                    archive.addfile(info, io.BytesIO(data))
            pins = {"issue94.tar.gz": [source.as_uri(), hashlib.sha256(source.read_bytes()).hexdigest()]}
            inputs = root / "pins.json"; inputs.write_text(json.dumps(pins))
            cache = root / "cache"; cache.mkdir()
            (cache / "agronomic_old.json").write_text("old")
            with self.assertRaisesRegex(ValueError, "separate directory"):
                prepare(cache, inputs)
            self.assertFalse((cache / "prepared-inputs.json").exists())
            (cache / "agronomic_old.json").unlink()
            prepare(cache, inputs)
            receipt = json.loads((cache / "prepared-inputs.json").read_text())
            self.assertEqual(set(receipt["files"]), set(members))
            # Verification must reject altered holds before downstream consumers run.
            (cache / "issue94-date-holds.csv").write_text("changed")
            original_read = Path.read_text
            def read(path, *args, **kwargs):
                if str(path) in ("audit/inputs.json", "audit/inputs-historical.json"):
                    return json.dumps(pins)
                return original_read(path, *args, **kwargs)
            with patch.object(Path, "read_text", read):
                with self.assertRaisesRegex(ValueError, "Prepared input changed"):
                    verify(cache)
