import pytest

from conftest import write_csv
from foreverdb import assertions as A, db, quests
from foreverdb.provenance import DatasetRecord
from foreverdb.registry import load_registry
from pathlib import Path


def _ds(conn, tag):
    rec = DatasetRecord("user_file", f"file:///{tag}", tag, tag, "2026-01-01T00:00:00Z", tag.ljust(64, "0")[:64], None, 1, True,
                        "user_supplied", None, "unresolved", "unresolved", None, None, None)
    return db.insert_dataset(conn, rec)


def test_schema_is_idempotent_and_registry_loads(conn):
    db.init_schema(conn)
    reg = load_registry(Path(__file__).resolve().parents[2] / "registry" / "builds.toml")
    db.insert_registry(conn, reg)
    db.insert_registry(conn, reg)
    assert conn.execute("SELECT COUNT(*) FROM build").fetchone()[0] == 3
    assert conn.execute("SELECT COUNT(*) FROM build WHERE verification='unverified'").fetchone()[0] == 3
    assert conn.execute("PRAGMA user_version").fetchone()[0] == db.SCHEMA_VERSION


def test_dataset_insert_is_idempotent_and_redistributable_stays_null(conn):
    _ds(conn, "x")
    _ds(conn, "x")
    rows = conn.execute("SELECT redistributable FROM dataset").fetchall()
    assert len(rows) == 1 and rows[0][0] is None


def test_shell_flags_are_null_until_a_source_of_that_kind_is_loaded(conn):
    att = _ds(conn, "att")
    quests.add_evidence(conn, 3, "att_observed", att, "f.lua:1")
    quests.register_scope(conn, "att_observed", att)
    s = quests.shell(conn, 3)
    assert s == {"quest_id": 3, "client_id_observed": None, "era_baseline": None, "att_observed": 1, "server_confirmed": None}


def test_client_membership_then_att_only_ids_are_flagged_zero(conn):
    att, qv2 = _ds(conn, "att"), _ds(conn, "qv2")
    for q in (3, 4):
        quests.add_evidence(conn, q, "att_observed", att)
    quests.register_scope(conn, "att_observed", att)
    quests.load_client_questv2(conn, [(1, 0, 0), (2, 1, None), (3, None, 5)], qv2, "1.60.1.69913")
    assert quests.shell(conn, 3)["client_id_observed"] == 1 and quests.shell(conn, 3)["att_observed"] == 1
    assert quests.shell(conn, 4)["client_id_observed"] == 0        # ATT lists it, client table does not
    assert quests.shell(conn, 1)["att_observed"] == 0               # ATT loaded, ID absent there
    assert quests.shell(conn, 1)["era_baseline"] is None            # no baseline loaded: unknown, not 0
    assert quests.shell(conn, 2)["server_confirmed"] is None        # nothing can confirm yet


def test_era_baseline_from_client_table_only_after_load(conn):
    qv2, era = _ds(conn, "qv2"), _ds(conn, "era")
    quests.load_client_questv2(conn, [(1, None, None), (2, None, None)], qv2, "1.60.1.69913")
    quests.load_era_baseline(conn, [1], era)
    assert quests.shell(conn, 1)["era_baseline"] == 1 and quests.shell(conn, 2)["era_baseline"] == 0


def test_questv2_reload_is_idempotent_and_client_rows_are_per_dataset(conn, tmp_path):
    p = write_csv(tmp_path / "QuestV2.csv", ["ID", "UniqueBitFlag", "UiQuestDetailsThemeID"], [[1, 0, 0], [2, 1, 0]])
    rows = quests.read_questv2(p)
    ds = _ds(conn, "qv2")
    assert quests.load_client_questv2(conn, rows, ds, "1.60.1.69913") == 2
    quests.load_client_questv2(conn, rows, ds, "1.60.1.69913")
    assert conn.execute("SELECT COUNT(*) FROM quest").fetchone()[0] == 2
    assert conn.execute("SELECT COUNT(*) FROM quest_client_row").fetchone()[0] == 2


def test_read_questv2_rejects_files_without_id(tmp_path):
    p = write_csv(tmp_path / "x.csv", ["Foo"], [[1]])
    with pytest.raises(ValueError):
        quests.read_questv2(p)


