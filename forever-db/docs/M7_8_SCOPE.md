# M7.8 Scope Reconstruction: Passive Quest Collection

**Status: PROPOSED — scope reconstruction only.** Nothing was implemented. No dataset, recorder, importer,
CollectionRun, or locked artifact was modified. M7.7 (COMPLETE / LOCKED) was not touched.

**Recommendation:** M7.8 should be a **read-only candidate coverage-accounting milestone** — a report that
measures how far passive play has moved the 1,102 ATT-only candidates toward observed evidence, computed from
existing M6 machinery, writing nothing to M6. It should *not* change the recorder, the M4 importer, M6, or the
CollectionRun system, and it should *not* ingest anything into M6. Section 5 explains why.

## 0. Where the numbers in this document come from

Every measurement below was made **read-only and in memory**: an export was parsed, imported through the
unmodified M4 importer into a throwaway in-memory database, and summarized with M6.2's own
`build_quest_coverage()`. Nothing was written to the project.

| Input | Detail | SHA-256 |
|---|---|---|
| M6's current input export | `m6-dataset-baseline/out/latest_export_ForeverRecorder.lua`, 2,510 observations | `b5c35bec723664375f0fcd6a3d0cc96f3b7ac66794ef9c0426f6451e9a18663d` |
| Newest real export (post-M7.7 validation) | 3,008 observations; the first 2,510 are identical, observation for observation, to M6's input (checked) | `723dac899c56b1cfd884f07670f3ecd8aa77dde1627c87529c525e5103bea39a` |
| Locked candidate list | `research/m7_4/proposed_targets.json` (1,102 candidates) | `b7fc38de6993836e51f3b8f437238d0cd0d833005e8639a54ad8ac80a6c6a50b` |
| Locked ATT/M6 comparison | `research/m7_3/coverage_gap_analysis.json` | `10c8c1aec44bccddc2f8da56727f5e029bf00eaebf4c0043ef5ecb70d65d36d5` |

**"Hypothetical" means: what M6 would show if the newest export were ingested. It has not been ingested.**
M6's on-disk outputs still describe the 2,510-observation export.

## 1. Problem Statement

The operator will not grind quests for data. The recorder already runs during normal play, and M7.7 extended
what it captures. Two things are missing, and neither is a capture problem:

1. **M6 cannot see most of what normal play has already produced.** M6's input export holds 2,510
   observations; the newest export holds 3,008. The **498 observations M6 has never seen** came from ordinary
   play and short test sessions.
2. **There is no way to measure progress against the 1,102 candidates.** The only existing progress measure,
   the CollectionRun coverage delta, is designed for a deliberate, bounded effort (Section 4.8), not for
   open-ended passive play.

The question for M7.8 is therefore not "how do we capture more?" but "can we make passive collection
*measurable* without changing M6?"

## 2. Existing Capabilities (from the implementation)

### 2.1 Recorder (M7.7, locked) — what fires and what runs

| Checkpoint | Fires when | Observers that run |
|---|---|---|
| `GOSSIP_SHOW` | an NPC gossip window opens | `GiverIdentity`, `Gossip` |
| `quest_detail` | a quest-offer screen opens | `QuestMeta`, `RewardsItems`, `RewardsReputation`, `GiverIdentity` |
| `quest_progress` | a quest-progress screen opens (M7.7) | `QuestMeta`, `GiverIdentity` |
| `quest_complete_immediate` / `_delayed` | the reward screen opens / +1.5 s | `QuestMeta`, `RewardsItems`, `RewardsReputation`, `GiverIdentity` |
| `QUEST_TURNED_IN` | a quest is turned in | `RewardsXPMoney` |
| `GET_ITEM_INFO_RECEIVED` | item data arrives late (retry, max 3) | `RewardsItems` |

No new hook is proposed here.

### 2.2 What reaches M6 (M4 importer → M6.2 field map)

