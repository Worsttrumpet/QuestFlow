import json

import pytest

from conftest import make_repo
from foreverdb import acquire, coords, db, quests
from foreverdb.att import importer as I

CONSTANTS = "MAP = {\n\tELWYNN_FOREST = 1429;\n\tMULGORE = 1412;\n\tRIVERGLADES = 2548;\n};\n"
CONFIG = '{\n "DataPhase": "FOREVER",\n "DataPatch": [ 1, 60, 1, 69893 ],\n}\n'
ZONE = '''maproot(MAP.ELWYNN_FOREST, {
  groups = {
    n(QUESTS, {
      q(783, {  -- A Threat Within [Elwynn Forest]
        qg = 823,
        coord = { 48.1, 42.9, MAP.ELWYNN_FOREST },
        lvl = 2,
        cost = 5,
        races = ALLIANCE_ONLY,
        groups = {
          objective(1, { provider = { "i", 182 }, coord = { 57.4, 48.6, MAP.ELWYNN_FOREST }, cr = 103 }),
          objective(2, { providers = { { "n", 197 }, { "o", 5 } } }),
          i(6076),
          title(9),
        },
      }),
      q(92461, {  -- Harmony in Balance
        ["qg"] = 251361,
        ["coords"] = { { 42.1, 23.5, MAP.RIVERGLADES }, { 1.0, 2.0, MAP.MISSING }, { 3, 4, 77 } },
        ["sourceQuests"] = { 92460 },
      }),
      q(6, { sourceQuest = 18, qg = 823, coord = { 48.1, 42.9, MAP.ELWYNN_FOREST }, isBreadcrumb = true,
        lvl = lvlsquish(30, 30, 10),
        groups = { i(BURNING_BLOSSOM), q(7, { qg = 1 }) } }),
    }),
    n(FLIGHT_PATHS, {
      fp(3276, {  -- Farholde Keep, Riverglades
        ["cr"] = 257087,
        ["coord"] = { 60.6, 81.6, MAP.RIVERGLADES },
        ["races"] = ALLIANCE_ONLY,
      }),
    }),
  },
})
'''


def make_snapshot(tmp_path):
    root = tmp_path / "snap"
    base = ".contrib/.db/forever"
    sha = make_repo(root, {
        f"{base}/.config/constants/maps.lua": CONSTANTS,
        f"{base}/.config/forever.config": CONFIG,
        f"{base}/zones/elwynn.lua": ZONE,
        f"{base}/zzOLD/old.lua": "q(1, { qg = 1 })\n",
        f"{base}/.config/ignored.lua": "q(2, { qg = 2 })\n",
    })
    info = acquire.SnapshotInfo("t", "https://example.invalid/att.git", sha, root, "MIT", "verified", "unresolved", True)
    return info, (base, f"{base}/.config/constants/maps.lua", f"{base}/.config/forever.config")


@pytest.fixture()
def imported(conn, tmp_path):
    info, (fr, co, cf) = make_snapshot(tmp_path)
    rep = I.import_att_snapshot(conn, info, fr, co, cf)
    return conn, rep, info


def fields(conn, etype, eid):
    return [(r["field"], json.loads(r["value_json"]), r["source_locator"]) for r in
            conn.execute("SELECT * FROM assertion WHERE entity_type=? AND entity_id=? ORDER BY assertion_id", (etype, eid))]


def test_excluded_dirs_and_counts(imported):
    conn, rep, _ = imported
    assert rep.files == 1 and rep.quest_ids == {783, 92461, 6, 7} and rep.fp_records == 1 and rep.parse_errors == []


def test_no_semantics_are_assumed(imported):
    conn, _, _ = imported
    all_fields = {r[0] for r in conn.execute("SELECT DISTINCT field FROM assertion")}
    assert not {f for f in all_fields if f in ("level", "quest.level", "reward", "rewards", "quest.reward")}
    assert "level.att_lvl_unverified" in all_fields and "att.item_child_unverified" in all_fields


def test_name_keeps_raw_and_normalised(imported):
    conn, _, _ = imported
    name = [v for f, v, _ in fields(conn, "quest", 783) if f == "name.att_comment"][0]
    assert name == {"raw": "A Threat Within [Elwynn Forest]", "normalized": "A Threat Within"}


def test_coord_and_coords_normalise_to_one_shape_with_symbol_resolution(imported):
    conn, _, _ = imported
    single = [v for f, v, _ in fields(conn, "quest", 783) if f == "location.att_coord"]
    assert single == [{"frame": "uimap_pct", "ui_map_id": 1429, "ui_map_symbol": "MAP.ELWYNN_FOREST", "x": 48.1, "y": 42.9}]
    multi = [v for f, v, _ in fields(conn, "quest", 92461) if f == "location.att_coord"]
    assert multi[0]["ui_map_id"] == 2548 and multi[0]["ui_map_symbol"] == "MAP.RIVERGLADES"
    assert multi[1]["ui_map_id"] is None and multi[1]["ui_map_symbol"] == "MAP.MISSING"     # unresolved kept, not guessed
    assert multi[2]["ui_map_id"] == 77 and multi[2]["ui_map_symbol"] is None


