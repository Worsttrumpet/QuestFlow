"""Tests for coverage.py. Constructs synthetic assertions directly via the
existing, unmodified add_assertion()/AssertionInput -- matching the M4
importer's own test style -- rather than requiring a full synthetic Lua
export for every case. All quest/NPC IDs here are obviously synthetic
(999999xxx pattern, matching this project's established convention).
"""
import sys
from pathlib import Path

sys.path.insert(0, "/mnt/user-data/outputs/forever-db/src")
sys.path.insert(0, str(Path(__file__).resolve().parent))

import pytest
from foreverdb import db as fdb
from foreverdb.assertions import AssertionInput, add_assertion

from coverage import build_npc_coverage, build_quest_coverage


@pytest.fixture
def conn():
    c = fdb.connect(":memory:")
    fdb.init_schema(c)
    # Minimal valid dataset row -- add_assertion's source_dataset_id is a real
    # foreign key into this table, same as the real importer always provides
    # via user_file_record(); a bare string alone is not enough.
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


def _assert(conn, entity_type, entity_id, field, value, locator, build="99999001", method="Test@quest_detail"):
    add_assertion(conn, AssertionInput(
        entity_type=entity_type, entity_id=entity_id, field=field, value=value,
        source_kind="harvest_observation", source_dataset_id="test-dataset",
        source_locator=locator, observed_build_id=build, method=method,
        status="observed", confidence="observed_first_hand",
    ))


def test_deduplication_multiple_observations_one_logical_entry(conn):
    """Multiple observations of the same quest must produce ONE coverage entry,
    not one per observation."""
    _assert(conn, "quest", 999999010, "title.harvest_observed", "EXAMPLE Quest",
            "session:S1|observations[0].title", method="QuestMeta@quest_detail")
    _assert(conn, "quest", 999999010, "title.harvest_observed", "EXAMPLE Quest",
            "session:S1|observations[5].title", method="QuestMeta@quest_complete_immediate")
    cov = build_quest_coverage(conn, 999999010, [])
    assert cov["quest_id"] == 999999010
    assert cov["fields"]["title"]["observation_count"] == 2
    # still ONE logical entry -- not two separate quest records anywhere


def test_missing_fields_visible_for_partial_quest(conn):
    _assert(conn, "quest", 999999011, "title.harvest_observed", "EXAMPLE",
            "session:S1|observations[0].title")
    cov = build_quest_coverage(conn, 999999011, [])
    assert "title" not in cov["missing_fields"]
    assert "objectives" in cov["missing_fields"]
    assert "giver" in cov["missing_fields"]
    assert "prerequisites" in cov["missing_fields"]  # always unresolved, no source exists


def test_evidence_states_remain_distinct(conn):
    _assert(conn, "quest", 999999012, "title.harvest_observed", "EXAMPLE",
            "session:S1|obs[0].title")
    _assert(conn, "quest", 999999012, "giver.npc", {"npc_id": 1, "name": "EXAMPLE NPC"},
            "session:S1|obs[0].giver")
    cov = build_quest_coverage(conn, 999999012, [])
    assert cov["fields"]["title"]["evidence_state"] == "confirmed"
    assert cov["fields"]["giver"]["evidence_state"] == "observed"
    assert cov["fields"]["prerequisites"]["evidence_state"] == "unresolved"


def test_reward_categories_never_collapsed(conn):
    _assert(conn, "quest", 999999013, "reward_xp.harvest_observed", {"xp_reward": 100},
            "session:S1|obs[0].xp")
    _assert(conn, "quest", 999999013, "reward_choice_items.harvest_observed",
            {"items": [{"r1": "A"}], "checkpoint": "quest_detail"}, "session:S1|obs[0].choice")
    cov = build_quest_coverage(conn, 999999013, [])
    assert cov["fields"]["xp"]["observation_count"] == 1
    assert cov["fields"]["choice_items"]["observation_count"] == 1
    assert cov["fields"]["guaranteed_items"]["observation_count"] == 0
    assert cov["fields"]["money"]["observation_count"] == 0
    assert cov["fields"]["reputation"]["observation_count"] == 0


def test_guaranteed_vs_choice_items_different_evidence_tier(conn):
    _assert(conn, "quest", 999999014, "reward_choice_items.harvest_observed",
            {"items": [], "checkpoint": "quest_detail"}, "session:S1|obs[0].c")
    _assert(conn, "quest", 999999014, "reward_items.harvest_observed",
            {"items": [], "checkpoint": "quest_detail"}, "session:S1|obs[0].g")
    cov = build_quest_coverage(conn, 999999014, [])
    assert cov["fields"]["choice_items"]["evidence_state"] == "confirmed"
    assert cov["fields"]["guaranteed_items"]["evidence_state"] == "observed"


