# M7.9 Completion Report: Pending Evidence Ingested into M6

**Status: COMPLETE.** The approved pending export was ingested into M6 using the existing M6 refresh path, unmodified.
The mutation was exactly four files. Quest 792's `r5` conflict is retained, unresolved and documented. No CollectionRun,
recorder, importer, classifier, source or licensing change was made.

## 1. Source export identity

| | Previous | Ingested |
|---|---|---|
| SHA-256 | `b5c35bec723664375f0fcd6a3d0cc96f3b7ac66794ef9c0426f6451e9a18663d` | `723dac899c56b1cfd884f07670f3ecd8aa77dde1627c87529c525e5103bea39a` |
| Size (bytes) | 3,200,963 | 3,848,772 |
| Observations | 2,510 | 3,008 (**+498**) |

The first 2,510 observations of the ingested export are identical, observation for observation, to the previous export,
so the 498 are purely additive evidence. The export was copied byte-for-byte into M6's canonical input slot
(`m6-dataset-baseline/out/latest_export_ForeverRecorder.lua`); its SHA-256 was checked before and after the copy.

**How it was run** (the existing path, exactly as documented in `docs/M7_9_SCOPE.md`; no manual edit of any generated file):

```
cp <approved export> m6-dataset-baseline/out/latest_export_ForeverRecorder.lua
cd m6-dataset-baseline/scripts
python3 coverage.py && python3 evidence_report.py && python3 guide_data.py
```

`inventory.py` and `collection_runs.py` were **not** run.

## 2. Before and after

| Measure | Before | After |
|---|---:|---:|
| Observations | 2,510 | 3,008 |
| Assertion rows | 3,200 | 3,835 (+635) |
| Observed quests | 121 | 153 |
| NPCs | 96 | 118 |
| Guide-ready quests | 84 | 96 (none lost) |
| Insufficient-evidence quests | 37 | 57 |
| M6.4 `genuine_conflict` | 2 | 6 |
| M6.4 `ambiguous_difference` | 0 | 0 |
| ATT-only candidates with any evidence (of 1,102) | 0 | **19** (6 guide-ready) |
| ATT-only candidates still unobserved | 1,102 | **1,083** |

These figures were **computed from the regenerated files**, not hardcoded. Blockers: before `{"title": 8, "quest_level": 8, "objectives": 36}`, after `{"title": 25, "quest_level": 25, "objectives": 42}`
(the denominator grew by 32 quests, many seen only at an offer screen). Field coverage by M6.2's own summary:

| Field | Before (covered / missing) | After (covered / missing) |
|---|---:|---:|
| `title` | 113 / 8 | 128 / 25 |
| `quest_level` | 113 / 8 | 128 / 25 |
| `objectives` | 85 / 36 | 111 / 42 |
| `xp` | 113 / 8 | 127 / 26 |
| `money` | 113 / 8 | 127 / 26 |
| `choice_items` | 44 / 77 | 49 / 104 |
| `guaranteed_items` | 15 / 106 | 26 / 127 |
| `reputation` | 92 / 29 | 114 / 39 |
| `giver` | 120 / 1 | 151 / 2 |
| `interaction_position` | 120 / 1 | 151 / 2 |
| `gossip_availability_sightings` | 86 / 35 | 99 / 54 |
| `prerequisites` | 0 / 121 | 0 / 153 |
| `completion` | 113 / 8 | 127 / 26 |

Two integrity results: all 3,200 previous assertion rows are reproduced **exactly** as the first rows of the new
import (same ID, entity, field, value hash, locator, method), and the new rows collide with the dedup key **0** times.
The regenerated `m6_evidence_report.json` and `m6_guide_dataset.json` are byte-identical to the M7.9 rehearsal and to a
fresh recomputation in a separate process; `m6_coverage.json` matches once only the documented unsorted conflict lists
are ignored.

## 3. The 19 newly covered candidates

All 19 came from sessions with **no CollectionRun**. Under the M7.8 operator declaration (not derivable from recorded
data): 16 were reached only outside the declared test sessions, 1 (815) in both, and 2
(907, 913) only in declared test sessions. The ATT column is source-derived candidate information and was **not** promoted.

