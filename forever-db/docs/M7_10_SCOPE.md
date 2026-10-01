# M7.10: Post-Ingestion Coverage & Guide Gap Analysis — Scope Reconstruction

**Status: scope reconstruction only. No implementation performed.** Nothing was regenerated, modified, or created except
this document. All figures below were read or computed from the canonical M6 outputs, the M6.4 evidence report, the
locked M7.3/M7.4 artifacts, and an in-memory, read-only ATT import; none was assumed from the M7.10 request text.

**Reconstruction date:** 2026-09-28.

## 1. Current M6 baseline (verified against the files, not assumed)

| | Value | Source |
|---|---:|---|
| Canonical export | `723dac89…` | `m6-dataset-baseline/out/latest_export_ForeverRecorder.lua` |
| Observations | 3,008 (31 sessions) | same |
| Observed quests | 153 | `m6_coverage.json` |
| NPCs | 118 | same |
| Guide-ready quests | 96 | `m6_guide_dataset.json` |
| Insufficient-evidence quests | 57 | same |
| Guide-readiness rule | requires `title`, `quest_level`, `objectives` all `confirmed` | same |
| M7.4 qualified candidate pool | 1,102 | `research/m7_4/proposed_targets.json` |
| — with any M6 evidence | 19 (13 partial, 6 guide-ready) | derived below |
| — unobserved | 1,083 | derived below |
| M6.4 `genuine_conflict` | 6: (789,objectives) (792,choice_items) (913,guaranteed_items) (1195,objectives) (4402,guaranteed_items) (4402,objectives) | `m6_evidence_report.json` |
| M6.4 `ambiguous_difference` | 0 | same |
| CollectionRun registry | 11 (1 `active`, 10 `planned`) | `m6_collection_runs.json` |

Every number in the M7.10 request matches what the repository actually says. No discrepancy was found.

## 2. Method / evidence sources inspected

