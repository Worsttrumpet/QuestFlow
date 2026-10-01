import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, "/mnt/user-data/outputs/m6-dataset-baseline/scripts")

import pytest
import collection_runs as cr
import create_pilot_runs as P


@pytest.fixture
def temp_registry(tmp_path):
    return cr.RunRegistry(path=tmp_path / "test_registry.json")


def test_selection_is_deterministic():
    proposal = P.load_proposal()
    t1 = P.select_pilot_targets(proposal)
    t2 = P.select_pilot_targets(proposal)
    assert [t["quest_id"] for t in t1] == [t["quest_id"] for t in t2]


def test_selection_picks_exactly_ten():
    proposal = P.load_proposal()
    targets = P.select_pilot_targets(proposal)
    assert len(targets) == 10


def test_selection_is_the_ten_lowest_quest_ids():
    proposal = P.load_proposal()
    all_ids = sorted(t["quest_id"] for t in proposal["att_candidate_targets"])
    selected_ids = sorted(t["quest_id"] for t in P.select_pilot_targets(proposal))
    assert selected_ids == all_ids[:10]


def test_quest_794_never_selected():
    proposal = P.load_proposal()
    targets = P.select_pilot_targets(proposal)
    assert 794 not in [t["quest_id"] for t in targets]


def test_no_att_m6_intersection_quest_selected():
    proposal = P.load_proposal()
    intersection = {788, 789, 790, 792, 794, 804, 959, 3082, 4402, 4641, 92460, 92461, 92462, 92465}
    targets = P.select_pilot_targets(proposal)
    for t in targets:
        assert t["quest_id"] not in intersection


def test_every_selected_target_came_from_att_candidate_targets():
    proposal = P.load_proposal()
    candidate_ids = {t["quest_id"] for t in proposal["att_candidate_targets"]}
    for t in P.select_pilot_targets(proposal):
        assert t["quest_id"] in candidate_ids


def test_created_runs_begin_as_planned(temp_registry):
    proposal = P.load_proposal()
    targets = P.select_pilot_targets(proposal)
    for t in targets[:2]:
        run = P.create_pilot_run(temp_registry, t, proposal["att_snapshot"])
        assert run.status == "planned"
        assert run.started_at is None
        assert run.completed_at is None


def test_created_runs_are_not_active_completed_or_observed(temp_registry):
    proposal = P.load_proposal()
    targets = P.select_pilot_targets(proposal)
    for t in targets[:2]:
        run = P.create_pilot_run(temp_registry, t, proposal["att_snapshot"])
        assert run.status not in ("active", "completed", "observed", "verified")


def test_pilot_run_retains_att_snapshot_provenance(temp_registry):
    proposal = P.load_proposal()
    targets = P.select_pilot_targets(proposal)
    run = P.create_pilot_run(temp_registry, targets[0], proposal["att_snapshot"])
    assert run.target_scope["att_snapshot"]["sha"] == proposal["att_snapshot"]["sha"]


def test_pilot_run_candidate_hint_is_explicitly_labeled_not_observed(temp_registry):
    proposal = P.load_proposal()
    targets = P.select_pilot_targets(proposal)
    run = P.create_pilot_run(temp_registry, targets[0], proposal["att_snapshot"])
    hint = run.target_scope["att_candidate_hint"]
    assert "source_derived_not_observed" in hint["evidence_status"]


def test_pilot_run_target_quest_id_matches_single_selected_quest(temp_registry):
    proposal = P.load_proposal()
    targets = P.select_pilot_targets(proposal)
    run = P.create_pilot_run(temp_registry, targets[0], proposal["att_snapshot"])
    assert run.target_quest_ids == [targets[0]["quest_id"]]


def test_target_fields_are_the_standard_three(temp_registry):
    proposal = P.load_proposal()
    targets = P.select_pilot_targets(proposal)
    run = P.create_pilot_run(temp_registry, targets[0], proposal["att_snapshot"])
    assert set(run.target_fields) == {"title", "quest_level", "objectives"}


def test_no_fabrication_creating_a_run_never_touches_m6_evidence_files():
    import hashlib
    m6_out = Path("/mnt/user-data/outputs/m6-dataset-baseline/out")
    evidence_files = ["m6_guide_dataset.json", "m6_coverage.json", "m6_evidence_report.json"]
    before = {f: hashlib.sha256((m6_out / f).read_bytes()).hexdigest() for f in evidence_files}
    # Re-selecting and building (not saving) a run must never touch these files.
    proposal = P.load_proposal()
    targets = P.select_pilot_targets(proposal)
    tmp_registry = cr.RunRegistry(path=Path(tempfile.mkdtemp()) / "scratch.json")
    P.create_pilot_run(tmp_registry, targets[0], proposal["att_snapshot"])
    after = {f: hashlib.sha256((m6_out / f).read_bytes()).hexdigest() for f in evidence_files}
    assert before == after


def test_real_registry_contains_exactly_eleven_runs_after_pilot_creation():
    """Confirms the actual, real M6 registry state produced by this milestone:
    the pre-existing Run-001 plus exactly 10 new planned pilot runs, nothing
    fabricated or extra."""
    data = json.loads(
        Path("/mnt/user-data/outputs/m6-dataset-baseline/out/m6_collection_runs.json").read_text()
    )
    assert len(data) == 11
    assert "run-001-resolve-unresolved-titles" in data
    pilot_keys = [k for k in data if k.startswith("run-m7-5-pilot-")]
    assert len(pilot_keys) == 10
    assert all(data[k]["status"] == "planned" for k in pilot_keys)
    assert data["run-001-resolve-unresolved-titles"]["status"] == "active"  # unchanged by this milestone