| M6 field | Tier | Comes from | Populated at |
|---|---|---|---|
| `title`, `quest_level`, `objectives` | confirmed | `QuestMeta` | detail, progress, complete |
| `xp`, `money` | confirmed | `RewardsXPMoney` | `QUEST_TURNED_IN` only |
| `choice_items`, `reputation` | confirmed | `RewardsItems`, `RewardsReputation` | detail, complete |
| `guaranteed_items` | observed (weaker) | `RewardsItems` | detail, complete |
| `giver`, `interaction_position` | observed | `GiverIdentity` (quest-scoped) | detail, progress, complete |
| `gossip_availability_sightings` | observed | `Gossip` | gossip |
| `prerequisites` | always unresolved | none | never |

Key mechanics, verified in code:

- **The tier is a property of the field, not of the observation count.** M6.2 reports a field as its fixed
  tier as soon as *one* assertion exists, otherwise `unresolved`.
- **`guide_ready`** = `title`, `quest_level` and `objectives` all `confirmed` (M6.6). It reads only M6.2's tier.
- A quest becomes an M6 "quest entity" if it has **any** quest-scoped assertion, including a bare gossip
  sighting.
- **Gossip does not populate `title`/`quest_level`.** The gossip title and level are embedded *inside* the
  sighting value, so a quest seen only in gossip is partially observed with `title` still `unresolved`.

### 2.3 What exists for measurement

- **M6.2 coverage** is a snapshot of one export. `EXPORT_PATH` is hard-wired in `inventory.py`,
  `coverage.py` and `evidence_report.py`, so refreshing M6 means replacing that one file and re-running
  the scripts — an explicit, human-triggered step (as in M6.5).
- **M6.4 already carries provenance per field**: each field's evidence lists its `sessions` and its
  `collection_runs`, where a run appears *only* if M6.3 recorded the association explicitly (never inferred).
  A session with no run association is exactly "not part of any deliberate effort".
- **M6.3 CollectionRun**: bookkeeping about intent (Section 4.8).
- **M7.3 / M7.4** provide the fixed populations: 1,537 ATT quests; 14 in both ATT and M6; 1,523 ATT-only;
  **1,102 findability-qualified candidates**; 421 ATT-only unqualified. **M7.5** holds ten planned, untouched runs.

### 2.4 Documented limitations that this scope preserves

- `giver.npc` does not distinguish offering vs turn-in roles (quest 92528); `giver` is capped at `observed`.
- `interaction_position` is the **player's** position, never the NPC's.
- `guaranteed_items` is weaker evidence than `choice_items` (confirmed once, not independently reproduced).
- `evidence_note` does not reach the SQLite assertions (M5, unfixed).
- `coverage.py` converts a set to a list without sorting when reporting conflicts, so its JSON is not
  byte-reproducible across processes (M6.5; unfixed). Counts and tiers are stable.
- Gossip captures detail for at most **5** quests per list; the count is kept, the rest is not read.
- At `quest_detail`, an unaccepted quest is not in the quest log, so `title`/`level` generally do not resolve
  (M6.5 lesson; confirmed again in Section 3.2). M6.5 also found that revisiting an accepted quest's giver
  produced gossip only. M7.7 showed a progress screen can now be captured on the tested cases.
- Quest 913's `QUEST_DETAIL` title/level failure remains an unresolved separate observation.

## 3. Passive Evidence Opportunities

### 3.1 What ordinary play yields, by natural action

| Natural action | Checkpoint | M6 fields it can populate | Notes |
|---|---|---|---|
| Talk to any NPC | `GOSSIP_SHOW` | gossip sighting (≤5 quests/list); NPC-scoped sighting and position | No quest is accepted or completed |
| Open an offered quest | `quest_detail` | `objectives` (sometimes), rewards, `giver`, position | `title`/`level` usually unresolved; item names can be blank on first read |
| Revisit an accepted quest via its giver | `quest_progress` | `title`, `level`, `objectives`, `giver`, position | Verified on 3 real events; completable quests untested |
| Turn in a quest | `quest_complete_*`, `QUEST_TURNED_IN` | everything above plus `xp`, `money`, rewards | The strongest single event |
| *(nothing)* | — | `prerequisites` | No data source exists |