def test_session_provenance_retained(conn):
    _assert(conn, "quest", 999999015, "title.harvest_observed", "EXAMPLE",
            "session:SESSION-A|obs[0].title", build="11111111")
    _assert(conn, "quest", 999999015, "title.harvest_observed", "EXAMPLE",
            "session:SESSION-B|obs[9].title", build="22222222")
    cov = build_quest_coverage(conn, 999999015, [])
    assert set(cov["fields"]["title"]["sessions"]) == {"SESSION-A", "SESSION-B"}
    assert set(cov["fields"]["title"]["builds"]) == {"11111111", "22222222"}
    assert set(cov["sessions_observed"]) == {"SESSION-A", "SESSION-B"}


def test_npc_scoped_evidence_never_becomes_quest_giver_evidence(conn):
    """An NPC-scoped sighting (entity_type=npc) must not leak into any quest's
    giver evidence."""
    _assert(conn, "npc", 999999020, "sighting.harvest_observed",
            {"name": "EXAMPLE Sighted NPC", "checkpoint": "GOSSIP_SHOW"}, "session:S1|obs[0].sighting")
    npc_cov = build_npc_coverage(conn, 999999020)
    assert npc_cov["npc_scoped_sighting_evidence"]["observation_count"] == 1
    assert npc_cov["quest_relationships"] == []  # never fabricated from an NPC-scoped sighting alone


def test_position_semantics_labeled_as_interaction_not_npc_location(conn):
    _assert(conn, "quest", 999999016, "location.observed_player_position",
            {"ui_map_id": 1413, "x": 0.5, "y": 0.5, "checkpoint": "quest_detail"}, "session:S1|obs[0].pos")
    cov = build_quest_coverage(conn, 999999016, [])
    # the field is named "interaction_position", never "npc_location" or "giver_location"
    assert "interaction_position" in cov["fields"]
    assert "npc_location" not in cov["fields"]
    assert cov["fields"]["interaction_position"]["evidence_state"] == "observed"  # not "confirmed"


def test_repeat_processing_is_idempotent(conn):
    _assert(conn, "quest", 999999017, "title.harvest_observed", "EXAMPLE",
            "session:S1|obs[0].title")
    cov1 = build_quest_coverage(conn, 999999017, [])
    cov2 = build_quest_coverage(conn, 999999017, [])
    assert cov1 == cov2


def test_conflict_detection_same_checkpoint_different_value(conn):
    """A genuine conflict: the SAME method/checkpoint producing two different
    values for an identity-type field."""
    _assert(conn, "quest", 999999018, "title.harvest_observed", "EXAMPLE Title A",
            "session:S1|obs[0].title", method="QuestMeta@quest_detail")
    _assert(conn, "quest", 999999018, "title.harvest_observed", "EXAMPLE Title B",
            "session:S2|obs[3].title", method="QuestMeta@quest_detail")
    cov = build_quest_coverage(conn, 999999018, [])
    assert cov["fields"]["title"]["conflict"] is True


def test_no_conflict_flagged_for_different_checkpoints_disagreeing(conn):
    """Different checkpoints producing different values is EXPECTED behavior
    (e.g. item choices resolving later) -- must NOT be flagged as a conflict."""
    _assert(conn, "quest", 999999019, "reward_choice_items.harvest_observed",
            {"items": [], "checkpoint": "quest_detail"}, "session:S1|obs[0].c",
            method="RewardsItems@quest_detail")
    _assert(conn, "quest", 999999019, "reward_choice_items.harvest_observed",
            {"items": [{"r1": "Resolved Item"}], "checkpoint": "quest_complete_immediate"},
            "session:S1|obs[1].c", method="RewardsItems@quest_complete_immediate")
    cov = build_quest_coverage(conn, 999999019, [])
    assert cov["fields"]["choice_items"]["conflict"] is False


def test_guaranteed_item_evidence_note_read_from_raw_not_assertion(conn):
    """evidence_note is NOT in the assertion (the importer doesn't map it) --
    coverage must read it from the raw export and say so explicitly."""
    _assert(conn, "quest", 999999021, "reward_items.harvest_observed",
            {"items": [{"r1": "EXAMPLE Item"}], "checkpoint": "quest_detail"}, "session:S1|obs[0].g")
    raw_obs = [{
        "quest_id": 999999021, "module_name": "RewardsItems",
        "data": {"reward_items_evidence_note": "EXAMPLE evidence note text"},
    }]
    cov = build_quest_coverage(conn, 999999021, raw_obs)
    assert cov["fields"]["guaranteed_items"]["evidence_note"] == ["EXAMPLE evidence note text"]
    assert "raw export" in cov["fields"]["guaranteed_items"]["evidence_note_source"]
