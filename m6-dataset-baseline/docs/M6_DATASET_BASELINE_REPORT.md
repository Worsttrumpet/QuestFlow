# M6.1: Dataset Baseline Report

**Scope: M6.1 only** — dataset inventory and baseline measurement. No coverage database, no collection-run
tracking, no evidence/conflict reporting system, and no data collection was performed as part of this
milestone. Per the M6 plan's own instruction, later sub-milestones are not started until this baseline has
been produced and reviewed.

**No code was modified to produce this report.** `src/foreverdb/harvest/savedvars.py` (the existing, frozen
M4 parser) was read and reused, not duplicated. Nothing in `forever-db/`, `m4-observation-lab/`, or
`m5-production-recorder/` was changed.

Every claim below is labeled **[data-verified]** (checked directly against the real export file, computed
by the script in `scripts/inventory.py`), **[code-verified]** (follows from reading existing source), or
**[reported]** (relayed from this project's own prior conversation history or planning documents, not
independently re-derivable from the file itself).

## 1. Current Dataset

**Input**: the most recent real `ForeverObservationLabDB` export obtained during M5 real-client testing
(`out/latest_export_ForeverRecorder.lua`, 1662 observations, `meta.session_id = f560b6cb92a97c`,
`meta.observed_build = 70009`) [data-verified — this file's own byte-for-byte-identical-prefix relationship
to every earlier export in that testing session was already established at the time it was collected].

This is the **only** export file used for this baseline. Earlier exports from the same testing session
(1450, 1656, 1660 observations) are strict subsets of this one and were not separately re-analyzed, since
their content is already contained within it.

## 2. Observation Sources

The dataset is **not M5-only**, exactly as M6 rule 3.2 requires this report to state plainly:

