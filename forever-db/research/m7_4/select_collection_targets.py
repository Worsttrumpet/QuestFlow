"""M7.4: ATT Candidate Collection Target Proposal.

Read-only. Produces a human-reviewable proposal of which ATT-only quests
have enough candidate information (name + giver + coordinates) to be worth
investigating in-game, plus a separate follow-up section for quest 794 (the
one M7.3 observed-evidence gap).

This module NEVER:
  - writes to any M6 output file
  - creates an M6 CollectionRun (active, planned, or otherwise)
  - labels any ATT value "observed", "confirmed", or "verified"

It reuses, unmodified: the existing ATT importer (src/foreverdb/att/importer.py),
run against the already-preserved, already-verified att-head snapshot (commit
8e25511677df4ea5c3d0322009eafc18f203ffd3 -- no new revision fetched), and the
existing M6 coverage machinery (coverage.build_coverage()), called read-only.

research/m7_3/coverage_gap_analysis.py and its JSON output are locked and are
not imported or modified by this module -- the ATT-only ID list and quest 794
finding are the only facts carried over from it (as literal, restated values,
re-derivable independently), everything else here is derived fresh from the
same underlying sources M7.3 used.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

FOREVER_DB_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FOREVER_DB_ROOT / "src"))
sys.path.insert(0, "/mnt/user-data/outputs/m6-dataset-baseline/scripts")

from foreverdb import acquire, cli, client_tables, coords, db  # noqa: E402
from foreverdb.att import importer as ATT  # noqa: E402
import coverage  # noqa: E402 -- existing, unmodified M6.2 module; read-only use

RAW_DIR = FOREVER_DB_ROOT / "data" / "raw"
ATT_SNAPSHOT_SHA = "8e25511677df4ea5c3d0322009eafc18f203ffd3"
ATT_SNAPSHOT_KEY = "att-head"

# The one M7.3 finding this module restates rather than re-derives from scratch:
# quest 794 already has full M6 context available via coverage.build_coverage()
# itself, so its "unresolved objectives" status is re-checked live below, not
# merely copied from the M7.3 report.
QUEST_794_ID = 794


def run_att_import_with_values() -> tuple[set[int], dict[int, dict[str, list[Any]]]]:
    """Runs the EXISTING, UNMODIFIED ATT importer against the preserved
    att-head snapshot, in a throwaway in-memory connection. Returns the full
    ATT quest-ID population (matching M7.3's own 1,537/1,523 figures exactly
    -- including the 24 bare q()-call stubs with no assertions at all) and a
    per-quest dict of {field_name: [values]} for quests that have at least
    one assertion (1,513 of the 1,537 -- a stub quest correctly cannot
    qualify for any completeness group, with no special-casing needed)."""
    conn = db.connect(":memory:")
    db.init_schema(conn)
    info, cfg = cli.snapshot_info(FOREVER_DB_ROOT, ATT_SNAPSHOT_KEY, RAW_DIR)
    assert info.sha == ATT_SNAPSHOT_SHA, "refusing to proceed: pinned commit mismatch"
    build = cli.snapshot_source_set(info, cfg).build_claim
    for table in ("UiMapAssignment", "TaxiNodes", "UiMap"):
        rel = f"{cfg['wago_dir']}/{table}.{build}.csv"
        ds = db.insert_dataset(conn, acquire.mirrored_csv_record(info, rel, build))
        if table == "UiMapAssignment":
            assignments = coords.read_assignments(info.root / rel)
            coords.load_assignments_into_db(conn, assignments, ds)
        elif table == "TaxiNodes":
            client_tables.load_taxi_nodes(conn, info.root / rel, ds)
        else:
            client_tables.load_ui_maps(conn, info.root / rel, ds)

    att_report = ATT.import_att_snapshot(conn, info, cfg["forever_root"], cfg["constants"], cfg["config"])

    rows = conn.execute(
        "SELECT entity_id, field, value_json FROM assertion WHERE entity_type='quest' ORDER BY entity_id, field, assertion_id"
    ).fetchall()
    out: dict[int, dict[str, list[Any]]] = {}
    for qid, field_name, value_json in rows:
        out.setdefault(qid, {}).setdefault(field_name, []).append(json.loads(value_json))
    return set(att_report.quest_ids), out


def build_proposal() -> dict[str, Any]:
    att_ids, att_fields = run_att_import_with_values()

    m6_cov = coverage.build_coverage()
    m6_ids = set(m6_cov["quests"].keys())  # native int keys

    att_only_ids = sorted(att_ids - m6_ids)

    def has(qid: int, field_name: str) -> bool:
        return bool(att_fields.get(qid, {}).get(field_name))

    def group(*field_names: str) -> list[int]:
        return sorted(q for q in att_only_ids if all(has(q, f) for f in field_names))

    completeness = {
        "with_name": group("name.att_comment"),
        "with_coordinates": group("location.att_coord"),
        "with_giver": group("giver.npc"),
        "with_name_and_coordinates": group("name.att_comment", "location.att_coord"),
        "with_name_and_giver": group("name.att_comment", "giver.npc"),
        "with_giver_and_coordinates": group("giver.npc", "location.att_coord"),
        "with_name_and_giver_and_coordinates": group("name.att_comment", "giver.npc", "location.att_coord"),
    }
    completeness_counts = {k: len(v) for k, v in completeness.items()}

    qualified_ids = completeness["with_name_and_giver_and_coordinates"]
    # Sanity: every qualified target must genuinely be ATT-only and never one
    # of the 14 ATT/M6 intersection quests -- checked structurally, not assumed.
    assert all(q not in m6_ids for q in qualified_ids)
    assert QUEST_794_ID not in qualified_ids

    # Constant fields (snapshot identity, evidence status, the collection-hint
    # note, intended fields) are stated ONCE at the top level of the output,
    # not repeated per target -- 1,102 targets repeating ~300 bytes of
    # identical text each pushed the file well past this repo's own
    # pre-existing 1MB tracked-file limit (test_repo_safety.py) for no
    # informational gain. Every fact is still present; nothing is cut, only
    # de-duplicated.
    att_candidate_targets = []
    for qid in qualified_ids:
        fields = att_fields[qid]
        att_candidate_targets.append({
            "quest_id": qid,
            "status": "candidate_target",
            "candidate_name": fields["name.att_comment"][0],
            "candidate_giver": fields["giver.npc"],
            "candidate_coordinates": fields["location.att_coord"],
        })

    # Observed-evidence follow-up: quest 794, checked live against current M6
    # coverage, not merely copied from the M7.3 report.
    q794_m6 = m6_cov["quests"].get(QUEST_794_ID)
    followups = []
    if q794_m6 is not None:
        obj_field = q794_m6["fields"]["objectives"]
        att_794 = att_fields.get(QUEST_794_ID, {})
        followups.append({
            "quest_id": QUEST_794_ID,
            "target_field": "objectives",
            "current_m6_evidence_state": obj_field["evidence_state"],
            "att_has_candidate_objective_info": bool(att_794.get("objective.att")),
            "att_candidate_objective_data": att_794.get("objective.att", []),
        })

    return {
        "milestone": "M7.4",
        "purpose": "Human-reviewable proposal of ATT-only collection targets and one observed-evidence "
                   "follow-up. This is a review artifact, not an M6 CollectionRun and not observed evidence.",
        "att_snapshot": {"repo": "https://github.com/ATTWoWAddon/AllTheThings.git", "sha": ATT_SNAPSHOT_SHA,
                          "key": ATT_SNAPSHOT_KEY,
                          "note": "Applies to every candidate value in this entire file -- name, giver, "
                                   "coordinates, and the quest-794 objective data -- not just the entries "
                                   "that repeat it."},
        "evidence_status": "source_derived_not_observed -- applies to every candidate_* field and every "
                            "att_candidate_* field in this entire file. None of it is confirmed, verified, "
                            "or observed game data; it is a collection hint only. Investigate in-game, do "
                            "not assume.",
        "intended_future_collection_fields_for_att_candidate_targets": ["title", "quest_level", "objectives"],
        "att_only_count": len(att_only_ids),
        "m6_observed_count": len(m6_ids),
        "completeness_counts": completeness_counts,
        "findability_qualified_count": len(qualified_ids),
        "observed_evidence_followups": followups,
        "att_candidate_targets": att_candidate_targets,
    }


if __name__ == "__main__":
    result = build_proposal()
    out_path = Path(__file__).resolve().parent / "proposed_targets.json"
    out_path.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
    print(f"wrote {out_path} ({out_path.stat().st_size} bytes)")
    print("completeness_counts:", json.dumps(result["completeness_counts"], indent=2))
    print("findability_qualified_count:", result["findability_qualified_count"])
    print("observed_evidence_followups:", len(result["observed_evidence_followups"]))
