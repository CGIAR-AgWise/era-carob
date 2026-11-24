"""Fetch checksum-pinned archives and extract required files into a local cache."""
from contextlib import contextmanager
from pathlib import Path
from tempfile import NamedTemporaryFile
import argparse
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


def prepare(root, inputs=Path("audit/inputs.json")):
    root.mkdir(parents=True, exist_ok=True)
    pins = json.loads(inputs.read_text())
    receipt = {"archives": pins, "files": {}}
    marker = root / "prepared-inputs.json"
    marker.unlink(missing_ok=True)
    for name, (url, checksum) in pins.items():
        archive = root / name
        fetch(archive, url, checksum)
        if name.endswith(".zip"):
            with zipfile.ZipFile(archive) as z:
                for key in ("carob_agronomy-cc.csv", "carob_agronomy_metadata-cc.csv"):
                    with z.open(key) as src:
                        extract_stream(src, root / key)
                    receipt["files"][key] = digest(root / key)
        else:
            with tarfile.open(archive) as t:
                selected = []
                for prefix in ("agronomic_", "era_master_codes"):
                    [member] = [m for m in t.getmembers() if m.isfile() and Path(m.name).name.startswith(prefix) and m.name.endswith(".json")]
                    stale = [p for p in root.glob(prefix + "*.json") if p.name != Path(member.name).name]
                    if stale:
                        raise ValueError("Different ERA snapshot already in cache; use a separate directory: " + str(root))
                    selected.append(member)
                if "issue94" in name:
                    selected += [t.getmember(key) for key in
                                 ("issue94-date-audit.csv", "issue94-date-holds.csv", "issue94-manifest.json")]
                for member in selected:
                    with t.extractfile(member) as src:
                        extract_stream(src, root / Path(member.name).name)
                    key = Path(member.name).name
                    receipt["files"][key] = digest(root / key)
    marker.write_text(json.dumps(receipt, indent=2) + "\n")


def verify(root):
    receipt = json.loads((root / "prepared-inputs.json").read_text())
    supported = [json.loads(Path(p).read_text()) for p in
                 ("audit/inputs.json", "audit/inputs-historical.json")]
    if receipt["archives"] not in supported:
        raise ValueError("Cache does not match a supported input pin")
    for pattern in ("agronomic_*.json", "era_master_codes*.json"):
        selected = list(root.glob(pattern))
        if len(selected) != 1 or selected[0].name not in receipt["files"]:
            raise ValueError("Missing or mixed source JSON files: " + pattern)
    for name, expected in receipt["files"].items():
        if Path(name).name != name or digest(root / name) != expected:
            raise ValueError("Prepared input changed: " + name)
    required = {"carob_agronomy-cc.csv", "carob_agronomy_metadata-cc.csv"}
    if any("issue94" in name for name in receipt["archives"]):
        required |= {"issue94-date-audit.csv", "issue94-date-holds.csv", "issue94-manifest.json"}
    if not required <= receipt["files"].keys():
        raise ValueError("Prepared input receipt is incomplete")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cache", type=Path)
    parser.add_argument("--inputs", type=Path, default=Path("audit/inputs.json"))
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if args.verify_only:
        verify(args.cache)
    else:
        prepare(args.cache, args.inputs)
