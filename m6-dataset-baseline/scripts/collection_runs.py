"""M6.3: Collection Run Tracking.

Layering, exactly as specified -- never collapsed together:

    Collection Run (organizational metadata, this module)
        -> Session(s) (recorder session IDs, associated but not owned by a run)
            -> Observations (raw export data)
                -> Assertions / Evidence (M4, unchanged)
                    -> M6.2 Coverage (unchanged, reused via coverage.build_coverage())

A collection run is bookkeeping about *intent and organization* -- it does not
itself make any observation more trustworthy, and associating a session with
a run does not change that session's evidence in any way. Evidence state
remains exactly what M6.2's coverage layer already says it is.

Storage: a single JSON registry (out/m6_collection_runs.json), matching the
established M6.1/M6.2 convention, plus small per-run coverage SNAPSHOT files
under out/coverage_snapshots/ (the full coverage output is ~1.4MB; embedding
two full copies per run directly in the registry would make the registry
itself unreadable). The registry stores each snapshot's path and a content
hash, not the snapshot's content.

No M4/M5 file, schema, or observation contract is read for write access,
modified, or has any new dependency introduced by this module.
"""
from __future__ import annotations

import hashlib
import json
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import coverage  # noqa: E402 -- the existing, unmodified M6.2 module; reused, not duplicated

OUT_DIR = Path(__file__).resolve().parents[1] / "out"
REGISTRY_PATH = OUT_DIR / "m6_collection_runs.json"
SNAPSHOT_DIR = OUT_DIR / "coverage_snapshots"

VALID_STATUSES = ("planned", "active", "completed", "abandoned")
# planned -> active -> completed, or -> abandoned from planned or active.
# No other transition is permitted -- this is intentionally a small, fixed
# lifecycle, not a general workflow engine (per the "keep it small" rule).
VALID_TRANSITIONS = {
    "planned": {"active", "abandoned"},
    "active": {"completed", "abandoned"},
    "completed": set(),
    "abandoned": set(),
}


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


@dataclass
class CollectionRun:
    run_id: str
    status: str = "planned"
    purpose: str = ""
    description: str = ""
    target_quest_ids: list[int] = field(default_factory=list)
    target_fields: list[str] = field(default_factory=list)
    target_scope: dict[str, Any] = field(default_factory=dict)
    created_at: str = field(default_factory=_now)
    started_at: str | None = None
    completed_at: str | None = None
    notes: list[str] = field(default_factory=list)
    session_ids: list[str] = field(default_factory=list)
    before_coverage_ref: dict[str, Any] | None = None
    after_coverage_ref: dict[str, Any] | None = None
    results: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @staticmethod
    def from_dict(d: dict[str, Any]) -> "CollectionRun":
        return CollectionRun(**d)


class RunRegistry:
    """Thin JSON-file-backed store. Loads eagerly, saves explicitly -- no
    implicit autosave, so a caller can make several changes and persist once."""

    def __init__(self, path: Path = REGISTRY_PATH):
        self.path = path
        self.runs: dict[str, CollectionRun] = {}
        if self.path.exists():
            data = json.loads(self.path.read_text(encoding="utf-8"))
            self.runs = {rid: CollectionRun.from_dict(r) for rid, r in data.items()}

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(
            json.dumps({rid: r.to_dict() for rid, r in self.runs.items()}, indent=2), encoding="utf-8")

    def create_run(self, run_id: str, purpose: str, description: str = "") -> CollectionRun:
        if run_id in self.runs:
            raise ValueError(f"run_id {run_id!r} already exists -- run IDs must be unique")
        run = CollectionRun(run_id=run_id, purpose=purpose, description=description)
        self.runs[run_id] = run
        return run

    def get_run(self, run_id: str) -> CollectionRun:
        if run_id not in self.runs:
            raise KeyError(f"no such run: {run_id!r}")
        return self.runs[run_id]

    def list_runs(self) -> list[CollectionRun]:
        return list(self.runs.values())


def transition_status(run: CollectionRun, new_status: str) -> None:
    if new_status not in VALID_STATUSES:
        raise ValueError(f"unknown status {new_status!r}; must be one of {VALID_STATUSES}")
    allowed = VALID_TRANSITIONS[run.status]
    if new_status not in allowed:
        raise ValueError(f"cannot transition run {run.run_id!r} from {run.status!r} to {new_status!r} "
                          f"(allowed from {run.status!r}: {sorted(allowed) or 'none -- terminal state'})")
    run.status = new_status
    if new_status == "active" and run.started_at is None:
        run.started_at = _now()
    if new_status in ("completed", "abandoned"):
        run.completed_at = _now()


def set_target_quest_ids(run: CollectionRun, quest_ids: list[int]) -> None:
    """No validation that these IDs already have coverage -- a run may
    deliberately target quests with NO current evidence at all; that is
    exactly the point of a 'planned' run. This never writes a fabricated
    fact about any quest -- it only records that the RUN intends to look
    at these IDs, which is metadata about the run, not evidence about the
    quest."""
    run.target_quest_ids = sorted(set(quest_ids))