Quests the operator never accepts, never revisits, or cannot encounter (other zones, races, classes) produce
at most a gossip sighting or an offer screen.

### 3.2 Measured passive yield (one real sample)

The 498 observations M6 has not seen, by checkpoint: `quest_detail` 184, `GOSSIP_SHOW` 94,
`quest_complete_immediate` 96, `quest_complete_delayed` 96, `QUEST_TURNED_IN` 22, `quest_progress` 6.
About 84% (417 of 498) come from two ordinary Troll Shaman leveling sessions; the rest from short
M7.6/M7.7 test sessions.

**If the newest export were ingested (hypothetical):**

| Measure | Current M6 | Hypothetical |
|---|---:|---:|
| Quests in M6 | 121 | 153 (+32) |
| `guide_ready` quests | 84 | 96 |
| Quest 794 `objectives` (the M7.3 gap) | unresolved | confirmed |
| Candidates (of 1,102) with any evidence | 0 | **19** (1.7%) |
| Candidates never observed | 1,102 | **1,083** (98.3%) |

The 32 newly observed quests split as: 19 in the candidate pool, 2 in the ATT-only unqualified set, and
**11 not in ATT at all** (passive play also discovers quests ATT does not list).

The 19 candidates, by evidence reached: **6 guide-ready**, 9 partial with some core field, 4 partial with only
non-core fields. All 19 were observed only in sessions with **no CollectionRun association** (0 run-associated).
By session type: **16** only in the ordinary leveling sessions, 1 (quest 815) in both a leveling and a test
session, 2 (907, 913) only in test sessions.

Title and level came almost entirely from completion screens; objectives came from offer, progress and
completion screens; `quest_progress` supplied evidence for one candidate (815). Several candidates show
objectives but no title (offered, never accepted), the limitation in Section 2.4.

**Interpretation limits.** This is one sample: one class start zone, roughly two hours of play, partly
overlapping deliberate testing. It supports "passive play measurably moves the pool, with no grinding". It does
**not** support a rate, and it does not show that any given quest will be reached.

### 3.3 Repeated observations (deduplication)

| Question | Finding (verified) |
|---|---|
| Is re-importing the same export safe? | Yes. Importing the newest export twice into one database added 3,835 assertions, then 0 (3,835 ignored). The dedup key includes `session:<id>\|observations[<index>]`. |
| Does a repeated capture create a duplicate? | It creates a **separate row** (each capture has its own locator). `observation_count` grows; the value list keeps every capture. |
| Does that inflate coverage or readiness? | No. The tier is fixed per field, `guide_ready` reads only the tier, and `compute_coverage_delta` explicitly ignores count increases. |
| Can it create false conflicts? | **Yes, in M6.4.** It calls it a `genuine_conflict` when the *same checkpoint* yields more than one distinct value. |

Real data: the newest export would raise M6.4's `genuine_conflict` count from 2 (both quest 4402) to 6. Of the
four new ones, three are the known "item name blank at first read, resolved later" pattern (quests 789 and 1195
`objectives`; 913 `guaranteed_items`). The fourth (792 `choice_items`) differs only in `r5`, the fifth return of
`GetQuestItemInfo`, whose meaning this project never labeled; it correlates with one session, and whether it is
character-dependent is **unverified**. **None involve `quest_progress`.**

The `quest_progress` mechanism was confirmed **synthetically**: two same-checkpoint objective values with
different progress ("2/8" vs "6/8") classify as `genuine_conflict`; the same values at different checkpoints
classify as `state_change`. Before M7.7, progress could only change *across* checkpoints; `quest_progress` is
the first checkpoint where it can change *within* one. This is not yet seen in real data.

