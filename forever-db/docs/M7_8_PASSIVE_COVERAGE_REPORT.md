# M7.8 Passive Coverage Accounting Report

**Accounting only. M6 was NOT modified and nothing was ingested.** Every figure labeled HYPOTHETICAL / PENDING was computed in memory from an export that has not been ingested into M6. Implements the approved `docs/M7_8_SCOPE.md`. Report content hash: `eac8d3e74c4d8b6e10b5da3d79ddfbf59294181eb28982684b9194a603478840`.

## 1. Input / export identity

| Role | Path used | Observations | SHA-256 |
|---|---|---:|---|
| Baseline: M6's canonical input (`coverage.EXPORT_PATH`) | `/mnt/user-data/outputs/m6-dataset-baseline/out/latest_export_ForeverRecorder.lua` | 2,510 | `b5c35bec723664375f0fcd6a3d0cc96f3b7ac66794ef9c0426f6451e9a18663d` |
| Pending: passed explicitly, **not ingested** | `/home/claude/m5_real/ForeverRecorder_m77_test2.lua` | 3,008 | `723dac899c56b1cfd884f07670f3ecd8aa77dde1627c87529c525e5103bea39a` |
| Locked candidate list (M7.4) | `research/m7_4/proposed_targets.json` | 1,102 candidates | `b7fc38de6993836e51f3b8f437238d0cd0d833005e8639a54ad8ac80a6c6a50b` |
| Locked ATT/M6 comparison (M7.3) | `research/m7_3/coverage_gap_analysis.json` | - | `10c8c1aec44bccddc2f8da56727f5e029bf00eaebf4c0043ef5ecb70d65d36d5` |

**Input convention.** No new default was created. The baseline is M6's own canonical input path. M6 has no canonical path for a *pending* export, so it is supplied explicitly (`--pending-export`, no default) and identified by SHA-256; the path above is informational and excluded from the content hash.

**Lineage:** the first 2,510 observations of the pending export are identical, observation for observation, to the baseline. The pending export therefore adds **498** observations.

## 2. Existing M6 baseline

- Quests observed: **121**; guide-ready: **84**.
- Candidates (of 1,102) already present in M6: **0**.
- Persisted M6 outputs (`m6_coverage.json`, `m6_guide_dataset.json`) vs this recomputation: **consistent** (121 quests, 84 guide-ready persisted, 0 field-state mismatches).

## 3. New observations pending ingestion

**498** observations are in the pending export but not in M6's input.

| Checkpoint | Observations |
|---|---:|
| `GOSSIP_SHOW` | 94 |
| `QUEST_TURNED_IN` | 22 |
| `quest_complete_delayed` | 96 |
| `quest_complete_immediate` | 96 |
| `quest_detail` | 184 |
| `quest_progress` | 6 |

| Session | Observations | First | Last | Distinct quests | CollectionRuns |
|---|---:|---|---|---:|---|
| `0df16c83d4799a` | 12 | 2026-09-27 20:27:35 | 2026-09-27 20:27:45 | 2 | none |
| `2f912201625e3a` | 12 | 2026-09-25 05:32:26 | 2026-09-25 05:37:05 | 1 | none |
| `3a36d86e1d2070` | 2 | 2026-09-25 05:46:35 | 2026-09-25 05:46:35 | 0 | none |
| `3d2cdddf99fa10` | 295 | 2026-09-27 19:46:31 | 2026-09-27 20:10:52 | 31 | none |
| `538e3166c69d56` | 122 | 2026-09-27 18:37:19 | 2026-09-27 18:53:57 | 10 | none |
| `7e6f72f9ca76b0` | 2 | 2026-09-27 20:28:53 | 2026-09-27 20:28:53 | 0 | none |
| `a736b9052541c3` | 2 | 2026-09-27 00:09:06 | 2026-09-27 00:09:06 | 0 | none |
| `bcb81b2ecb2b42` | 16 | 2026-09-25 05:50:11 | 2026-09-25 05:54:28 | 2 | none |
| `beba6db0129d72` | 35 | 2026-09-26 23:27:15 | 2026-09-26 23:55:41 | 3 | none |

Quests that would newly appear in M6: **32** (att_only_unqualified: 2, candidate_pool: 19, not_in_att: 11).

Fields that would go from unresolved to resolved: `choice_items` 5, `completion` 14, `giver` 31, `gossip_availability_sightings` 13, `guaranteed_items` 11, `interaction_position` 31, `money` 14, `objectives` 26, `quest_level` 15, `reputation` 22, `title` 15, `xp` 14.

