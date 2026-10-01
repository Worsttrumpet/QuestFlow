"""M6.1: Dataset Inventory / Baseline.

Reads the real ForeverObservationLabDB export (the shared dataset written by
both the historical Observation Lab and the production ForeverRecorder) and
produces a machine-readable inventory plus the numbers behind
docs/M6_DATASET_BASELINE_REPORT.md.

Reuses the existing, unmodified M4 parser (src/foreverdb/harvest/savedvars.py)
-- does not duplicate SavedVariables parsing logic, per M6 rule #29.4.

This script does not modify any file it reads, does not touch the M4
importer, schema, or the recorder, and does not write anything back into
forever-db/ or m5-production-recorder/.
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

FOREVERDB_SRC = Path("/mnt/user-data/outputs/forever-db/src")
sys.path.insert(0, str(FOREVERDB_SRC))
from foreverdb.harvest.savedvars import parse_saved_variables  # noqa: E402

EXPORT_PATH = Path(__file__).resolve().parents[1] / "out" / "latest_export_ForeverRecorder.lua"

# Sessions independently confirmed, in this project's own real-client testing
# conversation, to have been produced by ForeverRecorder specifically (not
# inferred from the file's own structure -- the shared dataset carries no
# per-observation field naming which addon wrote it). Every other session is
# reported as "pre-existing / Lab-attributed, per conversation history" --
# not something this script can independently re-derive from the file alone.
KNOWN_RECORDER_SESSIONS = {
    "f0e0a3f870f296", "90318e46308b48", "e91d734523ba1a",
    "9a2307cc62589b", "038eb179f79ceb", "f560b6cb92a97c",
}

# Reported in the M6 planning document itself, citing "prior research" --
# NOT independently re-derived by this script. This script has no raw
# QuestV2/ATT/Era ID list to load and compute a real quest-ID-level overlap
# against; only these prior aggregate figures are available. Reported as
# reported, not upgraded to data-verified.
REPORTED_CANDIDATE_SCALE = {
    "questv2_total_rows_reported": 6600,
    "att_forever_unique_quest_ids_reported": 1537,
    "source": "M6 planning document, Section 6, citing prior project research; "
              "this script has no raw ID list on disk to independently verify these figures "
              "or compute a real overlap with the observed quest ID set below.",
}


def main() -> dict:
    text = EXPORT_PATH.read_text(encoding="utf-8")
    db = parse_saved_variables(text)["ForeverObservationLabDB"]
    obs = db["observations"]

    by_session = Counter(o.get("session_id") for o in obs)
    by_build = Counter(o.get("observed_build") for o in obs)
    by_module = Counter(o.get("module_name") for o in obs)

    recorder_obs = [o for o in obs if o.get("session_id") in KNOWN_RECORDER_SESSIONS]
    other_obs = [o for o in obs if o.get("session_id") not in KNOWN_RECORDER_SESSIONS]

    quest_ids_touched = sorted({o["quest_id"] for o in obs if o.get("quest_id") is not None})

    # Quest observations by type -- module rows that carry a real quest_id.
    quest_scoped_by_module = Counter(
        o["module_name"] for o in obs if o.get("quest_id") is not None
    )

    # NPC observations: every GiverIdentity row's npc.parsed_creature_id,
    # whether quest-scoped or NPC-scoped (the M4/M5 distinction is about
    # WHICH ENTITY the evidence attaches to at import time, not whether the
    # NPC was seen at all).
    npc_ids_seen = set()
    npc_scoped_observations = 0
    quest_scoped_giver_observations = 0
    observations_with_position = 0
    for o in obs:
        if o.get("module_name") == "GiverIdentity" and o.get("data"):
            npc = o["data"].get("npc") or {}
            cid = npc.get("parsed_creature_id")
            if cid is not None:
                npc_ids_seen.add(cid)
            if o.get("quest_id") is None:
                npc_scoped_observations += 1
            else:
                quest_scoped_giver_observations += 1
            pos = npc.get("position") or {}
            if pos.get("position_ok"):
                observations_with_position += 1

    # Reward observations by type -- distinguishing categories per M6 rule 25,
    # never collapsed into one generic "reward confirmed" flag.
    reward_counts = {
        "xp_money_observations": sum(1 for o in obs if o.get("module_name") == "RewardsXPMoney"),
        "choice_item_observations": sum(
            1 for o in obs if o.get("module_name") == "RewardsItems"
            and o.get("data") and (o["data"].get("num_choices") or 0) > 0
        ),
        "guaranteed_item_observations": sum(
            1 for o in obs if o.get("module_name") == "RewardsItems"
            and o.get("data") and (o["data"].get("num_rewards") or 0) > 0
        ),
        "reputation_observations": sum(
            1 for o in obs if o.get("module_name") == "RewardsReputation"
            and o.get("data") and (o["data"].get("num_factions") or 0) > 0
        ),
    }
    guaranteed_item_quest_ids = sorted({
        o["quest_id"] for o in obs if o.get("module_name") == "RewardsItems"
        and o.get("data") and (o["data"].get("num_rewards") or 0) > 0 and o.get("quest_id") is not None
    })
    choice_item_quest_ids = sorted({
        o["quest_id"] for o in obs if o.get("module_name") == "RewardsItems"
        and o.get("data") and (o["data"].get("num_choices") or 0) > 0 and o.get("quest_id") is not None
    })

    # Unresolved fields -- first-class, per M6 rule 19, not silently discarded.
    unresolved_titles = [
        {"quest_id": o["quest_id"], "reason": o["data"].get("quest_log_index_error")}
        for o in obs if o.get("module_name") == "QuestMeta" and o.get("data")
        and o["data"].get("title") is None and o.get("quest_id") is not None
    ]
    unresolved_item_names = sum(
        1 for o in obs if o.get("module_name") == "RewardsItems" and o.get("data")
        and o["data"].get("saw_unresolved_first_value")
    )

    inventory = {
        "export_file": str(EXPORT_PATH.name),
        "total_observations": len(obs),
        "recorder_attributed_observations": len(recorder_obs),
        "pre_existing_lab_attributed_observations": len(other_obs),
        "attribution_note": "Session-to-addon attribution for 'recorder' sessions is based on this "
                             "project's own real-client testing conversation history, not on any field "
                             "in the data itself -- the shared ForeverObservationLabDB schema does not "
                             "record which addon wrote a given observation.",
        "sessions": dict(by_session),
        "builds": dict(by_build),
        "by_module": dict(by_module),
        "unique_quest_ids_touched": quest_ids_touched,
        "unique_quest_ids_touched_count": len(quest_ids_touched),
        "quest_scoped_observations_by_module": dict(quest_scoped_by_module),
        "npc_coverage": {
            "unique_npc_creature_ids_seen": sorted(npc_ids_seen),
            "unique_npc_creature_ids_seen_count": len(npc_ids_seen),
            "npc_scoped_observations": npc_scoped_observations,
            "quest_scoped_giver_observations": quest_scoped_giver_observations,
        },
        "reward_coverage": reward_counts,
        "guaranteed_item_quest_ids": guaranteed_item_quest_ids,
        "choice_item_quest_ids": choice_item_quest_ids,
        "position_coverage": {
            "giver_identity_observations_with_position": observations_with_position,
        },
        "unresolved_fields": {
            "quest_meta_title_unresolved": unresolved_titles,
            "quest_meta_title_unresolved_count": len(unresolved_titles),
            "item_name_unresolved_at_first_read_count": unresolved_item_names,
        },
        "reported_candidate_scale": REPORTED_CANDIDATE_SCALE,
    }
    return inventory


if __name__ == "__main__":
    result = main()
    out_path = Path(__file__).resolve().parents[1] / "out" / "inventory.json"
    out_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"wrote {out_path} ({out_path.stat().st_size} bytes)")
    print(json.dumps(result, indent=2))
