"""ATT Forever data -> assertions.

Design rules (M1):
* every value is stored as ATT said it, with file:line provenance;
* fields whose meaning is not established are named ``att.*`` or ``*_unverified``;
* item children are NOT rewards, and ``lvl`` is NOT the quest level, until verified;
* nothing is filtered: quests absent from the client table are flagged by the shell view, not dropped;
* Questie, ForeverGuide, RestedXP and Wowhead data are never read here.
"""
from __future__ import annotations

import re
import sqlite3
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterator

from .. import db, quests
from ..acquire import SnapshotInfo, snapshot_record
from ..assertions import AssertionInput, add_assertion
from ..provenance import DatasetRecord, sha256_file, utc_now
from .dsl import Call, Ident, Opaque, Table, parse_source, walk_calls

EXCLUDED_DIRS = frozenset({".config", "zzOLD"})
FLAG_KEYS = ("isBreadcrumb", "repeatable", "isYearly", "isMonthly", "isWeekly", "isDaily")
RAW_KEYS = ("provider", "providers", "qi", "qis", "qs", "cr", "crs")
CLAIM_BASIS = "ATT forever.config DataPatch"


def read_constants(path: Path) -> dict[str, int]:
    text = Path(path).read_text(encoding="utf-8-sig", errors="replace")
    return {m.group(1): int(m.group(2)) for m in re.finditer(r"\b([A-Z][A-Z0-9_]*)\s*=\s*(\d+)\s*[;,]", text)}


def read_data_patch(path: Path) -> str | None:
    text = Path(path).read_text(encoding="utf-8-sig", errors="replace")
    m = re.search(r'"DataPatch"\s*:\s*\[\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]', text)
    return ".".join(m.groups()) if m else None


def iter_data_files(forever_root: Path) -> Iterator[Path]:
    for p in sorted(Path(forever_root).rglob("*.lua")):
        if EXCLUDED_DIRS.intersection(p.relative_to(forever_root).parts):
            continue
        yield p


def _plain(v: Any) -> Any:
    if isinstance(v, Ident):
        return {"symbol": v.name}
    if isinstance(v, Opaque):
        return {"expr": v.text}
    if isinstance(v, Call):
        return {"call": v.name, "args": [_plain(a) for a in v.args]}
    if isinstance(v, Table):
        if v.kv and not v.pos:
            return {k: _plain(x) for k, x in v.kv.items()}
        if v.kv:
            return {"pos": [_plain(x) for x in v.pos], "kv": {k: _plain(x) for k, x in v.kv.items()}}
        return [_plain(x) for x in v.pos]
    return v


def _ints(v: Any) -> list[int]:
    if isinstance(v, int) and not isinstance(v, bool):
        return [v]
    if isinstance(v, Table):
        return [x for x in v.pos if isinstance(x, int) and not isinstance(x, bool)]
    return []


def _map_ref(v: Any, constants: dict[str, int]) -> tuple[int | None, str | None]:
    if isinstance(v, int) and not isinstance(v, bool):
        return v, None
    if isinstance(v, Ident):
        return constants.get(v.name.split(".")[-1]), v.name
    return None, None


def coords_of(value: Any, constants: dict[str, int]) -> list[dict[str, Any]]:
    """Normalise ATT's `coord = {x, y, map}` and `coords = { {x, y, map}, ... }` to one shape."""
    if not isinstance(value, Table):
        return []
    items = value.pos if value.pos and all(isinstance(p, Table) for p in value.pos) else [value]
    out = []
    for c in items:
        if not isinstance(c, Table) or len(c.pos) < 2:
            continue
        x, y = c.pos[0], c.pos[1]
        if isinstance(x, bool) or isinstance(y, bool) or not isinstance(x, (int, float)) or not isinstance(y, (int, float)):
            continue
        ui, sym = _map_ref(c.pos[2] if len(c.pos) > 2 else None, constants)
        out.append({"frame": "uimap_pct", "ui_map_id": ui, "ui_map_symbol": sym, "x": float(x), "y": float(y)})
    return out


def normalize_name(raw: str) -> str:
    """Strip ATT's trailing '[Zone]' decoration. The raw comment is always kept too."""
    return re.sub(r"\s*\[[^\]]+\]\s*$", "", raw).strip()