Existing M6 quests that would gain fields: 794 (`completion`), 794 (`money`), 794 (`objectives`), 794 (`quest_level`), 794 (`title`), 794 (`xp`), 1195 (`objectives`), 97538 (`objectives`). Fields that would regress: 0.

## 4. Candidate-pool coverage

| Status | Existing M6 | HYPOTHETICAL if ingested |
|---|---:|---:|
| candidate-only | 1,102 | 1,083 |
| partial | 0 | 13 |
| &nbsp;&nbsp;partial, some core field | 0 | 9 |
| &nbsp;&nbsp;partial, non-core only | 0 | 4 |
| &nbsp;&nbsp;(of which gossip-sighting only) | 0 | 0 |
| guide-ready | 0 | 6 |
| **Total** | **1,102** | **1,102** |

Candidates that would gain evidence: **19**, of which **6** would be guide-ready. **1,083** would remain unobserved. Status uses only M6.2 evidence states and the locked M6.6 readiness rule (`title`, `quest_level`, `objectives` all confirmed).

ATT candidate names below are **source-derived, not observed**; the observed title/level are pending M6-style evidence, kept in separate columns.

| Quest | ATT candidate name (source-derived) | Status if ingested | Observed title (pending) | Level | Provenance | Checkpoints |
|---:|---|---|---|---:|---|---|
| 784 | Vanquish the Betrayers | partial (core) | - | - | passive_only | quest_detail |
| 786 | Thwarting Kolkar Aggression | partial (noncore) | - | - | passive_only | quest_detail |
| 805 | Report to Sen'jin Village | partial (core) | Report to Sen'jin Village | 5 | passive_only | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail |
| 806 | Dark Storms | partial (noncore) | - | - | passive_only | quest_detail |
| 808 | Minshina's Skull | partial (core) | - | - | passive_only | quest_detail |
| 815 | Break a Few Eggs | guide_ready | Break a Few Eggs | 8 | passive_only | GOSSIP_SHOW, quest_detail, quest_progress |
| 817 | Practical Prey | partial (core) | - | - | passive_only | quest_detail |
| 818 | A Solvent Spirit | partial (noncore) | - | - | passive_only | quest_detail |
| 823 | Report to Orgnil | partial (core) | Report to Orgnil | 7 | passive_only | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail |
| 826 | Zalazane | partial (core) | - | - | passive_only | quest_detail |
| 837 | Encroachment | partial (core) | - | - | passive_only | quest_detail |
| 907 | Enraged Thunder Lizards | guide_ready | Enraged Thunder Lizards | 18 | passive_only | GOSSIP_SHOW, QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate |
| 913 | Cry of the Thunderhawk | partial (core) | - | - | passive_only | GOSSIP_SHOW, quest_detail |
| 1463 | Earth Sapta | partial (noncore) | - | - | passive_only | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate |
| 1516 | Call of Earth (1/3) | guide_ready | Call of Earth | 4 | passive_only | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail |
| 1517 | Call of Earth (2/3) | partial (core) | Call of Earth | 4 | passive_only | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail |
| 1518 | Call of Earth (3/3) | guide_ready | Call of Earth | 4 | passive_only | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail |
| 5441 | Lazy Peons | guide_ready | Lazy Peons | 4 | passive_only | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail |
| 6394 | Thazz'ril's Pick | guide_ready | Thazz'ril's Pick | 4 | passive_only | QUEST_TURNED_IN, quest_complete_delayed, quest_complete_immediate, quest_detail |

## 5. Passive vs CollectionRun provenance

Derived from explicit M6.3 session->CollectionRun associations only (evidence_report._load_session_to_run_map); never inferred. 'passive' therefore means 'not associated with any CollectionRun' -- bookkeeping, not intent.

Evidence considered: evidence from the ADDITIONAL observations. Newly covered candidates: **passive only 19**, run-associated only 0, mixed 0. No CollectionRun was created or modified.

**Operator-declared annotation (separate from the data-derived figures above).** Operator-declared, NOT derivable from recorded data: the recorder and the CollectionRun registry have no notion of a 'test' session. These IDs are declared on the command line; the counts below hold only under that declaration.

Declared test sessions: `0df16c83d4799a`, `2f912201625e3a`, `3a36d86e1d2070`, `7e6f72f9ca76b0`, `a736b9052541c3`, `bcb81b2ecb2b42`, `beba6db0129d72`.

