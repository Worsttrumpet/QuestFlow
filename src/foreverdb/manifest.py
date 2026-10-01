"""DB2 table manifest: which tables exist in a source, row counts, columns. Metadata only."""
from __future__ import annotations

import csv
import json
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .provenance import sha256_file

csv.field_size_limit(1 << 30)
LOCALES = ("deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW", "enUS", "enGB")


@dataclass(frozen=True)
class TableProbe:
    table: str
    row_count: int
    columns: tuple[str, ...]
    sha256: str
    size_bytes: int


@dataclass(frozen=True)
class TableSpec:
    name: str
    why: str
    priority: int


@dataclass(frozen=True)
class SourceSet:
    """A directory of `<Table>.<build>.csv` files and how much we trust its labels."""
    label: str              # e.g. "att-head"
    kind: str               # git | wago | user_file
    uri: str
    ref: str                # commit sha
    directory: Path
    rel_dir: str
    build_claim: str        # the build the FILENAMES claim
    claim_basis: str
    origin: str             # mirror | direct | user_supplied
    mirror_of: str | None


def load_table_specs(path: Path) -> list[TableSpec]:
    raw = tomllib.loads(Path(path).read_text(encoding="utf-8"))
    return [TableSpec(t["name"], t["why"], int(t["priority"])) for t in raw["table"]]


def probe_csv(path: Path, table: str | None = None) -> TableProbe:
    path = Path(path)
    with open(path, newline="", encoding="utf-8-sig") as fh:
        reader = csv.reader(fh)
        try:
            header = next(reader)
        except StopIteration:
            raise ValueError(f"{path} is empty") from None
        rows = sum(1 for _ in reader)
    name = table or path.name.split(".")[0]
    return TableProbe(name, rows, tuple(header), sha256_file(path), path.stat().st_size)


def _table_files(directory: Path, build: str) -> dict[str, Path]:
    """Map table name -> file for `<Table>.<build>.csv`, excluding localized variants."""
    out: dict[str, Path] = {}
    suffix = f".{build}.csv"
    for p in sorted(Path(directory).glob(f"*{suffix}")):
        stem = p.name[: -len(suffix)]
        parts = stem.split(".")
        if len(parts) > 1 and parts[-1] in LOCALES:
            continue
        out[stem] = p
    return out


def build_manifest(specs: list[TableSpec], src: SourceSet) -> dict[str, Any]:
    files = _table_files(src.directory, src.build_claim)
    tables: list[dict[str, Any]] = []
    wanted = {s.name for s in specs}
    for spec in sorted(specs, key=lambda s: s.name):
        f = files.get(spec.name)
        if f is None:
            tables.append({
                "table": spec.name, "priority": spec.priority, "status": "not_probed", "exists": None,
                "reason": "no file in this source; absence here proves nothing about the client",
            })
            continue
        p = probe_csv(f, spec.name)
        tables.append({
            "table": spec.name, "priority": spec.priority, "status": "read", "exists": True,
            "row_count": p.row_count, "columns": list(p.columns), "sha256": p.sha256, "size_bytes": p.size_bytes,
        })
    extra = []
    for name, f in files.items():
        if name not in wanted:
            p = probe_csv(f, name)
            extra.append({"table": name, "row_count": p.row_count, "columns": list(p.columns), "sha256": p.sha256})
    return {
        "manifest_version": 1,
        "source": {
            "label": src.label, "kind": src.kind, "uri": src.uri, "ref": src.ref, "path": src.rel_dir,
            "origin": src.origin, "mirror_of": src.mirror_of,
            "read_first_hand": True,
            "build_claim": src.build_claim, "claim_basis": src.claim_basis, "build_claim_verified": False,
        },
        "tables": tables,
        "extra_tables_present": sorted(extra, key=lambda d: d["table"]),
    }


def _index(m: dict[str, Any]) -> dict[str, dict[str, Any]]:
    idx = {t["table"]: t for t in m["tables"] if t.get("status") == "read"}
    for t in m.get("extra_tables_present", []):
        idx.setdefault(t["table"], t)
    return idx


def diff_manifests(a: dict[str, Any], b: dict[str, Any]) -> dict[str, Any]:
    ia, ib = _index(a), _index(b)
    identical, changed = [], []
    for name in sorted(set(ia) & set(ib)):
        ta, tb = ia[name], ib[name]
        if ta["sha256"] == tb["sha256"]:
            identical.append(name)
            continue
        ca, cb = list(ta["columns"]), list(tb["columns"])
        changed.append({
            "table": name,
            "row_count": [ta["row_count"], tb["row_count"]],
            "columns_added": [c for c in cb if c not in ca],
            "columns_removed": [c for c in ca if c not in cb],
        })
    warnings: list[str] = []
    la, lb = a["source"]["build_claim"], b["source"]["build_claim"]
    if la != lb and identical and (a["source"]["origin"] == "mirror" or b["source"]["origin"] == "mirror"):
        warnings.append(
            f"{len(identical)} tables are byte-identical across build labels {la} and {lb} in a mirrored source. "
            "This cannot distinguish 'unchanged in the game' from 'file relabelled without re-download'."
        )
    return {
        "a": {"label": a["source"]["label"], "ref": a["source"]["ref"], "build_claim": la},
        "b": {"label": b["source"]["label"], "ref": b["source"]["ref"], "build_claim": lb},
        "identical_content": identical,
        "changed": changed,
        "added": sorted(set(ib) - set(ia)),
        "removed": sorted(set(ia) - set(ib)),
        "warnings": warnings,
    }


def write_json(path: Path, obj: Any) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(obj, indent=2, sort_keys=True) + "\n", encoding="utf-8")
