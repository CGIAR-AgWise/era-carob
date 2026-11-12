"""Fetch checksum-pinned archives and extract required files into a local cache."""
from contextlib import contextmanager
from pathlib import Path
from tempfile import NamedTemporaryFile
import hashlib
import json
import shutil
import subprocess
import sys
import tarfile
import zipfile


@contextmanager
def temporary_sibling(target):
    with NamedTemporaryFile(dir=target.parent, prefix=target.name + ".", delete=False) as handle:
        part = Path(handle.name)
    try:
        yield part
    finally:
        part.unlink(missing_ok=True)


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as src:
        for block in iter(lambda: src.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def fetch(archive, url, expected):
    if archive.exists() and digest(archive) == expected:
        return
    with temporary_sibling(archive) as part:
        subprocess.run(["curl", "-fLsS", "--retry", "3", "-o", str(part), url], check=True)
        actual = digest(part)
        if actual != expected:
            sys.exit(f"{url}: expected SHA-256 {expected}, received {actual}. Supply the pinned archive in {archive}.")
        part.replace(archive)


def extract_stream(source, destination):
    with temporary_sibling(destination) as part:
        with part.open("wb") as dst:
            shutil.copyfileobj(source, dst)
        part.replace(destination)


def prepare(root):
    root.mkdir(parents=True, exist_ok=True)
    for name, (url, checksum) in json.loads(Path("audit/inputs.json").read_text()).items():
        archive = root / name
        fetch(archive, url, checksum)
        if name.endswith(".zip"):
            with zipfile.ZipFile(archive) as z:
                for key in ("carob_agronomy-cc.csv", "carob_agronomy_metadata-cc.csv"):
                    with z.open(key) as src:
                        extract_stream(src, root / key)
        else:
            with tarfile.open(archive) as t:
                for prefix in ("agronomic_", "era_master_codes"):
                    [member] = [m for m in t.getmembers() if m.isfile() and Path(m.name).name.startswith(prefix) and m.name.endswith(".json")]
                    with t.extractfile(member) as src:
                        extract_stream(src, root / Path(member.name).name)


if __name__ == "__main__":
    prepare(Path(sys.argv[1]))
