import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, "/mnt/user-data/outputs/forever-db/src")

import pytest
from foreverdb import db as fdb
from foreverdb.assertions import AssertionInput, add_assertion

import evidence_report as ev


@pytest.fixture
def conn():
    c = fdb.connect(":memory:")
    fdb.init_schema(c)
    c.execute(
        """INSERT INTO dataset(dataset_id, source_kind, source_uri, source_ref, path_in_source,
             retrieved_at, sha256, first_hand, origin, license_id, license_status,
             build_claim_verified, notes)
           VALUES (?, ?, ?, ?, NULL, ?, ?, 1, ?, ?, ?, 0, '')""",
        ("test-dataset", "user_file", "test://synthetic", "test", "2026-01-01T00:00:00Z",
         "0" * 64, "user_supplied", "unknown", "unresolved"),
    )
    c.commit()
    return c


def _assert(conn, entity_id, field, value, locator, method, build="99999001"):
    add_assertion(conn, AssertionInput(
        entity_type="quest", entity_id=entity_id, field=field, value=value,
        source_kind="harvest_observation", source_dataset_id="test-dataset",
        source_locator=locator, observed_build_id=build, method=method,
        status="observed", confidence="observed_first_hand",
    ))


def test_no_evidence_is_not_a_conflict(conn):
    result = ev.analyze_field(conn, 999999001, "title", "title.harvest_observed", {})
    assert result["classification"] == "no_evidence"


def test_one_observed_value_is_not_a_conflict(conn):
    _assert(conn, 999999002, "title.harvest_observed", "EXAMPLE", "session:S1|obs[0].title",
            "QuestMeta@quest_detail")
    result = ev.analyze_field(conn, 999999002, "title", "title.harvest_observed", {})
    assert result["classification"] == "single_observation"


def test_repeated_identical_values_not_a_conflict(conn):
    for i in range(3):
        _assert(conn, 999999003, "title.harvest_observed", "EXAMPLE Quest",
                f"session:S1|obs[{i}].title", "QuestMeta@quest_detail")
    result = ev.analyze_field(conn, 999999003, "title", "title.harvest_observed", {})
    assert result["classification"] == "none"
    assert result["observation_count"] == 3


def test_two_different_stable_values_produce_genuine_conflict(conn):
    _assert(conn, 999999004, "title.harvest_observed", "Quest A", "session:S1|obs[0].title",
            "QuestMeta@quest_detail", build="99999001")
    _assert(conn, 999999004, "title.harvest_observed", "Quest B", "session:S1|obs[1].title",
            "QuestMeta@quest_complete_immediate", build="99999001")
    result = ev.analyze_field(conn, 999999004, "title", "title.harvest_observed", {})
    assert result["classification"] == "genuine_conflict"


def test_conflict_output_preserves_both_values(conn):
    _assert(conn, 999999005, "title.harvest_observed", "Quest A", "session:S1|obs[0].title",
            "QuestMeta@quest_detail")
    _assert(conn, 999999005, "title.harvest_observed", "Quest B", "session:S1|obs[1].title",
            "QuestMeta@quest_complete_immediate")
    result = ev.analyze_field(conn, 999999005, "title", "title.harvest_observed", {})
    values = {v["value"] for v in result["values"]}
    assert values == {"Quest A", "Quest B"}


def test_conflict_output_does_not_select_a_winner(conn):
    _assert(conn, 999999006, "title.harvest_observed", "Quest A", "session:S1|obs[0].title",
            "QuestMeta@quest_detail")
    _assert(conn, 999999006, "title.harvest_observed", "Quest B", "session:S1|obs[1].title",
            "QuestMeta@quest_complete_immediate")
    result = ev.analyze_field(conn, 999999006, "title", "title.harvest_observed", {})
    assert "winner" not in result and "resolved_value" not in result and "value" not in result


