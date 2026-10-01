"""Quest shell: one record per observed ID, plus evidence. Flags are derived by view, never stored."""
from __future__ import annotations

import csv
import sqlite3
from pathlib import Path
from typing import Iterable

EVIDENCE_KINDS = ("client_id_observed", "era_baseline", "att_observed", "server_confirmed")


def read_questv2(path: Path) -> list[tuple[int, int | None, int | None]]:
    """Read a QuestV2 CSV: (ID, UniqueBitFlag, UiQuestDetailsThemeID). Extra columns are ignored."""
    out: list[tuple[int, int | None, int | None]] = []
    with open(path, newline="", encoding="utf-8-sig") as fh:
        rd = csv.DictReader(fh)
        if rd.fieldnames is None or "ID" not in rd.fieldnames:
            raise ValueError(f"{path} has no ID column; not a QuestV2 CSV?")

        def _i(v: str | None) -> int | None:
            return int(v) if v not in (None, "") else None

        for r in rd:
            out.append((int(r["ID"]), _i(r.get("UniqueBitFlag")), _i(r.get("UiQuestDetailsThemeID"))))
    return out


def ensure_quest(conn: sqlite3.Connection, quest_id: int) -> None:
    conn.execute("INSERT OR IGNORE INTO quest(quest_id) VALUES (?)", (quest_id,))


def register_scope(conn: sqlite3.Connection, kind: str, dataset_id: str) -> None:
    if kind not in EVIDENCE_KINDS:
        raise ValueError(kind)
    conn.execute("INSERT OR IGNORE INTO evidence_scope(evidence_kind, dataset_id) VALUES (?,?)", (kind, dataset_id))


def add_evidence(conn: sqlite3.Connection, quest_id: int, kind: str, dataset_id: str, locator: str = "") -> None:
    if kind not in EVIDENCE_KINDS:
        raise ValueError(kind)
    ensure_quest(conn, quest_id)
    conn.execute(
        "INSERT OR IGNORE INTO quest_evidence(quest_id, evidence_kind, dataset_id, locator) VALUES (?,?,?,?)",
        (quest_id, kind, dataset_id, locator),
    )


def load_client_questv2(conn: sqlite3.Connection, rows: Iterable[tuple[int, int | None, int | None]],
                        dataset_id: str, claimed_build_id: str | None) -> int:
    """QuestV2 membership = an observed client ID. It is NOT proof the quest is obtainable."""
    n = 0
    for qid, flag, theme in rows:
        ensure_quest(conn, qid)
        conn.execute(
            "INSERT OR IGNORE INTO quest_client_row(quest_id, dataset_id, claimed_build_id, unique_bit_flag, "
            "ui_quest_details_theme_id) VALUES (?,?,?,?,?)", (qid, dataset_id, claimed_build_id, flag, theme))
        conn.execute("INSERT OR IGNORE INTO quest_evidence(quest_id, evidence_kind, dataset_id) "
                     "VALUES (?, 'client_id_observed', ?)", (qid, dataset_id))
        n += 1
    register_scope(conn, "client_id_observed", dataset_id)
    conn.commit()
    return n


def load_era_baseline(conn: sqlite3.Connection, quest_ids: Iterable[int], dataset_id: str) -> int:
    """IDs present in an Era-client QuestV2. Must come from a client table, not from a GPL quest database."""
    n = 0
    for qid in quest_ids:
        ensure_quest(conn, qid)
        conn.execute("INSERT OR IGNORE INTO quest_evidence(quest_id, evidence_kind, dataset_id) "
                     "VALUES (?, 'era_baseline', ?)", (qid, dataset_id))
        n += 1
    register_scope(conn, "era_baseline", dataset_id)
    conn.commit()
    return n


def shell(conn: sqlite3.Connection, quest_id: int) -> dict[str, int | None] | None:
    r = conn.execute("SELECT * FROM v_quest_shell WHERE quest_id=?", (quest_id,)).fetchone()
    return dict(r) if r else None
