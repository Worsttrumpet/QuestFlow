"""M7.3: Cross-Source Coverage & Evidence-Gap Analysis.

Read-only. Compares the already-preserved ATT candidate snapshot (data/raw/att-head,
acquired and verified in M7.2-B) against the existing M6 observed dataset
(coverage.build_coverage(), unmodified). Writes NOTHING back to either: the
ATT import runs in a throwaway in-memory SQLite connection (the same pattern
M7.2-B already established and tested), and coverage.build_coverage() is only
called, never written to.

Central rule, enforced throughout: ATT is candidate/source-derived information.
M6 is observed evidence. This module never labels an ATT-only fact "observed"
and never writes to any M6 output file.
"""
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

FOREVER_DB_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FOREVER_DB_ROOT / "src"))
sys.path.insert(0, "/mnt/user-data/outputs/m6-dataset-baseline/scripts")

from foreverdb import acquire, cli, client_tables, coords, db  # noqa: E402
from foreverdb.att import importer as ATT  # noqa: E402
import coverage  # noqa: E402 -- the existing, unmodified M6.2 module

RAW_DIR = FOREVER_DB_ROOT / "data" / "raw"

# Maps the ATT importer's own real field names (verbatim from
# src/foreverdb/att/importer.py -- nothing invented here) to the semantic
# categories M7.3's spec asks for. One ATT field can serve one category only,
# chosen by its most direct meaning; several ATT fields can map to none of
# the spec's named categories, and those are reported under "other".
FIELD_CATEGORY_MAP = {
    "name.att_comment": "name",
    "level.att_lvl_unverified": "level",
    "giver.npc": "giver",
    "location.att_coord": "coordinates",
    "objective.att": "objectives",
    "att.item_child_unverified": "item_reward_related",
    "relation.att_source_quest": "prerequisites",
    "relation.att_alt_quest": "prerequisites",
    "flight_master.att_cr": "other",
    "att.flag.isBreadcrumb": "other",
    "att.flag.repeatable": "other",
    "att.flag.isYearly": "other",
    "att.flag.isMonthly": "other",
    "att.flag.isWeekly": "other",
    "att.flag.isDaily": "other",
    "att.restriction.races": "other",
    "att.restriction.classes": "other",
    "att.provider": "other",
    "att.providers": "other",
    "att.qi": "other",
    "att.qis": "other",
    "att.qs": "other",
    "att.cr": "other",
    "att.crs": "other",
}

# M6 fields that correspond most directly to an ATT category, used only for
# the observed-evidence-gap comparison (section 3 of the spec) -- this is a
# reporting-time mapping for comparison purposes only; it does not change
# M6's own field definitions or evidence states in any way.
M6_FIELD_FOR_ATT_CATEGORY = {
    "level": "quest_level",
    "giver": "giver",
    "objectives": "objectives",
}


def run_att_import() -> tuple[ATT.ImportReport, dict[int, set[str]]]:
    """Runs the EXISTING, UNMODIFIED ATT importer against the preserved
    att-head snapshot, in a throwaway in-memory connection -- the identical
    pattern M7.2-B already used and verified. Returns the report plus a
    per-quest map of which raw ATT field names were emitted for it."""
    conn = db.connect(":memory:")
    db.init_schema(conn)
    info, cfg = cli.snapshot_info(FOREVER_DB_ROOT, "att-head", RAW_DIR)
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

    report = ATT.import_att_snapshot(conn, info, cfg["forever_root"], cfg["constants"], cfg["config"])

    rows = conn.execute(
        "SELECT entity_id, field FROM assertion WHERE entity_type='quest'"
    ).fetchall()
    quest_fields: dict[int, set[str]] = defaultdict(set)
    for qid, field_name in rows:
        quest_fields[qid].add(field_name)
    return report, dict(quest_fields)


def categorize_fields(field_names: set[str]) -> set[str]:
    return {FIELD_CATEGORY_MAP.get(f, "other") for f in field_names}