| Quest | ATT candidate name (source-derived) | Status now | Observed title (M6) | Level | Sessions with a CollectionRun |
|---:|---|---|---|---:|---:|
| 784 | Vanquish the Betrayers | partial (core) | - | - | 0 |
| 786 | Thwarting Kolkar Aggression | partial (noncore) | - | - | 0 |
| 805 | Report to Sen'jin Village | partial (core) | Report to Sen'jin Village | 5 | 0 |
| 806 | Dark Storms | partial (noncore) | - | - | 0 |
| 808 | Minshina's Skull | partial (core) | - | - | 0 |
| 815 | Break a Few Eggs | guide-ready | Break a Few Eggs | 8 | 0 |
| 817 | Practical Prey | partial (core) | - | - | 0 |
| 818 | A Solvent Spirit | partial (noncore) | - | - | 0 |
| 823 | Report to Orgnil | partial (core) | Report to Orgnil | 7 | 0 |
| 826 | Zalazane | partial (core) | - | - | 0 |
| 837 | Encroachment | partial (core) | - | - | 0 |
| 907 | Enraged Thunder Lizards | guide-ready | Enraged Thunder Lizards | 18 | 0 |
| 913 | Cry of the Thunderhawk | partial (core) | - | - | 0 |
| 1463 | Earth Sapta | partial (noncore) | - | - | 0 |
| 1516 | Call of Earth (1/3) | guide-ready | Call of Earth | 4 | 0 |
| 1517 | Call of Earth (2/3) | partial (core) | Call of Earth | 4 | 0 |
| 1518 | Call of Earth (3/3) | guide-ready | Call of Earth | 4 | 0 |
| 5441 | Lazy Peons | guide-ready | Lazy Peons | 4 | 0 |
| 6394 | Thazz'ril's Pick | guide-ready | Thazz'ril's Pick | 4 | 0 |

Three of the partial quests (805, 823, 1517) are complete but stay partial because the recorder captured an empty
objectives list: they have no objectives, so the locked readiness rule cannot mark them guide-ready. Quest 913 remains
partial with title and level unresolved (the known `QUEST_DETAIL` issue, out of scope).

## 4. The 6 newly guide-ready candidates

Each required field moved from "no quest entity in M6" to `confirmed`. What supplied each:

| Quest | Before (M6) | `title` | `quest_level` | `objectives` |
|---:|---|---|---|---|
| 815 | no quest entity | **Break a Few Eggs** - 1 obs [quest_progress]; first obs#2996 20:27:37 sess 0df16c | **8** - 1 obs [quest_progress]; first obs#2996 20:27:37 sess 0df16c | `0/3  ` - 1 obs [quest_detail]; first obs#2961 20:09:32 sess 3d2cdd<br>`0/3 Taillasher Egg` - 1 obs [quest_progress]; first obs#2996 20:27:37 sess 0df16c |
| 907 | no quest entity | **Enraged Thunder Lizards** - 1 obs [quest_complete_immediate]; first obs#2550 23:54:06 sess beba6d | **18** - 1 obs [quest_complete_immediate]; first obs#2550 23:54:06 sess beba6d | `0/3 Thunder Lizard Blood` - 1 obs [quest_complete_delayed]; first obs#2559 23:54:07 sess beba6d<br>`3/3 Thunder Lizard Blood` - 1 obs [quest_complete_immediate]; first obs#2550 23:54:06 sess beba6d |
| 1516 | no quest entity | **Call of Earth** - 1 obs [quest_complete_immediate]; first obs#2729 19:47:39 sess 3d2cdd | **4** - 1 obs [quest_complete_immediate]; first obs#2729 19:47:39 sess 3d2cdd | `0/2 Felstalker Hoof` - 1 obs [quest_complete_delayed]; first obs#2738 19:47:41 sess 3d2cdd<br>`2/2 Felstalker Hoof` - 1 obs [quest_complete_immediate]; first obs#2729 19:47:39 sess 3d2cdd |
| 1518 | no quest entity | **Call of Earth** - 1 obs [quest_complete_immediate]; first obs#2790 19:51:19 sess 3d2cdd | **4** - 1 obs [quest_complete_immediate]; first obs#2790 19:51:19 sess 3d2cdd | `Bring the Rough Quartz to Canaga Earthcaller in the Valley of Trials.` - 1 obs [quest_complete_immediate]; first obs#2790 19:51:19 sess 3d2cdd |
| 5441 | no quest entity | **Lazy Peons** - 1 obs [quest_complete_immediate]; first obs#2755 19:48:33 sess 3d2cdd | **4** - 1 obs [quest_complete_immediate]; first obs#2755 19:48:33 sess 3d2cdd | `0/5 Peons Awoken` - 1 obs [quest_complete_delayed]; first obs#2764 19:48:35 sess 3d2cdd<br>`5/5 Peons Awoken` - 1 obs [quest_complete_immediate]; first obs#2755 19:48:33 sess 3d2cdd |
| 6394 | no quest entity | **Thazz'ril's Pick** - 1 obs [quest_complete_immediate]; first obs#2801 19:59:26 sess 3d2cdd | **4** - 1 obs [quest_complete_immediate]; first obs#2801 19:59:26 sess 3d2cdd | `0/1 Thazz'ril's Pick` - 1 obs [quest_complete_delayed]; first obs#2806 19:59:27 sess 3d2cdd<br>`1/1 Thazz'ril's Pick` - 1 obs [quest_complete_immediate]; first obs#2801 19:59:26 sess 3d2cdd |

