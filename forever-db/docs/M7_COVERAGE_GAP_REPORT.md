# M7.3: Cross-Source Coverage & Evidence-Gap Analysis

**Read-only analysis. ATT is candidate/source-derived information throughout this report. M6 observation
is the project's only evidence layer. Nothing here has been merged into any M6 output.**

## Objective

Answer: what does the already-approved, already-acquired ATT candidate source cover relative to what M6
has actually observed, and where are the evidence gaps? Not: can ATT be turned into truth?

## Exact Input Sources and Versions

- **ATT**: `data/raw/att-head`, commit `8e25511677df4ea5c3d0322009eafc18f203ffd3` (acquired and verified
  exactly in M7.2-B). Imported fresh via the existing, unmodified `src/foreverdb/att/importer.py`, in a
  throwaway in-memory SQLite connection — the identical pattern M7.2-B already used and tested. Nothing was
  written back to the snapshot or to any persistent database.
- **M6**: `coverage.build_coverage()` (the existing, unmodified M6.2 function), called directly — not read
  from a potentially-stale JSON file — reflecting the current, live observed dataset.

## Methodology

`research/m7_3/coverage_gap_analysis.py` runs both of the above and compares the two resulting quest-ID
populations and their field data. Reproducible via:

```
cd forever-db && python3 research/m7_3/coverage_gap_analysis.py
```

Verified deterministic: run twice, byte-identical output both times.

## ATT Candidate Population

**1,537** quest IDs — matching M7.2-B's exact historical reproduction precisely. Of these, **24** are bare
`q()` call stubs in ATT's own source with no comment, giver, level, coordinate, or objective data at all —
included in the population count since ATT's own parser counts them as encountered, but they contribute
nothing to any field-coverage figure below.

## M6 Observed Population

**121** quest entities — the current, live count from `coverage.build_coverage()`.

## ATT ∩ M6 / ATT-Only / M6-Only

| Set | Count |
|---|---|
| ATT ∩ M6 (intersection) | **14** |
| ATT-only | **1,523** |
| M6-only | **107** |

The intersection (`14 + 1,523 = 1,537`; `14 + 107 = 121` — both check out exactly) splits into two
distinct groups worth naming precisely, not left as an unexplained number: **9 are pre-existing, low-numbered
classic quest IDs** (788, 789, 790, 792, 794, 804, 959, 3082, 4402, 4641 — already known to M6 from earlier
incidental leveling activity on other characters, not Forever-new content) and **4 are genuine Forever-new
IDs** (92460, 92461, 92462, 92465) that both ATT and this project's real recorder happen to cover. This
split makes sense: ATT documents WoW content broadly, not only Forever's new additions, so overlap with
old-world quest IDs picked up incidentally is expected.

## Field-Level ATT Coverage

Every category below maps directly to a real, verbatim ATT importer field name (see `FIELD_CATEGORY_MAP` in
the analysis script) — nothing invented beyond what the importer already emits.

| Category | ATT field(s) | All ATT quests (of 1,537) | ATT-only (of 1,523) | ATT ∩ M6 (of 14) |
|---|---|---:|---:|---:|
| Name | `name.att_comment` | 1,513 | 1,499 | 14 |
| Level | `level.att_lvl_unverified` | 1,123 | 1,121 | 2 |
| Giver | `giver.npc` | 1,205 | 1,191 | 14 |
| Coordinates | `location.att_coord` | 1,374 | 1,360 | 14 |
| Objectives | `objective.att` | 543 | 533 | 10 |
| Item/reward-related | `att.item_child_unverified` | 412 | 404 | 8 |
| Prerequisites | `relation.att_source_quest`, `relation.att_alt_quest` | 900 | 890 | 10 |
| Other (flags, restrictions, provider hints, creature refs) | `att.flag.*`, `att.restriction.*`, `att.provider(s)`, `att.qi(s)`, `att.qs`, `att.cr(s)`, `flight_master.att_cr` | 1,284 | 1,275 | 9 |

Notably: **all 14** of the intersecting quests have ATT name, giver, and coordinate data — a genuinely rich
candidate set on the overlap, even though only 2 of them have level data and 10 have objectives.

## Observed-Evidence Gaps

