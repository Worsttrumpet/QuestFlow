# M7.5: Human-Reviewed Pilot Collection

**This milestone stops at the planned-run stage. No real in-game observation was performed or simulated —
Claude has no ability to interact with a live WoW client. Every real observation this project has ever
produced came from the human operator manually playing and reporting back; that step has not yet happened
for this pilot. Reporting this honestly, per the milestone's own explicit instruction, rather than
fabricating or skipping it.**

## 1. Objective

Demonstrate whether the pipeline `ATT candidate → human-reviewed target → planned CollectionRun → real
observation → M6 evidence → coverage delta` can work, using a small, non-exhaustive pilot batch, without
compromising the project's candidate/observed-evidence separation.

## 2. Why 10 Targets Were Selected

Per explicit instruction: a small pilot to validate the pipeline, not to maximize data acquisition. All
1,102 findability-qualified candidates satisfied the eligibility criteria, so the limiting factor was the
mandated pilot size (10), not a scarcity of eligible candidates.

## 3. Deterministic Selection Method

**The 10 lowest quest IDs among the 1,102 `att_candidate_targets` entries in the locked
`research/m7_4/proposed_targets.json`.** The simplest defensible, fully reproducible method available — no
weighting, scoring, or "best quest" claim. Verified structurally (not merely assumed) that this excludes
quest 794 and all 14 ATT/M6 intersection quests, since those quest IDs never appear in
`att_candidate_targets` at all.

**A real, honest finding about this method's consequence**: because low ATT quest IDs correspond to very
old, generic classic-WoW content, all 10 selected pilot quests are recognizable vanilla Elwynn
Forest/Westfall-style quests (bounties, kobold camps, gnoll bounties) — not Forever-new discoveries. The
simplest deterministic method produced a pilot batch that tests the *pipeline mechanics* well, but says
nothing about Forever-specific content specifically. This is stated plainly, not smoothed over.

## 4. Exact 10 Quest IDs

`6, 7, 11, 15, 16, 17, 18, 21, 33, 35`

## 5. ATT Candidate Provenance

Every pilot run's `target_scope` carries: `candidate_name`, `candidate_giver`, `candidate_coordinates` (all
taken verbatim from the locked M7.4 proposal, not re-derived), the exact ATT snapshot identity
(`ATTWoWAddon/AllTheThings` @ `8e25511677df4ea5c3d0322009eafc18f203ffd3`), and an explicit
`evidence_status: "source_derived_not_observed -- a collection hint only"` string on the hint itself.

| Quest | Candidate Name | Candidate Giver (NPC ID) |
|---|---|---|
| 6 | Bounty on Garrick Padfoot | 823 |
| 7 | Kobold Camp Cleanup | 197 |
| 11 | Riverpaw Gnoll Bounty | 963 |
| 15 | Investigate Echo Ridge | 197 |
| 16 | Give Gerard a Drink | 255 |
| 17 | Uldaman Reagent Run | 1470 |
| 18 | Brotherhood of Thieves | 823 |
| 21 | Skirmish at Echo Ridge | 197 |
| 33 | Wolves Across the Border | 196 |
| 35 | Further Concerns | 240 |

## 6. CollectionRun Creation

Created **10 separate** `CollectionRun` records (not one batch run), via the existing, unmodified
`collection_runs.py` — the identical mechanism Run-001 used. Each: `run-m7-5-pilot-<quest_id>`, status
`planned`, one target quest ID, target fields `title`/`quest_level`/`objectives`. Verified directly against
the real registry: **11 total runs now exist** (`run-001-resolve-unresolved-titles`, unchanged, still
`active`; plus the 10 new pilots, all `planned`).

## 7. Collection Procedure

Reused Run-001's exact, already-proven procedure — no new mechanism invented. For a human operator to
actually execute this pilot: enable `ForeverRecorder`, visit each candidate giver NPC (by ID, since exact
in-game names/locations are only ATT hints, not confirmed), attempt to view and/or turn in the quest if it
exists, `/fr status` then `/fr save`, and report the export back for processing through the same pipeline
used throughout M6.5 (Run-001).

## 8. Actual Observation Results

