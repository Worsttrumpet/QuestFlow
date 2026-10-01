"""Build registry and Blizzard version-feed check.

Rules: a build is `unverified` unless Blizzard's version service confirms it as the *current*
build. The service cannot confirm historical builds. If it is unreachable we record that; we
never guess.
"""
from __future__ import annotations

import json
import re
import tomllib
import urllib.request
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Callable

from .provenance import utc_now

BUILD_ID_RE = re.compile(r"^\d+\.\d+\.\d+\.\d+$")
VERIFICATIONS = frozenset({"unverified", "blizzard_current"})
SERVICE_STATUSES = frozenset({"not_checked", "unreachable", "checked"})


@dataclass(frozen=True)
class BuildEvidence:
    kind: str
    source: str
    note: str


@dataclass(frozen=True)
class BuildRecord:
    id: str
    verification: str
    notes: str
    evidence: tuple[BuildEvidence, ...]


@dataclass(frozen=True)
class VersionService:
    url: str
    status: str
    last_attempt: str | None
    detail: str


@dataclass(frozen=True)
class Registry:
    product: str
    last_reviewed: str
    version_service: VersionService
    builds: tuple[BuildRecord, ...]

    def ids(self) -> list[str]:
        return [b.id for b in self.builds]

    def get(self, build_id: str) -> BuildRecord:
        for b in self.builds:
            if b.id == build_id:
                return b
        raise KeyError(build_id)


def load_registry(path: Path) -> Registry:
    raw = tomllib.loads(Path(path).read_text(encoding="utf-8"))
    vs = raw["blizzard_version_service"]
    if vs["status"] not in SERVICE_STATUSES:
        raise ValueError(f"bad version service status {vs['status']!r}")
    builds: list[BuildRecord] = []
    for b in raw.get("build", []):
        if not BUILD_ID_RE.match(b["id"]):
            raise ValueError(f"bad build id {b['id']!r}")
        if b["verification"] not in VERIFICATIONS:
            raise ValueError(f"bad verification {b['verification']!r}")
        ev = tuple(BuildEvidence(e["kind"], e["source"], e.get("note", "")) for e in b.get("evidence", []))
        builds.append(BuildRecord(b["id"], b["verification"], b.get("notes", ""), ev))
    return Registry(
        raw["meta"]["product"],
        raw["meta"]["last_reviewed"],
        VersionService(vs["url"], vs["status"], vs.get("last_attempt"), vs.get("detail", "")),
        tuple(builds),
    )


# ---- Blizzard pipe-delimited version feed -------------------------------------------------

@dataclass(frozen=True)
class FeedRow:
    region: str
    build_id: int
    versions_name: str


def parse_versions_feed(text: str) -> list[FeedRow]:
    """Parse Blizzard's pipe-delimited feed: header fields look like `Name!TYPE:len`."""
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    if not lines:
        raise ValueError("empty version feed")
    headers = [f.split("!", 1)[0] for f in lines[0].split("|")]
    for need in ("Region", "BuildId", "VersionsName"):
        if need not in headers:
            raise ValueError(f"version feed lacks column {need}")
    rows: list[FeedRow] = []
    for ln in lines[1:]:
        if ln.startswith("##"):
            continue
        vals = ln.split("|")
        if len(vals) != len(headers):
            raise ValueError("malformed version feed row")
        rec = dict(zip(headers, vals))
        rows.append(FeedRow(rec["Region"], int(rec["BuildId"]), rec["VersionsName"]))
    return rows


@dataclass(frozen=True)
class CheckResult:
    checked_at: str
    url: str
    status: str                     # unreachable | checked
    detail: str
    current_build: str | None = None
    registered: bool | None = None  # is current_build in the registry?


def default_fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=30) as resp:  # noqa: S310 (fixed https URL from registry)
        return resp.read().decode("utf-8")


def check_version_service(reg: Registry, fetch: Callable[[str], str] = default_fetch, region: str = "us") -> CheckResult:
    url = reg.version_service.url
    now = utc_now()
    try:
        text = fetch(url)
    except Exception as exc:  # network, HTTP, DNS: all mean "we could not check"
        return CheckResult(now, url, "unreachable", f"{type(exc).__name__}: {exc}")
    try:
        rows = [r for r in parse_versions_feed(text) if r.region == region]
    except ValueError as exc:
        return CheckResult(now, url, "unreachable", f"unparseable feed: {exc}")
    if not rows:
        return CheckResult(now, url, "unreachable", f"feed has no {region!r} row")
    cur = rows[0].versions_name
    return CheckResult(now, url, "checked", f"feed reports {cur} (BuildId {rows[0].build_id})", cur, cur in reg.ids())


def append_log(log_path: Path, result: CheckResult) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with open(log_path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(result.__dict__, sort_keys=True) + "\n")


def effective_registry(reg: Registry, log_path: Path) -> Registry:
    """Registry as of the latest *successful* check. A failed check changes nothing."""
    if not Path(log_path).exists():
        return reg
    latest: dict | None = None
    for ln in Path(log_path).read_text(encoding="utf-8").splitlines():
        if not ln.strip():
            continue
        rec = json.loads(ln)
        if rec.get("status") == "checked":
            latest = rec
    builds = reg.builds
    if latest and latest.get("current_build") in reg.ids():
        builds = tuple(
            replace(b, verification="blizzard_current") if b.id == latest["current_build"] else b
            for b in reg.builds
        )
    return replace(reg, builds=builds)