def _targets(kv: dict[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    prov = kv.get("provider")
    if isinstance(prov, Table) and len(prov.pos) >= 2:
        out.append({"kind": _plain(prov.pos[0]), "id": _plain(prov.pos[1])})
    provs = kv.get("providers")
    if isinstance(provs, Table):
        for p in provs.pos:
            if isinstance(p, Table) and len(p.pos) >= 2:
                out.append({"kind": _plain(p.pos[0]), "id": _plain(p.pos[1])})
    for key in ("cr", "crs"):
        for i in _ints(kv.get(key)):
            out.append({"kind": "cr", "id": i})
    return out


@dataclass
class ImportReport:
    files: int = 0
    parse_errors: list[str] = field(default_factory=list)
    quest_records: int = 0
    quest_ids: set[int] = field(default_factory=set)
    fp_records: int = 0
    assertions_added: int = 0
    assertions_duplicate: int = 0
    by_field: Counter = field(default_factory=Counter)
    unmapped_keys: Counter = field(default_factory=Counter)
    unmapped_child_calls: Counter = field(default_factory=Counter)

    def summary(self) -> dict[str, Any]:
        return {
            "files": self.files, "parse_errors": len(self.parse_errors), "quest_records": self.quest_records,
            "unique_quest_ids": len(self.quest_ids), "flight_path_records": self.fp_records,
            "assertions_added": self.assertions_added, "assertions_duplicate": self.assertions_duplicate,
            "by_field": dict(sorted(self.by_field.items())),
            "unmapped_quest_keys": dict(sorted(self.unmapped_keys.items())),
            "unmapped_group_calls": dict(sorted(self.unmapped_child_calls.items())),
        }


def quest_facts(call: Call, constants: dict[str, int], report: ImportReport) -> list[tuple[str, Any, int, str]]:
    """(field, value, line, method) for one q() call."""
    body = call.args[1] if len(call.args) > 1 and isinstance(call.args[1], Table) else Table([], {}, call.line)
    facts: list[tuple[str, Any, int, str]] = []
    if call.comment:
        facts.append(("name.att_comment", {"raw": call.comment, "normalized": normalize_name(call.comment)}, call.line, "code_comment"))
    for key in sorted(body.kv):
        val = body.kv[key]
        if key in ("qg", "qgs"):
            facts += [("giver.npc", {"npc_id": i}, call.line, "att_dsl_field") for i in _ints(val)]
        elif key in ("coord", "coords"):
            facts += [("location.att_coord", c, call.line, "att_dsl_field") for c in coords_of(val, constants)]
        elif key == "lvl":
            # ATT uses expressions here (e.g. lvlsquish(30, 30, 10)) and named constants, so the raw form is kept.
            facts.append(("level.att_lvl_unverified", _plain(val), call.line, "att_dsl_field"))
        elif key in ("sourceQuest", "sourceQuests"):
            facts += [("relation.att_source_quest", {"quest_id": i}, call.line, "att_dsl_field") for i in _ints(val)]
        elif key == "altQuests":
            facts += [("relation.att_alt_quest", {"quest_id": i}, call.line, "att_dsl_field") for i in _ints(val)]
        elif key in FLAG_KEYS:
            facts.append((f"att.flag.{key}", _plain(val), call.line, "att_dsl_field"))
        elif key in ("races", "classes"):
            facts.append((f"att.restriction.{key}", _plain(val), call.line, "att_dsl_field"))
        elif key in RAW_KEYS:
            facts.append((f"att.{key}", _plain(val), call.line, "att_dsl_field"))
        elif key == "groups":
            pass
        else:
            report.unmapped_keys[key] += 1
    groups = body.kv.get("groups")
    if isinstance(groups, Table):
        for child in groups.pos:
            if not isinstance(child, Call):
                continue
            if child.name == "objective":
                cbody = child.args[1] if len(child.args) > 1 and isinstance(child.args[1], Table) else Table([], {}, child.line)
                idx = child.args[0] if child.args and isinstance(child.args[0], int) else None
                facts.append(("objective.att", {
                    "index": idx, "targets": _targets(cbody.kv),
                    "coords": [c for k in ("coord", "coords") for c in coords_of(cbody.kv.get(k), constants)],
                    "other_keys": sorted(k for k in cbody.kv if k not in ("provider", "providers", "cr", "crs", "coord", "coords")),
                }, child.line, "att_dsl_call"))
            elif child.name == "i" and child.args and isinstance(child.args[0], int):
                facts.append(("att.item_child_unverified", {"item_id": child.args[0]}, child.line, "att_dsl_call"))
            elif child.name == "i" and child.args:
                facts.append(("att.item_child_unverified", {"item_ref": _plain(child.args[0])}, child.line, "att_dsl_call"))
            elif child.name == "q":
                pass    # nested quest: imported as its own record when the walk reaches it
            else:
                report.unmapped_child_calls[child.name] += 1
    return facts


def fp_facts(call: Call, constants: dict[str, int]) -> list[tuple[str, Any, int, str]]:
    body = call.args[1] if len(call.args) > 1 and isinstance(call.args[1], Table) else Table([], {}, call.line)
    facts: list[tuple[str, Any, int, str]] = []
    for key in sorted(body.kv):
        val = body.kv[key]
        if key == "cr":
            facts += [("flight_master.att_cr", {"npc_id": i}, call.line, "att_dsl_field") for i in _ints(val)]
        elif key in ("coord", "coords"):
            facts += [("location.att_coord", c, call.line, "att_dsl_field") for c in coords_of(val, constants)]
        elif key == "races":
            facts.append(("att.restriction.races", _plain(val), call.line, "att_dsl_field"))
    if call.comment:
        facts.append(("name.att_comment", {"raw": call.comment, "normalized": normalize_name(call.comment)}, call.line, "code_comment"))
    return facts


def import_att_snapshot(conn: sqlite3.Connection, info: SnapshotInfo, forever_rel: str, constants_rel: str, config_rel: str) -> ImportReport:
    report = ImportReport()
    root = info.root
    constants = read_constants(root / constants_rel)
    patch = read_data_patch(root / config_rel)
    db.insert_dataset(conn, snapshot_record(info))
    for path in iter_data_files(root / forever_rel):
        rel = path.relative_to(root).as_posix()
        rec = DatasetRecord(
            source_kind="git", source_uri=info.repo_url, source_ref=info.sha, path_in_source=rel, retrieved_at=utc_now(),
            sha256=sha256_file(path), content_id=None, size_bytes=path.stat().st_size, first_hand=True, origin="direct",
            mirror_of=None, license_id=info.license_id, license_status=info.license_status, redistributable=None,
            claimed_build_id=patch, claim_basis=CLAIM_BASIS if patch else None, build_claim_verified=False,
            notes=f"ATT-authored file; upstream provenance of its values: {info.upstream_provenance}",
        )
        ds = db.insert_dataset(conn, rec)
        parsed = parse_source(path.read_text(encoding="utf-8-sig", errors="replace"))
        report.files += 1
        report.parse_errors += [f"{rel}: {e}" for e in parsed.errors]
        saw_quest = False
        for call in walk_calls(parsed.calls):
            if call.name == "q" and call.args and isinstance(call.args[0], int):
                etype, eid, facts = "quest", call.args[0], quest_facts(call, constants, report)
                report.quest_records += 1
                report.quest_ids.add(eid)
                quests.add_evidence(conn, eid, "att_observed", ds, f"{rel}:{call.line}")
                saw_quest = True
            elif call.name == "fp" and call.args and isinstance(call.args[0], int):
                etype, eid, facts = "taxi_node", call.args[0], fp_facts(call, constants)
                report.fp_records += 1
            else:
                continue
            for fld, val, line, method in facts:
                new = add_assertion(conn, AssertionInput(
                    entity_type=etype, entity_id=eid, field=fld, value=val, source_kind="third_party_import",
                    source_dataset_id=ds, confidence="third_party_unverified", source_locator=f"{rel}:{line}",
                    claimed_build_id=patch, claim_basis=CLAIM_BASIS if patch else None, method=method))
                if new is None:
                    report.assertions_duplicate += 1
                else:
                    report.assertions_added += 1
                    report.by_field[fld] += 1
        if saw_quest:
            quests.register_scope(conn, "att_observed", ds)
    conn.commit()
    return report


def crosscheck_ids(forever_root: Path) -> dict[str, Any]:
    """Compare parser output with an independent regex scan, so parser gaps cannot silently drop records."""
    from .dsl import parse_source, walk_calls

    def strip(src: str) -> str:
        src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
        return re.sub(r"--[^\n]*", "", src)

    rq: set[int] = set(); rf: set[int] = set(); pq: set[int] = set(); pf: set[int] = set()
    for path in iter_data_files(forever_root):
        src = path.read_text(encoding="utf-8-sig", errors="replace")
        text = strip(src)
        rq |= {int(x) for x in re.findall(r"\bq\(\s*(\d+)\s*,", text)}
        rf |= {int(x) for x in re.findall(r"\bfp\(\s*(\d+)\s*,", text)}
        for c in walk_calls(parse_source(src).calls):
            if c.args and isinstance(c.args[0], int):
                (pq if c.name == "q" else pf if c.name == "fp" else set()).add(c.args[0])
    return {
        "regex_quest_ids": len(rq), "parsed_quest_ids": len(pq), "quest_ids_missing_from_parse": sorted(rq - pq),
        "quest_ids_only_parser_found": len(pq - rq),
        "regex_fp_ids": len(rf), "parsed_fp_ids": len(pf), "fp_ids_mismatch": sorted(rf ^ pf),
    }