def test_gossip_available_to_active_is_state_change(conn):
    _assert(conn, 999999007, "availability.harvest_gossip_seen",
            {"kind": "available", "checkpoint": "GOSSIP_SHOW", "title": "EXAMPLE", "level": 3},
            "session:S1|obs[0].g", "Gossip@GOSSIP_SHOW")
    _assert(conn, 999999007, "availability.harvest_gossip_seen",
            {"kind": "active", "checkpoint": "GOSSIP_SHOW", "title": "EXAMPLE", "level": 3},
            "session:S1|obs[1].g", "Gossip@GOSSIP_SHOW")
    result = ev.analyze_field(conn, 999999007, "gossip_availability_sightings",
                               "availability.harvest_gossip_seen", {})
    assert result["classification"] == "state_change"


def test_gossip_title_difference_is_ambiguous_not_silently_state_change(conn):
    _assert(conn, 999999008, "availability.harvest_gossip_seen",
            {"kind": "available", "checkpoint": "GOSSIP_SHOW", "title": "Title A", "level": 3},
            "session:S1|obs[0].g", "Gossip@GOSSIP_SHOW")
    _assert(conn, 999999008, "availability.harvest_gossip_seen",
            {"kind": "available", "checkpoint": "GOSSIP_SHOW", "title": "Title B", "level": 3},
            "session:S1|obs[1].g", "Gossip@GOSSIP_SHOW")
    result = ev.analyze_field(conn, 999999008, "gossip_availability_sightings",
                               "availability.harvest_gossip_seen", {})
    assert result["classification"] == "ambiguous_difference"


def test_tiny_coordinate_variance_within_tolerance(conn):
    _assert(conn, 999999009, "location.observed_player_position",
            {"ui_map_id": 2521, "x": 0.500000, "y": 0.500000, "checkpoint": "quest_detail"},
            "session:S1|obs[0].p", "GiverIdentity@quest_detail")
    _assert(conn, 999999009, "location.observed_player_position",
            {"ui_map_id": 2521, "x": 0.500030, "y": 0.500030, "checkpoint": "quest_complete_immediate"},
            "session:S1|obs[1].p", "GiverIdentity@quest_complete_immediate")
    result = ev.analyze_field(conn, 999999009, "interaction_position",
                               "location.observed_player_position", {})
    assert result["classification"] == "none"


def test_large_coordinate_difference_is_position_variance(conn):
    _assert(conn, 999999010, "location.observed_player_position",
            {"ui_map_id": 2521, "x": 0.100000, "y": 0.100000, "checkpoint": "quest_detail"},
            "session:S1|obs[0].p", "GiverIdentity@quest_detail")
    _assert(conn, 999999010, "location.observed_player_position",
            {"ui_map_id": 2521, "x": 0.900000, "y": 0.900000, "checkpoint": "quest_complete_immediate"},
            "session:S1|obs[1].p", "GiverIdentity@quest_complete_immediate")
    result = ev.analyze_field(conn, 999999010, "interaction_position",
                               "location.observed_player_position", {})
    assert result["classification"] == "position_variance"


def test_player_interaction_position_never_becomes_npc_location(conn):
    _assert(conn, 999999011, "location.observed_player_position",
            {"ui_map_id": 2521, "x": 0.1, "y": 0.1, "checkpoint": "quest_detail"},
            "session:S1|obs[0].p", "GiverIdentity@quest_detail")
    _assert(conn, 999999011, "location.observed_player_position",
            {"ui_map_id": 2521, "x": 0.9, "y": 0.9, "checkpoint": "quest_complete_immediate"},
            "session:S1|obs[1].p", "GiverIdentity@quest_complete_immediate")
    result = ev.analyze_field(conn, 999999011, "interaction_position",
                               "location.observed_player_position", {})
    assert "npc_location" not in str(result) and "npc_position" not in str(result)


def test_missing_fields_remain_unresolved_not_conflict(conn):
    result = ev.analyze_field(conn, 999999012, "giver", "giver.npc", {})
    assert result["classification"] == "no_evidence"
    assert result["classification"] != "genuine_conflict"


def test_session_ids_preserved(conn):
    _assert(conn, 999999013, "title.harvest_observed", "EXAMPLE", "session:MY-SESSION-A|obs[0].title",
            "QuestMeta@quest_detail")
    result = ev.analyze_field(conn, 999999013, "title", "title.harvest_observed", {})
    assert result["sessions"] == ["MY-SESSION-A"]


