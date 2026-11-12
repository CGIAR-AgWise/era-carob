"""Fetch pinned source archives and extract only the required members."""
from pathlib import Path
import hashlib, json, subprocess, tarfile, zipfile, shutil, sys
root = Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=True)
for name, (url, checksum) in json.loads(Path("audit/inputs.json").read_text()).items():
    archive = root / name
    if not archive.exists():
        subprocess.run(["curl", "-fLsS", "--retry", "3", "-o", str(archive), url], check=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != checksum:
        sys.exit(f"Checksum mismatch: {name}. Obtain the pinned bytes; do not use latest.")
    if name.endswith(".zip"):
        with zipfile.ZipFile(archive) as z:
            for key in ["carob_agronomy-cc.csv", "carob_agronomy_metadata-cc.csv"]:
                with z.open(key) as src, (root / key).open("wb") as dst:
                    shutil.copyfileobj(src, dst)
    else:
        with tarfile.open(archive) as t:
            for prefix in ("agronomic_", "era_master_codes"):
                [m] = [m for m in t if m.isfile() and Path(m.name).name.startswith(prefix) and m.name.endswith(".json")]
                with t.extractfile(m) as src, (root / Path(m.name).name).open("wb") as dst:
                    shutil.copyfileobj(src, dst)
