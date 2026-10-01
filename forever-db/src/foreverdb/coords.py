"""World <-> UI-map percentage transform from UiMapAssignment, with validation helpers.

Validated in M0 on 14 ATT flight paths (mean error 0.09 map-%): only for assignments whose UI
rectangle is the whole map ((0,0)-(1,1)). Anything else raises UnsupportedAssignment rather than guessing.

    map_x% = 100 * (1 - (world_y - Rmin_y) / (Rmax_y - Rmin_y))
    map_y% = 100 * (1 - (world_x - Rmin_x) / (Rmax_x - Rmin_x))
"""
from __future__ import annotations

import csv
import sqlite3
import statistics
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

TRANSFORM_ID = "uimap_region_v1"


class UnsupportedAssignment(ValueError):
    pass


@dataclass(frozen=True)
class Assignment:
    assignment_id: int
    ui_map_id: int
    map_id: int
    area_id: int
    order_index: int
    ui_min: tuple[float, float]
    ui_max: tuple[float, float]
    region_min: tuple[float, float, float]
    region_max: tuple[float, float, float]

    @property
    def supported(self) -> bool:
        full = self.ui_min == (0.0, 0.0) and self.ui_max == (1.0, 1.0)
        span_ok = self.region_max[0] != self.region_min[0] and self.region_max[1] != self.region_min[1]
        return full and span_ok

    def _check(self) -> None:
        if not self.supported:
            raise UnsupportedAssignment(
                f"assignment {self.assignment_id} (ui_map {self.ui_map_id}) is not a full-map rectangle; "
                "transform not validated for it")

    def world_to_map(self, wx: float, wy: float) -> tuple[float, float]:
        self._check()
        (x0, y0, _), (x1, y1, _) = self.region_min, self.region_max
        return 100.0 * (1.0 - (wy - y0) / (y1 - y0)), 100.0 * (1.0 - (wx - x0) / (x1 - x0))

    def map_to_world(self, x_pct: float, y_pct: float) -> tuple[float, float]:
        self._check()
        (x0, y0, _), (x1, y1, _) = self.region_min, self.region_max
        return x0 + (1.0 - y_pct / 100.0) * (x1 - x0), y0 + (1.0 - x_pct / 100.0) * (y1 - y0)


def in_bounds(x: float, y: float, margin: float = 0.0) -> bool:
    return -margin <= x <= 100 + margin and -margin <= y <= 100 + margin


def _f(v: str) -> float:
    return float(v)


def read_assignments(path: Path) -> list[Assignment]:
    out: list[Assignment] = []
    with open(path, newline="", encoding="utf-8-sig") as fh:
        for r in csv.DictReader(fh):
            out.append(Assignment(
                int(r["ID"]), int(r["UiMapID"]), int(r["MapID"]), int(r["AreaID"]), int(r["OrderIndex"]),
                (_f(r["UiMin_0"]), _f(r["UiMin_1"])), (_f(r["UiMax_0"]), _f(r["UiMax_1"])),
                (_f(r["Region_0"]), _f(r["Region_1"]), _f(r["Region_2"])),
                (_f(r["Region_3"]), _f(r["Region_4"]), _f(r["Region_5"])),
            ))
    return out


def select(assignments: Iterable[Assignment], ui_map_id: int, map_id: int | None = None) -> Assignment | None:
    cands = [a for a in assignments if a.ui_map_id == ui_map_id]
    if map_id is not None:
        matching = [a for a in cands if a.map_id == map_id]
        cands = matching or cands
    return min(cands, key=lambda a: a.order_index) if cands else None


def load_assignments_into_db(conn: sqlite3.Connection, assignments: Iterable[Assignment], dataset_id: str) -> int:
    n = 0
    for a in assignments:
        conn.execute(
            "INSERT OR IGNORE INTO client_ui_map_assignment VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (a.assignment_id, dataset_id, a.ui_map_id, a.map_id, a.area_id, a.order_index, *a.ui_min, *a.ui_max,
             *a.region_min, *a.region_max))
        n += 1
    conn.commit()
    return n


def assignments_from_db(conn: sqlite3.Connection, dataset_id: str) -> list[Assignment]:
    out = []
    for r in conn.execute("SELECT * FROM client_ui_map_assignment WHERE dataset_id=?", (dataset_id,)):
        out.append(Assignment(r["assignment_id"], r["ui_map_id"], r["map_id"], r["area_id"], r["order_index"],
                              (r["ui_min_x"], r["ui_min_y"]), (r["ui_max_x"], r["ui_max_y"]),
                              (r["region_min_x"], r["region_min_y"], r["region_min_z"]),
                              (r["region_max_x"], r["region_max_y"], r["region_max_z"])))
    return out


