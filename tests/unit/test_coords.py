import json

import pytest

from conftest import write_csv
from foreverdb import assertions as A, coords as C, db
from foreverdb.provenance import DatasetRecord

HEADER = ["UiMin_0", "UiMin_1", "UiMax_0", "UiMax_1", "Region_0", "Region_1", "Region_2", "Region_3", "Region_4", "Region_5",
          "ID", "UiMapID", "OrderIndex", "MapID", "AreaID", "WMODoodadPlacementID", "WMOGroupID", "Field_x"]


def asg(**kw):
    d = dict(assignment_id=1, ui_map_id=100, map_id=0, area_id=1, order_index=0, ui_min=(0.0, 0.0), ui_max=(1.0, 1.0),
             region_min=(-1000.0, -2000.0, 0.0), region_max=(1000.0, 2000.0, 100.0))
    d.update(kw)
    return C.Assignment(**d)


def test_orientation_and_corners():
    a = asg()
    assert a.world_to_map(0, 0) == pytest.approx((50, 50))
    # map x runs against world y, map y runs against world x (the orientation validated in M0)
    assert a.world_to_map(-1000, 2000) == pytest.approx((0, 100))
    assert a.world_to_map(1000, -2000) == pytest.approx((100, 0))


def test_round_trip():
    a = asg()
    for wx, wy in [(-999, -1999), (0, 0), (123.4, -777.7), (1000, 2000)]:
        x, y = a.world_to_map(wx, wy)
        assert a.map_to_world(x, y) == pytest.approx((wx, wy))


def test_partial_rectangles_are_refused_not_guessed():
    a = asg(ui_max=(0.5, 1.0))
    assert not a.supported
    with pytest.raises(C.UnsupportedAssignment):
        a.world_to_map(0, 0)
    with pytest.raises(C.UnsupportedAssignment):
        a.map_to_world(1, 1)
    assert not asg(region_max=(-1000.0, 2000.0, 0.0)).supported          # zero-width region


def test_select_prefers_matching_map_then_lowest_order():
    xs = [asg(assignment_id=1, ui_map_id=5, map_id=1, order_index=2), asg(assignment_id=2, ui_map_id=5, map_id=1, order_index=0),
          asg(assignment_id=3, ui_map_id=5, map_id=0, order_index=0)]
    assert C.select(xs, 5).assignment_id in (2, 3)
    assert C.select(xs, 5, map_id=1).assignment_id == 2
    assert C.select(xs, 9) is None


def test_read_assignments_from_csv(tmp_path):
    p = write_csv(tmp_path / "U.csv", HEADER, [[0, 0, 1, 1, -1000, -2000, 0, 1000, 2000, 100, 7, 100, 0, 0, 12, 0, 0, 0]], bom=True)
    (a,) = C.read_assignments(p)
    assert (a.assignment_id, a.ui_map_id, a.map_id, a.supported) == (7, 100, 0, True)
    assert a.region_max == (1000.0, 2000.0, 100.0)


def _ds(conn):
    return db.insert_dataset(conn, DatasetRecord("git", "u", "r" * 40, "p", "2026-01-01T00:00:00Z", "e" * 64, None, 1, True, "mirror", "wago.tools",
                                                 "unresolved", "unresolved", None, "1.60.1.69913", "label"))


