"""Loaders for the few client tables M1 needs: TaxiNodes and UiMap (UiMapAssignment lives in coords.py)."""
from __future__ import annotations

import csv
import sqlite3
from pathlib import Path


def load_taxi_nodes(conn: sqlite3.Connection, path: Path, dataset_id: str) -> int:
    n = 0
    with open(path, newline="", encoding="utf-8-sig") as fh:
        for r in csv.DictReader(fh):
            conn.execute(
                "INSERT OR IGNORE INTO client_taxi_node(node_id, dataset_id, name, continent_id, world_x, world_y, world_z) "
                "VALUES (?,?,?,?,?,?,?)",
                (int(r["ID"]), dataset_id, r["Name_lang"], int(r["ContinentID"]),
                 float(r["Pos_0"]), float(r["Pos_1"]), float(r["Pos_2"])))
            n += 1
    conn.commit()
    return n


def load_ui_maps(conn: sqlite3.Connection, path: Path, dataset_id: str) -> int:
    n = 0
    with open(path, newline="", encoding="utf-8-sig") as fh:
        for r in csv.DictReader(fh):
            conn.execute("INSERT OR IGNORE INTO client_ui_map(ui_map_id, dataset_id, name, parent_ui_map_id) VALUES (?,?,?,?)",
                         (int(r["ID"]), dataset_id, r["Name_lang"], int(r["ParentUiMapID"])))
            n += 1
    conn.commit()
    return n
