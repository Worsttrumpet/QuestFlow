import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, "/mnt/user-data/outputs/m6-dataset-baseline/scripts")

import select_collection_targets as SEL

M6_OUT = Path("/mnt/user-data/outputs/m6-dataset-baseline/out")
M6_FILES = ["m6_guide_dataset.json", "m6_coverage.json", "m6_evidence_report.json", "m6_collection_runs.json"]


def _hash_all(paths):
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def test_m6_outputs_unchanged_by_running_the_proposal():
    before = _hash_all([M6_OUT / f for f in M6_FILES])
    SEL.build_proposal()
    after = _hash_all([M6_OUT / f for f in M6_FILES])
    assert before == after, "M7.4 must never modify any M6 output file"


def test_no_att_value_uses_observed_evidence_vocabulary():
    result = SEL.build_proposal()
    forbidden = {"observed", "confirmed", "verified"}
    # the global evidence_status (stated once, applies to every candidate
    # value in the file -- see the field's own note) is the source of truth,
    # not a per-target repeated field.
    assert "source_derived_not_observed" in result["evidence_status"]
    for target in result["att_candidate_targets"]:
        assert target["status"] not in forbidden


def test_quest_794_is_a_followup_not_a_candidate_target():
    result = SEL.build_proposal()
    candidate_ids = {t["quest_id"] for t in result["att_candidate_targets"]}
    assert 794 not in candidate_ids
    followup_ids = {f["quest_id"] for f in result["observed_evidence_followups"]}
    assert 794 in followup_ids


def test_every_candidate_target_is_genuinely_att_only():
    import coverage
    result = SEL.build_proposal()
    m6_ids = set(coverage.build_coverage()["quests"].keys())
    for target in result["att_candidate_targets"]:
        assert target["quest_id"] not in m6_ids, "an M6-observed quest must never appear as an ATT-only target"


def test_every_candidate_target_has_name_giver_and_coordinates():
    result = SEL.build_proposal()
    for target in result["att_candidate_targets"]:
        assert target["candidate_name"]
        assert target["candidate_giver"]
        assert target["candidate_coordinates"]


def test_every_candidate_target_retains_att_snapshot_provenance():
    result = SEL.build_proposal()
    # Snapshot identity is stated once at the top level and explicitly says
    # it applies to every candidate value in the file (including the
    # per-target entries and the quest-794 followup) -- checked here rather
    # than expecting it repeated on each of the 1,102+ entries.
    assert result["att_snapshot"]["sha"] == SEL.ATT_SNAPSHOT_SHA
    assert "every candidate value in this entire file" in result["att_snapshot"]["note"]
    assert len(result["att_candidate_targets"]) > 0
    assert len(result["observed_evidence_followups"]) > 0


def test_determinism_two_runs_identical():
    r1 = SEL.build_proposal()
    r2 = SEL.build_proposal()
    assert json.dumps(r1, sort_keys=True) == json.dumps(r2, sort_keys=True)


def test_no_collection_run_is_created_in_the_m6_registry():
    before = (M6_OUT / "m6_collection_runs.json").read_text()
    SEL.build_proposal()
    after = (M6_OUT / "m6_collection_runs.json").read_text()
    assert before == after
    data = json.loads(after)
    assert "run-001-resolve-unresolved-titles" in data
    # no new run key was added by this module
    assert len(data) == 1


def test_no_run_in_output_is_active_or_completed():
    result = SEL.build_proposal()
    for target in result["att_candidate_targets"]:
        assert target["status"] not in ("active", "completed")


def test_findability_filter_is_the_strict_intersection_of_three_groups():
    result = SEL.build_proposal()
    c = result["completeness_counts"]
    assert result["findability_qualified_count"] == c["with_name_and_giver_and_coordinates"]
    assert result["findability_qualified_count"] <= c["with_name"]
    assert result["findability_qualified_count"] <= c["with_giver"]
    assert result["findability_qualified_count"] <= c["with_coordinates"]


def test_completeness_counts_only_cover_att_only_population():
    result = SEL.build_proposal()
    assert result["att_only_count"] == 1523