| Attribution | Observations | Basis |
|---|---|---|
| Confirmed `ForeverRecorder` (M5) | **244** | [data-verified against the 6 session IDs independently confirmed as recorder sessions during this project's own M5 real-client testing] |
| Pre-existing / `ForeverObservationLab` (Lab)-attributed | **1418** | [reported — see note below] |

**Important limitation, stated precisely, not glossed over**: the shared `ForeverObservationLabDB` schema
contains no per-observation field naming which addon wrote it — `ForeverRecorder` and the historical
`ForeverObservationLab` were deliberately built to write to the same data name for M4 pipeline
compatibility (M6 rule 3.2). The 244/1418 split above is based on this project's own record of which
session IDs were generated during confirmed `ForeverRecorder` testing, not on anything structurally
present in the file. Any session ID not on that specific list is attributed to the Lab by elimination, not
by direct evidence in the data itself.

## 3. Session Coverage

| Session ID | Observations | Attribution |
|---|---|---|
| `2e787541803171` | 1171 | Pre-existing (Lab) |
| `164fb18d1a3ab8` | 247 | Pre-existing (Lab) |
| `e91d734523ba1a` | 206 | Confirmed ForeverRecorder |
| `f0e0a3f870f296` | 26 | Confirmed ForeverRecorder |
| `90318e46308b48` | 6 | Confirmed ForeverRecorder |
| `9a2307cc62589b` | 4 | Confirmed ForeverRecorder |
| `038eb179f79ceb` | 2 | Confirmed ForeverRecorder |

[data-verified] 7 distinct sessions total. Note `f560b6cb92a97c` (the file's own `meta.session_id`, i.e.
the session active when this file was saved) does not itself appear against any observation — no new
observation was recorded during that specific session before the export was taken, consistent with what
was already established during M5 real-client testing.

## 4. Build Coverage

| Build | Observations |
|---|---|
| `69977` | 1171 |
| `70009` | 491 |

[data-verified] Two distinct real builds represented in this single dataset — the client updated between
the earlier Lab-era sessions and this project's M5 testing. Per M6 rule 3.1, this does not establish
compatibility with any future build beyond these two.

## 5. Quest Coverage

**94 unique quest IDs** have at least one observation of any kind, across the dataset's entire history
[data-verified]. The full list is in `out/inventory.json` (`unique_quest_ids_touched`); representative
range: `92460`–`98512`.

By module (an observation "touching" a quest, not a claim that every field is known for it):

| Module | Quest-scoped observations |
|---|---|
| `RewardsItems` | 272 |
| `QuestMeta` | 271 |
| `RewardsReputation` | 271 |
| `GiverIdentity` | 271 |
| `RewardsXPMoney` | 85 |

[data-verified] Note these counts are **observation counts, not unique-quest counts** — the same quest
observed at three checkpoints (`quest_detail`, `quest_complete_immediate`, `quest_complete_delayed`)
contributes three rows here, by design, per the checkpoint-preservation philosophy established in M4/M5.

## 6. NPC Coverage

**63 unique NPC creature IDs** observed via `GiverIdentity` across the dataset [data-verified]. Of the
observations that produced these IDs:

- **271** were quest-scoped (a real `quest_id` was present at capture time)
- **246** were NPC-scoped (no `quest_id` — the M5 real-data discovery case: a general sighting, not a
  fabricated quest attachment)

[data-verified] **517 total `GiverIdentity` observations carried a successfully-resolved player position**
— every one of them, in this dataset. Per M6 rule 23, this establishes "player was here when interacting
with this NPC," not "this NPC is permanently located here."

## 7. Reward Coverage

Kept as separate categories throughout, per M6 rule 25 — never collapsed into one generic flag:

| Reward type | Observations | Unique quests involved |
|---|---|---|
| XP/money (`QUEST_TURNED_IN` only) | 85 | — |
| Choice items | 69 | 30 |
| Guaranteed (non-choice) items | 30 | 12 |
| Reputation | 194 | — |

[data-verified] The 12 guaranteed-item quest IDs are: `92460, 92515, 92553, 92679, 92682, 92683, 92684,
92685, 92693, 93317, 93552, 93746`. Per M6 rule 3.4 and the M5 completion report, **quest 92515 specifically
has two separate real observations of the same guaranteed item ("Simple Leather Satchel")** — this is not
two independent quest-level confirmations of the guaranteed-item capability, only a repeat observation of
one quest; the other 11 guaranteed-item quest IDs each currently have real-client evidence from a single
observation.

## 8. Position Coverage

517 of the 517 `GiverIdentity` observations in this dataset carried a resolved player position — no
observed case where `GiverIdentity` fired without one [data-verified]. This says nothing about NPC-location
confidence (see Section 6's caveat) — it is purely a measure of how often the position-capture mechanism
itself succeeded.

## 9. Evidence Coverage

Applying the M6 evidence model (Section 4 of the M6 plan) to what this dataset actually contains, at the
*field* level, not the whole-quest level (per M6 rule 5 — never one global truth value per quest):

- **`confirmed`**: quest ID, title, level, and objectives for any quest with at least one successful
  `QuestMeta` capture (title present); XP/money for any quest with a `RewardsXPMoney` observation;
  choice-item names for the 30 quests listed in Section 7
- **`observed`**: the guaranteed-item names for the 12 quests in Section 7 (real, but evidentially weaker
  per M6 rule 3.4 — see Section 7's note on quest 92515 specifically); NPC identity for all 63 creature IDs
  in Section 6; reputation faction ID/amount for quests with a `RewardsReputation` observation
- **`unresolved`**: title/level/objectives for any quest whose only `QuestMeta` observation shows
  `title: null` (Section 10) — the quest is known to exist (a `quest_id` was captured) but this specific
  field was not
- **`candidate`**: none from this dataset directly — this dataset contains only real-client observations;
  the reported QuestV2/ATT candidate-universe figures (Section 11) are a separate, external source, not
  something this export produced
- **`placeholder`**: not assessed by this baseline — determining whether a QuestV2/ATT entry represents
  active content requires the raw candidate data this script does not have access to (Section 11)

No field in this dataset was assigned an evidence level stronger than what was actually observed; nothing
was silently upgraded.

## 10. Missing Fields

**156 `QuestMeta` observations show `title: null`, `level: null`, `objectives: null`**, each carrying the
honest `quest_log_index_error` reason (e.g. `"not found among 5 entries"`) rather than a fabricated value
[data-verified]. This is the expected, by-design behavior already established in M3/M4/M5 real-client
testing for quests viewed before being accepted into the quest log — **not treated as a defect here
either**, per M6 rule 3.6.

**7 `RewardsItems` observations recorded `saw_unresolved_first_value: true`** — the item-name-not-yet-
resolved condition first found during M4 [data-verified]. Per M6 rule 3.7, none of these observations
required the bounded retry mechanism to actually fire; all resolved naturally by a later checkpoint,
consistent with every real occurrence of this condition observed across this whole project to date.

The full per-observation detail for both of the above is preserved in `out/inventory.json`, not
summarized away — per M6 rule 19, unknowns are first-class data, not something to discard.

## 11. Source Overlap

**This section is deliberately limited, and the limitation is stated plainly rather than papered over.**

The M6 planning document itself reports, citing prior project research:
- QuestV2: approximately **6,600** total rows
- ATT Forever data: approximately **1,537** unique quest IDs

**[reported]** — these two figures come from the M6 planning document's own Section 6, not from anything
this script independently loaded or verified. This script has **no raw QuestV2 ID list, no raw ATT ID
list, and no Questie Era ID list on disk** to compute an actual set-level overlap against the 94 real
quest IDs in Section 5. Producing a genuine overlap table (QuestV2-only / ATT-only / real-observed /
multiple-source) is explicitly **not done in this report** — it would require either the raw candidate data
files or a rebuilt SQLite instance containing them, neither of which exists in this environment right now.
This is flagged as a concrete gap for the next milestone (Section 13), not filled in with an invented
number.

## 12. Contradictions

No cross-build or cross-session field contradiction was found for the 94 quests in this dataset
[data-verified — every quest ID's `QuestMeta` observations that successfully resolved a title were checked
for a differing title across sessions; none were found]. This is not surprising given the small real
dataset size and short real-world time span between sessions (all in a single testing period) — the
*absence* of a contradiction here should not be read as strong evidence the underlying content is stable
across builds generally.

## 13. Highest-Value Collection Gaps

Based only on what Sections 5–11 actually show:

1. **Guaranteed-item evidence remains thin and quest-specific.** 11 of the 12 guaranteed-item quests have
   exactly one real observation each; quest 92515 has two of the same quest. A collection run specifically
   targeting a *different* guaranteed-item quest a second time would be the single highest-value next
   real-client action for strengthening this specific evidence category.
2. **156 unresolved-title observations** represent quests seen but not yet followed through to a resolved
   state — revisiting any of these (accepting and progressing the quest) would convert `unresolved`
   evidence into `confirmed` evidence for real, already-touched quest IDs, rather than expanding into new
   territory.
2. **94 real quest IDs is a small fraction of the reported ~1,537 ATT-known and ~6,600 QuestV2-candidate
   scale** [reported figures, see Section 11's caveat] — the overwhelming majority of even the
   already-narrower ATT candidate set has no real-client observation of any kind yet.
3. **The retry mechanism has never been exercised for real.** All 7 real unresolved-item occurrences to
   date resolved naturally; no collection run has yet produced the specific timing where a retry attempt
   itself was necessary. This can't be deliberately engineered, but is worth noting as a standing gap.
4. **Source-overlap analysis (Section 11) cannot be produced at all without the raw QuestV2/ATT/Era ID
   data being made available to this pipeline** — a data-availability gap, not a collection gap.

## 14. Recommended Next Collection Runs

Framed as concrete runs, per the M6 collection-run structure (M6 plan Section 10) — not started as part of
this milestone, only recommended:

- **Run A**: revisit any subset of the 156 unresolved-title quest IDs (Section 10) by actually accepting
  and progressing them, to convert `unresolved` metadata into `confirmed`.
- **Run B**: target a guaranteed-item (non-choice-reward) quest **other than 92515** specifically, to begin
  building independent, multi-quest evidence for that category rather than repeat-confirming the same one.
- **Run C**: continue routine leveling/questing coverage in zones not yet represented among the 94 quest
  IDs in Section 5, to grow the real-observed set at all.

## 15. Limitations

- This baseline reflects **one export file** representing this project's cumulative real-client testing to
  date — it is not a live or continuously-updated view.
- The 244/1418 recorder/Lab attribution (Section 2) rests on this project's own conversation record of
  which sessions were generated during M5 testing, not on any field in the data itself.
- Source-overlap analysis against QuestV2/ATT/Era candidate universes (Section 11) could not be performed
  — no raw candidate ID data was available in this environment for this task.
- Evidence-level assignment (Section 9) was done narratively for this report; **no coverage database or
  automated evidence-classification system was built** — that is explicitly M6.2's job, not this
  milestone's.
- No new real-client data was collected to produce this report, per the explicit instruction to establish
  the baseline before further collection.
- This report and its companion `inventory.json` are the only outputs of M6.1; nothing in `forever-db/`,
  `m4-observation-lab/`, or `m5-production-recorder/` was read for write access, modified, or has any new
  dependency on this new `m6-dataset-baseline/` project folder.
