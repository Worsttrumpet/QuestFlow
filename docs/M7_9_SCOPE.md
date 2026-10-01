# M7.9 Scope Reconstruction: Pending Evidence Review and M6 Ingestion

**Status: PROPOSED — scope reconstruction and evidence review only.** Nothing was ingested. M6 (datasets,
registry, export), the recorder, the importer, the classifier, licensing and sources were not modified. No
CollectionRun was created or changed.

**In brief.** The existing M6 refresh path can accept the pending export **as-is**: no code, importer, schema or
classifier change is needed. Ingestion is all-or-nothing at file granularity, so the 498 additional observations
cannot be taken selectively. The rehearsal (Section 0) shows the mutation boundary is exactly **four files**. Seven
decisions still need a human (Section 13), chiefly the unlabeled `r5` sub-field in quest 792, three quests whose
*displayed* objective would be a blank item name although a named capture exists, and a set of locked tests that
encode today's M6 state and would go stale. The smallest safe M7.9 is two gates: **(A)** operator review and
sign-off on Section 13, then **(B)** one controlled, hash-verified refresh, only if approved.

## 0. How this review was done

| Input | Detail | SHA-256 |
|---|---|---|
| Existing M6 input export | `m6-dataset-baseline/out/latest_export_ForeverRecorder.lua`, 2,510 observations | `b5c35bec723664375f0fcd6a3d0cc96f3b7ac66794ef9c0426f6451e9a18663d` |
| Pending export (not ingested) | 3,008 observations. Read from a scratch path outside the repository (`/home/claude/m5_real/ForeverRecorder_m77_test2.lua`) | `723dac899c56b1cfd884f07670f3ecd8aa77dde1627c87529c525e5103bea39a` |
| M7.8 accounting report | `research/m7_8/candidate_coverage_accounting.json`, content hash | `eac8d3e74c4d8b6e10b5da3d79ddfbf59294181eb28982684b9194a603478840` |
| Locked candidate list (M7.4) | 1,102 candidates | `b7fc38de6993836e51f3b8f437238d0cd0d833005e8639a54ad8ac80a6c6a50b` |

Three kinds of work, none of which touched the project:

1. **In-memory analysis.** Both exports were imported into throwaway in-memory databases through the unmodified M4
   importer and summarized with M6's own functions (Sections 3–8).
2. **A dry-run rehearsal in a throwaway copy** of `m6-dataset-baseline/` under `/tmp` (outside the project). The pending
   export was placed in the *copy's* canonical input slot and the three routine refresh scripts were run there
   (Sections 9–10). Sections 7 and 8 (idempotency) are in-memory only; the rehearsal is what wrote files, and only into
   the copy. The real M6 was hash-verified unchanged afterwards.
3. **An in-process simulation** for downstream tests: the `EXPORT_PATH` attribute of the already-imported `coverage`
   module was pointed at the pending export inside one Python process (Section 9). No file was edited.

**Two statements in the request that the evidence refines:**

- *"The first 2,510 observations are byte-for-byte identical."* What was verified is **observation-for-observation
  identity of the parsed records**, and, more strongly for ingestion, that all 3,200 assertion rows built from them are
  reproduced exactly (Section 8). The raw file bytes naturally differ, because the pending file is longer.
- *"The existing 792 conflict."* In the existing M6, M6.4 classifies 792's `choice_items` as `none`. **The 792 conflict is
  new after ingestion.** The only existing genuine conflicts are the two on quest 4402.

## 1. Problem statement

M7.8 measured what the pending export would do. Before any mutation of the authoritative dataset, three further
questions need answers: *which exact evidence would be added*, *what would that evidence look like to a reader of M6*,
and *what exactly would change on disk and downstream*. This document answers them from the actual data, and defines a
gated, minimal path to ingestion. It does not authorize or perform it.

## 2. Pending evidence summary

| Measure | Existing M6 | If ingested (rehearsed) |
|---|---:|---:|
| Observations in the input export | 2,510 | 3,008 (+498) |
| Assertion rows | 3,200 | 3,835 (+635: 541 quest-scoped, 94 NPC-scoped) |
| Quests | 121 | 153 (+32) |
| NPCs | 96 | 118 (+22) |
| Guide-ready quests | 84 | 96 (+12; none lost) |
| Insufficient-evidence quests | 37 | 57 |
| Candidates (of 1,102) with any evidence | 0 | 19 (6 guide-ready) |
| M6.4 `genuine_conflict` | 2 | 6 |
| M6.4 `ambiguous_difference` | 0 | 0 |
| Coverage-level `conflicts_found` (M6.2) | 60 | 81 |

