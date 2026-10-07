"""Assertions: what a source said about an entity field. Competing observations coexist."""
from __future__ import annotations

import hashlib
import json
import sqlite3
from dataclasses import dataclass
from typing import Any

from . import policy
from .provenance import utc_now


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def value_hash(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()[:16]


@dataclass(frozen=True)
class AssertionInput:
    entity_type: str
    entity_id: int
    field: str
    value: Any
    source_kind: str
    source_dataset_id: str
    confidence: str
    source_locator: str = ""
    status: str = "imported_unverified"
    observed_build_id: str | None = None
    claimed_build_id: str | None = None
    claim_basis: str | None = None
    method: str = ""
    supersedes_id: int | None = None


def add_assertion(conn: sqlite3.Connection, a: AssertionInput) -> int | None:
    """Insert; returns the new id, or None if the identical observation from this source/locator exists."""
    if a.source_kind not in policy.SOURCE_KINDS:
        raise ValueError(f"bad source_kind {a.source_kind!r}")
    if a.status not in policy.STATUSES:
        raise ValueError(f"bad status {a.status!r}")
    if a.confidence not in policy.CONFIDENCES:
        raise ValueError(f"bad confidence {a.confidence!r}")
    cur = conn.execute(
        """INSERT OR IGNORE INTO assertion(entity_type, entity_id, field, value_json, value_hash, source_kind,
             source_dataset_id, source_locator, observed_build_id, claimed_build_id, claim_basis, method, status,
             confidence, supersedes_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (a.entity_type, a.entity_id, a.field, canonical_json(a.value), value_hash(a.value), a.source_kind,
         a.source_dataset_id, a.source_locator, a.observed_build_id, a.claimed_build_id, a.claim_basis, a.method,
         a.status, a.confidence, a.supersedes_id, utc_now()),
    )
    return cur.lastrowid if cur.rowcount else None


def set_status(conn: sqlite3.Connection, assertion_id: int, new_status: str, reason: str) -> None:
    if new_status not in policy.STATUSES:
        raise ValueError(f"bad status {new_status!r}")
    row = conn.execute("SELECT status FROM assertion WHERE assertion_id=?", (assertion_id,)).fetchone()
    if row is None:
        raise KeyError(assertion_id)
    conn.execute("UPDATE assertion SET status=? WHERE assertion_id=?", (new_status, assertion_id))
    conn.execute(
        "INSERT INTO assertion_status_log(assertion_id, old_status, new_status, changed_at, reason) VALUES (?,?,?,?,?)",
        (assertion_id, row["status"], new_status, utc_now(), reason),
    )


def _row(r: sqlite3.Row) -> dict[str, Any]:
    d = dict(r)
    d["value"] = json.loads(d.pop("value_json"))
    return d


def history(conn: sqlite3.Connection, entity_type: str, entity_id: int, field: str | None = None) -> list[dict[str, Any]]:
    """Every assertion ever recorded, including superseded and rejected ones."""
    q = "SELECT * FROM assertion WHERE entity_type=? AND entity_id=?"
    args: list[Any] = [entity_type, entity_id]
    if field is not None:
        q += " AND field=?"
        args.append(field)
    return [_row(r) for r in conn.execute(q + " ORDER BY field, assertion_id", args)]


def resolve(conn: sqlite3.Connection, entity_type: str, entity_id: int, field: str | None = None) -> dict[str, dict[str, Any]]:
    """Per field: the strongest tier ('winners') and everything else still on record ('others').

    Nothing is dropped from the database; excluded statuses are simply not candidates.
    """
    by_field: dict[str, list[tuple[int, dict[str, Any]]]] = {}
    for a in history(conn, entity_type, entity_id, field):
        rk = policy.rank(a["source_kind"], a["confidence"], a["status"])
        if rk is None:
            continue
        a["rank"] = rk
        by_field.setdefault(a["field"], []).append((rk, a))
    out: dict[str, dict[str, Any]] = {}
    for fld, items in by_field.items():
        top = max(rk for rk, _ in items)
        winners = [a for rk, a in items if rk == top]
        winners.sort(key=lambda a: (a["observed_build_id"] or "", a["assertion_id"]), reverse=True)
        out[fld] = {"winners": winners, "others": [a for rk, a in items if rk != top]}
    return out
