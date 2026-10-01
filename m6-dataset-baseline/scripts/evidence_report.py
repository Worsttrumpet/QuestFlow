"""M6.4: Evidence / Conflict Reporting.

Central rule: a difference is not automatically a conflict. This module
classifies every field of every quest into one of a small, fixed set of
categories, using field-type-aware rules (documented per field below), then
reports the result -- it never picks a winning value and never changes any
evidence_state established by M6.2.

Reuses, does not duplicate: the M4 importer (import_harvest_export), the M4
assertion query function (history()), and M6.2's own field-to-assertion
mapping (coverage.QUEST_FIELD_MAP). coverage.py itself is not modified --
this module queries history() directly for the one thing coverage.py's own
output doesn't preserve (per-observation session/method pairing), rather
than changing coverage.py's output shape.

Classification categories (kept deliberately small, per instruction):
    no_evidence           -- zero observations for this field
    single_observation    -- exactly one observation (not yet a duplicate,
                              not yet a conflict -- distinct from both)
    none                  -- 2+ observations, all effectively identical
    state_change          -- 2+ observations, values differ, but the
                              difference matches a documented, legitimate
                              evolution pattern for this field type
    position_variance     -- position values differ, but within/around the
                              documented numeric tolerance for real-world
                              player-standing variance
    genuine_conflict       -- 2+ observations, values differ, no legitimate
                              explanation applies -- the actual M6 plan
                              example (title A vs title B)
    ambiguous_difference   -- values differ, but the evidence is not
                              sufficient to confidently classify which of
                              the above applies (e.g. differ across builds,
                              or a gossip title change alongside a kind
                              change) -- never invented into a confident
                              answer it doesn't support
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import coverage  # noqa: E402 -- reused for QUEST_FIELD_MAP only, never modified

sys.path.insert(0, "/mnt/user-data/outputs/forever-db/src")
from foreverdb import db as fdb  # noqa: E402
from foreverdb.assertions import history  # noqa: E402
from foreverdb.harvest.importer import import_harvest_export  # noqa: E402

OUT_DIR = Path(__file__).resolve().parents[1] / "out"
EXPORT_PATH = OUT_DIR / "latest_export_ForeverRecorder.lua"
RUNS_REGISTRY_PATH = OUT_DIR / "m6_collection_runs.json"

_SESSION_LOCATOR_RE = re.compile(r"^session:([^|]+)\|")

# Documented, deterministic, tested tolerance for interaction-position
# coordinates (0-1 map-fraction floats, not world yards). Justification: the
# one real position difference found in the M6.2 baseline (quest 92703,
# real coordinates) was ~0.0000336 -- ordinary noise from the player standing
# in a very slightly different spot between two real interactions. 0.001 is
# roughly 30x that real observed noise -- comfortably above real-world jitter
# while still tight: on a typical ~2000-yard zone dimension, 0.001 of the
# map fraction is on the order of a couple of yards, so a difference this
# large or larger reflects the player genuinely standing somewhere
# meaningfully different, not measurement noise.
POSITION_TOLERANCE = 0.001

# Field-type classification -- which comparison rule applies. Every field in
# coverage.QUEST_FIELD_MAP (reused, not redefined) appears here exactly once.
STRICTLY_STABLE_FIELDS = {"title", "quest_level", "xp", "money"}
CHECKPOINT_PROGRESSIVE_FIELDS = {"objectives"}
CHECKPOINT_EMBEDDED_REWARD_FIELDS = {"choice_items", "guaranteed_items", "reputation"}
GOSSIP_FIELD = "gossip_availability_sightings"
GIVER_FIELD = "giver"
POSITION_FIELD = "interaction_position"

VALUE_EXTRACTORS = {
    # For strictly-stable fields, extract the single scalar identity value
    # buried in each field's own stored shape, so "Simple Leather Satchel"-
    # style wrapper dicts don't get compared as opaque blobs.
    "title": lambda v: v,
    "quest_level": lambda v: v,
    "xp": lambda v: v.get("xp_reward") if isinstance(v, dict) else v,
    "money": lambda v: v.get("money_reward") if isinstance(v, dict) else v,
}


def _session_from_locator(locator: str) -> str | None:
    m = _SESSION_LOCATOR_RE.match(locator)
    return m.group(1) if m else None


def _checkpoint_from_method(method: str) -> str:
    return method.split("@", 1)[-1] if "@" in method else method


def _load_session_to_run_map() -> dict[str, list[str]]:
    """Session -> collection run IDs, ONLY where M6.3 explicitly recorded the
    association. A session with no explicit mapping stays unmapped -- never
    inferred."""
    if not RUNS_REGISTRY_PATH.exists():
        return {}
    data = json.loads(RUNS_REGISTRY_PATH.read_text(encoding="utf-8"))
    out: dict[str, list[str]] = defaultdict(list)
    for run_id, run in data.items():
        for sid in run.get("session_ids", []):
            out[sid].append(run_id)
    return dict(out)


def _classify_scalar(rows: list[dict], extractor) -> dict[str, Any]:
    """title / quest_level / xp / money: never legitimately differ, at any
    checkpoint, for the same quest -- any real difference is a genuine
    conflict candidate, UNLESS it correlates perfectly with a build
    difference, in which case it's reported as an ambiguous, not confident,
    possible-client-change difference rather than a confident conflict."""
    values = [extractor(r["value"]) for r in rows]
    distinct = sorted({json.dumps(v, sort_keys=True) for v in values})
    if len(distinct) <= 1:
        return {"classification": "none"}

    by_build: dict[str, set[str]] = defaultdict(set)
    for r, v in zip(rows, values):
        by_build[r["observed_build_id"] or "unknown"].add(json.dumps(v, sort_keys=True))
    if len(by_build) > 1 and all(len(vs) == 1 for vs in by_build.values()):
        return {"classification": "ambiguous_difference",
                "explanation": "values differ, but each distinct value correlates entirely with a "
                                "different observed build -- consistent with a possible client-side "
                                "change between builds, not confidently a data-quality conflict. "
                                "Not resolved automatically; both values are preserved."}
    return {"classification": "genuine_conflict",
            "explanation": "this field is not expected to legitimately vary, and no build correlation "
                            "explains the difference"}


def _classify_checkpoint_grouped(rows: list[dict], get_checkpoint, get_comparable_value,
                                  progressive_explanation: str) -> dict[str, Any]:
    """Shared logic for fields where a value legitimately differs ACROSS
    checkpoints (progress, reward resolution, gossip state) but should NOT
    differ within the SAME checkpoint."""
    by_checkpoint: dict[str, set[str]] = defaultdict(set)
    for r in rows:
        cp = get_checkpoint(r)
        by_checkpoint[cp].add(json.dumps(get_comparable_value(r["value"]), sort_keys=True))

    same_checkpoint_conflict = any(len(vs) > 1 for vs in by_checkpoint.values())
    if same_checkpoint_conflict:
        return {"classification": "genuine_conflict",
                "explanation": "the SAME checkpoint produced more than one distinct value -- this is not "
                                "explained by expected checkpoint-to-checkpoint evolution"}

    all_values = {json.dumps(get_comparable_value(r["value"]), sort_keys=True) for r in rows}
    if len(all_values) <= 1:
        return {"classification": "none"}
    return {"classification": "state_change", "explanation": progressive_explanation}


def _classify_giver(rows: list[dict]) -> dict[str, Any]:
    def get_cp(r):
        return _checkpoint_from_method(r["method"])
    def get_val(v):
        return v
    return _classify_checkpoint_grouped(
        rows, get_cp, get_val,
        "different NPCs at different checkpoints is a documented, legitimate pattern (e.g. quest 92528: "
        "one NPC offers the quest, a different NPC receives the turn-in) -- not necessarily the same role "
        "changing, and not treated as a contradiction. giver.npc does not yet distinguish which role each "
        "observation represents.")


def _classify_objectives(rows: list[dict]) -> dict[str, Any]:
    def get_cp(r):
        return _checkpoint_from_method(r["method"])
    def get_val(v):
        return v
    return _classify_checkpoint_grouped(
        rows, get_cp, get_val,
        "objective progress is expected to evolve across checkpoints (e.g. 0/8 at quest_detail, 8/8 at "
        "quest_complete) -- this is the field working as intended, not a data conflict.")


def _classify_checkpoint_embedded_reward(rows: list[dict]) -> dict[str, Any]:
    def get_cp(r):
        # The value itself carries its own checkpoint key for these fields;
        # use that directly rather than the method, since it's the more
        # precise source (method is per-observation-envelope, the value's
        # own checkpoint key is what the module itself recorded it against).
        v = r["value"]
        return v.get("checkpoint", _checkpoint_from_method(r["method"])) if isinstance(v, dict) else \
            _checkpoint_from_method(r["method"])
    def get_val(v):
        return {k: val for k, val in v.items() if k != "checkpoint"} if isinstance(v, dict) else v
    return _classify_checkpoint_grouped(
        rows, get_cp, get_val,
        "reward data resolving differently at a later checkpoint is a documented, real behavior (e.g. "
        "quest 92514: item choices read 0 at quest_detail, correctly 3 by quest_complete_delayed) -- not "
        "a data conflict. No checkpoint-superiority ranking is invented here; both values are preserved.")


def _classify_gossip(rows: list[dict]) -> dict[str, Any]:
    """kind transitions (available -> active) are an expected, legitimate
    quest-state progression. A DIFFERING title alongside a differing kind is
    NOT confidently explained by that same logic -- reported as ambiguous
    rather than assumed to also be a normal progression."""
    kinds = {r["value"].get("kind") for r in rows if isinstance(r["value"], dict)}
    titles = {r["value"].get("title") for r in rows if isinstance(r["value"], dict)}
    levels = {r["value"].get("level") for r in rows if isinstance(r["value"], dict)}

    if len(titles) <= 1 and len(kinds) <= 1 and len(levels) <= 1:
        return {"classification": "none"}
    if len(titles) <= 1 and (len(kinds) > 1 or len(levels) > 1):
        return {"classification": "state_change",
                "explanation": "kind and/or level differ (e.g. available -> active) while the title stays "
                                "consistent -- this matches the documented gossip quest-state-progression "
                                "pattern (a quest's availability state changes as the player progresses "
                                "through it), not a data conflict."}
    return {"classification": "ambiguous_difference",
            "explanation": "the quest's title itself differs across gossip sightings, which the "
                            "state-progression explanation does not cover -- reported as ambiguous rather "
                            "than assumed to also be normal progression."}


def _classify_position(rows: list[dict]) -> dict[str, Any]:
    coords = [(r["value"].get("x"), r["value"].get("y")) for r in rows
              if isinstance(r["value"], dict) and r["value"].get("x") is not None]
    if len(coords) <= 1:
        return {"classification": "none"}
    max_x = max(c[0] for c in coords) - min(c[0] for c in coords)
    max_y = max(c[1] for c in coords) - min(c[1] for c in coords)
    if max_x <= POSITION_TOLERANCE and max_y <= POSITION_TOLERANCE:
        return {"classification": "none",
                "explanation": f"max spread (x={max_x:.6f}, y={max_y:.6f}) is within the documented "
                                f"tolerance ({POSITION_TOLERANCE}) -- ordinary real-world standing variance"}
    return {"classification": "position_variance",
            "explanation": f"max spread (x={max_x:.6f}, y={max_y:.6f}) exceeds the documented tolerance "
                            f"({POSITION_TOLERANCE}) -- the player was in a materially different spot "
                            f"across these interactions. This is recorded PLAYER position variance, never "
                            f"converted into an NPC-location claim or conflict."}


FIELD_CLASSIFIERS = {
    **{f: (lambda rows, f=f: _classify_scalar(rows, VALUE_EXTRACTORS[f])) for f in STRICTLY_STABLE_FIELDS},
    "objectives": _classify_objectives,
    "choice_items": _classify_checkpoint_embedded_reward,
    "guaranteed_items": _classify_checkpoint_embedded_reward,
    "reputation": _classify_checkpoint_embedded_reward,
    "giver": _classify_giver,
    "interaction_position": _classify_position,
    "gossip_availability_sightings": _classify_gossip,
}


def analyze_field(conn, quest_id: int, field_name: str, assertion_field: str,
                   session_to_runs: dict[str, list[str]]) -> dict[str, Any]:
    rows = history(conn, "quest", quest_id, assertion_field)
    sessions = sorted({_session_from_locator(r["source_locator"]) for r in rows} - {None})
    runs = sorted({rid for s in sessions for rid in session_to_runs.get(s, [])})

    if len(rows) == 0:
        result = {"classification": "no_evidence", "observation_count": 0}
    elif len(rows) == 1:
        result = {"classification": "single_observation", "observation_count": 1}
    else:
        result = FIELD_CLASSIFIERS[field_name](rows)
        result["observation_count"] = len(rows)

    result["sessions"] = sessions
    result["collection_runs"] = runs
    if result["classification"] in ("genuine_conflict", "ambiguous_difference", "state_change",
                                     "position_variance"):
        result["values"] = _value_counts(rows)
    return result


def _value_counts(rows: list[dict]) -> list[dict[str, Any]]:
    counts: Counter[str] = Counter(json.dumps(r["value"], sort_keys=True) for r in rows)
    return [{"value": json.loads(v), "count": c} for v, c in counts.items()]


def build_evidence_report() -> dict[str, Any]:
    conn = fdb.connect(":memory:")
    fdb.init_schema(conn)
    imp_report = import_harvest_export(conn, EXPORT_PATH)
    if imp_report.fatal_error:
        raise RuntimeError(f"import failed: {imp_report.fatal_error}")

    session_to_runs = _load_session_to_run_map()
    quest_ids = sorted(r[0] for r in conn.execute(
        "SELECT DISTINCT entity_id FROM assertion WHERE entity_type='quest'"))

    summary: Counter[str] = Counter()
    per_field_summary: dict[str, Counter[str]] = defaultdict(Counter)
    quests: dict[int, dict[str, Any]] = {}
    genuine_conflicts: list[dict[str, Any]] = []
    ambiguous: list[dict[str, Any]] = []
    recommended_collection: list[dict[str, Any]] = []

    for qid in quest_ids:
        quest_fields = {}
        for field_name, (assertion_field, _tier) in coverage.QUEST_FIELD_MAP.items():
            result = analyze_field(conn, qid, field_name, assertion_field, session_to_runs)
            quest_fields[field_name] = result
            summary[result["classification"]] += 1
            per_field_summary[field_name][result["classification"]] += 1

            if result["classification"] == "genuine_conflict":
                genuine_conflicts.append({"quest_id": qid, "field": field_name, **result})
                recommended_collection.append({"quest_id": qid, "field": field_name,
                                                "classification": "genuine_conflict",
                                                "recommended_collection": True})
            elif result["classification"] == "ambiguous_difference":
                ambiguous.append({"quest_id": qid, "field": field_name, **result})
                recommended_collection.append({"quest_id": qid, "field": field_name,
                                                "classification": "ambiguous_difference",
                                                "recommended_collection": True})
            elif result["classification"] in ("no_evidence",):
                recommended_collection.append({"quest_id": qid, "field": field_name,
                                                "classification": "unresolved",
                                                "recommended_collection": True})
        quests[qid] = {"fields": quest_fields}

    return {
        "source_export": str(EXPORT_PATH.name),
        "position_tolerance": POSITION_TOLERANCE,
        "quest_count": len(quest_ids),
        "summary": dict(summary),
        "per_field_summary": {f: dict(c) for f, c in per_field_summary.items()},
        "genuine_conflicts": genuine_conflicts,
        "ambiguous_differences": ambiguous,
        "recommended_collection_targets": recommended_collection,
        "quests": quests,
    }


if __name__ == "__main__":
    result = build_evidence_report()
    out_path = OUT_DIR / "m6_evidence_report.json"
    out_path.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
    print(f"wrote {out_path} ({out_path.stat().st_size} bytes)")
    print("summary:", json.dumps(result["summary"], indent=2))
    print("per_field_summary:", json.dumps(result["per_field_summary"], indent=2))
    print("genuine_conflicts:", len(result["genuine_conflicts"]))
    print("ambiguous_differences:", len(result["ambiguous_differences"]))
