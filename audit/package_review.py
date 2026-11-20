"""Package committed, allowlisted review files; print SHA-256 after verifying members."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile

METADATA = "audit/packages.json"


def git(*args):
    return subprocess.check_output(["git", *args])


def package(revision, target, product="sf001"):
    commit = git("rev-parse", "--verify", "--end-of-options", revision + "^{commit}").decode().strip()
    products = json.loads(git("show", f"{commit}:{METADATA}"))
    spec = products[product]
    manifest, prefix = spec["manifest"], spec["archive_prefix"]
    if not prefix.endswith("/") or PurePosixPath(prefix).is_absolute() or ".." in PurePosixPath(prefix).parts:
        raise ValueError("Invalid archive prefix.")
    listed = git("show", f"{commit}:{manifest}").decode().splitlines()
    files = [name for name in listed if name and not name.startswith("#")]
    if len(files) != len(set(files)) or manifest not in files or METADATA not in files:
        raise ValueError("Package manifest must list itself, package metadata and unique file paths.")
    for name in files:
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or path.as_posix() != name:
            raise ValueError(f"Invalid package member: {name}")
    target = Path(target).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=target.parent) as folder:
        tar = Path(folder) / "review.tar"
        compressed = Path(folder) / "review.tar.gz"
        subprocess.run(["git", "--literal-pathspecs", "archive", "--format=tar", f"--prefix={prefix}",
                        "-o", str(tar), commit, "--", *files], check=True)
        with tarfile.open(tar) as source:
            members = [m for m in source if not m.isdir()]
            expected = {prefix + name for name in files}
            if {m.name for m in members} != expected or len(members) != len(files) or any(not m.isfile() for m in members):
                raise ValueError("Archive does not contain exactly the regular files in the package manifest.")
        with tar.open("rb") as source, compressed.open("wb") as raw:
            with gzip.GzipFile(filename="", fileobj=raw, mode="wb", mtime=0) as dest:
                shutil.copyfileobj(source, dest)
        digest = hashlib.sha256(compressed.read_bytes()).hexdigest()
        os.replace(compressed, target)
    return commit, digest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("commit", help="Git revision whose manifest and files to package")
    parser.add_argument("archive", type=Path, help="Destination .tar.gz")
    parser.add_argument("--product", choices=("sf001", "sf003"), default="sf001")
    args = parser.parse_args()
    commit, digest = package(args.commit, args.archive, args.product)
    print(f"Commit {commit}\n{digest}  {args.archive}")