**Conclusion:** no deduplication is needed for coverage or readiness. There is a possible future
normalization question in the frozen M6.4 classifier. It is documented here, **not proposed**, and the
accounting must not depend on conflict counts (Section 4.6).

### 3.4 Reachability of the candidates

**829 of the 1,102 candidates (75.2%)** carry an ATT race and/or class restriction hint (races 800, classes
254; 273 carry neither). These are candidate hints, not observed facts, and their values are not decoded or
verified here. The M4 filter (name + giver + coordinates) does not consider them. Passive coverage is bounded by
which characters the operator plays, so "never observed" cannot be read as "not yet reached." The pool skews to
classic-numbered IDs (381 below 1,000; 692 in 1,000–9,999; 8 in 10,000–89,999; 21 at 90,000 and above), given as
context, not as a route.

## 4. Coverage / Accounting Model

### 4.1 Denominator and baseline

The denominator is the **locked M7.4 list of 1,102**, fixed and never recomputed. All 1,102 were absent from M6
at M7.4 time, so **any candidate that later appears in M6-style coverage is, by construction, newly observed**;
no extra baseline snapshot is needed. Verified today: 0 of 1,102 are in current M6.

Tracked separately (not in the denominator): the 421 unqualified, the 14 intersection quests, and observed
quests not in ATT at all.

### 4.2 Two axes, kept separate

**Status** (from M6.2 tiers only):

| Status | Rule |
|---|---|
| `candidate_only` | no quest entity in the coverage being read |
| `partial_core` | 1–2 of `title`, `quest_level`, `objectives` resolved |
| `partial_noncore` | none of the three, but another field resolved (sub-count: gossip-sighting-only) |
| `guide_ready` | all three resolved (M6.6 rule) |

**Provenance** (from existing `sessions` / `collection_runs`): `passive_only`, `run_associated_only`, `mixed`.
"Passive" means "not associated with a CollectionRun"; it describes bookkeeping, not intent (3 of the 19 were
touched by deliberate test sessions).

### 4.3 The user's four categories, mapped

| Category | Definition |
|---|---|
| ATT candidate only | status `candidate_only` |
| Observed in M6 | present in the on-disk M6 coverage (today: 0) |
| Newly observed through passive collection | present in a supplied export, or in M6 after a future refresh, with provenance `passive_only` |
| Partially observed | `partial_core` or `partial_noncore` |

### 4.4 Data modes

| Mode | Reads | Writes |
|---|---|---|
| Current M6 | on-disk M6 coverage | nothing |
| Pending export | an explicit export path, in memory | nothing |
| After a future M6 refresh | the same as "Current M6" | nothing |

### 4.5 Headline metrics and non-metrics

Metrics: counts per status; per-candidate core-field fill (of 3); provenance split; side counts for
non-pool quests; the quest-794-style follow-up state. **Not** metrics: `observation_count`, and M6.4 conflict
counts, which are reported in a separate `data_quality` block.

### 4.6 Worked example (measured, hypothetical ingest of the newest export)

| Status | Candidates |
|---|---:|
| `candidate_only` | 1,083 |
| `partial_core` | 9 |
| `partial_noncore` | 4 |
| `guide_ready` | 6 |
| **Total** | **1,102** |

Provenance of the 19 observed: `passive_only` 19, run-associated 0, mixed 0.

### 4.7 Determinism

Reports must contain counts and sorted lists only, never `coverage.py`'s unsorted conflict lists (Section 2.4).

### 4.8 Why not a CollectionRun

A CollectionRun is "bookkeeping about intent and organization"; sessions are *associated, not owned*; the
lifecycle is `planned → active → completed | abandoned`; snapshots are full `build_coverage()` outputs written
into the M6 output directory. A run *can* be forced to express passive collection (target IDs = the pool,
fields = the three core fields, sessions associated afterward), and `compute_coverage_delta` would then give
`fields_resolved` and `remaining_targets`. But that stretches its documented semantics:

