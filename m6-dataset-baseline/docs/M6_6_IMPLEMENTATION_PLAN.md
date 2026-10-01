# M6.6 Implementation Plan — Guide Data Preparation

**This is a planning document only.** No code was written, no existing file was modified, and M6.6 has not
been started. Grounded directly against the current repository state — `coverage.py`'s actual field map
and checkpoint-priority logic, and the real current dataset (121 quest entities; exactly 8 of the 10 M6.5
targets have both `title` and `quest_level` confirmed, matching the honest 8/10 result) — not assumed from
memory.

## 1. Original M6.6 Objective

Per the M6 master plan: **"Begin transforming well-supported observations into guide-ready structures."**
Explicitly not the final interactive map, not route optimization, not a finished leveling guide — M6 rule
28 rules all of that out, and the master plan's own layering diagram (Section 12) places M6.6 as the *last*
step of a chain that starts with the candidate universe and ends at "usable guide data," consuming only
what's already been observed, not expanding what's known.

## 2. Exact Inputs

- **Primary**: `coverage.build_coverage()` — the existing, unmodified M6.2 function — as the sole source of
  per-field evidence (`evidence_state`, representative `value`, provenance). M6.6 does not re-parse the raw
  SavedVariables export itself; that would duplicate M6.2's own work.
- **Secondary**: `evidence_report.build_evidence_report()` — the existing, unmodified M6.4 function — for
  each field's `classification` (`none`/`state_change`/`position_variance`/`genuine_conflict`/
  `ambiguous_difference`), so a guide record can carry a conflict flag rather than silently picking a value.
- **Informational only**: `m6_collection_runs.json` — for provenance/traceability (which run/session
  produced a given quest's resolution), never as a data source in its own right.
- **Explicitly not an input yet**: any QuestV2/ATT/Era candidate data (see item 8).

## 3. Exact Outputs

- **Machine-readable**: `out/m6_guide_dataset.json` — one record per quest entity already known to
  `coverage.py`, each field carrying its value, evidence tier, and conflict classification; plus a
  `guide_ready` boolean per quest based on a minimum-field threshold (defined in Section 5).
- **Human-readable**: `docs/M6_GUIDE_DATA_REPORT.md`, matching the established naming and evidence-tagging
  convention (`[data-verified]`/`[code-verified]`/`[reported]`) used in every prior M6 report.

## 4. Evidence States/Classifications That Must Be Preserved

Both existing layers, never collapsed into one flag:
- M6.2's tiers: `confirmed`, `observed`, `unresolved` (and the model's broader `inferred`/`candidate`/
  `placeholder`, though none of the last three are actually produced by any current code path).
- M6.4's classifications: `none`, `single_observation`, `no_evidence`, `state_change`,
  `position_variance`, `genuine_conflict`, `ambiguous_difference`.

A guide record's field looks like `{value, evidence_state, classification, sessions, builds}` — the same
shape M6.2 already produces, passed through, not flattened into a single "is this field good" flag.

## 5. Representation of Confirmed/Observed/Inferred/Candidate/Placeholder/Unresolved Data

Field-level, exactly as M6.2 already does — never one whole-quest status. Proposed **guide-readiness
threshold**, stated explicitly here as a decision M6.6 needs to formalize, not something already decided:
a quest is `guide_ready: true` only if `title`, `quest_level`, and `objectives` are all `confirmed` — the
same three fields Run-001 itself targeted, which is not a coincidence: they're the minimum a leveling guide
entry needs to be useful at all. `giver` and `interaction_position` are valuable but capped at `observed`
tier by design (per the already-documented role-ambiguity and player-vs-NPC-position caveats), so requiring
`confirmed` giver evidence for guide-readiness would make the bar unreachable under the current evidence
model — the threshold should not implicitly demand a stronger claim than the pipeline is designed to make.
`candidate`/`placeholder` do not appear in current output at all (no candidate-source data exists yet to
produce them) and require no special handling until item 8's later milestone begins.

