#!/usr/bin/env python3
"""Build an allowlisted, deterministic addon ZIP; never include local player data."""
from hashlib import sha256
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
ADDON = "CWoWCompanionManager"
source = ROOT / ADDON
manifest = source / (ADDON + ".toc")
entries = [line.strip() for line in manifest.read_text().splitlines()
           if line.strip() and not line.startswith("#")]
expected = ["Shared.lua", "Factions.lua", "Transport.lua", "Party.lua", "Manager.lua", "UI.lua", "Core.lua"]
if entries != expected:
    raise SystemExit("Manifest differs from the reviewed release allowlist.")
files = [(manifest, manifest.name)] + [(source / name, name) for name in entries]
files += [(ROOT / name, name) for name in ("README.md", "LICENSE", "CHANGELOG.md")]
files.append((ROOT / "docs" / "MANUAL_TESTS.md", "docs/MANUAL_TESTS.md"))
out = ROOT / "dist"
out.mkdir(exist_ok=True)
archive = out / (ADDON + ".zip")
with ZipFile(archive, "w", compression=ZIP_DEFLATED) as z:
    for path, relative in files:
        info = ZipInfo(ADDON + "/" + relative, date_time=(2026, 10, 9, 0, 0, 0))
        info.compress_type = ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        z.writestr(info, path.read_bytes())
with ZipFile(archive) as z:
    if z.testzip() is not None or len(z.namelist()) != len(files):
        raise SystemExit("Release archive integrity check failed.")
digest = sha256(archive.read_bytes()).hexdigest()
(out / (ADDON + ".zip.sha256")).write_text(digest + "  " + archive.name + "\n")
print(str(archive))
print(digest)
