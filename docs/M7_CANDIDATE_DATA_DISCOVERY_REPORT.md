# M7.1: Candidate Data Discovery Report

**Read-only discovery pass. No code written, no file modified, no candidate data ingested or promoted to
evidence.** Every finding below comes from directly inspecting files that exist in this repository right
now — nothing is repeated from memory or from the M6 master plan's own prior aggregate figures without
independently re-verifying where those figures actually came from.

## Executive Summary

**No raw candidate data (QuestV2, ATT, Questie Era, or ForeverGuide) exists anywhere in this repository.**
What exists instead is: (1) real, working *importer code* for ATT (`src/foreverdb/att/`), built and tested
against small synthetic fixtures, never against a persisted full ATT dataset; (2) a detailed **historical
report** (`m0/M0_REPORT.md`) documenting real numbers computed during the original M0 investigation, when
the raw sources were transiently cloned and analyzed but never checked into this project's outputs; and
(3) a real **import summary** (`forever-db/manifests/att_import_report.att-head.json`) from a genuine past
ATT import run, containing aggregate counts and per-field assertion counts, but not the underlying quest ID
list itself. No ID-level overlap calculation against the current 121 observed quests is possible without
re-acquiring the raw sources — this is stated plainly in Section "Quest ID Coverage," not worked around.

## Source Inventory

### QuestV2 (client DB2 table)

- **No raw file exists anywhere** — confirmed by an exhaustive filename search across the entire
  `/mnt/user-data/outputs` tree.
- What exists: `forever-db/manifests/carried_from_m0.json` records a **carried, not re-probed** claim —
  `row_count: 6600`, columns `[ID, UniqueBitFlag, UiQuestDetailsThemeID]`, build `1.60.1.69913` — explicitly
  labeled `"status": "carried_from_m0_not_reprobed"` and sourced from "a third-party repository's vendored
  CSVs (ForeverGuide)," which M1's own pipeline deliberately excludes as a source. The same file states
  plainly: *"existence of a client quest ID only; no names, levels or rewards."*
- No script in this repository embeds or generates a QuestV2 ID list; `m0/scripts/quest_sets.py` and
  `questie_cov.py` both hardcode a relative path
  (`ForeverGuide/data-src/db2/QuestV2.1.60.1.69913.csv`) to a file that would only exist if `setup_sources.sh`
  had been run and its clone target persisted — which it was not.

### ATT / AllTheThings

- **No raw ATT Lua source tree exists.** `tests/integration/test_real_att.py` explicitly checks for
  `data/raw/att-head/.git` and **skips itself automatically** when absent — confirmed absent (`data/raw/`
  does not exist anywhere under `forever-db/`).
- **Real, working importer code exists**: `src/foreverdb/att/importer.py`, with its own DSL parser
  (`test_att_dsl.py`) and importer tests (`test_att_importer.py`). These tests use small, hand-written
  snippets of **real ATT syntax** (not fabricated syntax) — e.g. real quest IDs `783` ("A Threat Within")
  and `92461` ("Harmony in Balance") appear as illustrative fixtures — but this is a handful of example
  quests written to exercise the parser's correctness, not a usable candidate dataset in its own right.
- **A real historical import report exists**: `manifests/att_import_report.att-head.json`, from an actual
  past run of this importer against real ATT data (pinned commit `8e25511677df4ea5c3d0322009eafc18f203ffd3`).
  It contains genuine, real aggregate output:
  - `parsed_quest_ids: 1537` (matches the M0/M6-cited figure exactly — traced to its real source)
  - `quest_ids_only_parser_found: 21`, `regex_quest_ids: 1516` — a real cross-check discrepancy between two
    parsing methods, previously undocumented in any M6 report
  - `fp_records: 14`, `fp_ids_mismatch: []`
  - A `by_field` breakdown of assertion counts: `giver.npc: 1221`, `location.att_coord: 1469`,
    `name.att_comment: 1527`, `level.att_lvl_unverified: 1123`, `objective.att: 771` (from the fuller listing
    in the M6-era manifest read), `relation.att_source_quest: 1011`, and others.
  - **This is real field-coverage information about the ATT source**, distinct from having zero
    information — but it is aggregate counts, not a queryable per-quest ID list.