def test_collection_run_ids_included_only_when_explicitly_mapped(conn):
    _assert(conn, 999999014, "title.harvest_observed", "EXAMPLE", "session:MAPPED-SESSION|obs[0].title",
            "QuestMeta@quest_detail")
    _assert(conn, 999999015, "title.harvest_observed", "EXAMPLE", "session:UNMAPPED-SESSION|obs[0].title",
            "QuestMeta@quest_detail")
    session_to_runs = {"MAPPED-SESSION": ["run-001"]}
    r1 = ev.analyze_field(conn, 999999014, "title", "title.harvest_observed", session_to_runs)
    r2 = ev.analyze_field(conn, 999999015, "title", "title.harvest_observed", session_to_runs)
    assert r1["collection_runs"] == ["run-001"]
    assert r2["collection_runs"] == []  # never inferred for an unmapped session


def test_multiple_sessions_do_not_overwrite_each_other(conn):
    _assert(conn, 999999016, "title.harvest_observed", "EXAMPLE", "session:S1|obs[0].title",
            "QuestMeta@quest_detail")
    _assert(conn, 999999016, "title.harvest_observed", "EXAMPLE", "session:S2|obs[5].title",
            "QuestMeta@quest_complete_immediate")
    result = ev.analyze_field(conn, 999999016, "title", "title.harvest_observed", {})
    assert set(result["sessions"]) == {"S1", "S2"}


def test_duplicate_observations_do_not_multiply_conflict_records(conn):
    for i in range(5):
        _assert(conn, 999999017, "title.harvest_observed", "Quest A", f"session:S1|obs[{i}].title",
                "QuestMeta@quest_detail")
    _assert(conn, 999999017, "title.harvest_observed", "Quest B", "session:S1|obs[9].title",
            "QuestMeta@quest_complete_immediate")
    result = ev.analyze_field(conn, 999999017, "title", "title.harvest_observed", {})
    assert result["classification"] == "genuine_conflict"
    assert len(result["values"]) == 2  # one record per DISTINCT value, not one per observation
    a = next(v for v in result["values"] if v["value"] == "Quest A")
    assert a["count"] == 5


def test_evidence_counts_accurate(conn):
    for i in range(4):
        _assert(conn, 999999018, "title.harvest_observed", "EXAMPLE", f"session:S1|obs[{i}].title",
                "QuestMeta@quest_detail")
    result = ev.analyze_field(conn, 999999018, "title", "title.harvest_observed", {})
    assert result["observation_count"] == 4


def test_current_m6_dataset_can_be_analyzed():
    result = ev.build_evidence_report()
    assert result["quest_count"] > 0
    assert "genuine_conflicts" in result
    assert "ambiguous_differences" in result


def test_checkpoint_embedded_reward_state_change_not_flagged_as_conflict(conn):
    """Item choices resolving differently at a later checkpoint (the real
    quest 92514 pattern) must be state_change, not genuine_conflict."""
    _assert(conn, 999999019, "reward_choice_items.harvest_observed",
            {"items": [], "checkpoint": "quest_detail"}, "session:S1|obs[0].c",
            "RewardsItems@quest_detail")
    _assert(conn, 999999019, "reward_choice_items.harvest_observed",
            {"items": [{"r1": "Resolved Item"}], "checkpoint": "quest_complete_immediate"},
            "session:S1|obs[1].c", "RewardsItems@quest_complete_immediate")
    result = ev.analyze_field(conn, 999999019, "choice_items", "reward_choice_items.harvest_observed", {})
    assert result["classification"] == "state_change"


def test_giver_different_npc_different_checkpoint_is_state_change_not_conflict(conn):
    _assert(conn, 999999020, "giver.npc", {"npc_id": 1, "name": "NPC One"}, "session:S1|obs[0].g",
            "GiverIdentity@quest_detail")
    _assert(conn, 999999020, "giver.npc", {"npc_id": 2, "name": "NPC Two"}, "session:S1|obs[1].g",
            "GiverIdentity@QUEST_TURNED_IN")
    result = ev.analyze_field(conn, 999999020, "giver", "giver.npc", {})
    assert result["classification"] == "state_change"