def build_analysis() -> dict[str, Any]:
    att_report, att_quest_fields = run_att_import()
    # att_report.quest_ids (1,537) is every q() call ATT's parser encountered --
    # the same figure M7.2-B verified exactly against the historical import.
    # att_quest_fields only has entries for quests that emitted at least one
    # assertion (1,513) -- 24 IDs are bare q() stubs with no comment/fields at
    # all. The population used for set overlap is the full 1,537 (matching
    # the verified historical count); field-coverage analysis naturally only
    # ever applies to the 1,513 that have something to categorize.
    att_ids = set(att_report.quest_ids)
    att_ids_with_fields = set(att_quest_fields.keys())

    m6_cov = coverage.build_coverage()
    m6_ids = set(m6_cov["quests"].keys())  # native int keys from the in-memory call, not JSON-stringified

    intersection = sorted(att_ids & m6_ids)
    att_only = sorted(att_ids - m6_ids)
    m6_only = sorted(m6_ids - att_ids)

    def field_coverage_summary(quest_ids: list[int]) -> dict[str, int]:
        cat_counts: Counter[str] = Counter()
        for qid in quest_ids:
            for cat in categorize_fields(att_quest_fields.get(qid, set())):
                cat_counts[cat] += 1
        return dict(sorted(cat_counts.items()))

    field_coverage = {
        "all_att_quests": field_coverage_summary(sorted(att_ids)),
        "att_only_quests": field_coverage_summary(att_only),
        "att_and_m6_quests": field_coverage_summary(intersection),
    }

    # Observed-evidence gap: for quests BOTH in ATT and M6, where M6's own
    # field is still unresolved but ATT has SOME candidate data for the
    # corresponding category. Reported as a gap list -- never as a value to
    # adopt. M6's evidence_state is read, never written.
    gaps = []
    for qid in intersection:
        m6_fields = m6_cov["quests"][qid]["fields"]
        att_cats = categorize_fields(att_quest_fields[qid])
        for att_cat, m6_field in M6_FIELD_FOR_ATT_CATEGORY.items():
            if att_cat in att_cats and m6_fields[m6_field]["evidence_state"] == "unresolved":
                gaps.append({
                    "quest_id": qid,
                    "m6_field": m6_field,
                    "m6_evidence_state": "unresolved",
                    "att_category_available": att_cat,
                    "note": "ATT candidate data exists for this category; M6 has no observed evidence for "
                            "this field. This is a collection-priority signal, not a value to adopt.",
                })

    return {
        "methodology": "ATT imported fresh via the existing, unmodified src/foreverdb/att/importer.py "
                        "against the preserved data/raw/att-head snapshot (commit "
                        "8e25511677df4ea5c3d0322009eafc18f203ffd3), in a throwaway in-memory SQLite "
                        "connection. M6 population read via the existing, unmodified "
                        "coverage.build_coverage(). Neither source was written to.",
        "att_quest_count": len(att_ids),
        "att_quests_with_zero_candidate_fields": len(att_ids - att_ids_with_fields),
        "att_quests_with_zero_candidate_fields_note": "bare q()-call stubs in ATT's source with no "
                                                       "comment, giver, level, coordinate, or objective "
                                                       "data at all -- included in the population count "
                                                       "since ATT's own parser counts them, but they "
                                                       "contribute nothing to the field-coverage figures.",
        "att_import_summary": att_report.summary(),
        "m6_observed_quest_count": len(m6_ids),
        "intersection_count": len(intersection),
        "att_only_count": len(att_only),
        "m6_only_count": len(m6_only),
        "intersection_quest_ids": intersection,
        "att_only_quest_ids": att_only,
        "m6_only_quest_ids": m6_only,
        "field_category_coverage": field_coverage,
        "observed_evidence_gaps": gaps,
        "observed_evidence_gap_count": len(gaps),
    }


if __name__ == "__main__":
    result = build_analysis()
    out_path = Path(__file__).resolve().parent / "coverage_gap_analysis.json"
    out_path.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
    print(f"wrote {out_path} ({out_path.stat().st_size} bytes)")
    print(f"ATT quests: {result['att_quest_count']} | M6 observed: {result['m6_observed_quest_count']}")
    print(f"intersection: {result['intersection_count']} | ATT-only: {result['att_only_count']} | "
          f"M6-only: {result['m6_only_count']}")
    print("field_category_coverage:", json.dumps(result["field_category_coverage"], indent=2))
    print("observed_evidence_gap_count:", result["observed_evidence_gap_count"])