def _a(ds, value, kind="third_party_import", conf="third_party_unverified", status="imported_unverified", loc="", field="giver.npc", **kw):
    return A.AssertionInput("quest", 1, field, value, kind, ds, conf, loc, status, **kw)


def test_duplicate_observation_is_ignored_but_different_locator_is_kept(conn, dataset):
    assert A.add_assertion(conn, _a(dataset, {"npc_id": 5}, loc="f:1")) is not None
    assert A.add_assertion(conn, _a(dataset, {"npc_id": 5}, loc="f:1")) is None
    assert A.add_assertion(conn, _a(dataset, {"npc_id": 5}, loc="f:9")) is not None


def test_competing_assertions_coexist_and_strongest_tier_wins(conn, dataset):
    A.add_assertion(conn, _a(dataset, {"npc_id": 5}))
    A.add_assertion(conn, _a(dataset, {"npc_id": 6}, kind="harvest_observation", conf="observed_first_hand", status="observed"))
    res = A.resolve(conn, "quest", 1, "giver.npc")["giver.npc"]
    assert [w["value"] for w in res["winners"]] == [{"npc_id": 6}]
    assert [o["value"] for o in res["others"]] == [{"npc_id": 5}]
    assert len(A.history(conn, "quest", 1, "giver.npc")) == 2          # nothing deleted


def test_same_tier_multi_values_are_all_winners(conn, dataset):
    for n in (5, 6):
        A.add_assertion(conn, _a(dataset, {"npc_id": n}, loc=f"f:{n}"))
    assert len(A.resolve(conn, "quest", 1)["giver.npc"]["winners"]) == 2


def test_verified_beats_unverified_within_tier_but_not_across_tiers(conn, dataset):
    A.add_assertion(conn, _a(dataset, 1, field="f", loc="a"))
    A.add_assertion(conn, _a(dataset, 2, field="f", loc="b", status="verified"))
    assert [w["value"] for w in A.resolve(conn, "quest", 1, "f")["f"]["winners"]] == [2]
    A.add_assertion(conn, _a(dataset, 3, field="f", loc="c", kind="harvest_observation", conf="observed_first_hand", status="observed"))
    assert [w["value"] for w in A.resolve(conn, "quest", 1, "f")["f"]["winners"]] == [3]


def test_rejected_and_superseded_leave_resolution_but_stay_in_history_with_log(conn, dataset):
    i = A.add_assertion(conn, _a(dataset, 1, field="f", loc="a"))
    j = A.add_assertion(conn, _a(dataset, 2, field="f", loc="b", status="verified"))
    A.set_status(conn, j, "rejected", "checked against server: wrong")
    assert [w["value"] for w in A.resolve(conn, "quest", 1, "f")["f"]["winners"]] == [1]
    assert len(A.history(conn, "quest", 1, "f")) == 2
    log = conn.execute("SELECT old_status, new_status, reason FROM assertion_status_log WHERE assertion_id=?", (j,)).fetchall()
    assert [tuple(r) for r in log] == [("verified", "rejected", "checked against server: wrong")]
    A.set_status(conn, i, "superseded", "replaced")
    assert "f" not in A.resolve(conn, "quest", 1, "f")


def test_invalid_enums_and_missing_dataset_are_rejected(conn, dataset):
    with pytest.raises(ValueError):
        A.add_assertion(conn, _a(dataset, 1, kind="rumour"))
    with pytest.raises(ValueError):
        A.add_assertion(conn, _a(dataset, 1, status="maybe"))
    with pytest.raises(ValueError):
        A.add_assertion(conn, _a(dataset, 1, conf="sure"))
    import sqlite3
    with pytest.raises(sqlite3.IntegrityError):
        A.add_assertion(conn, _a("no-such-dataset", 1))


def test_build_provenance_is_carried_and_observed_build_stays_null_for_claims(conn, dataset):
    A.add_assertion(conn, _a(dataset, 1, field="f", claimed_build_id="1.60.1.69893", claim_basis="config"))
    row = A.history(conn, "quest", 1, "f")[0]
    assert row["claimed_build_id"] == "1.60.1.69893" and row["observed_build_id"] is None
