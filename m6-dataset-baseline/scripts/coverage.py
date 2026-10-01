"""M6.2: Coverage Database / View.

Architecture, exactly as specified:

    RAW OBSERVATIONS -> M4 ASSERTIONS -> M6 COVERAGE VIEW

This module imports a real export through the EXISTING, UNMODIFIED M4
importer (src/foreverdb/harvest/importer.py) into an in-memory SQLite
database, then builds a field-level, evidence-aware coverage view by
querying the resulting assertions (src/foreverdb/assertions.py's history()).
It does not duplicate the SavedVariables parser, the importer's field
mapping, or the M1 provenance model -- it reads what those already produce.

One deliberate exception to "read only from assertions": `evidence_note`
(on the guaranteed-item reward case) is a real field the recorder exports
and the schema accepts, but the existing importer's field mapping for
reward_items.harvest_observed only extracts {items, checkpoint} -- it has
no code path for a sibling key it doesn't know about (this was found and
documented during M5; see HARVEST_CONTRACT.md and the M5 completion
report). Per the M6.2 instructions, the importer is NOT modified to fix
this. Instead, this module reads `evidence_note` directly from the RAW
export for the one field that needs it, and says so explicitly in the
output -- it does not pretend the assertion layer carries it.

No fabricated candidate data: this module operates ONLY on the real
observed quest/NPC set. It does not generate QuestV2/ATT IDs, does not
compute or guess a source-overlap number, and does not upgrade the M6
plan's reported ~6600/~1537 aggregate figures into anything resembling
verified per-quest coverage.
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

FOREVERDB_SRC = Path("/mnt/user-data/outputs/forever-db/src")
sys.path.insert(0, str(FOREVERDB_SRC))
from foreverdb import db as fdb  # noqa: E402
from foreverdb.assertions import history  # noqa: E402
from foreverdb.harvest.importer import import_harvest_export  # noqa: E402
from foreverdb.harvest.savedvars import parse_saved_variables  # noqa: E402

EXPORT_PATH = Path(__file__).resolve().parents[1] / "out" / "latest_export_ForeverRecorder.lua"

# Field -> (assertion field name, evidence tier when present).
# Tiers follow the M6 plan's own worked example for quest 92515 exactly:
# title/level/objectives/xp/money/reputation/choice-items = confirmed
# (independently reproduced across multiple real sessions per the M5
# completion report); giver/position/guaranteed-item/gossip-availability =
# observed (a real sighting/interaction, not independently sufficient to
# establish the stronger claim on its own -- and, for guaranteed items,
# explicitly weaker per M6 rule 3.4/section 14: "especially important for
# quest 92515", which has exactly this evidence, observed twice, same quest).
QUEST_FIELD_MAP = {
    "title": ("title.harvest_observed", "confirmed"),
    "quest_level": ("level.harvest_observed", "confirmed"),
    "objectives": ("objectives.harvest_observed", "confirmed"),
    "xp": ("reward_xp.harvest_observed", "confirmed"),
    "money": ("reward_money.harvest_observed", "confirmed"),
    "choice_items": ("reward_choice_items.harvest_observed", "confirmed"),
    "guaranteed_items": ("reward_items.harvest_observed", "observed"),
    "reputation": ("reward_reputation.harvest_observed", "confirmed"),
    "giver": ("giver.npc", "observed"),
    "interaction_position": ("location.observed_player_position", "observed"),
    "gossip_availability_sightings": ("availability.harvest_gossip_seen", "observed"),
}
# Never populated from any current data source -- always unresolved, stated
# plainly rather than silently omitted (M6 rule: unknowns are first-class).
ALWAYS_UNRESOLVED_FIELDS = ["prerequisites"]

_SESSION_LOCATOR_RE = re.compile(r"^session:([^|]+)\|")


def _session_from_locator(locator: str) -> str | None:
    m = _SESSION_LOCATOR_RE.match(locator)
    return m.group(1) if m else None


def _group_by_method(rows: list[dict]) -> dict[str, list[dict]]:
    """Groups assertion rows by their `method` field (e.g. 'GiverIdentity@quest_detail'),
    which is the ONLY reliable way to recover which checkpoint produced a given
    value -- most field values themselves do not embed the checkpoint (only the
    reward-type fields' own value dict happens to include one)."""
    out: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        out[r["method"]].append(r)
    return out


def _field_coverage(conn, entity_type: str, entity_id: int, assertion_field: str,
                     tier: str) -> dict[str, Any]:
    rows = history(conn, entity_type, entity_id, assertion_field)
    if not rows:
        return {"evidence_state": "unresolved", "observation_count": 0}

    by_method = _group_by_method(rows)
    conflicts = []
    for method, group in by_method.items():
        distinct_values = {json.dumps(r["value"], sort_keys=True) for r in group}
        if len(distinct_values) > 1:
            conflicts.append({"method": method, "distinct_values": [json.loads(v) for v in distinct_values]})

    sessions = sorted({_session_from_locator(r["source_locator"]) for r in rows} - {None})
    builds = sorted({r["observed_build_id"] for r in rows if r["observed_build_id"]})

    # Representative value: prefer the LATEST checkpoint present for
    # reward-type/lifecycle fields (matches the project's own established
    # "later checkpoint is more complete" finding, quest 92514) -- but this
    # is a DISPLAY choice only; every raw value remains in `all_values`,
    # nothing is discarded.
    checkpoint_priority = ["QUEST_TURNED_IN", "quest_complete_delayed", "quest_complete_immediate",
                            "quest_detail", "GOSSIP_SHOW"]
    def _cp_of(method: str) -> str:
        return method.split("@", 1)[-1] if "@" in method else method
    best = min(rows, key=lambda r: (
        checkpoint_priority.index(_cp_of(r["method"])) if _cp_of(r["method"]) in checkpoint_priority else 99,
        -r["assertion_id"],
    ))

    return {
        "evidence_state": tier,
        "value": best["value"],
        "observation_count": len(rows),
        "sessions": sessions,
        "builds": builds,
        "conflict": bool(conflicts),
        "conflicts": conflicts,
        "all_values": [r["value"] for r in rows],
    }


def _completion_evidence(conn, quest_id: int) -> dict[str, Any]:
    """Derived, not a separate assertion field: true if ANY assertion for this
    quest was captured via a turn-in-lifecycle checkpoint. Uses `method`
    (module@checkpoint) across every field, since no single field alone
    establishes 'this quest was completed' better than the checkpoint itself
    does."""
    rows = history(conn, "quest", quest_id)
    checkpoints_seen = {r["method"].split("@", 1)[-1] for r in rows if "@" in r["method"]}
    completion_checkpoints = {"quest_complete_immediate", "quest_complete_delayed", "QUEST_TURNED_IN"}
    hit = checkpoints_seen & completion_checkpoints
    return {
        "evidence_state": "confirmed" if hit else "unresolved",
        "completion_checkpoints_observed": sorted(hit),
    }


def _guaranteed_item_evidence_notes(quest_id: int, raw_obs: list[dict]) -> list[str]:
    """The one field this module reads from the RAW export rather than
    assertions -- see module docstring for why."""
    notes = []
    for o in raw_obs:
        if o.get("quest_id") == quest_id and o.get("module_name") == "RewardsItems" and o.get("data"):
            note = o["data"].get("reward_items_evidence_note")
            if note and note not in notes:
                notes.append(note)
    return notes


def build_quest_coverage(conn, quest_id: int, raw_obs: list[dict]) -> dict[str, Any]:
    record: dict[str, Any] = {"quest_id": quest_id, "evidence_state": {}, "fields": {}}
    for field_name, (assertion_field, tier) in QUEST_FIELD_MAP.items():
        cov = _field_coverage(conn, "quest", quest_id, assertion_field, tier)
        record["fields"][field_name] = cov
    for field_name in ALWAYS_UNRESOLVED_FIELDS:
        record["fields"][field_name] = {"evidence_state": "unresolved", "observation_count": 0,
                                         "reason": "no current data source establishes this"}
    record["fields"]["completion"] = _completion_evidence(conn, quest_id)

    if record["fields"]["guaranteed_items"]["observation_count"] > 0:
        record["fields"]["guaranteed_items"]["evidence_note"] = _guaranteed_item_evidence_notes(
            quest_id, raw_obs)
        record["fields"]["guaranteed_items"]["evidence_note_source"] = (
            "raw export, NOT the SQLite assertion -- the existing, unmodified M4 importer does not map "
            "this field; see module docstring")

    missing = [f for f, cov in record["fields"].items() if cov["evidence_state"] == "unresolved"]
    record["missing_fields"] = missing

    all_sessions, all_builds = set(), set()
    for cov in record["fields"].values():
        all_sessions.update(cov.get("sessions") or [])
        all_builds.update(cov.get("builds") or [])
    record["sessions_observed"] = sorted(all_sessions)
    record["builds_observed"] = sorted(all_builds)
    record["total_observations"] = sum(cov.get("observation_count", 0) for cov in record["fields"].values())
    return record


def build_npc_coverage(conn, npc_id: int) -> dict[str, Any]:
    sighting = _field_coverage(conn, "npc", npc_id, "sighting.harvest_observed", "observed")
    position = _field_coverage(conn, "npc", npc_id, "location.observed_player_position", "observed")
    quest_giver_rows = conn.execute(
        "SELECT DISTINCT entity_id FROM assertion WHERE field='giver.npc' AND "
        "json_extract(value_json, '$.npc_id') = ?", (npc_id,)
    ).fetchall()
    quest_relationships = sorted(r[0] for r in quest_giver_rows)
    return {
        "npc_id": npc_id,
        "name": sighting.get("value", {}).get("name") if sighting.get("value") else None,
        "npc_scoped_sighting_evidence": sighting,
        "interaction_position_evidence": position,
        "quest_relationships": quest_relationships,
        "quest_relationship_note": "these are quests where this NPC appeared as giver.npc during a "
                                    "quest-scoped observation -- NOT proof this NPC exclusively or "
                                    "permanently gives these quests; see HARVEST_CONTRACT.md's giver.npc "
                                    "role-ambiguity limitation",
    }


def build_coverage() -> dict[str, Any]:
    text = EXPORT_PATH.read_text(encoding="utf-8")
    raw_db = parse_saved_variables(text)["ForeverObservationLabDB"]
    raw_obs = raw_db["observations"]

    conn = fdb.connect(":memory:")
    fdb.init_schema(conn)
    report = import_harvest_export(conn, EXPORT_PATH)
    if report.fatal_error:
        raise RuntimeError(f"import failed: {report.fatal_error}")

    quest_ids = sorted(r[0] for r in conn.execute(
        "SELECT DISTINCT entity_id FROM assertion WHERE entity_type='quest'"))

    # NPC IDs come from TWO places, not one -- a real gap found while building
    # this: an NPC observed only in a quest-scoped GiverIdentity capture (a
    # real quest_id was present) never gets its own entity_type='npc' row at
    # all in the current importer's entity model -- it only exists as the
    # npc_id value nested inside that quest's giver.npc assertion. Querying
    # entity_type='npc' alone silently misses every NPC that was only ever
    # seen in that quest-scoped capacity. This is a coverage-VIEW-level fix
    # (a broader query against existing assertion data), not an importer
    # change -- no assertion field mapping was touched.
    npc_scoped_ids = {r[0] for r in conn.execute(
        "SELECT DISTINCT entity_id FROM assertion WHERE entity_type='npc'")}
    giver_npc_ids = {
        r[0]
        for r in conn.execute(
            "SELECT DISTINCT json_extract(value_json, '$.npc_id') FROM assertion WHERE field='giver.npc'")
        if r[0] is not None
    }
    npc_ids = sorted(npc_scoped_ids | giver_npc_ids)

    quests = {qid: build_quest_coverage(conn, qid, raw_obs) for qid in quest_ids}
    npcs = {nid: build_npc_coverage(conn, nid) for nid in npc_ids}

    field_summary = {}
    for field_name in list(QUEST_FIELD_MAP.keys()) + ALWAYS_UNRESOLVED_FIELDS + ["completion"]:
        covered = sum(1 for q in quests.values() if q["fields"][field_name]["evidence_state"] != "unresolved")
        field_summary[field_name] = {"covered": covered, "missing": len(quests) - covered}

    conflicts_found = [
        {"quest_id": qid, "field": fname, "conflicts": cov["conflicts"]}
        for qid, q in quests.items() for fname, cov in q["fields"].items() if cov.get("conflict")
    ]

    return {
        "source_export": str(EXPORT_PATH.name),
        "importer_summary": report.summary(),
        "quest_count": len(quests),
        "npc_count": len(npcs),
        "quests": quests,
        "npcs": npcs,
        "field_summary": field_summary,
        "conflicts_found": conflicts_found,
    }


if __name__ == "__main__":
    result = build_coverage()
    out_path = Path(__file__).resolve().parents[1] / "out" / "m6_coverage.json"
    out_path.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
    print(f"wrote {out_path} ({out_path.stat().st_size} bytes)")
    print(f"quest_count={result['quest_count']} npc_count={result['npc_count']}")
    print("field_summary:", json.dumps(result["field_summary"], indent=2))
    print("conflicts_found:", len(result["conflicts_found"]))