- `manifests/db2_manifest.att-head.json` / `.att-a054efd.json` / `_diff.json`: DB2 **schema manifests**
  (table names, column layouts, hashes) for two pinned ATT commits — genuinely real, but structural
  metadata only, containing no quest content.

### Questie Era

- **No raw QuestieDB Lua file exists.** `m0/scripts/questie_cov.py` hardcodes
  `QuestieDB/data/Classic/classicQuestDB.lua` — absent.
- No importer code exists for Questie in `forever-db/src/` at all (unlike ATT, which has a real importer).
- All Questie-derived numbers trace to `m0/M0_REPORT.md`'s prose (Section 8: *"Questie's Forever tables are
  Era data with converted coordinates and identical entity counts: 4,244 quests... They contain no
  Forever-new entities. Era quest IDs max out at 9,665."*) — a real, historical, one-time finding, not
  something this repository can currently reproduce or query.

### Other Candidate Sources Identified

- **ForeverGuide**: `m0/M0_REPORT.md` Section 10 states plainly: *"no license file, so all rights are
  reserved by default... includes facts from RestedXP guides (CC BY-NC-SA 4.0)... Do not ingest."* No
  ForeverGuide data exists locally either — confirmed absent by the same search.
- **lodestar**: referenced only as a documentation/claims source in `M0_REPORT.md` (e.g. the 2,824/1,795
  baseline figures, Section 8) — no raw lodestar data exists locally, and no importer exists for it.
- **wago.tools**: mentioned only as an unresolved licensing question (Section 10: *"terms not retrieved"*)
  — no data, no code.

## Quest ID Coverage

**Cannot be calculated for any pair of sources** — no raw ID list exists locally for QuestV2, ATT, or
Questie Era. This is not a gap papered over: it is the direct, verified consequence of Section "Source
Inventory" above.

What *can* be reported, precisely, from the historical record in `M0_REPORT.md` (real numbers from a real
past analysis, not reconstructed or approximated here):
- QuestV2 total: 6,600 (existence-only, per `carried_from_m0.json`)
- Questie Era total: 4,244 quests; Era IDs max out at 9,665
- QuestV2 ∩ Questie Era: 3,535 (stated in `M0_REPORT.md` §7)
- QuestV2 − Era: 3,065 (2,844 of these ≥ 30000; 221 below)
- Era − QuestV2: 709
- ATT (real import, `att_import_report.att-head.json`): 1,537 parsed quest IDs
- ATT ∩ QuestV2: 1,372 (89.3% of ATT, per `M0_REPORT.md` §7)
- Of the 3,065 QuestV2-not-in-Era IDs, ATT or ForeverGuide has *some* record for 791 (25.8%)

**These are cited, not recomputed** — this task did not reproduce any of these numbers from raw data,
because no raw data exists to reproduce them from.

## Field Coverage

