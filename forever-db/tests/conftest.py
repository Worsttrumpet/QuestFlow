from __future__ import annotations

import csv
import subprocess
from pathlib import Path

import pytest

from foreverdb import db


@pytest.fixture()
def conn():
    c = db.connect(":memory:")
    db.init_schema(c)
    return c


def write_csv(path: Path, header: list[str], rows: list[list[object]], bom: bool = False) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8-sig" if bom else "utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(rows)
    return path


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", "-c", "user.email=t@example.invalid", "-c", "user.name=t", *args],
                          cwd=cwd, capture_output=True, text=True, check=True).stdout.strip()


def make_repo(root: Path, files: dict[str, str]) -> str:
    root.mkdir(parents=True, exist_ok=True)
    git(root, "init", "-q")
    for rel, text in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "fixture")
    return git(root, "rev-parse", "HEAD")


@pytest.fixture()
def dataset(conn):
    """A throwaway dataset row so assertions have a valid source."""
    from foreverdb.provenance import DatasetRecord
    rec = DatasetRecord("git", "https://example.invalid/r.git", "a" * 40, "f.lua", "2026-01-01T00:00:00Z", "b" * 64, None, 1,
                        True, "direct", None, "MIT", "verified", None, None, None)
    return db.insert_dataset(conn, rec)