def set_target_fields(run: CollectionRun, fields: list[str]) -> None:
    unknown = set(fields) - set(coverage.QUEST_FIELD_MAP.keys()) - set(coverage.ALWAYS_UNRESOLVED_FIELDS) - {"completion"}
    if unknown:
        raise ValueError(f"unknown target field(s) {sorted(unknown)} -- not part of the existing "
                          f"M6.2 coverage field set")
    run.target_fields = sorted(set(fields))


def set_target_scope(run: CollectionRun, scope: dict[str, Any]) -> None:
    run.target_scope = dict(scope)


def associate_session(run: CollectionRun, session_id: str) -> None:
    """Idempotent: associating the same session twice does not duplicate it,
    and never removes or reorders sessions already associated."""
    if session_id not in run.session_ids:
        run.session_ids.append(session_id)


def _hash_json(obj: Any) -> str:
    return hashlib.sha256(json.dumps(obj, sort_keys=True).encode("utf-8")).hexdigest()


def snapshot_coverage(run: CollectionRun, which: str) -> dict[str, Any]:
    """Computes coverage fresh via the EXISTING, UNMODIFIED M6.2
    build_coverage() (never duplicated), writes it to its own small file, and
    stores a path+hash reference on the run -- not the coverage content
    itself, keeping the registry file itself small and readable."""
    if which not in ("before", "after"):
        raise ValueError("which must be 'before' or 'after'")
    result = coverage.build_coverage()
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    snap_path = SNAPSHOT_DIR / f"{run.run_id}_{which}.json"
    snap_path.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
    ref = {
        "path": str(snap_path.relative_to(OUT_DIR)),
        "sha256": _hash_json(result),
        "captured_at": _now(),
        "quest_count": result["quest_count"],
        "npc_count": result["npc_count"],
    }
    if which == "before":
        run.before_coverage_ref = ref
    else:
        run.after_coverage_ref = ref
    return ref


def compute_coverage_delta(run: CollectionRun) -> dict[str, Any]:
    """Compares two coverage snapshots FIELD-BY-FIELD, per quest -- an actual
    evidence_state transition is a real coverage change; a rise in
    observation_count alone with no evidence_state change is explicitly NOT
    counted as a coverage change, per the project's own rule that observation
    count must never be treated as proof of increased coverage."""
    if run.before_coverage_ref is None or run.after_coverage_ref is None:
        return {"status": "unknown", "reason": "both a before and an after snapshot are required; at "
                                                 "least one is missing for this run -- no result is "
                                                 "estimated in its place"}

    before = json.loads((OUT_DIR / run.before_coverage_ref["path"]).read_text(encoding="utf-8"))
    after = json.loads((OUT_DIR / run.after_coverage_ref["path"]).read_text(encoding="utf-8"))

    target_quests = set(run.target_quest_ids) if run.target_quest_ids else (
        set(before["quests"].keys()) | set(after["quests"].keys()))
    target_fields = set(run.target_fields) if run.target_fields else None  # None = all fields

    new_quests = sorted(int(q) for q in (set(after["quests"].keys()) - set(before["quests"].keys()))
                         if int(q) in target_quests or not run.target_quest_ids)
    fields_resolved = []
    fields_regressed = []
    for qid_str in target_quests:
        qid_str = str(qid_str)
        b_quest = before["quests"].get(qid_str)
        a_quest = after["quests"].get(qid_str)
        if not a_quest:
            continue
        fields_to_check = target_fields or set(a_quest["fields"].keys())
        for fname in fields_to_check:
            b_state = (b_quest["fields"].get(fname, {}).get("evidence_state") if b_quest else "unresolved")
            a_state = a_quest["fields"].get(fname, {}).get("evidence_state", "unresolved")
            if b_state == "unresolved" and a_state != "unresolved":
                fields_resolved.append({"quest_id": int(qid_str), "field": fname,
                                         "evidence_state": a_state})
            elif b_state != "unresolved" and a_state == "unresolved":
                # A field that regresses to unresolved would be a real anomaly
                # worth surfacing, not silently dropping -- this project never
                # deletes evidence, so this should not normally happen; if it
                # does, it is reported, not hidden.
                fields_regressed.append({"quest_id": int(qid_str), "field": fname,
                                          "previous_evidence_state": b_state})

    remaining_targets = []
    if run.target_quest_ids and run.target_fields:
        for qid in run.target_quest_ids:
            a_quest = after["quests"].get(str(qid))
            for fname in run.target_fields:
                state = (a_quest["fields"].get(fname, {}).get("evidence_state", "unresolved")
                         if a_quest else "unresolved")
                if state == "unresolved":
                    remaining_targets.append({"quest_id": qid, "field": fname})

    return {
        "status": "computed",
        "new_quests_observed": new_quests,
        "fields_resolved": fields_resolved,
        "fields_resolved_count": len(fields_resolved),
        "fields_regressed": fields_regressed,
        "remaining_targets": remaining_targets if (run.target_quest_ids and run.target_fields) else None,
        "note": "Only genuine evidence_state transitions are counted here. A rise in observation_count "
                "with no evidence_state change is deliberately NOT reported as a coverage change.",
    }


def finalize_run_results(run: CollectionRun) -> None:
    """Populates run.results from whatever can actually be established --
    never estimates a value it cannot compute."""
    delta = compute_coverage_delta(run)
    run.results = {
        "sessions_used": list(run.session_ids),
        "coverage_delta": delta,
    }