Checked every one of the 14 intersecting quests: for each, does M6 show `unresolved` on `quest_level`,
`giver`, or `objectives` while ATT has candidate data for the matching category?

**Exactly one gap found**: quest **794** — M6's `objectives` field is `unresolved`; ATT has candidate
objective data for this quest. This is reported as a collection-priority signal only — **not** a value to
adopt, and nothing was written to M6's `objectives` field for quest 794 or any other quest.

The narrowness of this result follows directly from the population itself: 13 of the 14 intersecting quests
already have most of their formal M6 fields resolved (the 9 classic quests were incidentally observed
thoroughly; the 4 Forever-new ones overlap with already-well-covered IDs), leaving little room for a gap to
appear. The much larger, unaddressed opportunity is the **1,523 ATT-only quests** — M6 has zero observed
evidence for any of them, and this analysis does not attempt to close that gap, per the milestone's explicit
scope.

## Provenance / Evidence Status

Every ATT-derived fact discussed in this report carries the same status established since M4/M7.1: **candidate,
source-derived, not independently verified** (ATT's own repository is MIT-licensed and its content was
verified byte-identical to the historical import in M7.2-B, but the *coordinate data's upstream provenance
specifically remains "unresolved,"* per `config/sources.toml`). No ATT fact discussed here has been
labeled `observed`, `confirmed`, or any other M6 evidence-state term. The one ATT-derived table cell that
does exist in this project's SQLite schema outside M6 — `quest_evidence.evidence_kind = 'att_observed'`,
written by the ATT importer's own existing `quests.add_evidence()` call — is a **different, older, M1-era
tracking concept** ("ATT's own files record this ID"), unrelated to and never conflated with M6's
`evidence_state` vocabulary (`confirmed`/`observed`/`unresolved`/etc.) in this report or anywhere in this
analysis. This distinction matters and is stated explicitly to avoid exactly the kind of confusion the
milestone's rules warn against.

## Limitations

- This analysis reflects the ATT snapshot at its single pinned commit; it says nothing about whether ATT's
  `head` branch has since changed (M7.2-B already established the pinned commit itself is stable and
  reproduces exactly).
- The field-category mapping (e.g., grouping `att.qi`/`att.qis`/`att.qs`/`att.provider(s)`/`att.cr(s)` under
  "other") is a reporting-time convenience for this milestone's comparison table — it does not redefine or
  reinterpret what those ATT fields mean; the importer's own field names are the authoritative record.
- The single identified gap (quest 794) is exactly that — one instance. No broader claim is made about how
  many of the 1,523 ATT-only quests, if ever observed by M6, would similarly show a resolvable gap; that
  would require actual future observation, not more analysis of ATT alone.
- No coordinate, level, or objective value from ATT was independently checked against anything beyond the
  M7.2-B reproduction check — this milestone does not attempt correctness validation of ATT's content.

## Validation

| Check | Result |
|---|---|
| ATT unit tests (`test_att_dsl.py`, `test_att_importer.py`) | **18/18 passed** |
| Full M4 unit suite | **141/141 passed** (includes the 18 above) |
| Real ATT integration test (`test_real_att.py`, against the preserved snapshot) | **7/7 passed** |
| Repository safety tests (`test_repo_safety.py`) | **5/5 passed** |
| M6 regression suite (M6.2 + M6.3 + M6.4 + M6.6) | **62/62 passed** |
| Analysis determinism | Ran twice; byte-identical JSON output both times |
| M7.2-B raw snapshots unmodified | Both `git rev-parse HEAD` re-confirmed exact: `8e25511677df4ea5c3d0322009eafc18f203ffd3`, `a054efd473f0b9b13c0695dc1e81a16af4918f9d` |
| M6 output files | Zero files under `m6-dataset-baseline/` show a modification time newer than before this task |
| M4/M5/Observation Lab | Zero files show a modification time newer than before this task |
| Core frozen files (`db.py`, `assertions.py`, `harvest/importer.py`, `att/importer.py`, `sources.toml`, `LICENSING.md`) | All byte-identical by hash |

**Total: 233 tests passed, 0 failed** (7 integration + 18 ATT-specific + 141 M4 unit total + 62 M6 — the
same full count M7.2-B established, re-confirmed unchanged by this milestone's read-only work).