| Source | Title | Level | Objectives | Giver | Giver creature ID | Coordinates | Prerequisites | Rewards | Reputation | Completion |
|---|---|---|---|---|---|---|---|---|---|---|
| QuestV2 (as documented) | No | No | No | No | No | No | No | No | No | No — existence only |
| ATT (per real import counts) | Partial (`name.att_comment`, 1,527 of 1,537) | Partial (`level.att_lvl_unverified`, 1,123) | Partial (`objective.att`, 771) | Yes (`giver.npc`, 1,221) | Implied via `giver.npc` | Yes (`location.att_coord`, 1,469) | Yes (`relation.att_source_quest`, 1,011; `relation.att_alt_quest`, 451) | Partial (`att.item_child_unverified`, 706 — explicitly unverified) | No field found in the import's `by_field` breakdown | No |
| Questie Era (per `M0_REPORT.md` prose only, not locally queryable) | Yes (converted Era data) | Yes | Yes (Era-sourced) | Yes | Not stated | Yes (converted) | Yes (`preQuestGroup`/`preQuestSingle`, per `questie_cov.py`'s field list) | **No** — `M0_REPORT.md` §9 states plainly: *"Questie's quest schema has no item, money or XP reward fields"* | Yes (`reputationReward` field referenced in `questie_cov.py`) | No |

ATT's percentages above are computed from real counts (`X of 1537`), not estimated. Questie's field
presence is asserted in `M0_REPORT.md`'s prose and `questie_cov.py`'s own field list, not independently
re-verified here (no raw file to check).

## Data Quality Notes

- **ATT's own real cross-check found a discrepancy**: 21 quest IDs were found by the DSL parser but not by
  a simpler regex-based check (`quest_ids_only_parser_found: 21`) — a genuine, documented parser-coverage
  question, not resolved here.
- **`att.item_child_unverified`** (706 occurrences) — the field name itself flags this as explicitly
  unverified by the importer's own authors, not a confident claim.
- **Questie's data is converted, not Forever-native** — `M0_REPORT.md` is explicit: *"Era data with
  converted coordinates and identical entity counts... contain no Forever-new entities."* Any Questie-Era
  quest is, by construction, *not* evidence of Forever-specific content.
- **QuestV2 membership is explicitly documented as not proof of a real quest** — `M0_REPORT.md` §8: *"every
  ID from 1 to 999 'exists' on the server, including placeholder rows titled `None` and `<UNUSED>`... new
  quests reuse some old IDs."*
- **No duplicate-ID or null-field analysis is possible** for any source right now — there is no raw file to
  run such a check against.

## Licensing and Provenance (as documented locally, no new legal conclusion)

| Source | License (as found in `M0_REPORT.md` §10) | Forever-specific? |
|---|---|---|
| ATT | MIT (the repo itself); coordinate origin unknown; wago CSVs are Blizzard-derived | Partially — real Forever content mixed with converted/legacy data |
| Questie/QuestieDB | GPL-3.0; upstream provenance of Era data not stated by Questie itself | No — explicitly converted Era data |
| ForeverGuide | No license file — all rights reserved by default; overlay includes RestedXP CC BY-NC-SA 4.0 material | Mixed, and explicitly flagged **"Do not ingest"** |
| Wowhead | Fanbyte EULA bars crawling/data-mining and derivative works | N/A — not used |
| Blizzard DB2/map art | No explicit redistribution grant found | N/A |
| wago.tools | Terms not retrieved | Unresolved |

All of the above is a direct citation of `M0_REPORT.md`'s own findings — this task did not re-derive or
reinterpret any licensing conclusion, only confirmed that this documentation exists and says what it says.

## M6 Overlap

**Cannot be calculated.** The 121 quest IDs currently in `m6_guide_dataset.json`/`m6_coverage.json` are all
real, directly-observed IDs (verified: `92460`–`99196`, the actual range this project's real recorder
sessions have touched). Comparing them against QuestV2/ATT/Era would require the raw ID lists from those
sources, which — per every finding above — do not exist locally. No approximation was attempted.

## Recommended M7 Architecture (Not Implemented)

Based only on what actually exists:

- **Source-specific candidate records: yes, needed** — ATT, Questie, and QuestV2 have meaningfully
  different field coverage and reliability (per the Field Coverage table above); collapsing them into one
  generic "candidate" shape would lose real, useful distinctions already documented.
- **Source provenance: yes, mandatory** — every candidate fact needs to carry which source produced it and
  that source's license, given ForeverGuide is an explicit do-not-ingest case sitting right next to two
  otherwise-usable sources (ATT, Questie).
- **Candidate field values: yes**, but explicitly never merged into `title.harvest_observed` or any other
  M6.2 field — a separate namespace (something like `candidate.att_title`, mirroring the ATT importer's own
  existing `att.*`/`*.att_*` naming convention already used for M4's non-Forever-specific fields).
- **Candidate-vs-observed comparison: yes, this is M7's central value** — but it cannot begin until raw
  ATT/QuestV2/Questie data is actually re-acquired (via `setup_sources.sh` or equivalent) and persisted
  somewhere this pipeline can read repeatedly, not just analyzed once and discarded as M0 did.
- **Explicit promotion rules: yes, and they should be conservative** — nothing here suggests any candidate
  source is reliable enough to auto-promote into evidence; QuestV2 confirms existence only, ATT has
  explicitly-unverified fields, Questie is admittedly non-Forever-native.
- **Conflict handling between candidate sources: needed eventually**, but secondary — with zero raw data
  currently available, there is nothing to conflict yet.
- **Separation between candidate data and confirmed evidence: yes, absolute** — exactly the existing M6.2/
  M6.4 architecture's own discipline, extended to a new, clearly-labeled layer rather than blended into it.

The most concrete, honest next step: **before any candidate-data code is written, the raw sources need to
be re-acquired and actually persisted** (unlike M0's transient clone-and-discard approach) — otherwise M7
would be designing a comparison layer with nothing real to compare against.

## Blockers / Unknowns

- Raw QuestV2, ATT, and Questie Era data must be re-acquired (via `setup_sources.sh`'s pinned commits or
  equivalent) before any real ID-level overlap or field-quality analysis can happen — this cannot be
  determined or worked around from local files alone.
- Whether `setup_sources.sh`'s pinned commits are still fetchable (repos may have changed, been deleted, or
  the pinned SHAs garbage-collected) is unknown without attempting the fetch.
- Whether the wago CSV data ATT depends on reflects the *current* build (`70009`, per M5/M6's real sessions)
  or the older pinned build (`69913`/`1.60.1`) the manifests reference is unresolved — the client has
  demonstrably moved on since these manifests were generated.
- No licensing conclusion beyond what `M0_REPORT.md` already states is offered here, per instruction.

## Final Response

1. **Inspected**: the entire `/mnt/user-data/outputs` tree by filename search; `forever-db/manifests/*`,
   `forever-db/src/foreverdb/att/`, `forever-db/tests/{unit,integration}/test_att_*`, all of `m0/scripts/`
   and `m0/M0_REPORT.md`, `m2-extraction-test/M2_ATTESTATION.json` and `verify_db2_header.py`.
2. **Candidate sources that actually exist**: none as raw data. Real artifacts found: ATT importer code +
   small synthetic/illustrative test fixtures, one real historical ATT import summary (counts only), and
   one detailed historical M0 analysis report (numbers only, sources no longer present).
3. **Real counts**: ATT `parsed_quest_ids: 1537` (from a real import run); QuestV2 `6600` and Questie Era
   `4244` (both cited from `M0_REPORT.md`/`carried_from_m0.json`, not independently recomputed here).
4. **Real schemas**: ATT's real per-field assertion-count breakdown (Field Coverage table); QuestV2's three
   known columns (existence-only); Questie's field list as referenced in `questie_cov.py`, not independently
   verified against a live file.
5. **ID overlaps calculable now**: none, directly. **Cited historically** (not recalculated): QuestV2∩Era
   (3,535), ATT∩QuestV2 (1,372), QuestV2−Era (3,065), Era−QuestV2 (709).
6. **Overlaps impossible to calculate, and why**: every pairing involving the current 121 M6-observed
   quests, and any *fresh* QuestV2/ATT/Era-to-Era comparison — because no raw ID list for any of these three
   sources persists anywhere in this repository.
7. **Licensing/provenance concerns**: ForeverGuide is explicitly do-not-ingest (undocumented license +
   embedded RestedXP CC BY-NC-SA material); Blizzard DB2 redistribution rights are undocumented; wago.tools
   terms were never retrieved — all as already documented in `M0_REPORT.md`, confirmed still accurate.
8. **Discovery report created**: yes — creating a new report file matches this project's own established
   convention for every prior read-only investigation (e.g. the M6.5 pre-collection investigation).
9. **Files created**: this one report, `forever-db/docs/M7_CANDIDATE_DATA_DISCOVERY_REPORT.md`.
10. **Files modified**: none.
11. **M4/M5/Observation Lab/M6 confirmed unmodified**: yes — `db.py`/`assertions.py`/`importer.py` hashes
    unchanged; no file under `m4-observation-lab/`, `m5-production-recorder/`, or `m6-dataset-baseline/`
    has a timestamp newer than before this task began.
12. **Recommendation for M7.2**: re-acquire and *persist* the raw ATT/QuestV2/Questie snapshots (not
    transiently, as M0 did) as the actual first step — a real candidate-data comparison layer cannot be
    meaningfully designed, let alone implemented, against sources that exist only as historical prose.