def test_derived_coordinates_are_separate_and_rebuildable(conn):
    ds = _ds(conn)
    C.load_assignments_into_db(conn, [asg(), asg(assignment_id=2, ui_map_id=200, ui_max=(0.5, 1.0))], ds)
    obs = [{"frame": "uimap_pct", "ui_map_id": 100, "x": 50.0, "y": 50.0},          # ok
           {"frame": "uimap_pct", "ui_map_id": 999, "x": 1.0, "y": 1.0},             # no assignment
           {"frame": "uimap_pct", "ui_map_id": 200, "x": 1.0, "y": 1.0},             # unsupported
           {"frame": "uimap_pct", "ui_map_id": 100, "x": 150.0, "y": 5.0},           # out of bounds
           {"frame": "uimap_pct", "ui_map_id": None, "x": 1.0, "y": 1.0}]            # unresolved map symbol
    for i, v in enumerate(obs):
        A.add_assertion(conn, A.AssertionInput("quest", 1, "location.att_coord", v, "third_party_import", ds, "third_party_unverified", f"l:{i}"))
    before = [dict(r) for r in conn.execute("SELECT * FROM assertion ORDER BY assertion_id")]
    counts = C.derive_coordinates(conn, ds)
    assert counts == {"ok": 1, "no_assignment": 2, "unsupported_assignment": 1, "out_of_bounds": 1}
    ok = conn.execute("SELECT * FROM derived_coordinate WHERE status='ok'").fetchone()
    assert (ok["world_x"], ok["world_y"], ok["map_id"]) == pytest.approx((0.0, 0.0, 0))
    assert C.derive_coordinates(conn, ds) == counts                                    # rebuild, no duplicates
    assert conn.execute("SELECT COUNT(*) FROM derived_coordinate").fetchone()[0] == 5
    assert [dict(r) for r in conn.execute("SELECT * FROM assertion ORDER BY assertion_id")] == before   # observations untouched


def test_flight_path_validation_detects_correct_and_wrong_transforms():
    a = asg()
    pts = []
    for i, (wx, wy) in enumerate([(-500, -1000), (300, 1500), (900, -1900)]):
        x, y = a.world_to_map(wx, wy)
        pts.append({"node_id": i, "name": f"n{i}", "ui_map_id": 100, "map_id": 0, "obs_x": round(x, 1), "obs_y": round(y, 1),
                    "world_x": wx, "world_y": wy})
    good = C.validate_flight_paths(pts, [a])
    assert good["n"] == 3 and good["max_abs_err_map_pct"] < 0.1 and good["points_per_ui_map"] == {"100": 3}
    swapped = [dict(p, obs_x=p["obs_y"], obs_y=p["obs_x"]) for p in pts]
    assert C.validate_flight_paths(swapped, [a])["mean_abs_err_map_pct"] > 5
    unsupported = C.validate_flight_paths(pts, [asg(ui_max=(0.5, 1.0))])
    assert unsupported["n"] == 0 and unsupported["skipped"][0]["reason"] == "unsupported_assignment"
    assert C.validate_flight_paths(pts, [])["skipped"][0]["reason"] == "no_assignment"


def test_containment_is_a_weak_named_check():
    a = asg(ui_map_id=1412)
    nodes = [{"node_id": 1, "name": "Village, Testland", "continent_id": 0, "world_x": 0.0, "world_y": 0.0},
             {"node_id": 2, "name": "Faraway, Testland", "continent_id": 0, "world_x": 9999.0, "world_y": 0.0},
             {"node_id": 3, "name": "Other, Elsewhere", "continent_id": 0, "world_x": 0.0, "world_y": 0.0},
             {"node_id": 4, "name": "Wrong map, Testland", "continent_id": 1, "world_x": 0.0, "world_y": 0.0}]
    out = C.containment_check(nodes, [a], {1412: "Testland"}, [1412, 1423])
    assert [n["node_id"] for n in out["1412"]["nodes"]] == [1, 2] and out["1412"]["all_inside"] is False
    assert out["1423"]["assignment"] == "none" and out["1423"]["nodes"] == []


def test_containment_aliases_are_explicit_and_reported():
    a = asg(ui_map_id=1433)
    nodes = [{"node_id": 5, "name": "Lakeshire, Redridge", "continent_id": 0, "world_x": 0.0, "world_y": 0.0}]
    assert C.containment_check(nodes, [a], {1433: "Redridge Mountains"}, [1433])["1433"]["nodes"] == []          # name alone misses it
    out = C.containment_check(nodes, [a], {1433: "Redridge Mountains"}, [1433], {1433: ["Redridge"]})["1433"]
    assert [n["node_id"] for n in out["nodes"]] == [5] and out["name_terms"] == ["Redridge Mountains", "Redridge"]