def test_source_quest_singular_and_plural_use_one_field(imported):
    conn, _, _ = imported
    a = [v for f, v, _ in fields(conn, "quest", 92461) if f == "relation.att_source_quest"]
    b = [v for f, v, _ in fields(conn, "quest", 6) if f == "relation.att_source_quest"]
    assert a == [{"quest_id": 92460}] and b == [{"quest_id": 18}]


def test_objectives_items_flags_and_unmapped_reporting(imported):
    conn, rep, _ = imported
    f = fields(conn, "quest", 783)
    objs = [v for n, v, _ in f if n == "objective.att"]
    assert objs[0]["index"] == 1 and objs[0]["targets"] == [{"kind": "i", "id": 182}, {"kind": "cr", "id": 103}] and len(objs[0]["coords"]) == 1
    assert objs[1]["targets"] == [{"kind": "n", "id": 197}, {"kind": "o", "id": 5}]
    assert [v for n, v, _ in f if n == "att.item_child_unverified"] == [{"item_id": 6076}]
    assert [v for n, v, _ in f if n == "att.restriction.races"] == [{"symbol": "ALLIANCE_ONLY"}]
    assert [v for n, v, _ in fields(conn, "quest", 6) if n == "att.flag.isBreadcrumb"] == [True]
    assert rep.unmapped_keys == {"cost": 1} and rep.unmapped_child_calls == {"title": 1}   # nested q is not "unmapped"


def test_odd_lvl_and_symbolic_items_are_kept_raw_not_dropped(imported):
    conn, _, _ = imported
    f = fields(conn, "quest", 6)
    lvl = [v for n, v, _ in f if n == "level.att_lvl_unverified"]
    assert lvl == [{"call": "lvlsquish", "args": [30, 30, 10]}]
    assert [v for n, v, _ in f if n == "att.item_child_unverified"] == [{"item_ref": {"symbol": "BURNING_BLOSSOM"}}]
    assert [v for n, v, _ in fields(conn, "quest", 783) if n == "level.att_lvl_unverified"] == [2]


def test_provenance_fields(imported):
    conn, _, info = imported
    rows = conn.execute("SELECT * FROM assertion").fetchall()
    assert rows and all(r["source_kind"] == "third_party_import" and r["status"] == "imported_unverified"
                        and r["confidence"] == "third_party_unverified" for r in rows)
    assert all(r["claimed_build_id"] == "1.60.1.69893" and r["observed_build_id"] is None for r in rows)
    assert all(r["claim_basis"] == "ATT forever.config DataPatch" for r in rows)
    locs = {r["source_locator"] for r in rows}
    assert any(l.endswith("zones/elwynn.lua:4") for l in locs)                     # quest 783 line
    ds = conn.execute("SELECT * FROM dataset WHERE path_in_source LIKE '%elwynn.lua'").fetchone()
    assert ds["sha256"] and ds["source_ref"] == info.sha and ds["license_id"] == "MIT" and ds["redistributable"] is None
    assert ds["build_claim_verified"] == 0


def test_flight_path_entity(imported):
    conn, _, _ = imported
    f = fields(conn, "taxi_node", 3276)
    names = {n for n, _, _ in f}
    assert names == {"flight_master.att_cr", "location.att_coord", "att.restriction.races", "name.att_comment"}
    assert [v for n, v, _ in f if n == "flight_master.att_cr"] == [{"npc_id": 257087}]


def test_reimport_is_idempotent(imported, tmp_path):
    conn, first, info = imported
    n = conn.execute("SELECT COUNT(*) FROM assertion").fetchone()[0]
    second = I.import_att_snapshot(conn, info, ".contrib/.db/forever", ".contrib/.db/forever/.config/constants/maps.lua",
                                   ".contrib/.db/forever/.config/forever.config")
    assert conn.execute("SELECT COUNT(*) FROM assertion").fetchone()[0] == n
    assert second.assertions_added == 0 and second.assertions_duplicate == first.assertions_added


def test_ids_absent_from_client_table_are_flagged_not_dropped(imported):
    conn, _, _ = imported
    from foreverdb.provenance import DatasetRecord
    ds = db.insert_dataset(conn, DatasetRecord("user_file", "file:///q", "q", "QuestV2.csv", "2026-01-01T00:00:00Z", "d" * 64, None, 1, True,
                                               "user_supplied", None, "unresolved", "unresolved", None, "1.60.1.69913", "declared"))
    quests.load_client_questv2(conn, [(783, None, None), (6, None, None)], ds, "1.60.1.69913")
    assert quests.shell(conn, 783)["client_id_observed"] == 1
    s = quests.shell(conn, 92461)
    assert s["client_id_observed"] == 0 and s["att_observed"] == 1
    assert conn.execute("SELECT COUNT(*) FROM assertion WHERE entity_id=92461").fetchone()[0] > 0


def test_config_helpers(tmp_path):
    (tmp_path / "c").write_text(CONFIG)
    assert I.read_data_patch(tmp_path / "c") == "1.60.1.69893"
    (tmp_path / "c").write_text("{}")
    assert I.read_data_patch(tmp_path / "c") is None
    (tmp_path / "m").write_text(CONSTANTS)
    assert I.read_constants(tmp_path / "m") == {"ELWYNN_FOREST": 1429, "MULGORE": 1412, "RIVERGLADES": 2548}
    assert I.normalize_name("Camping 101: Mining [Elwynn Forest]") == "Camping 101: Mining"
    assert I.normalize_name("No decoration") == "No decoration"