## 6. How M6.5's Real Evidence Flows Into the Guide Dataset

The 8 quests Run-001 resolved (92516, 92517, 92553, 93318, 93319, 93951, 94411, 97970) become the **first
real candidates** to actually clear the `guide_ready` threshold above — verified directly against the
current dataset, not assumed: all 8 show `title` and `quest_level` confirmed; 7 of 8 also show `objectives`
confirmed (93319 shows `objectives: confirmed` too, from its successful `quest_complete_immediate`
checkpoint, despite the delayed-checkpoint anomaly). `coverage.py`'s existing checkpoint-priority logic
(`QUEST_TURNED_IN` > `quest_complete_delayed` > `quest_complete_immediate` > `quest_detail` >
`GOSSIP_SHOW`) already selects the most complete real value for each field — M6.6 reuses this directly
rather than re-deriving a preference order of its own.

## 7. Unknown/Missing Fields Stay Explicit

A guide record is still produced for a quest below the readiness threshold — it is not excluded from
output, per the master plan's own rule that "a partially known quest is still useful." Its `guide_ready`
flag is simply `false`, and each missing field shows `evidence_state: unresolved` (or `no_evidence`), never
a fabricated value. **95350 and 99196 are the concrete test cases for this**: both should appear in
`m6_guide_dataset.json` with `guide_ready: false` and their known fields (95350's giver/position/
reputation; 99196's bare title, explicitly *not* promoted from its Gossip-only source into the formal
`title` field) intact, not omitted.

## 8. Does M6.6 Need QuestV2/ATT Candidate Data?

