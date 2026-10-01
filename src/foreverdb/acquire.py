"""Acquisition: pinned git snapshots, an opt-in Wago fetcher, and user-supplied files.

Nothing here writes into tracked directories: everything lands under data/raw.
"""
from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from .provenance import DatasetRecord, sha256_bytes, sha256_file, utc_now

Runner = Callable[..., "subprocess.CompletedProcess[str]"]


class WagoDisabled(RuntimeError):
    pass


def _git(args: list[str], cwd: Path, runner: Runner = subprocess.run) -> str:
    cp = runner(["git", *args], cwd=str(cwd), capture_output=True, text=True, check=True)
    return cp.stdout.strip()


def acquire_git_snapshot(repo_url: str, sha: str, dest: Path, runner: Runner = subprocess.run) -> Path:
    """Shallow-fetch exactly `sha` into `dest`. Idempotent; verifies HEAD afterwards."""
    dest = Path(dest)
    if not (dest / ".git").exists():
        dest.mkdir(parents=True, exist_ok=True)
        _git(["init", "-q"], dest, runner)
        _git(["remote", "add", "origin", repo_url], dest, runner)
    head = ""
    try:
        head = _git(["rev-parse", "HEAD"], dest, runner)
    except subprocess.CalledProcessError:
        pass
    if head != sha:
        _git(["fetch", "-q", "--depth", "1", "origin", sha], dest, runner)
        _git(["checkout", "-q", "FETCH_HEAD"], dest, runner)
        head = _git(["rev-parse", "HEAD"], dest, runner)
    if head != sha:
        raise RuntimeError(f"snapshot at {dest} is {head}, expected {sha}")
    return dest


@dataclass(frozen=True)
class SnapshotInfo:
    key: str
    repo_url: str
    sha: str
    root: Path
    license_id: str
    license_status: str
    upstream_provenance: str
    mirrors_blizzard_csv: bool


def snapshot_record(info: SnapshotInfo, runner: Runner = subprocess.run) -> DatasetRecord:
    tree = _git(["rev-parse", "HEAD^{tree}"], info.root, runner)
    return DatasetRecord(
        source_kind="git", source_uri=info.repo_url, source_ref=info.sha, path_in_source=None,
        retrieved_at=utc_now(), sha256=None, content_id=tree, size_bytes=None,
        first_hand=True, origin="direct", mirror_of=None,
        license_id=info.license_id, license_status=info.license_status,
        redistributable=None, claimed_build_id=None, claim_basis=None,
        notes=f"repo license={info.license_id}; upstream provenance {info.upstream_provenance}",
    )


def mirrored_csv_record(info: SnapshotInfo, rel_path: str, claimed_build_id: str | None) -> DatasetRecord:
    """A Blizzard-derived CSV that a third-party repo vendors. The build label is only a claim."""
    path = info.root / rel_path
    return DatasetRecord(
        source_kind="git", source_uri=info.repo_url, source_ref=info.sha, path_in_source=rel_path,
        retrieved_at=utc_now(), sha256=sha256_file(path), content_id=None, size_bytes=path.stat().st_size,
        first_hand=True, origin="mirror", mirror_of="wago.tools",
        license_id="unresolved-blizzard-derived", license_status="unresolved",
        redistributable=None, claimed_build_id=claimed_build_id,
        claim_basis="filename label in third-party repo",
        build_claim_verified=False,
        notes="Repo license does not establish rights to Blizzard-derived data.",
    )


def user_file_record(path: Path, claimed_build_id: str, claim_basis: str, mirror_of: str | None = None) -> DatasetRecord:
    path = Path(path)
    return DatasetRecord(
        source_kind="user_file", source_uri=path.as_uri(), source_ref=claimed_build_id, path_in_source=path.name,
        retrieved_at=utc_now(), sha256=sha256_file(path), content_id=None, size_bytes=path.stat().st_size,
        first_hand=True, origin="user_supplied", mirror_of=mirror_of,
        license_id="unresolved", license_status="unresolved", redistributable=None,
        claimed_build_id=claimed_build_id, claim_basis=claim_basis,
    )


class WagoFetcher:
    """Downloads a DB2 table as CSV from wago.tools. DISABLED unless explicitly enabled.

    wago.tools' robots.txt refused one automated client in M0 and its terms were not retrieved.
    Enabling is a deliberate act (`--allow-wago`), not a default.
    """

    URL = "https://wago.tools/db2/{table}/csv?build={build}"

    def __init__(self, enabled: bool = False, fetch: Callable[[str], bytes] | None = None) -> None:
        self.enabled = enabled
        self._fetch = fetch or self._default_fetch

    @staticmethod
    def _default_fetch(url: str) -> bytes:
        import urllib.request
        with urllib.request.urlopen(url, timeout=60) as resp:  # noqa: S310
            return resp.read()

    def url_for(self, table: str, build: str) -> str:
        return self.URL.format(table=table, build=build)

    def fetch_table(self, table: str, build: str, dest_dir: Path) -> DatasetRecord:
        if not self.enabled:
            raise WagoDisabled("Wago fetching is disabled; terms/robots unresolved. Pass --allow-wago to override.")
        url = self.url_for(table, build)
        data = self._fetch(url)
        head = data[:200].lstrip().lower()
        if not data or head.startswith(b"<!doctype") or head.startswith(b"<html"):
            raise RuntimeError(f"{url} did not return CSV")
        dest_dir = Path(dest_dir)
        dest_dir.mkdir(parents=True, exist_ok=True)
        out = dest_dir / f"{table}.{build}.csv"
        out.write_bytes(data)
        return DatasetRecord(
            source_kind="wago", source_uri=url, source_ref=build, path_in_source=out.name,
            retrieved_at=utc_now(), sha256=sha256_bytes(data), content_id=None, size_bytes=len(data),
            first_hand=True, origin="direct", mirror_of=None,
            license_id="unresolved-blizzard-derived", license_status="unresolved", redistributable=None,
            claimed_build_id=build, claim_basis="requested build parameter (wago's own labelling)",
            build_claim_verified=False,
        )