**None. No real in-game collection was performed during this milestone.** Per the milestone's own explicit
stop condition ("If real in-game collection cannot be performed by the available tooling in this
environment, stop at the planned-run stage and report that limitation honestly. Do not simulate the missing
collection"), this is the correct, honest outcome, not a shortfall.

## 9-11. Fields Resolved / Unresolved / Candidate-Observation Discrepancies

**Not applicable yet — no observation has occurred.** All 10 pilot targets remain exactly where M7.4 left
them: candidate-only, unconfirmed. Zero fields resolved by this milestone; zero discrepancies exist because
zero comparisons have been made.

## 12. Coverage Delta

**Not computed — there is nothing to compute yet.** `compute_coverage_delta()` exists and is
ready to use once real sessions are associated with these runs, exactly as it was for Run-001, but running
it now against zero real activity would produce an empty, uninformative result rather than a meaningful
measurement.

## 13. Quest 794 Handling

**Deferred, per instruction.** Quest 794 was not included in the pilot batch and was not collected
alongside it, since no real collection session occurred at all this milestone.

## 14. M6 File Changes

| File | Changed? | Reason |
|---|---|---|
| `m6_collection_runs.json` | **Yes** | 10 new planned runs added |
| `m6_guide_dataset.json` | No | No observation occurred |
| `m6_coverage.json` | No | No observation occurred |
| `m6_evidence_report.json` | No | No observation occurred |

Confirmed by SHA-256 comparison against a pre-collection snapshot taken before any M7.5 code ran (see
`research/m7_5/pre_collection_hashes.txt`). `research/m7_4/proposed_targets.json` — the locked M7.4
artifact — is also confirmed byte-identical, untouched.

## 15. Validation

**14 new M7.5 tests, all passing**, covering: deterministic selection, exact pilot size, correct exclusion
of quest 794 and all 14 intersection quests, every target genuinely sourced from
`att_candidate_targets`, planned-only status on creation, ATT provenance retention, explicit
not-observed labeling on every candidate hint, correct target-field set, no M6 evidence file touched by
run creation, and a direct check of the real registry's final state (11 runs, 10 planned + 1 pre-existing
active).

**A real, precise finding, not silently worked around**: M7.4's own locked test suite has one now-stale
assertion. `test_no_collection_run_is_created_in_the_m6_registry` asserts `len(data) == 1` — true when M7.4
was written (the registry held only Run-001), no longer true now that M7.5 has correctly, authorizedly added
10 more runs. The test's actual guarantee — that calling M7.4's own `build_proposal()` function never
itself modifies the registry (`before == after`) — still holds and still passes. Only the trailing,
registry-size-specific line is stale. Per instruction not to modify locked M7.3/M7.4 artifacts, **this test
file was not edited**. Current, honest result: M7.4's suite now shows **1 failed, 10 passed** (previously
11/11). Updating that one assertion to reflect the registry's new, legitimate size is a small, separate,
human-approved change outside this milestone's scope — recommended, not performed.

**Full regression, run fresh**: M4 unit suite 141/141, real ATT integration 7/7, M6 regression suite 62/62,
M7.5's own suite 14/14 — **224 passed**. M7.4's own suite: 10/10 passed, 1 failed (explained above), for a
project-wide total of **234 passed, 1 failed** (the one explained, pre-existing-assumption staleness, not a
functional defect).

## 16. Limitations

- The pilot's low-quest-ID selection method, while fully deterministic and reproducible as required,
  happens to select well-known classic content rather than Forever-new territory — a real property of
  "simplest method," not a flaw in execution.
- No actual pipeline validation (candidate → observation → evidence) has occurred yet; this milestone
  validates only the candidate → planned-run half of the pipeline.
- The M7.4 test staleness (above) means the project's own regression count is not currently "all green" —
  a real, transparent fact rather than something to paper over.

## 17. Lessons Learned

- The candidate → planned-run mechanism works cleanly with zero modification to any existing M6.3 code —
  `collection_runs.py`'s existing API was sufficient for a fundamentally new use case (ATT-sourced targets
  rather than hand-curated ones).
- A test suite that asserts on a collection's exact size, rather than only on the specific behavior it's
  meant to verify, becomes fragile the moment a later, legitimately-authorized milestone adds to that
  collection. Worth remembering for any future test design in this project.
- Simplicity in selection (lowest ID) is easy to verify and explain, but its practical usefulness for
  discovering *new* content specifically is limited — a future milestone might reasonably want a different,
  still-non-scored filter (e.g., quest ID range) if the goal shifts toward Forever-new discovery rather than
  pipeline validation.

## 18. Technical Viability for Future Larger-Scale Collection

Not yet established. The planned-run creation half of the pipeline is now demonstrated as
mechanically sound (11/11 of Run-001's kind of workflow, 14/14 of this milestone's own tests). Whether the
full pipeline — through to real observation and coverage delta — works reliably at any scale remains
unverified until an actual human collection session against these (or other) planned pilot runs is
performed and reported.

---

**No recommendation about a future milestone is made here, per instruction.** This report states evidence
and measurements only.