Five come from completed turn-ins. **815 is the only one that depends on the `quest_progress` checkpoint** (its title
and level come only from it).

## 5. Quest 794

The M7.3 evidence gap is closed, and 794 becomes guide-ready. All six gains were unresolved before, resolved after, and
backed only by the new observations; no other field of 794 changed state.

| Field | Before | After | Rows before | New rows (checkpoints) | Value (pending) |
|---|---|---|---:|---|---|
| `title` | unresolved | confirmed | 0 | 2 (quest_complete_delayed, quest_complete_immediate) | Burning Blade Medallion |
| `quest_level` | unresolved | confirmed | 0 | 2 (quest_complete_delayed, quest_complete_immediate) | 5 |
| `objectives` | unresolved | confirmed | 0 | 3 (quest_complete_delayed, quest_complete_immediate, quest_detail) | 1/1 Burning Blade Medallion |
| `xp` | unresolved | confirmed | 0 | 1 (QUEST_TURNED_IN) | 675 |
| `money` | unresolved | confirmed | 0 | 1 (QUEST_TURNED_IN) | 0 |
| `choice_items` | confirmed | confirmed | 2 | 3 (quest_complete_delayed, quest_complete_immediate, quest_detail) | - |
| `guaranteed_items` | observed | observed | 2 | 3 (quest_complete_delayed, quest_complete_immediate, quest_detail) | - |
| `reputation` | confirmed | confirmed | 2 | 3 (quest_complete_delayed, quest_complete_immediate, quest_detail) | - |
| `giver` | observed | observed | 2 | 3 (quest_complete_delayed, quest_complete_immediate, quest_detail) | - |
| `interaction_position` | observed | observed | 2 | 3 (quest_complete_delayed, quest_complete_immediate, quest_detail) | - |
| `gossip_availability_sightings` | unresolved | unresolved | 0 | 0 | - |
| `completion` (derived) | unresolved | confirmed | - | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate | - |

## 6. Other notable improvements

- **1195 and 97538** gain `objectives` (a count and an item type) but stay partial: title and level remain unresolved,
  and both captured objective texts have a blank item name.
- **Five quests outside the candidate pool** also become guide-ready (12 = 6 pool + 794 + these 5):

| Quest | Membership | Title | Level | Displayed objective |
|---:|---|---|---:|---|
| 2161 | ATT-only, unqualified (outside the 1,102) | A Peon's Burden | 5 | Bring Ukor's Burden to Innkeeper Grosk in Razor Hill. |
| 3084 | ATT-only, unqualified (outside the 1,102) | Rune-Inscribed Tablet | 1 | Speak to Shikrik in the Valley of Trials. |
| 96604 | not in ATT | The Great Outdoors | 6 | *(two empty placeholder objective entries)* |
| 96652 | not in ATT | The Adventurer | 6 | Bring the journal to Brakk near Razor Hill. |
| 96825 | not in ATT | This Fruit Could Bite Back | 6 | 0/8 |

- **12 of the 121 previously observed quests** received new evidence rows; only 794 changed guide-readiness:

