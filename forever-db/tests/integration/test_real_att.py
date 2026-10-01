"""Integration tests: need the pinned ATT snapshots acquired outside the repo.

    python -m foreverdb --raw /path/to/raw acquire att-head att-a054efd
    FOREVERDB_RAW=/path/to/raw python -m pytest tests/integration

Skipped automatically when the snapshots are absent.
"""
import os
import tomllib
from pathlib import Path

import pytest

from foreverdb import acquire, cli, client_tables, coords, db, manifest
from foreverdb.att import importer as I

pytestmark = pytest.mark.integration
ROOT = Path(__file__).resolve().parents[2]
RAW = Path(os.environ.get("FOREVERDB_RAW", ROOT / "data" / "raw"))
SOURCES = cli.load_sources(ROOT / "config" / "sources.toml")


def _need(key):
    if not (RAW / key / ".git").exists():
        pytest.skip(f"snapshot {key} not acquired under {RAW}")


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    _need("att-head")
    info, cfg = cli.snapshot_info(ROOT, "att-head", RAW)
    conn = db.connect(":memory:")
    db.init_schema(conn)
    build = cli.snapshot_source_set(info, cfg).build_claim
    for table in ("UiMapAssignment", "TaxiNodes", "UiMap"):
        rel = f"{cfg['wago_dir']}/{table}.{build}.csv"
        ds = db.insert_dataset(conn, acquire.mirrored_csv_record(info, rel, build))
        if table == "UiMapAssignment":
            assignments = coords.read_assignments(info.root / rel)
            coords.load_assignments_into_db(conn, assignments, ds)
            transform_ds = ds
        elif table == "TaxiNodes":
            client_tables.load_taxi_nodes(conn, info.root / rel, ds)
        else:
            client_tables.load_ui_maps(conn, info.root / rel, ds)
    report = I.import_att_snapshot(conn, info, cfg["forever_root"], cfg["constants"], cfg["config"])
    return conn, report, info, cfg, assignments, transform_ds


def test_snapshot_is_the_pinned_commit():
    _need("att-head")
    assert acquire._git(["rev-parse", "HEAD"], RAW / "att-head") == SOURCES["att-head"]["sha"]


def test_import_reproduces_m0_counts_and_loses_no_quest_ids(built):
    conn, report, info, cfg, *_ = built
    assert len(report.quest_ids) == 1537                       # M0 (independent throwaway parser) found the same number
    assert report.fp_records == 14
    check = I.crosscheck_ids(info.root / cfg["forever_root"])
    assert check["quest_ids_missing_from_parse"] == [] and check["fp_ids_mismatch"] == []
    assert len(report.parse_errors) <= 10, report.parse_errors[:5]      # known: one inline Lua function in a dungeon-sets file


def test_all_assertions_are_unverified_third_party_with_claimed_build(built):
    conn, *_ = built
    bad = conn.execute("""SELECT COUNT(*) FROM assertion WHERE source_kind!='third_party_import' OR status!='imported_unverified'
                          OR observed_build_id IS NOT NULL OR claimed_build_id IS NULL""").fetchone()[0]
    assert bad == 0


def test_no_att_level_or_reward_semantics_were_assumed(built):
    conn, *_ = built
    fields = {r[0] for r in conn.execute("SELECT DISTINCT field FROM assertion")}
    assert not {f for f in fields if f.startswith(("level.", "reward"))} - {"level.att_lvl_unverified"}
    assert "att.item_child_unverified" in fields and not any("reward" in f for f in fields)


def test_14_flight_paths_validate(built):
    conn, *_ = built
    pts = coords.flight_path_points_from_db(conn)
    ds = conn.execute("SELECT DISTINCT dataset_id FROM client_ui_map_assignment").fetchone()[0]
    rep = coords.validate_flight_paths(pts, coords.assignments_from_db(conn, ds))
    assert rep["n"] == 14 and rep["skipped"] == []
    assert rep["mean_abs_err_map_pct"] < 0.2 and rep["max_abs_err_map_pct"] < 0.5


def test_extra_maps_are_containment_only_and_limitation_is_recorded(built):
    conn, *_ = built
    ds = conn.execute("SELECT DISTINCT dataset_id FROM client_ui_map_assignment").fetchone()[0]
    assignments = coords.assignments_from_db(conn, ds)
    nodes = [dict(r) for r in conn.execute("SELECT node_id, name, continent_id, world_x, world_y FROM client_taxi_node")]
    names = {r["ui_map_id"]: r["name"] for r in conn.execute("SELECT ui_map_id, name FROM client_ui_map")}
    out = coords.containment_check(nodes, assignments, names, list(cli.VALIDATION_UI_MAPS), cli.NAME_ALIASES)
    for ui, e in out.items():
        assert e["assignment"] == "ok"
        assert e["all_inside"] in (True, None)
    pts = coords.flight_path_points_from_db(conn)
    per_map = {ui: sum(1 for p in pts if p["ui_map_id"] == ui) for ui in cli.VALIDATION_UI_MAPS}
    # Documented limitation: accuracy evidence for these maps is thin or absent (see manifests/coord_validation.json)
    assert per_map[1412] == 0 and per_map[1423] == 0 and per_map[1433] == 0 and per_map[1453] <= 1


def test_cross_label_diff_finds_identical_content():
    _need("att-head"); _need("att-a054efd")
    specs = manifest.load_table_specs(ROOT / "config" / "tables.toml")
    ms = {}
    for key in ("att-head", "att-a054efd"):
        info, cfg = cli.snapshot_info(ROOT, key, RAW)
        ms[key] = manifest.build_manifest(specs, cli.snapshot_source_set(info, cfg))
    assert ms["att-head"]["source"]["build_claim"] == "1.60.1.69913" and ms["att-a054efd"]["source"]["build_claim"] == "1.60.1.69893"
    d = manifest.diff_manifests(ms["att-a054efd"], ms["att-head"])
    assert {"TaxiNodes", "UiMapAssignment", "Item", "ItemSearchName"} <= set(d["identical_content"])
    assert d["changed"] == [] and d["warnings"]
