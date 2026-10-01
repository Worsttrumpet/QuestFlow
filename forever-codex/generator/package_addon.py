#!/usr/bin/env python3
"""Packages forever-codex/ForeverCodex into a deterministic zip for testers (fixed timestamps, sorted entries).

Usage: python3 package_addon.py [--out DIR]   ->  DIR/ForeverCodex-<version>.zip   (default: forever-codex/dist)
"""
import argparse
import re
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ADDON = HERE.parent / "ForeverCodex"
FIXED_TIME = (2026, 10, 1, 0, 0, 0)


def version() -> str:
    m = re.search(r"^## Version:\s*(\S+)", (ADDON / "ForeverCodex.toc").read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else "dev"


def build(out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"ForeverCodex-{version()}.zip"
    files = sorted(p for p in ADDON.rglob("*") if p.is_file())
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
        for p in files:
            info = zipfile.ZipInfo("ForeverCodex/" + p.relative_to(ADDON).as_posix(), FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, p.read_bytes())
    return target


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=HERE.parent / "dist")
    print(build(ap.parse_args().out))