- A bounded run must end; passive play does not.
- Associating a session with a run would *remove* its passive status by the definition in 4.2.
- Each snapshot adds ~1.4 MB to M6's output directory and writes the registry.
- It cannot express partial status, provenance, or non-pool quests.

The provenance model already gives "passive = no run association" with no run at all. **Recommendation:
create and use no CollectionRuns in M7.8.** The ten M7.5 pilots stay `planned` and untouched.

## 5. Proposed Minimal M7.8 Scope

**M7.8 — Passive Candidate Coverage Accounting (read-only).** One script that, given the locked M7.4 list, the
current M6 coverage and an optional explicit export path, writes a deterministic report of status × provenance
for the 1,102 candidates, the side populations, the data-quality counts, and the "would-change-if-ingested"
delta — clearly labeled hypothetical when it comes from a pending export.

**Why this and not the alternatives:**

| Option | Verdict | Reason |
|---|---|---|
| Read-only analysis only | Superseded | This document already is that analysis; it is not repeatable |
| Passive-capture data-flow improvement | **Rejected for M7.8** | Capture works end to end. Every gap found (gossip title/level not mapped, blank item names, conflict noise, gossip cap) sits in a frozen layer (M4 importer, M6.2, M6.4) or a change explicitly out of scope |
| **Coverage accounting / reporting** | **Recommended** | Answers the operator's actual question, reuses existing unmodified functions (the M7.3 / M7.4 pattern), touches no frozen file |
| Accounting + M6 refresh | Rejected | Refreshing M6 mutates the authoritative dataset; that is a separate, explicitly approved step |

**Why it is useful:** the accounting would state, for example, that ingesting the current export would add 19
candidates (6 guide-ready) and close the quest-794 gap — the information needed to decide whether to
ingest — and would give a repeatable progress measure as play continues.

**The M6 refresh is not part of M7.8.** The procedure already exists (replace the input export, re-run the
M6.2 / M6.4 / M6.6 scripts, verify hashes, as in M6.5) and requires its own explicit approval.

## 6. Explicit Exclusions

`QUEST_ACCEPTED`; changing quest-log lookup; WDB extraction; taxi data; new external sources; new ATT
acquisition; gossip redesign or expansion; target/NPC integration; automatic or manual M6 dataset mutation
(including ingesting the newest export); bulk or any CollectionRun creation or activation; manual
quest-grinding requirements; any licensing change; evidence-schema redesign; M4 importer, M6.2 / M6.4 / M6.6 or
recorder changes; normalizing the M6.4 classifier (Section 3.3); mapping gossip title/level into M6 fields;
decoding ATT restriction values; map or route generation.

## 7. Acceptance Criteria

1. **Read-only:** SHA-256 of every protected artifact is identical before and after a run: M6 outputs, the
   collection-run registry, M6's input export, M7.3 / M7.4 / M7.5 / M7.7 artifacts, `sources.toml`,
   `LICENSING.md`, the M4 / ATT code, the recorder.
2. **Denominator fidelity:** exactly the 1,102 IDs from the locked M7.4 file; none added or dropped.
3. **Partition invariants:** status counts sum to 1,102; provenance counts sum to the observed count.
4. **Tier-only status:** status uses M6.2 `evidence_state` only; M6.4 conflict counts appear only in
   `data_quality`.
5. **Labeling:** every pending-export figure is marked hypothetical and carries the export's SHA-256; current-M6
   figures come from M6 unchanged.
6. **Determinism:** two consecutive runs produce byte-identical output.
7. **Reproduces this scope's measurements** on the recorded export: 19 observed (6 / 9 / 4); 32 newly observed
   (19 / 2 / 11); `guide_ready` 84 → 96; quest 794 unresolved → confirmed. The real export is not in the repo,
   so this runs as an integration test that auto-skips when the file is absent (the `test_real_att.py`
   convention), backed by a synthetic-export unit test.
