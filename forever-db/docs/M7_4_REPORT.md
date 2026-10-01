# M7.4: ATT Candidate Collection Target Proposal

**This is a review proposal only. No ATT candidate has been promoted to observed evidence. No M6
CollectionRun was created. No M6 output was modified.**

## 1. Objective

Convert the 1,523 ATT-only quests (established in M7.3) and the single observed-evidence gap (quest 794)
into a deterministic, human-reviewable proposal answering: *which ATT-only quests currently have enough
candidate information to make them useful targets for a future in-game observation session?*

## 2. Inputs

- The existing M6 coverage machinery (`coverage.build_coverage()`), called read-only.
- The existing, unmodified ATT importer (`src/foreverdb/att/importer.py`), run fresh against the
  already-preserved `data/raw/att-head` snapshot — **no new revision fetched**, commit
  `8e25511677df4ea5c3d0322009eafc18f203ffd3` (the exact identity is asserted programmatically before any
  processing occurs, not merely assumed).
- `research/m7_3/coverage_gap_analysis.json` was consulted for context but not imported or modified — it
  remains locked. The ATT-only ID list and quest 794 finding are independently re-derived here from the
  same underlying sources M7.3 used, not copied from its file.

## 3. Evidence Boundary

Every ATT-derived value in this milestone's output carries the status **`source_derived_not_observed`**,
stated once at the top level of `proposed_targets.json` and applying to every candidate value in the file —
name, giver, coordinates, and the quest-794 objective hint alike. Nothing here is labeled `observed`,
`confirmed`, or `verified`. A "candidate target" means *investigate this in the game*, never *this is
confirmed to exist*.

## 4. Quest 794 Follow-Up

Quest 794 is kept entirely separate from the ATT-only candidate list, per instruction. Checked live against
current M6 coverage (not merely copied from the M7.3 report):

- **Current M6 evidence state**: `unresolved` (objectives field)
- **ATT candidate objective data available**: yes — one objective entry, a kill target (creature 3183) and
  an item target (item 4859), with coordinates on Durotar
- Represented once in `observed_evidence_followups`, explicitly labeled as a collection hint only

## 5. Completeness Counts (of the 1,523 ATT-only quests)

| Group | Count |
|---|---:|
| With candidate name | 1,499 |
| With candidate coordinates | 1,360 |
| With candidate giver | 1,191 |
| Name + coordinates | 1,360 |
| Name + giver | 1,191 |
| Giver + coordinates | 1,102 |
| **Name + giver + coordinates** | **1,102** |

These match M7.3's own aggregate field-coverage figures for the ATT-only population exactly (`name: 1,499`,
`coordinates: 1,360`, `giver: 1,191`) — an internal consistency check, not merely asserted.

## 6. Final Findability-Qualified Candidate Count

**1,102 quests** — every ATT-only quest with candidate name, giver, and coordinates all present. Called
"findability-qualified," never "highest priority," per instruction.

## 7. Output Artifacts

- `research/m7_4/select_collection_targets.py` — the deterministic selection logic
- `research/m7_4/proposed_targets.json` — the review artifact (549,409 bytes), containing
  `observed_evidence_followups` (1 entry: quest 794) and `att_candidate_targets` (1,102 entries), each with
  quest ID, candidate name, candidate giver, and candidate coordinates. Snapshot identity and evidence
  status are stated once at the top level rather than repeated per entry (see Limitations).
- `research/m7_4/test_select_collection_targets.py` — 11 tests

## 8. Validation

| Check | Result |
|---|---|
| M6 output files unchanged (hash comparison, before/after) | **Confirmed unchanged** — `m6_guide_dataset.json`, `m6_coverage.json`, `m6_evidence_report.json`, `m6_collection_runs.json` all byte-identical |
| `m6_collection_runs.json` — no new run created | Confirmed: still exactly one run (`run-001-resolve-unresolved-titles`), unmodified |
| ATT unit tests | 18/18 passed |
| Full M4 unit suite (includes ATT + repo-safety) | 141/141 passed |
| Real ATT integration test | 7/7 passed |
| Repository safety tests | 5/5 passed |
| M6 regression suite | 62/62 passed |
| M7.4 tests | 11/11 passed |
| Determinism | Two full runs produced byte-identical JSON |
| Every candidate target is genuinely ATT-only | Verified structurally against live M6 coverage, not assumed |
| No candidate target is `active` or `completed` | Verified — all are `candidate_target` |
| Quest 794 never appears in the ATT-only list | Verified |

**Total: 221 tests passed, 0 failed** (141 M4 unit + 7 ATT integration + 62 M6 + 11 M7.4).

## 9. M6 Safety Verification

Hashed all four M6 output files immediately before running any M7.4 code, and again immediately after. All
four hashes matched exactly. This check is also encoded as a permanent, reusable test
(`test_m6_outputs_unchanged_by_running_the_proposal`), not just a one-time manual check.

## 10. Provenance Handling

ATT snapshot identity (`repo`, `sha`, `key`) is asserted programmatically at the start of the import (the
script refuses to proceed if the loaded snapshot's commit doesn't match the expected SHA exactly) and
stated once at the top of the output file with an explicit note that it applies to every candidate value in
the document — not silently implied.

## 11. Limitations

- **A real issue was found and fixed during this milestone**: the first version of `proposed_targets.json`
  repeated the snapshot identity, evidence status, and hint note on all 1,102+ entries individually,
  producing a 1,036,261-byte file that failed this repository's own pre-existing `test_no_large_files`
  check (1 MB tracked-file limit). Fixed by stating those constant fields once at the top level instead of
  per-entry — no information was removed, only de-duplicated. The corrected file is 549,409 bytes.
- A second real, expected subtlety: ATT's parser encounters 24 bare `q()` call stubs with zero fields at
  all (already documented in M7.3); these correctly cannot qualify for any completeness group and are
  excluded from every group by construction, with no special-casing required.
- This proposal does not attempt to verify, weight, or rank the 1,102 qualified candidates beyond the flat
  three-field filter specified — no scoring model was introduced, per instruction.
- Coordinates and giver IDs are exactly what ATT's DSL encodes; no cross-check against the live game was
  performed or implied.

## 12. Explicit Statement: No Promotion Occurred

**No ATT candidate value — name, giver, coordinate, or objective hint — was written into any M6 evidence
field, coverage record, or guide-ready record.** Every value in `proposed_targets.json` remains
source-derived and unconfirmed.

## 13. Explicit Statement: No CollectionRun Was Created

**No entry was added to `m6-dataset-baseline/out/m6_collection_runs.json`.** It still contains exactly the
one pre-existing run, unmodified, confirmed by hash and by direct inspection. Creating any real
`CollectionRun` from this proposal is an explicit, separate, human-approved action outside this milestone's
scope.
