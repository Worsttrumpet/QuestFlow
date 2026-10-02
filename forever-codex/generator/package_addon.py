#!/usr/bin/env python3
"""Packages forever-codex/ForeverCodex into a deterministic zip for testers (fixed timestamps, sorted entries).

Usage: python3 package_addon.py [--out DIR]   ->  DIR/ForeverCodex-<version>.zip   (default: forever-codex/dist/<major>.<minor>/)

Versioning (see forever-codex/docs/RELEASING.md): every packaged code change gets a NEW patch version (0.2.1, 0.2.2, ...), set in
ForeverCodex.toc (## Version) and Core.lua (C.VERSION), which must match. A zip filename is never reused: if
ForeverCodex-<version>.zip already exists with different contents this refuses to overwrite it and tells you to bump the version.
Older zips in dist/ are left alone. Each minor version has its own folder (dist/0.4/ holds 0.4.0 .. 0.4.9).
"""
import argparse
import re
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ADDON = HERE.parent / "ForeverCodex"
FIXED_TIME = (2026, 10, 1, 0, 0, 0)


VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


def toc_version() -> str:
    m = re.search(r"^## Version:\s*(\S+)", (ADDON / "ForeverCodex.toc").read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else "dev"


def code_version() -> str | None:
    m = re.search(r'^C\.VERSION\s*=\s*"([^"]+)"', (ADDON / "Core.lua").read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else None


def version() -> str:
    """The packaged version: the .toc's, which must be a patch-style x.y.z and equal Core.lua's C.VERSION."""
    v = toc_version()
    if not VERSION_RE.match(v):
        raise SystemExit(f"ForeverCodex.toc version {v!r} is not patch-style (x.y.z, for example 0.2.1)")
    if code_version() != v:
        raise SystemExit(f"version mismatch: ForeverCodex.toc says {v!r} but Core.lua C.VERSION is {code_version()!r}; they must match")
    return v


def _zip_bytes() -> bytes:
    import io

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(p for p in ADDON.rglob("*") if p.is_file()):
            info = zipfile.ZipInfo("ForeverCodex/" + p.relative_to(ADDON).as_posix(), FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, p.read_bytes())
    return buf.getvalue()


def default_out() -> Path:
    """dist/<major>.<minor>/ : one folder per minor version (0.4.0 .. 0.4.9 share dist/0.4/)."""
    return HERE.parent / "dist" / ".".join(version().split(".")[:2])


def build(out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"ForeverCodex-{version()}.zip"
    data = _zip_bytes()
    if target.exists() and target.read_bytes() != data:
        raise SystemExit(f"{target.name} already exists with different contents. Never reuse a zip name: bump the version "
                         f"(ForeverCodex.toc and Core.lua) to the next patch number and package again.")
    target.write_bytes(data)
    return target


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=None)
    print(build(ap.parse_args().out or default_out()))