8. **Lineage check:** if the supplied export is not a prefix-superset of M6's input export (for example after
   `/fr clear`), the report says so loudly.
9. **No CollectionRun** is created; the registry hash is unchanged.
10. **Restriction hints**, if included, are labeled `source_derived_not_observed` and never affect status.
11. **Size:** output stays under the repository's 1 MB tracked-file limit.
12. **Regression:** existing suites unchanged (M4 141, ATT integration 7, M6 62, M7.5 14, M7.6 12, recorder
    all-pass, M7.4 10 + its 1 known stale test).

## 8. Risks and Unknowns

1. **One sample.** Single zone, about two hours, partly deliberate testing. No yield rate can be claimed.
2. **Unobserved does not mean unreached.** 75% of the pool carries restriction hints (Section 3.4); the
   recorder also has known gaps (accepted-but-never-revisited quests; gossip cap of 5).
3. **The ingestion decision is separate and open.** Until it is made, M6 shows 0 of 1,102.
4. **Conflict noise.** M6.4 will keep flagging same-checkpoint variation (blank names, progress counters,
   possibly character-dependent fields). Harmless to readiness, but it inflates a headline "conflicts" number.
5. **Non-reproducible ordering in `coverage.py`.** The accounting must avoid unsorted set-derived output.
6. **Export lineage.** Exports are cumulative and account-wide; `/fr clear`, or exports from another machine,
   break the prefix property. The lineage check (criterion 8) mitigates but does not prevent this.
7. **"Passive" is bookkeeping, not intent.** It means "no run association".
8. **Hard-wired `EXPORT_PATH`.** The accounting must call `import_harvest_export` and
   `build_quest_coverage` directly rather than overriding the constant in a frozen module.
9. **Whether a completable quest triggers a `quest_progress` capture** is still untested (carried from M7.7).
10. **The 1 MB repository limit** already forced a redesign in M7.4.

**Decisions needed from the operator (not assumed here):**

- **D1.** Approve M7.8 as accounting-only?
- **D2.** Ingest the newest export into M6 as its own explicit step, before or after M7.8?
- **D3.** Include ATT restriction hints as a labeled annotation?
- **D4.** Which export path should be the accounting's default input?

## 9. Files Expected to Be Touched If Implementation Is Later Approved

**New files only** (following the M7.3 / M7.4 / M7.5 layout):

| File | Purpose |
|---|---|
| `forever-db/research/m7_8/candidate_coverage_accounting.py` | the read-only accounting script |
| `forever-db/research/m7_8/test_candidate_coverage_accounting.py` | unit tests plus the auto-skipping real-export integration test |
| `forever-db/research/m7_8/candidate_coverage_accounting.json` | the deterministic report |
| `forever-db/research/m7_8/pre_run_hashes.txt` | protected-artifact hash snapshot (as in M7.5) |
| `forever-db/docs/M7_8_REPORT.md` | milestone report |

**Existing files modified: none.** Explicitly untouched: everything under `m5-production-recorder/`,
`m6-dataset-baseline/` (scripts, outputs, registry, exports), `forever-db/src/`, `forever-db/config/`,
`forever-db/docs/LICENSING.md`, and all M7.3 – M7.7 artifacts.

## Appendix: What Was Inspected

Recorder: `Dispatcher.lua`, `Registry.lua`, `Bootstrap.lua`, `SlashCommands.lua`, `Export.lua`, the six
observers, and the TOC. M4: `harvest/importer.py`, `assertions.py`, `db.py`. M6: `inventory.py`, `coverage.py`,
`collection_runs.py`, `evidence_report.py`, `guide_data.py`. Docs: `HARVEST_CONTRACT.md`, the M6 coverage,
evidence, collection-run, guide-data and production-collection reports, and the M7.3 – M7.7 documents. Data: the
M7.3 and M7.4 artifacts, the four M6 output files, and both exports. The locked M7.3 module's ATT helper was
run read-only, in memory, to count restriction hints.
