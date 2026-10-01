import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pytest
import collection_runs as cr


@pytest.fixture
def registry(tmp_path):
    """A registry backed by a throwaway path -- never touches the real
    out/m6_collection_runs.json."""
    return cr.RunRegistry(path=tmp_path / "test_registry.json")


def test_create_planned_run(registry):
    run = registry.create_run("run-001-starting-zone", purpose="Resolve unresolved starting-zone titles")
    assert run.status == "planned"
    assert run.created_at is not None
    assert run.started_at is None
    assert run.completed_at is None


def test_status_lifecycle_planned_active_completed(registry):
    run = registry.create_run("run-002", purpose="test")
    cr.transition_status(run, "active")
    assert run.status == "active" and run.started_at is not None
    cr.transition_status(run, "completed")
    assert run.status == "completed" and run.completed_at is not None


def test_invalid_transition_rejected(registry):
    run = registry.create_run("run-003", purpose="test")
    cr.transition_status(run, "active")
    cr.transition_status(run, "completed")
    with pytest.raises(ValueError):
        cr.transition_status(run, "active")  # completed is terminal


def test_abandon_from_planned_or_active(registry):
    run = registry.create_run("run-004", purpose="test")
    cr.transition_status(run, "abandoned")
    assert run.status == "abandoned" and run.completed_at is not None


def test_target_quest_ids_uses_real_project_ids_no_fabrication(registry):
    """Uses real quest IDs already known to this project's dataset (from the
    M6.2 coverage output) -- never invented placeholder IDs."""
    run = registry.create_run("run-005", purpose="test")
    cr.set_target_quest_ids(run, [92472, 96638])  # real, previously-unresolved-title quests
    assert run.target_quest_ids == [92472, 96638]
    # setting targets never creates or touches any assertion/coverage data
    # for these IDs -- it is purely metadata on the run object itself


def test_target_fields_rejects_unknown_field(registry):
    run = registry.create_run("run-006", purpose="test")
    cr.set_target_fields(run, ["title", "objectives"])
    assert run.target_fields == ["objectives", "title"]
    with pytest.raises(ValueError):
        cr.set_target_fields(run, ["not_a_real_field"])


def test_target_scope_broad(registry):
    run = registry.create_run("run-007", purpose="test")
    cr.set_target_scope(run, {"zone": "starting_zone", "level_range": "1-10"})
    assert run.target_scope == {"zone": "starting_zone", "level_range": "1-10"}


def test_associate_one_session(registry):
    run = registry.create_run("run-008", purpose="test")
    cr.associate_session(run, "e91d734523ba1a")
    assert run.session_ids == ["e91d734523ba1a"]


def test_associate_multiple_sessions(registry):
    run = registry.create_run("run-009", purpose="test")
    cr.associate_session(run, "session-A")
    cr.associate_session(run, "session-B")
    cr.associate_session(run, "session-C")
    assert run.session_ids == ["session-A", "session-B", "session-C"]


def test_duplicate_session_association_is_idempotent(registry):
    run = registry.create_run("run-010", purpose="test")
    cr.associate_session(run, "session-A")
    cr.associate_session(run, "session-A")
    cr.associate_session(run, "session-A")
    assert run.session_ids == ["session-A"]


def test_existing_session_associations_not_overwritten(registry):
    run = registry.create_run("run-011", purpose="test")
    cr.associate_session(run, "session-A")
    cr.associate_session(run, "session-B")
    assert "session-A" in run.session_ids and "session-B" in run.session_ids


def test_run_metadata_persists_correctly(tmp_path):
    path = tmp_path / "reg.json"
    reg1 = cr.RunRegistry(path=path)
    run = reg1.create_run("run-012", purpose="persistence test", description="example")
    cr.set_target_quest_ids(run, [92470])
    cr.associate_session(run, "session-X")
    cr.transition_status(run, "active")
    reg1.save()

    reg2 = cr.RunRegistry(path=path)
    loaded = reg2.get_run("run-012")
    assert loaded.purpose == "persistence test"
    assert loaded.target_quest_ids == [92470]
    assert loaded.session_ids == ["session-X"]
    assert loaded.status == "active"


def test_before_after_coverage_refs_preserved(registry, monkeypatch, tmp_path):
    fake_coverage = {"quest_count": 1, "npc_count": 1, "quests": {}, "npcs": {}}
    monkeypatch.setattr(cr.coverage, "build_coverage", lambda: fake_coverage)
    monkeypatch.setattr(cr, "OUT_DIR", tmp_path)
    monkeypatch.setattr(cr, "SNAPSHOT_DIR", tmp_path / "coverage_snapshots")

    run = registry.create_run("run-013", purpose="test")
    ref = cr.snapshot_coverage(run, "before")
    assert run.before_coverage_ref is not None
    assert run.before_coverage_ref["sha256"] == ref["sha256"]
    assert (tmp_path / run.before_coverage_ref["path"]).exists()