| Quest | New rows | Newly resolved fields | New distinct values added to | Guide-ready before → after | New M6.4 conflict |
|---:|---:|---|---|---|---|
| 788 | 22 | - | player position, objectives | yes → yes | - |
| 789 | 24 | - | player position, objectives | yes → yes | objectives |
| 790 | 16 | - | player position, objectives | yes → yes | - |
| 792 | 21 | - | player position, choice items | yes → yes | choice_items |
| 794 | 24 | title, quest_level, objectives, xp, money, completion | level, player position, objectives, choice items, guaranteed items, money, reputation, xp, title | no → yes | - |
| 804 | 23 | - | player position | no → no | - |
| 1195 | 12 | objectives | player position, objectives | no → no | objectives |
| 4402 | 40 | - | player position | yes → yes | - |
| 4641 | 16 | - | player position | no → no | - |
| 97279 | 17 | - | player position | yes → yes | - |
| 97538 | 4 | objectives | player position, objectives | no → no | - |
| 99196 | 2 | - | gossip sighting | no → no | - |

## 7. The four new conflicts

M6.4 now reports 6 `genuine_conflict`s: the two pre-existing ones on 4402 (unchanged) and four new ones. **None affects
guide-readiness**, which reads only M6.2's per-field tier. The classifier was not modified and no observation was
normalized.

| Quest / field | Status | Checkpoints | Distinct values | Pattern | Effect on guide-readiness |
|---|---|---|---:|---|---|
| 789 `objectives` | **new** | quest_complete_delayed, quest_complete_immediate, quest_detail | 3 | blank item name at one `quest_detail` capture vs named captures; completion captures agree | none |
| 792 `choice_items` | **new** | quest_complete_delayed, quest_complete_immediate, quest_detail | 6 | **`r5` differs between two session groups** (see the next section) | none |
| 913 `guaranteed_items` | **new** | quest_detail | 2 | blank name, then `Gloves of the Moon` about 80 s later in the same session | none |
| 1195 `objectives` | **new** | quest_detail | 2 | `0/1  `, `0/1 Filled Etched Phial`, then `0/1  ` again in a later session | none |
| 4402 `guaranteed_items` | pre-existing | quest_complete_delayed, quest_complete_immediate, quest_detail | 4 | pre-existing, unchanged | none |
| 4402 `objectives` | pre-existing | quest_complete_delayed, quest_complete_immediate, quest_detail | 3 | pre-existing, unchanged | none |

Three of the four (789, 913, 1195) are the documented blank-name pattern. Quest 792 is different and is treated below.

## 8. Quest 792 `r5`: retained, unresolved, documented

Accepted by the operator as an **unresolved field-semantic conflict**, and preserved exactly as the existing classifier
produced it.

- `r5` is the **fifth positional return of `GetQuestItemInfo`**. Its semantics are **unconfirmed on Forever**
  (`docs/M7_9_1_QUEST_792_R5_INVESTIGATION.md`).
- **Both observed values are retained**: 19 assertion rows, 16 with `r5` per item `FTTF` and 3 with `TFFT`. Neither was
  discarded, chosen as correct, suppressed, normalized or marked resolved.
- **No effect on guide-readiness**: 792 is guide-ready before and after, with `title`, `quest_level` and `objectives`
  all `confirmed`; `choice_items` is not a required readiness field.
- The conflict means **two distinct values were observed**. It is not a determination that either is incorrect.
- **Display only:** M6 now displays `TFFT` for 792's items (previously `FTTF`), simply because the newer observations
  are chosen by M6.2's display rule. If `r5` is per-character, neither vector is a quest-level fact, so `r5` is
  **unlabeled, possibly per-character, and must not be surfaced as a quest attribute**.

## 9. Blank-name display caveat (unchanged, by instruction)