**No — and it shouldn't, yet.** The master plan's own layering (`database candidate universe → possible
Forever content → observed Forever content → usable guide data`) places QuestV2/ATT ingestion as a
*separate, earlier* concern from guide-data preparation. M6.6 operates purely on what has already been
directly observed. Introducing candidate data now would also violate the standing project-wide rule
against fabricating or approximating that data (M6.1's own limitation, never filled in since) and would
conflate "things we know about" with "things we've merely heard exist" right at the step meant to produce
the most trustworthy output. This belongs to a distinct, later milestone — call it M6.7 or a discovery-
phase milestone — not M6.6.

## 9. Conflicts Between the Original Plan and What M6.5 Taught Us

- The original plan's phrasing ("well-supported observations") implicitly suggests a quest either is or
  isn't ready. **M6.5 concretely demonstrated this is never binary at the milestone level** — a genuinely
  successful collection round still ended at 8/10, not 10/10, for reasons (95350's likely pre-existing
  completion, 99196's material requirement) that have nothing to do with the pipeline's own correctness.
  M6.6's design (Sections 5 and 7) already accounts for this — no conflict requiring a plan change, but
  worth stating explicitly rather than silently assumed.
- The `giver.npc` role-ambiguity limitation (documented since M4, reconfirmed structurally still open)
  means M6.6 cannot yet present "the quest giver" as a single confident fact for any quest with multiple
  checkpoint-tagged giver observations — the guide dataset must carry the same caveat forward, not resolve
  it by picking whichever value `coverage.py`'s checkpoint-priority happens to select.

## 10. Files That Must Remain Frozen

Everything already established as frozen through M6.5: `forever-db/` (M4), the Observation Lab, the M5
recorder, and every existing M6.1–M6.4 script (`inventory.py`, `coverage.py`, `collection_runs.py`,
`evidence_report.py`) and their outputs. M6.6 is additive — a new script consuming existing functions —
never a modification to any of these. This explicitly includes `coverage.py`'s known non-deterministic
JSON-ordering issue (Section 13 of the M6.5 report): **not fixed as part of M6.6**, and M6.6's own output
should not rely on hash-based comparison of `coverage.py`'s output for anything — if M6.6 needs its own
determinism guarantee (e.g., for its own idempotency tests), it should sort its own output independently
rather than depend on `coverage.py`'s internal ordering.

## 11. Proposed Small Implementation Steps

1. Formalize the `guide_ready` threshold and the guide-record shape as a short written decision (Sections
   5–7 above, reviewed and confirmed) — no code yet.
2. Write `scripts/guide_data.py`: a single function that calls `coverage.build_coverage()` and
   `evidence_report.build_evidence_report()` (both unmodified) and merges them into one guide record per
   quest.
3. Apply the readiness threshold; split into `guide_ready` and `insufficient_evidence` groups in the output
   structure.
4. Generate `out/m6_guide_dataset.json` from the current real dataset; inspect manually before trusting it
   (same discipline as every prior M6 milestone).
5. Add focused tests (Section 12) using synthetic assertions, matching M6.2/M6.3/M6.4's own test style —
   not a new testing approach.
6. Run the full regression suite (M6.1–M6.5 tests plus M4's) and confirm preservation hashes, exactly as
   every prior milestone has.
7. Write `docs/M6_GUIDE_DATA_REPORT.md` documenting real findings from the actual current dataset — how
   many of the 121 known quests clear the threshold, which fields are the most common blockers overall
   (not just for the 10 Run-001 quests).
8. Stop. Do not begin whatever comes after M6.6 in the same pass.

## 12. Tests to Add or Reuse

New, focused tests (synthetic fixtures, not real-data-only):
- A quest with all three threshold fields confirmed → `guide_ready: true`.
- A quest missing any one of the three → `guide_ready: false`, but still present in the output with its
  other fields intact (never excluded entirely).
- A field with a `genuine_conflict` classification is still included, flagged, never silently dropped or
  auto-resolved.
- Gossip-only title evidence is never promoted into the formal `title` field of a guide record, even when
  it's the only title-like information available — mirrors the exact 99196 case directly.
- `giver` never reaches `guide_ready`-qualifying tier on its own inclusion in the threshold — confirms the
  threshold definition itself doesn't accidentally require an evidence tier the pipeline can't produce.
- Idempotent regeneration: running guide-dataset generation twice against the same underlying data produces
  byte-identical output (sorted independently of `coverage.py`'s own known ordering issue).
- A real-data smoke test against the current dataset, asserting exactly 8 (not more, not fewer) of the 10
  named M6.5 target quests show `guide_ready: true` — a concrete, falsifiable check tied to this round's
  actual, verified result, not a vague "some quests resolve" assertion.

Reused, unmodified: the existing M6.2/M6.3/M6.4 test suites continue running as regression checks; nothing
about them changes for M6.6.

## Known Limitations (Anticipated, Not Yet Encountered)

- The `guide_ready` threshold proposed here (title + level + objectives) is a judgment call, not something
  derived mechanically from the master plan — it should be confirmed, not assumed, before implementation.
- No quest in the current dataset has ever produced a `candidate` or `placeholder` evidence state, so
  M6.6's handling of those two tiers is necessarily speculative until real candidate-source data exists
  (item 8) — this cannot be tested against real data yet, only reasoned about.
- `coverage.py`'s ordering issue means any two independently-generated `m6_coverage.json` snapshots of
  identical data may not be byte-identical; M6.6 must not assume otherwise anywhere in its own logic.

## Frozen Files

`forever-db/` (all of M4), `m4-observation-lab/`, `m5-production-recorder/`, `scripts/inventory.py`,
`scripts/coverage.py`, `scripts/collection_runs.py`, `scripts/evidence_report.py`, and every existing
`out/*.json` file and `docs/*.md` report through M6.5.

## Explicitly Not In Scope for M6.6

Quest chain construction, leveling route generation, quest hub identification, zone progression modeling,
travel-path computation, map visualization, QuestV2/ATT/Era ingestion of any kind, fixing `coverage.py`'s
ordering issue, resolving the `giver.npc` role-ambiguity limitation, further real-client collection, and
beginning any milestone after M6.6.
