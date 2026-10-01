import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_data


def _field(evidence_state="confirmed", classification="none", value="x", count=1):
    return {"evidence_state": evidence_state, "classification": classification, "value": value,
            "observation_count": count}


def _cov_field(evidence_state="confirmed", value="x", count=1):
    return {"evidence_state": evidence_state, "value": value, "observation_count": count,
            "sessions": [], "builds": []}


def _ev_field(classification="none"):
    return {"classification": classification}


def test_all_three_required_fields_confirmed_is_guide_ready():
    cov_fields = {f: _cov_field("confirmed") for f in guide_data.ALL_QUEST_FIELDS}
    ev_fields = {f: _ev_field("none") for f in guide_data.coverage.QUEST_FIELD_MAP}
    rec = guide_data.build_guide_record(999999001, cov_fields, ev_fields)
    assert rec["guide_ready"] is True


def test_missing_one_required_field_is_not_guide_ready_but_still_included():
    cov_fields = {f: _cov_field("confirmed") for f in guide_data.ALL_QUEST_FIELDS}
    cov_fields["objectives"] = _cov_field("unresolved", value=None, count=0)
    ev_fields = {f: _ev_field("none") for f in guide_data.coverage.QUEST_FIELD_MAP}
    rec = guide_data.build_guide_record(999999002, cov_fields, ev_fields)
    assert rec["guide_ready"] is False
    # still fully present, not excluded -- title/level are still there
    assert rec["fields"]["title"]["evidence_state"] == "confirmed"
    assert rec["fields"]["quest_level"]["evidence_state"] == "confirmed"


def test_readiness_is_computed_not_hardcoded():
    """Directly proves the rule is title==confirmed AND quest_level==confirmed
    AND objectives==confirmed evaluated live -- not a fixed quest-ID list or
    count baked into the function."""
    base = {f: _cov_field("confirmed") for f in guide_data.ALL_QUEST_FIELDS}
    ev_fields = {f: _ev_field("none") for f in guide_data.coverage.QUEST_FIELD_MAP}

    for missing_field in guide_data.GUIDE_READY_REQUIRED_FIELDS:
        cov = dict(base)
        cov[missing_field] = _cov_field("observed")  # not confirmed
        rec = guide_data.build_guide_record(999999003, cov, ev_fields)
        assert rec["guide_ready"] is False, f"removing {missing_field} must break readiness"

    rec_full = guide_data.build_guide_record(999999003, base, ev_fields)
    assert rec_full["guide_ready"] is True


def test_genuine_conflict_field_preserved_not_dropped_or_autoresolved():
    cov_fields = {f: _cov_field("confirmed") for f in guide_data.ALL_QUEST_FIELDS}
    ev_fields = {f: _ev_field("none") for f in guide_data.coverage.QUEST_FIELD_MAP}
    ev_fields["title"] = _ev_field("genuine_conflict")
    rec = guide_data.build_guide_record(999999004, cov_fields, ev_fields)
    # M6.4's classification is passed through exactly, not reinterpreted --
    # note guide_ready still follows evidence_state (M6.2's authority), not
    # classification (M6.4's authority) -- the two systems stay separate.
    assert rec["fields"]["title"]["classification"] == "genuine_conflict"
    assert rec["guide_ready"] is True  # evidence_state alone drives readiness, unchanged
    assert "title" in rec["fields"]  # never dropped


def test_gossip_only_title_never_promoted_into_formal_title_field():
    """Mirrors the real 99196 case: only gossip_availability_sightings has
    evidence; title itself must remain unresolved, not filled in from gossip."""
    cov_fields = {f: _cov_field("unresolved", value=None, count=0) for f in guide_data.ALL_QUEST_FIELDS}
    cov_fields["gossip_availability_sightings"] = _cov_field(
        "observed", value={"kind": "available", "title": "A Donation of Wool"}, count=1)
    ev_fields = {f: _ev_field("none") for f in guide_data.coverage.QUEST_FIELD_MAP}
    rec = guide_data.build_guide_record(99196, cov_fields, ev_fields)
    assert rec["fields"]["title"]["evidence_state"] == "unresolved"
    assert rec["fields"]["title"]["value"] is None
    assert rec["guide_ready"] is False


def test_giver_capped_at_observed_never_required_for_readiness():
    """giver/interaction_position are deliberately excluded from the
    readiness threshold -- confirms the rule doesn't demand a stronger
    evidence tier than the pipeline is designed to produce for them."""
    cov_fields = {f: _cov_field("confirmed") for f in guide_data.ALL_QUEST_FIELDS}
    cov_fields["giver"] = _cov_field("observed")  # never reaches "confirmed" by design
    cov_fields["interaction_position"] = _cov_field("observed")
    ev_fields = {f: _ev_field("none") for f in guide_data.coverage.QUEST_FIELD_MAP}
    rec = guide_data.build_guide_record(999999005, cov_fields, ev_fields)
    assert rec["guide_ready"] is True
    assert "giver" not in guide_data.GUIDE_READY_REQUIRED_FIELDS


def test_prerequisites_and_completion_have_no_classification_not_fabricated_none_of_conflict():
    """prerequisites/completion aren't raw assertion fields M6.4 classifies --
    must show classification=None (not classified), never 'none' (classified
    as no-conflict) -- that distinction must not be blurred."""
    cov_fields = {f: _cov_field("confirmed") for f in guide_data.ALL_QUEST_FIELDS}
    ev_fields = {f: _ev_field("none") for f in guide_data.coverage.QUEST_FIELD_MAP}  # no prerequisites/completion key
    rec = guide_data.build_guide_record(999999006, cov_fields, ev_fields)
    assert rec["fields"]["prerequisites"]["classification"] is None
    assert rec["fields"]["completion"]["classification"] is None


def test_idempotent_regeneration():
    r1 = guide_data.build_guide_dataset()
    r2 = guide_data.build_guide_dataset()
    assert r1["guide_ready_count"] == r2["guide_ready_count"]
    assert r1["guide_ready_quest_ids"] == r2["guide_ready_quest_ids"]
    assert r1["insufficient_evidence_quest_ids"] == r2["insufficient_evidence_quest_ids"]


def test_real_data_run001_smoke_test_exactly_8_of_10():
    """Concrete, falsifiable regression check against the ACTUAL current
    dataset -- this is a snapshot assertion about today's real data, not the
    readiness rule itself (that's tested directly above, independent of any
    specific quest ID or count)."""
    result = guide_data.build_guide_dataset()
    targets = [92516, 92517, 92553, 93318, 93319, 93951, 94411, 95350, 97970, 99196]
    ready = sorted(q for q in targets if result["quests"][q]["guide_ready"])
    assert ready == [92516, 92517, 92553, 93318, 93319, 93951, 94411, 97970]
    assert 95350 not in ready
    assert 99196 not in ready


def test_no_quest_excluded_from_output_regardless_of_readiness():
    result = guide_data.build_guide_dataset()
    assert result["quest_count"] == result["guide_ready_count"] + result["insufficient_evidence_count"]
    assert 95350 in result["quests"]  # present even though not guide_ready
    assert 99196 in result["quests"]
