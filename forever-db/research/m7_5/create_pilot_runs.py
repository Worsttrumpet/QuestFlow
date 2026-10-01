"""M7.5: Human-Reviewed Pilot Collection -- run creation.

Deterministically selects 10 ATT-only, findability-qualified candidate
targets from research/m7_4/proposed_targets.json (unmodified, not
re-derived) and creates 10 SEPARATE planned CollectionRuns via the existing,
unmodified M6.3 collection_runs.py mechanism -- the same mechanism Run-001
used.

Selection method (documented, not a ranking): the 10 LOWEST quest IDs among
the 1,102 findability-qualified att_candidate_targets. This is the simplest
deterministic method available and makes no claim that these are the "best"
or "highest priority" quests -- only that they are reproducibly selected.

This module NEVER:
  - marks any run anything other than "planned"
  - writes an ATT value into any M6 evidence field
  - fabricates an observation
  - selects quest 794 or any of the 14 ATT/M6 intersection quests
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

FOREVER_DB_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, "/mnt/user-data/outputs/m6-dataset-baseline/scripts")
import collection_runs as cr  # noqa: E402 -- existing, unmodified M6.3 module

PROPOSAL_PATH = FOREVER_DB_ROOT / "research" / "m7_4" / "proposed_targets.json"
PILOT_SIZE = 10
EXCLUDED_IDS = {794, 788, 789, 790, 792, 804, 959, 3082, 4402, 4641, 92460, 92461, 92462, 92465}


def load_proposal() -> dict[str, Any]:
    return json.loads(PROPOSAL_PATH.read_text(encoding="utf-8"))


def select_pilot_targets(proposal: dict[str, Any], n: int = PILOT_SIZE) -> list[dict[str, Any]]:
    """The 10 lowest quest IDs among att_candidate_targets. Structurally
    verified (not merely assumed) to exclude quest 794 and every one of the
    14 ATT/M6 intersection quests, since those never appear in
    att_candidate_targets in the first place -- checked explicitly anyway."""
    targets = proposal["att_candidate_targets"]
    for t in targets:
        assert t["quest_id"] not in EXCLUDED_IDS, f"quest {t['quest_id']} must never be pilot-eligible"
    ordered = sorted(targets, key=lambda t: t["quest_id"])
    return ordered[:n]


def create_pilot_run(registry: cr.RunRegistry, target: dict[str, Any], att_snapshot: dict) -> cr.CollectionRun:
    qid = target["quest_id"]
    run_id = f"run-m7-5-pilot-{qid}"
    run = registry.create_run(
        run_id,
        purpose=f"M7.5 pilot: investigate ATT-only candidate quest {qid} in-game.",
        description="ATT candidate hint only -- not confirmed to exist in the live game. This run's "
                     "target_scope below carries source-derived information, never observed evidence. "
                     "Investigate, do not assume.",
    )
    cr.set_target_quest_ids(run, [qid])
    cr.set_target_fields(run, ["title", "quest_level", "objectives"])
    cr.set_target_scope(run, {
        "source": "M7.5 pilot, selected from research/m7_4/proposed_targets.json",
        "selection_method": "10 lowest quest IDs among the 1,102 findability-qualified att_candidate_targets",
        "att_candidate_hint": {
            "candidate_name": target["candidate_name"],
            "candidate_giver": target["candidate_giver"],
            "candidate_coordinates": target["candidate_coordinates"],
            "evidence_status": "source_derived_not_observed -- a collection hint only",
        },
        "att_snapshot": att_snapshot,
    })
    return run


def create_all_pilot_runs() -> list[str]:
    proposal = load_proposal()
    targets = select_pilot_targets(proposal)
    registry = cr.RunRegistry()
    created_ids = []
    for target in targets:
        run = create_pilot_run(registry, target, proposal["att_snapshot"])
        assert run.status == "planned"
        created_ids.append(run.run_id)
    registry.save()
    return created_ids


if __name__ == "__main__":
    created = create_all_pilot_runs()
    print(f"created {len(created)} planned pilot runs:")
    for rid in created:
        print(" ", rid)