Read-only throughout. No canonical output was regenerated; where a fresh recomputation was needed for a cross-check
(Section 10 of `M7_9_COMPLETION_REPORT.md`'s method), it was run in a separate process and never written back.

- `m6-dataset-baseline/out/{m6_coverage,m6_evidence_report,m6_guide_dataset,m6_collection_runs}.json` — read directly.
- `forever-db/research/m7_3/coverage_gap_analysis.json`, `forever-db/research/m7_4/proposed_targets.json` — read directly
  (locked artifacts).
- `forever-db/research/m7_4/select_collection_targets.py` — its existing, already-tested `run_att_import_with_values()`
  helper was called **in memory** to obtain ATT field values for every quest ID; nothing was written and no new ATT
  parsing logic was added.
- `forever-db/data/raw/att-head/.contrib/.db/forever/.config/.wago/UiMap*.csv` — the client zone-name table, read
  locally (already vendored; licensing status unchanged and still unresolved per `docs/LICENSING.md`).
- The M4 assertion layer, queried in memory via the existing importer, to see checkpoints and timestamps behind
  specific fields (`giver.npc`, `location.observed_player_position`, `money.harvest_observed`, etc.).
- Scratch code lived under `/tmp/m710/`, outside the project, and is not part of this deliverable.

## 3. The 96 guide-ready quests

**Level:** span levels 1–13, then 17, 18, 21, 25, 26. No guide-ready quest exists at 14, 15, 16, 19, 20, 22, 23 or 24.

**Zone** (map of the interaction position at the checkpoint M6 selected as representative; 1 quest, 3369, has positions
recorded in more than one map):

| Zone | Guide-ready quests |
|---|---:|
| Zephras Isle (2521) | 70 |
| Durotar (1411) | 18 |
| The Barrens (1413) | 4 |
| Thunder Bluff (1456) | 2 |
| Kalimdor (1414, unresolved sub-zone) | 2 |

**Level × zone:**

| Level | Zephras Isle | Durotar | The Barrens | Thunder Bluff | Kalimdor | Total |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 2 | 0 | 0 | 0 | 3 |
| 2 | 4 | 2 | 0 | 0 | 0 | 6 |
| 3 | 2 | 2 | 0 | 0 | 0 | 4 |
| 4 | 3 | 5 | 0 | 0 | 0 | 8 |
| 5 | 2 | 3 | 0 | 0 | 0 | 5 |
| 6 | 9 | 3 | 0 | 0 | 0 | 12 |
| 7 | 4 | 0 | 0 | 0 | 0 | 4 |
| 8 | 6 | 1 | 0 | 0 | 0 | 7 |
| 9 | 12 | 0 | 0 | 0 | 0 | 12 |
| 10 | 3 | 0 | 0 | 0 | 0 | 3 |
| 11 | 13 | 0 | 0 | 0 | 0 | 13 |
| 12 | 7 | 0 | 0 | 0 | 0 | 7 |
| 13 | 4 | 0 | 0 | 0 | 0 | 4 |
| 17 | 0 | 0 | 0 | 0 | 1 | 1 |
| 18 | 0 | 0 | 3 | 1 | 0 | 4 |
| 21 | 0 | 0 | 0 | 0 | 1 | 1 |
| 25 | 0 | 0 | 0 | 1 | 0 | 1 |
| 26 | 0 | 0 | 1 | 0 | 0 | 1 |

**Which screen supplied the three required fields:** 94 of 96 from a turn-in screen (`quest_complete_immediate` or
`quest_complete_delayed`); 2 (815, 96825) from the `quest_progress` screen only, with no turn-in ever captured for
either.

**Other fields present** (evidence_state ≠ `unresolved`): `giver` 96/96, `interaction_position` 96/96, `xp` 94/96,
`money` 94/96, `completion` 94/96, `reputation` 71/96, `gossip_availability_sightings` 67/96, `choice_items` 36/96,
`guaranteed_items` 17/96, `prerequisites` **0/96** (the field exists in the schema and has never been observed for any
quest in M6).

**Objective text as M6 displays it:** 87 of 96 show a named counter or text; 2 show a counter with a blank item name
(the documented pattern); 7 show only an empty placeholder list, i.e. the objectives field is `confirmed` because it
was observed as empty, not because it describes anything. 45 of 96 display a `0/`-style counter (the post-turn-in
reset state, not the character's actual progress at capture).

**Giver evidence side:** 85 of 96 have a giver capture on both the offer screen and a return/turn-in-type screen; 11
have it only on the return side (never seen being offered).

**Provenance:** 8 of 96 include a Run-001 (CollectionRun) session in their required-field evidence; the other 88 are
supported entirely by passive, non-run sessions.

**ATT membership:** only 19 of 96 guide-ready quests are known to ATT at all (77 are not); of the 77 not in ATT, 71 are
Forever-numbered (id ≥ 90,000) and sit at Zephras Isle, so most of the guide-ready set describes content ATT does not
list.

**Conflicts:** 3 of 96 (789, 792, 4402) carry an M6.4 `genuine_conflict`; none of the four conflicting fields
(`objectives` for 789, `choice_items` for 792, `guaranteed_items`/`objectives` for 4402) is a readiness-required field,
so none affects the 96 count.

## 4. The 19 newly evidenced candidates

| Quest | Status | Reason | Conflict |
|---:|---|---|---|
| 784 | partial/core | seen at offer screen only; title/level not yet in log | - |
| 786 | partial/noncore | offer screen only; no objectives, no title/level | - |
| 805 | partial/core | title/level captured; recorder saw an empty objectives list | - |
| 806 | partial/noncore | offer screen only; no objectives, no title/level | - |
| 808 | partial/core | seen at offer screen only; title/level not yet in log | - |
| 815 | guide-ready | title/level from progress screen; objectives captured | - |
| 817 | partial/core | seen at offer screen only; title/level not yet in log | - |
| 818 | partial/noncore | offer screen only; no objectives, no title/level | - |
| 823 | partial/core | title/level captured; recorder saw an empty objectives list | - |
| 826 | partial/core | seen at offer screen only; title/level not yet in log | - |
| 837 | partial/core | seen at offer screen only; title/level not yet in log | - |
| 907 | guide-ready | title/level from turn-in; objectives captured | - |
| 913 | partial/core | seen at offer screen only; title/level not yet in log | yes |
| 1463 | partial/noncore | turn-in captured but title/level lookup failed | - |
| 1516 | guide-ready | title/level from turn-in; objectives captured | - |
| 1517 | partial/core | title/level captured; recorder saw an empty objectives list | - |
| 1518 | guide-ready | title/level from turn-in; objectives captured | - |
| 5441 | guide-ready | title/level from turn-in; objectives captured | - |
| 6394 | guide-ready | title/level from turn-in; objectives captured | - |

Route-relevant evidence present across the 19 (each row independent, not cumulative): identity (title+level) 9/19,
objectives 12/19, offer-side NPC+position 17/19, return-side NPC+position 10/19, turn-in confirmation (`xp` resolved)
9/19, prerequisites 0/19. Four (1516, 1518, 5441, 6394) have all of identity, objectives, both NPC sides, and a
confirmed turn-in. Only 913 carries a conflict (`guaranteed_items`, the documented blank-name pattern; it does not
affect its `partial` status, since `guaranteed_items` is not a required field).

**Why the 6 crossed the readiness threshold:** 5 (907, 1516, 1518, 5441, 6394) had a captured turn-in screen that
supplied title, level and objectives together. The sixth, 815, had no turn-in captured at all; its title, level and
objectives came entirely from the `quest_progress` checkpoint added in M7.7. It is the only guide-ready quest in the
project whose readiness depends on that checkpoint.

## 5. The 1,083 remaining unobserved candidates

All fields below are ATT source-derived and unverified; none was promoted to observed evidence.

**Consistency check (not verification):** where both an ATT `lvl` value and an observed `quest_level` exist for the
same quest (10 quests), they agree exactly in 3, and differ by 1–8 levels in the rest — ATT's `lvl` is a source hint,
not a reliable predictor of the observed value.

**ATT level form:** plain integer 776, no ATT level at all 289, level-range list (a Cataclysm-style squish pair) 14,
unresolved expression (e.g. `lvlsquish(...)`, not decoded) 4.

| ATT level band (source-derived, unverified) | Candidate count |
|---|---:|
| 1-10 | 257 |
| 11-20 | 169 |
| 21-30 | 167 |
| 31-40 | 115 |
| 41-50 | 30 |
| 51-60 | 38 |
| No ATT level at all | 289 |

**ATT zone (first listed coordinate; 52 candidates list coordinates in more than one map, so the "first" zone
under-represents true spread):**

| ATT first-listed zone (source-derived) | Candidate count |
|---|---:|
| MAP.IRONFORGE | 111 |
| MAP.THE_BARRENS | 109 |
| MAP.STRANGLETHORN_VALE | 105 |
| MAP.STORMWIND_CITY | 102 |
| MAP.ELWYNN_FOREST | 87 |
| MAP.ORGRIMMAR | 61 |
| MAP.TELDRASSIL | 55 |
| MAP.MULGORE | 50 |
| MAP.DUN_MOROGH | 49 |
| MAP.ARATHI_HIGHLANDS | 49 |
| MAP.DUROTAR | 42 |
| MAP.WETLANDS | 33 |
| (12 more zones with fewer candidates each) | — |
| No ATT coordinate at all | 0 |

- 248 of 1,083 list a coordinate in one of the six maps where M6 already has observed quest evidence (1411–1414, 1456,
  2521); only **1** lists a coordinate in map 2521 itself, where 70 of the 96 guide-ready quests sit.
- 20 of 1,083 have an ATT giver NPC ID that M6 has already observed interacting with a player (so the *NPC* is known,
  even though the *quest* is not).
- 604 of 1,083 carry an ATT `sourceQuest`/`altQuest` hint (M7.3's "prerequisites" category). Most (595 reference
  instances) point at another unobserved pool candidate; 15 candidates have at least one hint pointing at a quest M6
  has already observed, and 11 of those point specifically at a quest that is already guide-ready.
- 448 of 1,083 carry an ATT objective hint (`objective.att`); this names item/NPC/object target IDs, not text, and was
  not decoded further here.
- Restriction fields, as ATT itself represents them: 403 Alliance-only, 257 Horde-only, 121 in another form (e.g.
  faction change flags), 273 with neither a race nor a class restriction entry.
- Flags: `repeatable` 118, `isBreadcrumb` 93, `isYearly` 42, `isMonthly` 1.
- The 21 unobserved Forever-numbered (id ≥ 90,000) candidates all list ATT coordinates in Elwynn Forest or Dun Morogh
  (Alliance starting zones), not in any zone M6 has touched.

**The 421 ATT-only quests that never qualified for the M7.4 pool:** 258 have no ATT giver NPC recorded, 74 have neither
a giver nor coordinates, 89 have coordinates but no giver, and 24 are bare stubs with zero decoded fields. Two of the
421 (2161, 3084) have since been observed anyway, through evidence not keyed on the M7.4 pool logic, and are already
counted among M6's 153.

**Coordinate sanity check, for what it's worth:** among the 35 observed quests that are also known to ATT, every one
has an ATT coordinate in the same map as an observed player interaction position, with a median offset of 0.0006 map
fraction (all within 0.02). This says only that ATT's own coordinates are internally consistent with what has been
observed near them — it says nothing about the 1,083 quests where no observation exists to check against.

## 6. Level/zone coverage structure

- Guide-ready coverage is concentrated at levels 1–13 (85 of 96 quests) and thins sharply after that: 5 quests at
  16–20, 2 at 21–25, 1 at 26, and none above 26.
- Within levels 1–13, 70 of the quests sit at a single zone (Zephras Isle, map 2521); the only other zone with more
  than 2 guide-ready quests in that range is Durotar (18 quests, levels 1–8).
- No guide-ready quest exists for 8 individual levels between 1 and 26 (14, 15, 16, 19, 20, 22, 23, 24).
- The Barrens, Thunder Bluff and Kalimdor each have 2–4 guide-ready quests, all above level 17.
- Sessions with any positioned NPC interaction touch up to 4 distinct maps in one login (2 sessions), but 25 of 31
  sessions never leave a single map. The recorded map-to-map transitions (Moonglade↔Thunder Bluff, Thunder
  Bluff↔Barrens, Barrens↔Kalimdor, Zephras Isle→Mulgore→Thunder Bluff, Thunder Bluff→Stranglethorn Vale→Barrens,
  Durotar↔Barrens) describe a handful of individual play sessions, not a leveling path; nothing links them to
  quest completion order.
- No field in M6 records which zone precedes which in a leveling sense; this describes the *evidence that exists*, not
  a route.

## 7. Evidence gaps vs. guide-design gaps

| Category | What was found |
|---|---|
| **A. Evidence gap** | The dominant category. 1,083 of 1,102 qualified candidates have zero M6 observations. Within the 153 observed quests, 32 have title+level but an empty captured objectives list, and 1 (1463) has a turn-in but no resolved title. |
| **B. Source-metadata gap** | 421 ATT-only quests lack enough ATT fields (giver and/or coordinates) to even qualify as a collection target. 289 of the 1,083 unobserved candidates have no ATT level at all. |
| **C. Guide-readiness gap** | 32 of the 57 insufficient-evidence quests have title and level `confirmed` but fail only on `objectives`, and in every one of those 32 the recorder observed an *empty* objectives list — the rule's requirement is met by "observed, empty" nowhere; readiness treats an empty list the same as no observation. This is a fact about the current rule, not a recommendation to change it. |
| **D. Route-structure gap** | `prerequisites` is 0/153 resolved. No character identity, no NPC world coordinates, and no usable turn-in ordering exist anywhere in M6. Nothing currently links one guide-ready quest to the next; 96 individually guide-ready quests do not by themselves establish a route. |
| **E. Unknown / cannot determine** | Whether the 604 ATT prerequisite hints are directionally correct (source vs. target) is not established in the repository. Whether a quest with an ATT class/race restriction is actually restricted on Forever is unverified (this milestone's own instruction not to reinterpret ATT fields applies). Whether the 289 candidates with no ATT level can be leveled by any other means is not determinable from what's on disk. |

## 8. Conflict / quality review

| Conflict | Field | Distinct values | Affects readiness? |
|---|---|---:|---|
| 789 | `objectives` | 3 | No (not required for a quest already readiness-independent of `objectives` conflicts; 789 is guide-ready) |
| 792 | `choice_items` | 6 (see below) | No — `choice_items` is not a required field |
| 913 | `guaranteed_items` | 2 | No — 913 is `partial`, blocked by title/level, unrelated to this field |
| 1195 | `objectives` | 2 | No — 1195 is `partial`, blocked by title/level |
| 4402 | `objectives` / `guaranteed_items` | 3 / 4 | No — pre-existing, unchanged since before M7.9 |

**Quest 792 `r5`.** The M7.9.1 conclusion is preserved unchanged: `r5` is the fifth positional return of
`GetQuestItemInfo`, its meaning is unconfirmed on Forever, both observed values (16 rows `FTTF`, 3 rows `TFFT`) remain
in M6, and the conflict is not suppressed. It has **no effect on guide construction**: 792 is guide-ready regardless
(its required fields are all `confirmed`), and nothing downstream currently reads `choice_items` for route purposes.
It is not reinterpreted or treated as a quest attribute here.

**Other quality issues that materially affect guide construction** (cosmetic issues, such as the blank-item-name
display pattern already documented in M7.9, are not repeated as blockers here):

- **32 "observed-empty" objectives quests** (Section 7C) are the largest single quality issue by count — more than
  three times the size of any conflict category.
- **2 guide-ready quests (815, 96825) have no turn-in evidence at all** — their inclusion rests entirely on the
  `quest_progress` checkpoint, a single observation path added in M7.7.
- **1 quest (1463) has a turn-in but a failed title/level lookup** at that exact moment — the pre-existing, unresolved
  `QUEST_DETAIL`/log-lookup issue from M7.6/M7.7, now visible on a second quest.
- **11 of 96 guide-ready quests were never seen being offered** — the guide can state what to do at completion but not
  what the quest asks for as an in-progress player would see it stated at pickup.

## 9. Major bottlenecks

1. **Evidence volume, not evidence quality, is the dominant bottleneck.**
   - Evidence: 1,083 of 1,102 qualified candidates (98%) have zero observations; 96 of 153 observed quests (63%) are
     guide-ready — a good conversion rate once a quest is seen at all.
   - Dataset/field: `m6_coverage.json` candidate-pool status counts.
   - Affects: data completeness, and therefore everything downstream.
   - Solvable without new data: **no.** This is the one bottleneck M7.10 cannot resolve by re-reading what exists.

2. **No route-ordering information exists in the dataset at all.**
   - Evidence: `prerequisites` 0/153 resolved; no character identity; no NPC world coordinates; ATT `sourceQuest`/
     `altQuest` hints are source-derived and only touch 15 unobserved candidates plus 15 guide-ready quests project-wide.
   - Dataset/field: `prerequisites` field, `location.observed_player_position` (records only the player, never the NPC).
   - Affects: route ordering, quest progression.
   - Solvable without new data: **no** for prerequisites and NPC positions (nothing on disk supplies them). **Partially**
     for a coarse ordering: level and zone, both already `confirmed`/`observed` fields, could sequence the *existing* 96
     quests without needing anything new — but see Section 6: coverage is too concentrated in one zone and has 8 gap
     levels to make a full route from these 96 alone.

3. **Guide-ready coverage is concentrated in one zone and one level band.**
   - Evidence: 70 of 96 (73%) sit in a single zone (Zephras Isle) and 85 of 96 (89%) sit at levels 1–13; nothing exists
     above level 26.
   - Dataset/field: `interaction_position.ui_map_id`, `quest_level`, both `confirmed`/`observed`.
   - Affects: geographic navigation, quest progression, data completeness (by implication).
   - Solvable without new data: **no** — the concentration reflects which zones the passive sessions actually visited.

4. **A specific, quantifiable class of "confirmed-but-empty" evidence blocks otherwise-close quests.**
   - Evidence: 32 quests have title and level `confirmed` and an *observed, empty* objectives list — the single
     largest reason quests fail readiness after title/level is already known.
   - Dataset/field: `objectives` field, guide-readiness rule (`m6_guide_dataset.json`'s required-field check).
   - Affects: guide-readiness.
   - Solvable without new data: **partially** — the underlying evidence (an empty list) already exists on disk; whether
     to treat "observed empty" differently from "never observed" is a guide-readiness *rule* question, not a data
     question, and changing it was explicitly out of scope for this milestone.

5. **ATT's 1,102-quest candidate pool substantially undercounts what the repository could plausibly connect.**
   - Evidence: 421 ATT-only quests were excluded from the pool for lacking a giver and/or coordinates; 20 unobserved
     candidates already have an ATT giver NPC that M6 has observed elsewhere.
   - Dataset/field: the M7.4 pool-qualification logic (locked), ATT `giver.npc`.
   - Affects: data completeness (which quests are even tracked as candidates).
   - Solvable without new data: **not within M7.4's existing rule**, but this is a description of that rule's boundary,
     not a defect — nothing here indicates the rule should change.

**"More quests" is not automatically the biggest bottleneck for the *guide-readiness* count** (item 4 and item 1's
"good conversion rate" observation both show meaningful gains are available without new data), but it **is** the
bottleneck for building an actual multi-zone leveling route (items 2 and 3), which needs breadth this dataset does not
have regardless of how the existing evidence is read.

## 10. Proposed M7.10 scope

M7.10 should remain **entirely analytical and read-only**. No implementation is proposed for this milestone.

The reconstruction above already answers M7.10's stated goal ("what can we build, and where are the gaps") using only
existing evidence. The one concrete, low-risk follow-on this analysis surfaces — clarifying how "observed empty"
objectives should be treated by the readiness rule (Section 7C, bottleneck 4) — is a **rule change**, which this
milestone's own constraints (Section "Do NOT... change guide-readiness rules") place out of scope. It is named here as
a candidate for a future, explicitly-scoped milestone, not something M7.10 should do.

If the operator wants a tangible M7.10 deliverable beyond this document, the smallest useful one would be a **static,
read-only report generator** that reproduces Sections 3–9 above from the canonical files on demand (so this analysis
does not go stale the next time M6 changes), with no effect on any generated M6 output. That is described only as an
option; it is not implemented here.

## 11. Explicit out-of-scope items

- New recorder hooks or addon changes.
- Any manual quest collection or new CollectionRuns.
- New external data sources (Wowhead, Questie/QuestieDB, ForeverGuide, RestedXP, or any other database).
- Reinterpreting or decoding unconfirmed ATT fields (`lvl` expressions, `objective.att` target semantics, restriction
  flags) beyond what the repository already establishes.
- Guide-route selection or optimization.
- Changing the guide-readiness rule (including the "observed empty" question raised in Section 7C/9).
- Resolving Quest 792 `r5` without new evidence, or treating it as a settled quest attribute.
- Rewriting historical milestone tests or reports (M7.4, M7.6, M7.8, or the M7.9/M7.9.1 documents).
- Regenerating any canonical M6 output.

## 12. Expected files to change during implementation

**None**, for the scope as proposed (entirely analytical). If the optional read-only report generator in Section 10 is
later approved, it would add exactly one new script and one new document under `forever-db/research/m7_10/` and
`forever-db/docs/`, with no changes to any existing file — but that approval and that implementation are both future
work, not this turn.

## 13. Acceptance criteria (for a future implementation, if one is approved)

- Any M7.10 script is read-only: it must not write to `m6-dataset-baseline/out/`, `forever-db/src/`, the recorder, or
  any locked research artifact.
- Any generated report must state its evidence source per figure (observed vs. ATT source-derived vs. derived-and-
  computed), following the labeling convention already used above.
- No ATT field may be presented without its `att_`/source-derived label.
- A protected-file hash check (as used in M7.8/M7.9) must show zero changes to any file outside the new report's own
  output.

## 14. Risks / unknowns

- The zone-concentration finding (Section 6) reflects which sessions happened to be recorded, not a property of the
  game world; a different set of passive sessions could show an entirely different concentration.
- The ATT-vs-observed level and coordinate consistency checks (Section 5) used only the quests where both already
  exist, a small and possibly unrepresentative sample (10 and 35 quests respectively).
- Whether the 604 ATT prerequisite hints are usable for ordering depends on decoding their direction, which this
  milestone did not attempt (would count as reinterpreting an unconfirmed field).
- The "observed empty" objectives pattern (32 quests) may or may not represent a genuine game-side placeholder versus
  a recorder timing issue; no evidence was found in this reconnaissance to distinguish the two.

## 15. Recommended next decision for the operator

Decide whether to:
(a) leave M7.10 as this analytical document with no further work,
(b) approve the optional read-only report-generator scope described in Section 10, or
(c) open a separate, explicitly-scoped milestone to address the "observed empty" objectives readiness question
(Section 7C/9 item 4), which is the one finding here with a plausible near-term readiness-count improvement that needs
no new data collection.

None of these decisions was made in this turn.