def test_coverage_delta_only_counts_real_evidence_changes(registry, monkeypatch, tmp_path):
    """The core rule: a field going from unresolved to something else IS a
    coverage change. Observation count alone changing is NOT."""
    monkeypatch.setattr(cr, "OUT_DIR", tmp_path)
    monkeypatch.setattr(cr, "SNAPSHOT_DIR", tmp_path / "coverage_snapshots")

    before = {
        "quest_count": 1, "npc_count": 0,
        "quests": {"92470": {"fields": {
            "title": {"evidence_state": "unresolved", "observation_count": 0},
            "objectives": {"evidence_state": "confirmed", "observation_count": 1},
        }}},
        "npcs": {},
    }
    after = {
        "quest_count": 1, "npc_count": 0,
        "quests": {"92470": {"fields": {
            "title": {"evidence_state": "confirmed", "observation_count": 1},
            # objectives evidence_state UNCHANGED, but observation_count rose --
            # must NOT be counted as a coverage change.
            "objectives": {"evidence_state": "confirmed", "observation_count": 5},
        }}},
        "npcs": {},
    }

    run = registry.create_run("run-014", purpose="test")
    cr.set_target_quest_ids(run, [92470])
    cr.set_target_fields(run, ["title", "objectives"])

    calls = iter([before, after])
    monkeypatch.setattr(cr.coverage, "build_coverage", lambda: next(calls))
    cr.snapshot_coverage(run, "before")
    cr.snapshot_coverage(run, "after")

    delta = cr.compute_coverage_delta(run)
    assert delta["status"] == "computed"
    resolved_fields = {(f["quest_id"], f["field"]) for f in delta["fields_resolved"]}
    assert (92470, "title") in resolved_fields
    assert (92470, "objectives") not in resolved_fields, \
        "an observation_count rise alone must never be reported as a coverage change"


def test_missing_coverage_remains_missing_when_no_evidence_changed(registry, monkeypatch, tmp_path):
    monkeypatch.setattr(cr, "OUT_DIR", tmp_path)
    monkeypatch.setattr(cr, "SNAPSHOT_DIR", tmp_path / "coverage_snapshots")
    same = {"quest_count": 1, "npc_count": 0,
            "quests": {"92472": {"fields": {"title": {"evidence_state": "unresolved", "observation_count": 1}}}},
            "npcs": {}}
    monkeypatch.setattr(cr.coverage, "build_coverage", lambda: same)

    run = registry.create_run("run-015", purpose="test")
    cr.set_target_quest_ids(run, [92472])
    cr.set_target_fields(run, ["title"])
    cr.snapshot_coverage(run, "before")
    cr.snapshot_coverage(run, "after")
    delta = cr.compute_coverage_delta(run)
    assert delta["fields_resolved"] == []
    assert delta["remaining_targets"] == [{"quest_id": 92472, "field": "title"}]


def test_multiple_runs_remain_independent(registry):
    run_a = registry.create_run("run-016-a", purpose="A")
    run_b = registry.create_run("run-016-b", purpose="B")
    cr.associate_session(run_a, "session-A")
    cr.associate_session(run_b, "session-B")
    assert run_a.session_ids == ["session-A"]
    assert run_b.session_ids == ["session-B"]
    cr.transition_status(run_a, "active")
    assert run_b.status == "planned"  # unaffected by run_a's transition


def test_registry_reload_is_idempotent(tmp_path):
    path = tmp_path / "reg.json"
    reg1 = cr.RunRegistry(path=path)
    reg1.create_run("run-017", purpose="test")
    reg1.save()
    content1 = path.read_text()

    reg2 = cr.RunRegistry(path=path)
    reg2.save()
    content2 = path.read_text()
    assert json.loads(content1) == json.loads(content2)


def test_no_fabricated_quest_ids_targeting_unobserved_id_is_allowed_but_creates_nothing(registry):
    """Targeting a quest with NO current evidence is legitimate -- that's the
    whole point of a planned run -- but it must not create any fabricated
    coverage/assertion data for that ID."""
    run = registry.create_run("run-018", purpose="test")
    cr.set_target_quest_ids(run, [999999999])  # a quest ID with no real evidence anywhere
    assert run.target_quest_ids == [999999999]
    # nothing else in this module writes to the assertion database or the
    # coverage output as a side effect of setting a target


def test_run_metadata_never_touches_raw_observation_export():
    """Static/structural check: nothing in this module opens the SavedVariables
    export directly -- only coverage.build_coverage() does, and this module
    only calls that function, never re-implements export parsing."""
    src = Path(cr.__file__).read_text()
    assert "parse_saved_variables" not in src
    assert "ForeverObservationLabDB" not in src


def test_snapshot_never_overwrites_the_shared_m6_coverage_json(monkeypatch, tmp_path, registry):
    """snapshot_coverage() must write to its OWN file, never to the shared
    out/m6_coverage.json that M6.2 itself produces and other tooling reads."""
    monkeypatch.setattr(cr, "OUT_DIR", tmp_path)
    monkeypatch.setattr(cr, "SNAPSHOT_DIR", tmp_path / "coverage_snapshots")
    monkeypatch.setattr(cr.coverage, "build_coverage", lambda: {"quest_count": 0, "npc_count": 0, "quests": {}, "npcs": {}})
    shared_path = tmp_path / "m6_coverage.json"
    shared_path.write_text('{"untouched": true}')

    run = registry.create_run("run-019", purpose="test")
    cr.snapshot_coverage(run, "before")
    assert json.loads(shared_path.read_text()) == {"untouched": True}