def derive_coordinates(conn: sqlite3.Connection, transform_dataset_id: str) -> dict[str, int]:
    """Rebuild derived world coordinates for every UI-map-percentage location assertion.

    Derived rows are disposable: the original observation stays untouched in `assertion`.
    """
    import json
    assignments = assignments_from_db(conn, transform_dataset_id)
    conn.execute("DELETE FROM derived_coordinate WHERE transform_id=?", (TRANSFORM_ID,))
    counts = {"ok": 0, "no_assignment": 0, "unsupported_assignment": 0, "out_of_bounds": 0}
    rows = conn.execute("SELECT assertion_id, value_json FROM assertion WHERE field='location.att_coord'").fetchall()
    for r in rows:
        v = json.loads(r["value_json"])
        if v.get("frame") != "uimap_pct" or v.get("ui_map_id") is None:
            status, wx, wy, map_id = "no_assignment", None, None, None
        else:
            a = select(assignments, v["ui_map_id"])
            if a is None:
                status, wx, wy, map_id = "no_assignment", None, None, None
            elif not in_bounds(v["x"], v["y"]):
                status, wx, wy, map_id = "out_of_bounds", None, None, a.map_id
            else:
                try:
                    wx, wy = a.map_to_world(v["x"], v["y"])
                    status, map_id = "ok", a.map_id
                except UnsupportedAssignment:
                    status, wx, wy, map_id = "unsupported_assignment", None, None, a.map_id
        conn.execute("INSERT INTO derived_coordinate VALUES (?,?,?,?,?,?,?,?)",
                     (r["assertion_id"], TRANSFORM_ID, transform_dataset_id, (v or {}).get("ui_map_id"), map_id, wx, wy, status))
        counts[status] += 1
    conn.commit()
    return counts


# ---- validation --------------------------------------------------------------------------

def flight_path_points_from_db(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    """ATT flight-path map% observations joined with the client's world position for the same node ID."""
    import json
    pts: list[dict[str, Any]] = []
    for r in conn.execute("""SELECT a.entity_id node_id, a.value_json v, t.name, t.continent_id map_id, t.world_x, t.world_y
                             FROM assertion a JOIN client_taxi_node t ON t.node_id=a.entity_id
                             WHERE a.entity_type='taxi_node' AND a.field='location.att_coord' ORDER BY a.entity_id"""):
        v = json.loads(r["v"])
        if v.get("ui_map_id") is None:
            continue
        pts.append({"node_id": r["node_id"], "name": r["name"], "ui_map_id": v["ui_map_id"], "map_id": r["map_id"],
                    "obs_x": v["x"], "obs_y": v["y"], "world_x": r["world_x"], "world_y": r["world_y"]})
    return pts


def validate_flight_paths(points: list[dict[str, Any]], assignments: list[Assignment]) -> dict[str, Any]:
    """points: {node_id, name, ui_map_id, map_id, obs_x, obs_y, world_x, world_y} (obs = ATT map %)."""
    rows, skipped = [], []
    for p in points:
        a = select(assignments, p["ui_map_id"], p["map_id"])
        if a is None:
            skipped.append({"node_id": p["node_id"], "reason": "no_assignment"})
            continue
        try:
            px, py = a.world_to_map(p["world_x"], p["world_y"])
        except UnsupportedAssignment:
            skipped.append({"node_id": p["node_id"], "reason": "unsupported_assignment"})
            continue
        rows.append({"node_id": p["node_id"], "name": p["name"], "ui_map_id": p["ui_map_id"],
                     "predicted": [round(px, 2), round(py, 2)], "observed": [p["obs_x"], p["obs_y"]],
                     "abs_err": [round(abs(px - p["obs_x"]), 3), round(abs(py - p["obs_y"]), 3)]})
    errs = [e for r in rows for e in r["abs_err"]]
    per_map: dict[int, int] = {}
    for r in rows:
        per_map[r["ui_map_id"]] = per_map.get(r["ui_map_id"], 0) + 1
    return {
        "n": len(rows), "skipped": skipped,
        "mean_abs_err_map_pct": round(statistics.fmean(errs), 3) if errs else None,
        "max_abs_err_map_pct": round(max(errs), 3) if errs else None,
        "points_per_ui_map": {str(k): v for k, v in sorted(per_map.items())},
        "points": rows,
    }


def containment_check(nodes: list[dict[str, Any]], assignments: list[Assignment], ui_map_names: dict[int, str],
                      ui_map_ids: list[int], aliases: dict[int, list[str]] | None = None) -> dict[str, Any]:
    """WEAK check: taxi nodes whose *name* mentions the zone must fall inside that zone's region.

    This proves consistency of the region rectangle with client naming. It does NOT validate accuracy.
    """
    out: dict[str, Any] = {}
    for ui in ui_map_ids:
        name = ui_map_names.get(ui)
        a = select(assignments, ui)
        terms = [t for t in [name, *(aliases or {}).get(ui, [])] if t]
        entry: dict[str, Any] = {"ui_map_name": name, "name_terms": terms,
                                 "assignment": "none" if a is None else ("ok" if a.supported else "unsupported")}
        if a is None or not a.supported or not name:
            entry["nodes"] = []
            out[str(ui)] = entry
            continue
        hits = []
        for n in nodes:
            if any(t.lower() in (n["name"] or "").lower() for t in terms) and n["continent_id"] == a.map_id:
                x, y = a.world_to_map(n["world_x"], n["world_y"])
                hits.append({"node_id": n["node_id"], "name": n["name"], "map_pct": [round(x, 1), round(y, 1)], "inside": in_bounds(x, y)})
        entry["nodes"] = hits
        entry["all_inside"] = all(h["inside"] for h in hits) if hits else None
        out[str(ui)] = entry
    return out