The 498 additional observations, by checkpoint:

| Checkpoint | Additional observations |
|---|---:|
| `GOSSIP_SHOW` | 94 |
| `QUEST_TURNED_IN` | 22 |
| `quest_complete_delayed` | 96 |
| `quest_complete_immediate` | 96 |
| `quest_detail` | 184 |
| `quest_progress` | 6 |

They come from 9 recorder sessions, none associated with any CollectionRun. About 84% (417) come from two ordinary
leveling sessions; the rest from short M7.6/M7.7 test sessions. That last distinction is **operator-declared** (M7.8) and
is not derivable from recorded data.

The 32 quests that would newly appear in M6 are: **19** in the candidate pool, **2** ATT-only quests outside the
1,102 (2161, 3084), and **11** not in ATT at all.

Field-level coverage (M6.2's own `field_summary`, existing vs rehearsed):

| Field | Existing M6 (covered / missing) | If ingested (covered / missing) |
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

`missing` rises for most fields because 32 new quests enter the denominator, many seen only at an offer screen.

## 3. The 19 newly covered ATT candidates

**6 guide-ready, 9 partial with some core field, 4 partial with non-core fields only.** All 19 came from sessions with
no CollectionRun. Under the M7.8 operator declaration, 16 were reached only outside the declared test sessions, 1 (815)
in both, and 2 (907, 913) only in declared test sessions.

Nothing here is promoted into M6. The *ATT candidate* column is source-derived (`source_derived_not_observed`); every
other column is pending observed evidence. For all 19, **at least one** observed giver NPC ID matches the ATT candidate
giver NPC ID; for 4 quests (805, 823, 1517, 1518) a second, different NPC was also observed (the offering-vs-turn-in
role ambiguity documented since M4). That is informational and does **not** verify ATT.

| Quest | ATT candidate (source-derived): name; giver NPC; map | Observed fields now present | Status | Checkpoints | Passive / run | Warnings |
|---:|---|---|---|---|---|---|
| 784 | Vanquish the Betrayers; giver 3139; DUROTAR | objectives; reputation; giver Gar'Thok (3139); player position | partial (core) | quest_detail | passive only; declared: no_declared_test | title unresolved; level unresolved; observed giver matches ATT giver |
| 786 | Thwarting Kolkar Aggression; giver 3140; DUROTAR | choice items; reputation; giver Lar Prowltusk (3140); player position | partial (noncore) | quest_detail | passive only; declared: no_declared_test | title unresolved; level unresolved; observed giver matches ATT giver |
| 805 | Report to Sen'jin Village; giver 3145; DUROTAR | title 'Report to Sen'jin Village'; level 5; xp; money; reputation; giver Zureetha Fargaze (3145)/Master Gadrin (3188); player position | partial (core) | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail | passive only; declared: no_declared_test | observed giver matches ATT giver |
| 806 | Dark Storms; giver 3142; DUROTAR | guaranteed items; reputation; giver Orgnil Soulscar (3142); player position | partial (noncore) | quest_detail | passive only; declared: no_declared_test | title unresolved; level unresolved; observed giver matches ATT giver |
| 808 | Minshina's Skull; giver 3188; DUROTAR | objectives; guaranteed items; reputation; giver Master Gadrin (3188); player position | partial (core) | quest_detail | passive only; declared: no_declared_test | title unresolved; level unresolved; blank item name in an objective capture; observed giver matches ATT giver |
| 815 | Break a Few Eggs; giver 3191; DUROTAR | title 'Break a Few Eggs'; level 8; objectives; guaranteed items; reputation; giver Cook Torka (3191); player position; gossip sighting (active,available) | guide_ready | GOSSIP_SHOW, quest_detail, quest_progress | passive only; declared: mixed_declared | blank item name in an objective capture; observed giver matches ATT giver |
| 817 | Practical Prey; giver 3194; DUROTAR | objectives; reputation; giver Vel'rin Fang (3194); player position | partial (core) | quest_detail | passive only; declared: no_declared_test | title unresolved; level unresolved; blank item name in an objective capture; observed giver matches ATT giver |
| 818 | A Solvent Spirit; giver 3304; DUROTAR | guaranteed items; reputation; giver Master Vornal (3304); player position | partial (noncore) | quest_detail | passive only; declared: no_declared_test | title unresolved; level unresolved; observed giver matches ATT giver |
| 823 | Report to Orgnil; giver 3188; DUROTAR | title 'Report to Orgnil'; level 7; xp; money; reputation; giver Orgnil Soulscar (3142)/Master Gadrin (3188); player position | partial (core) | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail | passive only; declared: no_declared_test | observed giver matches ATT giver |
| 826 | Zalazane; giver 3188; DUROTAR | objectives; choice items; reputation; giver Master Gadrin (3188); player position | partial (core) | quest_detail | passive only; declared: no_declared_test | title unresolved; level unresolved; blank item name in an objective capture; observed giver matches ATT giver |
| 837 | Encroachment; giver 3139; DUROTAR | objectives; reputation; giver Gar'Thok (3139); player position | partial (core) | quest_detail | passive only; declared: no_declared_test | title unresolved; level unresolved; observed giver matches ATT giver |
| 907 | Enraged Thunder Lizards; giver 3387; THE_BARRENS | title 'Enraged Thunder Lizards'; level 18; objectives; xp; money; choice items; guaranteed items; reputation; giver Jorn Skyseer (3387); player position; gossip sighting (active) | guide_ready | GOSSIP_SHOW, QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate | passive only; declared: only_declared_test | observed giver matches ATT giver |
| 913 | Cry of the Thunderhawk; giver 3387; THE_BARRENS | objectives; choice items; guaranteed items; reputation; giver Jorn Skyseer (3387); player position; gossip sighting (active,available) | partial (core) | GOSSIP_SHOW, quest_detail | passive only; declared: only_declared_test | title unresolved; level unresolved; blank item name in an objective capture; M6.4 genuine_conflict on guaranteed_items; observed giver matches ATT giver |
| 1463 | Earth Sapta; giver 5887; DUROTAR | xp; money; guaranteed items; giver Canaga Earthcaller (5887); player position | partial (noncore) | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate | passive only; declared: no_declared_test | title unresolved; level unresolved; observed giver matches ATT giver |
| 1516 | Call of Earth (1/3); giver 5887; DUROTAR | title 'Call of Earth'; level 4; objectives; xp; money; giver Canaga Earthcaller (5887); player position | guide_ready | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail | passive only; declared: no_declared_test | observed giver matches ATT giver |
| 1517 | Call of Earth (2/3); giver 5887; DUROTAR | title 'Call of Earth'; level 4; xp; money; guaranteed items; giver Canaga Earthcaller (5887)/Minor Manifestation of Earth (5891); player position | partial (core) | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail | passive only; declared: no_declared_test | observed giver matches ATT giver |
| 1518 | Call of Earth (3/3); giver 5891; DUROTAR | title 'Call of Earth'; level 4; objectives; xp; money; guaranteed items; giver Canaga Earthcaller (5887)/Minor Manifestation of Earth (5891); player position | guide_ready | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail | passive only; declared: no_declared_test | observed giver matches ATT giver |
| 5441 | Lazy Peons; giver 11378; DUROTAR | title 'Lazy Peons'; level 4; objectives; xp; money; reputation; giver Foreman Thazz'ril (11378); player position | guide_ready | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail | passive only; declared: no_declared_test | observed giver matches ATT giver |
| 6394 | Thazz'ril's Pick; giver 11378; DUROTAR | title 'Thazz'ril's Pick'; level 4; objectives; xp; money; reputation; giver Foreman Thazz'ril (11378); player position | guide_ready | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail | passive only; declared: no_declared_test | observed giver matches ATT giver |

Reading the table:

- **805, 823 and 1517 are complete but partial** because the recorder captured `objectives=[]` (an empty list) at their
  reward screens. They are "report to X" style quests with **zero objectives**, so the locked readiness rule (which
  requires confirmed `objectives`) can never mark them guide-ready. That is a rule limitation, not an evidence gap. The
  existing M6 already has 29 quests with title and level but no objectives; ingestion adds these 3.
- **913 remains partial** with title and level unresolved: the known `QUEST_DETAIL` lookup issue, out of scope here.
- "Blank item name" means a captured objective text like `0/3  ` (item name not yet loaded at first read).

## 4. The 6 newly guide-ready candidates

Each of the three required fields moves from **"no quest entity in M6"** to `confirmed`. What supplied each:

| Quest | Before (M6) | `title` | `quest_level` | `objectives` |
|---:|---|---|---|---|
| 815 | no quest entity | **Break a Few Eggs** - 1 obs [quest_progress]; first obs#2996 20:27:37 sess 0df16c | **8** - 1 obs [quest_progress]; first obs#2996 20:27:37 sess 0df16c | `0/3  ` - 1 obs [quest_detail]; first obs#2961 20:09:32 sess 3d2cdd<br>`0/3 Taillasher Egg` - 1 obs [quest_progress]; first obs#2996 20:27:37 sess 0df16c |
| 907 | no quest entity | **Enraged Thunder Lizards** - 1 obs [quest_complete_immediate]; first obs#2550 23:54:06 sess beba6d | **18** - 1 obs [quest_complete_immediate]; first obs#2550 23:54:06 sess beba6d | `0/3 Thunder Lizard Blood` - 1 obs [quest_complete_delayed]; first obs#2559 23:54:07 sess beba6d<br>`3/3 Thunder Lizard Blood` - 1 obs [quest_complete_immediate]; first obs#2550 23:54:06 sess beba6d |
| 1516 | no quest entity | **Call of Earth** - 1 obs [quest_complete_immediate]; first obs#2729 19:47:39 sess 3d2cdd | **4** - 1 obs [quest_complete_immediate]; first obs#2729 19:47:39 sess 3d2cdd | `0/2 Felstalker Hoof` - 1 obs [quest_complete_delayed]; first obs#2738 19:47:41 sess 3d2cdd<br>`2/2 Felstalker Hoof` - 1 obs [quest_complete_immediate]; first obs#2729 19:47:39 sess 3d2cdd |
| 1518 | no quest entity | **Call of Earth** - 1 obs [quest_complete_immediate]; first obs#2790 19:51:19 sess 3d2cdd | **4** - 1 obs [quest_complete_immediate]; first obs#2790 19:51:19 sess 3d2cdd | `Bring the Rough Quartz to Canaga Earthcaller in the Valley of Trials.` - 1 obs [quest_complete_immediate]; first obs#2790 19:51:19 sess 3d2cdd |
| 5441 | no quest entity | **Lazy Peons** - 1 obs [quest_complete_immediate]; first obs#2755 19:48:33 sess 3d2cdd | **4** - 1 obs [quest_complete_immediate]; first obs#2755 19:48:33 sess 3d2cdd | `0/5 Peons Awoken` - 1 obs [quest_complete_delayed]; first obs#2764 19:48:35 sess 3d2cdd<br>`5/5 Peons Awoken` - 1 obs [quest_complete_immediate]; first obs#2755 19:48:33 sess 3d2cdd |
| 6394 | no quest entity | **Thazz'ril's Pick** - 1 obs [quest_complete_immediate]; first obs#2801 19:59:26 sess 3d2cdd | **4** - 1 obs [quest_complete_immediate]; first obs#2801 19:59:26 sess 3d2cdd | `0/1 Thazz'ril's Pick` - 1 obs [quest_complete_delayed]; first obs#2806 19:59:27 sess 3d2cdd<br>`1/1 Thazz'ril's Pick` - 1 obs [quest_complete_immediate]; first obs#2801 19:59:26 sess 3d2cdd |

- **5 of the 6 come from completed turn-ins** (title and level from `quest_complete_immediate`, objectives from the
  completion checkpoints). **815 is the only one that depends on the M7.7 checkpoint:** its title and level come *only*
  from `quest_progress`, and the item name in its objective appears only in that capture.
- **907 came from a declared test session** (the M7.6 experiment), so it is real client evidence with an
  operator-declared, non-ordinary origin.
- **1518's objective is text-only** (a "bring X to Y" line with no counter).
- **Display caveats** (Section 7): for 815 M6 would *display* the blank-name `0/3  `; for 5 of the 6 (815, 907, 1516,
  5441, 6394) the displayed objective is the post-turn-in `0/N` state rather than `N/N`. The `0/N` display is already
  the convention: 39 of the existing 84 guide-ready quests display `0/…` (45 of 96 after).

## 5. Quest 794

Verified against the actual pending observations. Every claimed gain was **unresolved before, resolved after, and backed
only by the additional observations** (13 observations, obs#2725–2818, one session `3d2cdd…`, 19:47–19:59 on 2026-09-27);
none is backed by pre-existing rows. No other field of 794 changes state.

| Field | Existing M6 | If ingested | Rows before | New rows (checkpoints) | Value (pending) |
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

- **Gained (all six confirmed):** `title` "Burning Blade Medallion", `quest_level` 5, `objectives`
  `1/1 Burning Blade Medallion` (a single item-type objective), `xp` 675, `money` 0, and derived `completion`
  (the completion checkpoints `quest_complete_immediate`, `quest_complete_delayed` and `QUEST_TURNED_IN` were all observed). 794 goes from not guide-ready to guide-ready.
- **Prior M6 evidence** for 794 was 8 observations at `quest_detail` only, which yielded rewards, giver and position
  but no title, level or objectives.
- **M7.3 gap closes.** `objectives` was the single observed-evidence gap M7.3 found. M6.4 classification moves from
  `no_evidence` to `state_change` (`0/1  `, name not yet loaded, at `quest_detail` vs
  `1/1 Burning Blade Medallion` at both completion checkpoints).
- **ATT candidate hint, kept separate.** The locked M7.4 follow-up lists an item target (4859) and a creature target
  (3183) with Durotar coordinates. The observed evidence is one item-type objective. This is **not** a verification of
  ATT and nothing was promoted.

## 6. Other affected quests

**12 of the 121 existing M6 quests would receive new evidence rows.** None is a repeat-only case, none loses evidence,
and only 794 changes guide-readiness.

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

- **Gain new resolved fields (3):** 794 (above), **1195** and **97538**, each gaining `objectives` only.
  They stay partial because title and level are unresolved. The gain is still useful (the required count and type:
  one item for 1195, thirty for 97538), but **both captured objective texts have a blank item name** (`0/1  `,
  `0/30  `), so the *what* is incomplete.
- **Add a new distinct value to already-resolved fields only (9):** mostly new player-position values (M6.4
  `position_variance`, expected when standing in a different place), new objective variants at `quest_detail`
  (788, 789, 790), new choice-item variants (792), and one gossip sighting (99196).

Five quests **outside the candidate pool** would also become guide-ready (they account for 12 = 6 pool + 794 + 5):

| Quest | Membership | Title | Level | Displayed objective |
|---:|---|---|---:|---|
| 2161 | ATT-only, unqualified (outside the 1,102) | A Peon's Burden | 5 | Bring Ukor's Burden to Innkeeper Grosk in Razor Hill. |
| 3084 | ATT-only, unqualified (outside the 1,102) | Rune-Inscribed Tablet | 1 | Speak to Shikrik in the Valley of Trials. |
| 96604 | not in ATT | The Great Outdoors | 6 | *(two empty placeholder objective entries)* |
| 96652 | not in ATT | The Adventurer | 6 | Bring the journal to Brakk near Razor Hill. |
| 96825 | not in ATT | This Fruit Could Bite Back | 6 | 0/8 |

96604 counts as guide-ready under the locked rule although its objectives are **two empty placeholder entries**. It is
the seventh such quest: 6 of the existing 84 guide-ready quests already have only empty placeholder objectives.

## 7. Conflict review

**New M6.4 `genuine_conflict`s if ingested: four.** Two pre-existing conflicts (4402, both fields) are unchanged. The
classifier was not modified, and no observation was normalized.

| Quest / field | What differs | Effect on guide-readiness | Value M6 would display | Assessment |
|---|---|---|---|---|
| 789 `objectives` | A blank-name capture at `quest_detail` (`0/10  `) in a new session vs named captures (`0/10 Scorpid Worker Tail`). Structure identical; only the name text differs. Completion captures agree. | None (guide-ready before and after) | `10/10 Scorpid Worker Tail` | **Benign repeat-capture.** Classification label flips `state_change` → `genuine_conflict` |
| 913 `guaranteed_items` | `''` then `Gloves of the Moon` about 80 s later, same session. Differs in `r1` (name) and `r4` (0 vs 2); `r2`, `r3`, `r5`, `r6` equal | None (not a required field) | `Gloves of the Moon` | **Benign**: the documented unresolved-at-first-read pattern |
| 1195 `objectives` | `0/1  `, `0/1 Filled Etched Phial`, then `0/1  ` **again in a later session**. Structure identical | None (not guide-ready: title/level unresolved) | **`0/1  ` (blank)** | Evidence benign (every value retained), but the **display is blank although the name was captured**: human review |
| 792 `choice_items` | Item names identical in all 19 captures. `r5` flips for all four items between two session groups (details below) | None (not a required field) | same names | **Human review required** |
| 4402 (both fields) | pre-existing | unchanged | unchanged | unchanged after ingestion (descriptors identical) |

**The unlabeled `r5` sub-field (792).** Observed facts: `r5` is **perfectly stable within every session** (one vector per
session, across `quest_detail`, `quest_complete_immediate` and `quest_complete_delayed`). The four sessions split into
exactly two groups: the two existing-M6 sessions share one vector, and the two new sessions share its exact inverse.
`r5` is the **only** sub-field that ever differs, and only quest 792 is affected (of 51 quest-items seen in two or more
sessions, 4 differ, all on 792). That pattern is consistent with a per-character attribute, and the sub-field order
matches Blizzard's documented `GetQuestItemInfo` returns (`name, texture, numItems, quality, isUsable, itemID`), which
would make `r5` a usability flag. **That is a general-API-knowledge hypothesis, unverified on Forever**, so this conflict
is **not** declared safe. The data does not identify which characters the sessions belong to.

**Progress text (`2/8` → `6/8`).** No instance exists in the pending export. The only `quest_progress` captures are 815
(once) and 96825 (twice, both `2/8`); M6.4 classes both quests `state_change`. The mechanism was confirmed
synthetically: `2/8` then `6/8` at the **same** checkpoint classifies as `genuine_conflict`; the same values at different
checkpoints classify as `state_change`. It can occur in **future** exports but not in this one.

**Could a conflict affect guide-readiness or evidence correctness?**

- **Guide-readiness: no.** The locked rule reads only M6.2's per-field tier, which a conflict never changes. Verified:
  the four quests' required-field tiers are unchanged and the guide-ready set only grows.
- **Evidence correctness: not the evidence, but the value M6 would display.** Every captured value is retained. However,
  the guide dataset exposes M6.2's *chosen* value, and the choice has two effects:
  - **Blank names displayed.** The existing M6 displays a blank item name for 1 quest; ingestion raises that to 11
    (ten newly). For **3** of them (815, 1195, 96825) a *named* capture exists but is not the one displayed: for 815 and
    96825 because `quest_progress` is absent from M6.2's display-priority list and ranks last, for 1195 because a later
    blank capture at the same checkpoint wins the tie. The other 7 (808, 817, 826, 913, 97223, 97225, 97538) were only
    ever captured blank.
  - **Label change.** 789, 792, 913 and 1195 would carry `classification: genuine_conflict` in the guide dataset, which a
    consumer may read as a data-quality problem.

## 8. Idempotency findings (in memory only)

| Question | Finding |
|---|---|
| Does ingestion add only genuinely new observations? | The import re-reads the whole file, but all **3,200** existing assertion rows are reproduced **exactly** (same assertion ID, entity, field, value hash, locator and method) as the first rows of the pending import. All **635** new rows come from the 498 additional observations. |
| Does it create duplicate assertions? | No row collides on the dedup key (0). Of the 635 new rows, 356 add a genuinely new (entity, field, value) and 279 are repeat captures of a value already held. Importing the pending file a second time adds 0 (3,835 ignored). |
| Does it create new conflicts? | Yes: M6.4 `genuine_conflict` 2 → 6 (Section 7). `ambiguous_difference` stays 0. |
| Does it change guide-readiness? | 84 → 96 (+12). None lost; no field's `evidence_state` regresses. The 12: six pool candidates, 794, and five non-pool quests. Blockers: `title` 8→25, `quest_level` 8→25, `objectives` 36→42. |
| Does it change coverage counts? | Quests 121 → 153, NPCs 96 → 118, per-field counts in Section 2. |

M6.4's classification across all quest-fields:

| M6.4 classification (over all quest-fields) | Existing M6 | If ingested |
|---|---:|---:|
| `genuine_conflict` | 2 | 6 |
| `no_evidence` | 317 | 472 |
| `none` | 435 | 465 |
| `position_variance` | 47 | 60 |
| `single_observation` | 353 | 478 |
| `state_change` | 177 | 202 |

## 9. Exact proposed M6 mutation boundary

The routine refresh is: replace the canonical input export, then run `coverage.py`, `evidence_report.py` and
`guide_data.py`. The rehearsal shows **exactly four files change**:

| File (under `m6-dataset-baseline/out/`) | Action | Bytes now → after |
|---|---|---:|
| `latest_export_ForeverRecorder.lua` | **replaced** by the pending export (SHA-256 `723dac899c56b1cfd884f07670f3ecd8aa77dde1627c87529c525e5103bea39a`) | 3,200,963 → 3,848,772 |
| `m6_coverage.json` | **regenerated** | 2,312,541 → 2,869,530 |
| `m6_evidence_report.json` | **regenerated** | 656,193 → 822,334 |
| `m6_guide_dataset.json` | **regenerated** | 772,388 → 959,359 |

**Unchanged by design (verified in the rehearsal):** `m6_collection_runs.json`, `coverage_snapshots/*` (both Run-001
snapshots), the M6 scripts, and `inventory.json`.

- **`inventory.json` must not be regenerated.** It is a stale M6.1 artifact: it still reports 1,662 observations and 7 sessions
  against the 2,510 observations M6 reads today, so it has not been refreshed since M6.1. `inventory.py` hard-codes six "recorder" session IDs and reports **every other session as
  "pre-existing / Lab-attributed"**, so rerunning it would mislabel all recorder sessions added since.
- **No CollectionRun is created or associated.** The new sessions stay unassociated, so their evidence carries
  `collection_runs: []`.
- **M6's hand-written reports** (`docs/M6_*.md`) are dated historical records, not pipeline output, and are not
  regenerated.
- **Optional new file, a decision (D5):** an archive copy of the prior export and three prior outputs (about 7 MB)
  for rollback, since the project is not under git.

**Downstream locked artifacts that encode today's M6 state.** M6's own 62 tests pass on the ingested copy. These would
newly fail or go stale:

| Locked artifact / test | Effect if ingested | Basis |
|---|---|---|
| M7.4 `test_completeness_counts_only_cover_att_only_population` | **newly fails**: ATT-only 1,523 → **1,502** (19 pool + 2 unqualified leave the set) | simulated in-process |
| M7.4 `test_no_collection_run_is_created_in_the_m6_registry` | already failing (stale `len == 1`); unchanged | known since M7.5 |
| M7.4 `proposed_targets.json` | remains a valid historical snapshot; a regeneration would give 1,083 qualified and read 794 as `confirmed` | simulated |
| M7.6 `test_m6_outputs_unchanged` | **newly fails**: pins the three current M6 output hashes | hash comparison |
| M7.8 `test_protected_snapshot_matches_current_state`, `test_cli_smoke_…`, `test_real_export_reproduces_…` | **newly fail**: they encode the pre-ingestion snapshot and the 121/84/2,510 baseline | by construction, not simulated |
| M7.8 report and JSON | remain a valid record of the *pre-ingestion* state | static |
| M4 unit, ATT integration, recorder Lua, M7.5 | unaffected: none depends on the *content* of the regenerated files (M7.5 reads only the unchanged registry and compares M6 files before/after itself) | reasoning |

None of these locked files may be edited to make them pass; their handling is decision D6.

**Determinism.** Two of the three regenerated outputs are byte-stable across processes: `m6_evidence_report.json` and
`m6_guide_dataset.json`. `m6_coverage.json` is **not**: the only source is the documented unsorted set-to-list ordering
inside `conflicts[*].distinct_values`, and the conflict *set* is identical every time.

## 10. Ingestion safety assessment

**The existing path can accept this export as-is.** Evidence: the three refresh scripts ran cleanly on the ingested copy;
M6's 62 tests pass; every existing assertion row is reproduced exactly; no guide-ready quest or field state regresses;
the import is idempotent; nothing needed a code, importer, schema or classifier change.

Ingestion is **all-or-nothing at file granularity**. It cannot exclude the declared test sessions (907, 913, part of
815) or the 11 not-in-ATT quests; doing so would require a procedure change, which is out of scope.

Documented conditions, none blocking:

1. The four-file boundary above, with `inventory.json` left alone.
2. The display-layer caveats in Section 7, the objective-less quests, and 96604's empty placeholders.
3. 792's `r5` remains unverified.
4. The downstream locked tests above will change state.

**Exact commands for later (do not run in M7.9 review):**

```
# (first record the pre-ingestion hashes: Section 11, criterion 2)
cp <pending export> m6-dataset-baseline/out/latest_export_ForeverRecorder.lua   # the ONLY input change
cd m6-dataset-baseline/scripts
python3 coverage.py
python3 evidence_report.py
python3 guide_data.py
# do NOT run inventory.py or collection_runs.py
```

## 11. Acceptance criteria (for the eventual refresh, if approved)

1. **Gate:** no mutation until the operator resolves Section 13 in writing.
2. **Pre-state recorded:** a hash snapshot of every protected file, including M6 outputs, before any change.
3. **Boundary:** only the four files above (plus the archive, if D5 approves) change. Every other protected file,
   including `m6_collection_runs.json` (`60b713f2…`), `inventory.json`, both coverage snapshots, the M6 scripts, the
   recorder, M4/ATT code, `sources.toml`, `LICENSING.md` and the M7.7 17-file manifest, is byte-identical.
4. **Input identity:** the installed export has SHA-256 `723dac89…`, 3,008 observations, and its first 2,510 match the
   prior export.
5. **Semantic results:** 153 quests, 118 NPCs, 96 guide-ready (+12, none lost), 19 candidates gaining evidence (6
   guide-ready), 794's six fields resolved, M6.4 `genuine_conflict` exactly {4402×2, 789, 792, 913, 1195}, ambiguous 0.
6. **Assertion-level:** the prior 3,200 rows reproduce exactly; 635 new rows; 0 dedup-key collisions.
7. **Reproducibility:** `m6_evidence_report.json` and `m6_guide_dataset.json` are byte-identical across two
   regeneration processes; `m6_coverage.json` is compared with conflict lists canonicalized.
8. **Rehearsal parity:** the real regenerated outputs equal the rehearsal outputs (byte-identical for the two stable
   files, semantically for coverage).
9. **Tests:** M6 62/62; all other suites unchanged except the *enumerated* expected failures in Section 9, each recorded
   rather than silently fixed.
10. **No CollectionRun** is created or modified.

## 12. Explicit exclusions

Modifying M6 or ingesting the pending export during M7.9 review; changing CollectionRuns or creating any; modifying the
recorder, the M4 importer, ATT ingestion, or the evidence schema; changing the M6.4 classifier or M6.2 display
priority; redesigning guide readiness (including objective-less or placeholder-objective quests); fixing the 913
issue; `QUEST_ACCEPTED` or any new recorder hook; new sources; licensing changes; regenerating `inventory.json`;
editing locked M7.3–M7.8 artifacts or tests; starting M8 or another collection phase.

## 13. Unresolved questions (decisions needed)

- **D1. All-or-nothing ingestion.** Accept all 498 additional observations, including evidence from declared test
  sessions (907, 913, part of 815) and quests outside the pool?
- **D2. Quest 792 (`r5`).** Accept the conflict label as-is, or hold ingestion until `r5`'s meaning is checked on the
  real client? Its semantics remain unverified.
- **D3. Display-layer caveats.** Accept, as known and documented, blank-name displays for 815, 1195 and 96825 (named
  capture exists) and 7 others, the `0/N` convention, 96604's empty placeholders, and 805/823/1517 staying partial?
  M6.2 and M6.6 are frozen, so a fix would need a separate milestone.
- **D4. `inventory.json`.** Confirm it stays a stale M6.1 artifact and is not regenerated.
- **D5. Rollback.** Archive the prior export and three prior outputs inside M6's `out/` (adds four files), or rely on
  hashes alone?
- **D6. Locked tests.** Accept the enumerated new failures (M7.4 ×1, M7.6 ×1, M7.8 ×3) as documented consequences, or
  plan a separate approved change to make those tests state-independent?
- **D7. Test-session declaration.** Confirm the seven declared session IDs (`0df16c83d4799a`, `2f912201625e3a`,
  `3a36d86e1d2070`, `7e6f72f9ca76b0`, `a736b9052541c3`, `bcb81b2ecb2b42`, `beba6db0129d72`). The "16 ordinary" figure
  stays operator-declared either way.

Not resolved by this review: what `r5` means on Forever; whether future exports will contain same-checkpoint
progress-text differences (mechanism confirmed, no instance yet); and the cadence for ingesting later exports, since
each ingestion changes the baseline the M7.8 accounting compares against.
