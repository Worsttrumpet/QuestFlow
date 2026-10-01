"""M6.6: Guide Data Preparation.

Assembles existing evidence into guide-ready structures. Does NOT introduce a
new evidence or conflict system -- per the explicit approval condition:

    M6.2 evidence_state remains authoritative for evidence strength.
    M6.4 classification remains authoritative for conflict/difference classification.
    M6.6 assembles and exposes those existing values; it does not reinterpret
    or replace them.

Reuses, unmodified: coverage.build_coverage() (M6.2) and
evidence_report.build_evidence_report() (M6.4). Neither module is imported
for its side effects or altered in any way -- this module only calls their
existing public functions and merges the two results.

`guide_ready` is computed strictly from the three required fields' actual
evidence_state values at run time -- never hardcoded to any specific count.
The current dataset happens to produce 8 guide-ready quests among the 10
Run-001 targets; that is a real-data regression assertion this module's own
test suite checks for, not a rule baked into the readiness logic itself.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import coverage  # noqa: E402 -- existing, unmodified M6.2 module
import evidence_report  # noqa: E402 -- existing, unmodified M6.4 module

OUT_DIR = Path(__file__).resolve().parents[1] / "out"

# The three fields a guide entry needs to be minimally useful, per the
# approved plan. Not all of coverage.QUEST_FIELD_MAP -- giver/position are
# capped at "observed" tier by design (the role-ambiguity and player-vs-NPC
# position caveats), so requiring "confirmed" for them would demand a
# stronger claim than the pipeline is built to ever make.
GUIDE_READY_REQUIRED_FIELDS = ("title", "quest_level", "objectives")

# Every field name coverage.py actually produces for a quest -- reused
# directly, not redefined, so this module can never silently drift from
# what M6.2 tracks.
ALL_QUEST_FIELDS = tuple(coverage.QUEST_FIELD_MAP.keys()) + tuple(coverage.ALWAYS_UNRESOLVED_FIELDS) + ("completion",)


def _is_guide_ready(fields: dict[str, dict]) -> bool:
    """Computed strictly from the actual evidence_state values present right
    now -- never a hardcoded count or quest-ID list."""
    return all(fields[f]["evidence_state"] == "confirmed" for f in GUIDE_READY_REQUIRED_FIELDS)


def build_guide_record(quest_id: int, coverage_fields: dict, evidence_fields: dict) -> dict[str, Any]:
    fields: dict[str, Any] = {}
    for field_name in ALL_QUEST_FIELDS:
        cov = coverage_fields.get(field_name, {"evidence_state": "unresolved", "observation_count": 0})
        ev = evidence_fields.get(field_name)  # None for fields M6.4 doesn't classify (prerequisites, completion)
        fields[field_name] = {
            "value": cov.get("value"),
            # Authoritative from M6.2 -- passed through unchanged, never recomputed.
            "evidence_state": cov["evidence_state"],
            # Authoritative from M6.4 -- passed through unchanged. None means
            # "not classified by M6.4" (prerequisites/completion aren't raw
            # assertion fields), not "no conflict" -- that distinction is
            # preserved, not collapsed.
            "classification": ev["classification"] if ev else None,
            "observation_count": cov.get("observation_count", 0),
            "sessions": cov.get("sessions", []),
            "builds": cov.get("builds", []),
        }
    return {
        "quest_id": quest_id,
        "guide_ready": _is_guide_ready(fields),
        "fields": fields,
    }


def build_guide_dataset() -> dict[str, Any]:
    cov = coverage.build_coverage()
    ev = evidence_report.build_evidence_report()

    records: dict[int, dict] = {}
    for qid, qcov in cov["quests"].items():
        qev_fields = ev["quests"].get(qid, {}).get("fields", {})
        records[qid] = build_guide_record(qid, qcov["fields"], qev_fields)

    guide_ready_ids = sorted(qid for qid, r in records.items() if r["guide_ready"])
    insufficient_ids = sorted(qid for qid, r in records.items() if not r["guide_ready"])

    # Aggregate, informational only: which required field most often blocks
    # readiness across the whole dataset -- not limited to Run-001's targets.
    blocking_field_counts: dict[str, int] = {f: 0 for f in GUIDE_READY_REQUIRED_FIELDS}
    for qid in insufficient_ids:
        for f in GUIDE_READY_REQUIRED_FIELDS:
            if records[qid]["fields"][f]["evidence_state"] != "confirmed":
                blocking_field_counts[f] += 1

    return {
        "source": "coverage.build_coverage() + evidence_report.build_evidence_report(), both unmodified",
        "guide_ready_required_fields": list(GUIDE_READY_REQUIRED_FIELDS),
        "quest_count": len(records),
        "guide_ready_count": len(guide_ready_ids),
        "insufficient_evidence_count": len(insufficient_ids),
        "guide_ready_quest_ids": guide_ready_ids,
        "insufficient_evidence_quest_ids": insufficient_ids,
        "blocking_field_counts": blocking_field_counts,
        "quests": records,
    }


if __name__ == "__main__":
    result = build_guide_dataset()
    out_path = OUT_DIR / "m6_guide_dataset.json"
    out_path.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
    print(f"wrote {out_path} ({out_path.stat().st_size} bytes)")
    print(f"quest_count={result['quest_count']} guide_ready={result['guide_ready_count']} "
          f"insufficient={result['insufficient_evidence_count']}")
    print("blocking_field_counts:", result["blocking_field_counts"])