Under that declaration: **16** candidates reached only outside the declared sessions, 1 in both, 2 only in declared sessions.

## 6. Hypothetical post-ingestion coverage

*HYPOTHETICAL / PENDING -- computed in memory from an export that has NOT been ingested into M6.*

| | Existing M6 | HYPOTHETICAL |
|---|---:|---:|
| Quests observed | 121 | 153 (+32) |
| Guide-ready quests | 84 | 96 (+12) |

Newly guide-ready by category: candidate_pool: 6, existing_m6_quest_upgraded: 1, other_new_quest: 5. Guide-ready quests lost: 0.

## 7. ATT restriction annotation

**source_derived_not_observed.** ATT/source-derived hints only. Only the PRESENCE of ATT race/class restriction fields is recorded; their numeric values were not decoded or interpreted, and a hint does NOT establish that a quest is unavailable to any character.

| Group | Candidates | Race hint present | Class hint present | Either |
|---|---:|---:|---:|---:|
| Whole pool | 1,102 | 800 | 254 | 829 |
| Newly covered (hypothetical) | 19 | 19 | 4 | 19 |
| Unobserved after ingest (hypothetical) | 1,083 | 781 | 250 | 810 |

ATT snapshot: `att-head` @ `8e25511677df4ea5c3d0322009eafc18f203ffd3`.

## 8. Conflict caveat

M6.4 classifier output, reported for context only. It never influences status or guide-readiness in this report, and the classifier was not modified.

- M6.4 `genuine_conflict` count: existing M6 **2**, HYPOTHETICAL **6**.
- Genuine conflicts involving a `quest_progress` capture: **0**.
- M6.4 treats more than one distinct value at the SAME checkpoint as a genuine_conflict. Objective text embeds live progress ('2/8' vs '6/8'), item names can be blank at first read, and some sub-fields differ between captures, so repeated passive captures can be flagged even when nothing is wrong. This does not affect guide-readiness. The classifier was NOT modified and no observation was normalized.

New conflicts the classifier would report if ingested (descriptive only):

| Quest | Field | Checkpoints | Distinct values | Objective texts (if objectives) |
|---:|---|---|---:|---|
| 789 | `objectives` | quest_complete_delayed, quest_complete_immediate, quest_detail | 3 | `0/10  `; `0/10 Scorpid Worker Tail`; `10/10 Scorpid Worker Tail` |
| 792 | `choice_items` | quest_complete_delayed, quest_complete_immediate, quest_detail | 6 | - |
| 913 | `guaranteed_items` | quest_detail | 2 | - |
| 1195 | `objectives` | quest_detail | 2 | `0/1  `; `0/1 Filled Etched Phial` |

## 9. M6 was NOT modified

**Verified.** 111 protected files (M6 outputs, registry and scripts; recorder; M4/ATT code; schemas; sources and licensing documents; M7.3-M7.7 artifacts) were hashed before and after this run and compared with the pre-run snapshot; **0 changed, 0 added, 0 removed**. No CollectionRun was created. Nothing was ingested.

## 10. Reproducibility / verification

```
python3 forever-db/research/m7_8/candidate_coverage_accounting.py \
    --pending-export <path to the pending export, SHA-256 723dac899c56b1cf...> \
    --declared-test-session 0df16c83d4799a \
    --declared-test-session 2f912201625e3a \
    --declared-test-session 3a36d86e1d2070 \
    --declared-test-session 7e6f72f9ca76b0 \
    --declared-test-session a736b9052541c3 \
    --declared-test-session bcb81b2ecb2b42 \
    --declared-test-session beba6db0129d72
```

- Deterministic: the JSON carries `content_sha256` (`eac8d3e74c4d8b6e10b5da3d79ddfbf59294181eb28982684b9194a603478840`), computed over everything except the machine-specific `run_context` paths; re-running on the same inputs must reproduce it.
- Re-importing the pending export a second time added **0** assertions and ignored 3,835 duplicates (repeated captures are idempotent to import).
- Partition invariants hold: True (pool_size_matches_status_counts_current=True, pool_size_matches_status_counts_hypothetical=True, provenance_counts_sum_to_newly_covered=True).
- Machine-readable data: `forever-db/research/m7_8/candidate_coverage_accounting.json`; tests: `forever-db/research/m7_8/test_candidate_coverage_accounting.py`.