M6.2's display rule was not touched. M6's displayed objective is a blank item name for **1** quest before and
**11** after. For **3** (815, 1195, 96825) a named capture exists but is not the one displayed (`quest_progress`
is absent from M6.2's display-priority list, and for 1195 a later blank capture wins the tie). The other 8 (808, 817, 826, 913, 914, 97223, 97225, 97538)
were only ever captured blank (914 was already displayed blank before this ingestion, so ten are new). Every captured value remains in M6's `all_values`; this is a display choice, not lost
evidence.

## 10. Exact mutation boundary

| File (under `m6-dataset-baseline/out/`) | Role | Bytes before → after | SHA-256 before → after |
|---|---|---:|---|
| `latest_export_ForeverRecorder.lua` | canonical input export (replaced) | 3,200,963 → 3,848,772 | `b5c35bec72366437…` → `723dac899c56b1cf…` |
| `m6_coverage.json` | regenerated | 2,312,541 → 2,869,530 | `6671e4f02dcbdc88…` → `a562df257bd3523b…` |
| `m6_evidence_report.json` | regenerated | 656,193 → 822,334 | `ed31f3c22f8c3cb6…` → `bf29f47680462e5b…` |
| `m6_guide_dataset.json` | regenerated | 772,388 → 959,359 | `6f7099f44d37f24b…` → `13999e906b802d73…` |

Verified against a pre-ingestion hash snapshot of **113 protected files** (`research/m7_9/pre_ingestion_hashes.txt`): exactly
these four files changed, and nothing else was changed, added or removed among them. **Unchanged:** the CollectionRun
registry, `inventory.json` (a stale M6.1 artifact, deliberately not regenerated), both Run-001 coverage snapshots, the M6
scripts, the recorder, M4/ATT code, schemas, `sources.toml`, `LICENSING.md`, and every M7.3–M7.9.1 artifact.
Rollback copies of the four previous files were kept outside the repository (not part of the project); their hashes
are recorded above.

## 11. Test results

| Suite | Result |
|---|---|
| Recorder (Lua) | all pass |
| M6 (M6.2 + M6.3 + M6.4 + M6.6) | 62 / 62 |
| M4 unit (incl. repo-safety) | 141 / 141 |
| ATT integration | 7 / 7 |
| M7.5 | 14 / 14 |
| M7.4 | 9 pass, **2 expected-stale failures** |
| M7.6 | 11 pass, **1 expected-stale failure** |
| M7.8 (real export supplied) | 26 pass, **3 expected-stale failures** |
| New M7.9 (`research/m7_9/test_m7_9_ingestion.py`) | 14 / 14 |

**0 unexpected failures and 0 genuine regressions.** The 6 failures are all locked historical tests whose assertions
encode a fact about the pre-ingestion state (the M7.4 registry case predates M7.9):

| Test | Failing assertion | Cause |
|---|---|---|
| M7.4 `test_no_collection_run_is_created_in_the_m6_registry` | `11 == 1` | Pre-existing since M7.5 (ten pilot runs); unrelated to this ingestion |
| M7.4 `test_completeness_counts_only_cover_att_only_population` | `1502 == 1523` | 21 quests (19 pool + 2 unqualified) left the ATT-only set |
| M7.6 `test_m6_outputs_unchanged` | guide-dataset hash `13999e90…` ≠ pinned `6f7099f4…` | Pins the previous M6 outputs |
| M7.8 `test_protected_snapshot_matches_current_state` | 4 changed M6 files, plus 2 added docs | Snapshot encodes the previous M6 (it would also have failed on the added M7.9 documents alone) |
| M7.8 `test_cli_smoke_…` | exit code `3` vs `0` | The same snapshot check inside the CLI |
| M7.8 `test_real_export_reproduces_the_approved_known_results` | `(153, 96) == (121, 84)` | The canonical baseline *is* now the ingested state |

**Intentionally updated tests: none.** None of these was edited, because each asserts a pre-ingestion fact of a locked
milestone, and rewriting it would falsify what that milestone verified at the time (the same convention M7.5 applied to
the stale M7.4 registry test). The forward-looking guard is the new M7.9 test file, which pins the post-ingestion state
and the invariants that must now hold. Whether to retire or re-point the six locked tests is a separate change that
needs explicit approval and was not made.

## 12. Confirmations

- **No CollectionRun** was created, modified or associated: the registry still has **11** runs (Run-001 `active`, ten
  M7.5 pilots `planned`), SHA-256 `60b713f2bcaf5e6e…`, unchanged.
- **No source or licensing change:** `config/sources.toml` and `docs/LICENSING.md` are byte-identical.
- **No code change:** the recorder, the M4 importer, ATT ingestion, the evidence schema, the M6 scripts (including the
  M6.4 classifier and readiness logic) are byte-identical; the M7.7 17-file lock manifest passes.
- **No hand-edited output:** every regenerated file equals a fresh recomputation from the ingested export.
- Ingestion did not modify, reinterpret or replace any existing evidence: the 3,200 prior assertion rows are
  reproduced exactly.
