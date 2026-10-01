# M6.4: Evidence / Conflict Report

**Scope: M6.4 only.** This milestone analyzes evidence already present in the project — it collects no new
data, modifies no recorder or importer code, and does not begin M6.5 (production collection) or M6.6
(guide preparation). It replaces M6.2's crude same-checkpoint-only "47 conflicts" figure with a richer,
field-type-aware classification, without changing M6.2's own output or evidence states.

## Evidence Analysis

Built by re-importing the real export through the existing, unmodified M4 importer and calling the
existing `history()` function directly for every field in M6.2's own `coverage.QUEST_FIELD_MAP` (reused,
not redefined). One real limitation found during inspection, worth stating plainly: `m6_coverage.json`'s
own `all_values` list does not preserve per-value session/checkpoint pairing, which precise classification
needs — rather than change `coverage.py`'s output shape (which the integrity checklist requires stay
untouched), this milestone queries `history()` independently for that detail.

## Field Classifications

Seven categories, kept deliberately small:

| Category | Meaning |
|---|---|
| `no_evidence` | Zero observations for this field |
| `single_observation` | Exactly one — not yet duplicated, not yet a conflict |
| `none` | Two or more observations, all effectively identical |
| `state_change` | Values differ, but the difference matches a documented, legitimate evolution pattern |
| `position_variance` | Position values differ, beyond the documented tolerance, but this is real player-standing variance, not a fact conflict |
| `genuine_conflict` | Values differ with no legitimate explanation — a real candidate conflict |
| `ambiguous_difference` | Values differ, but evidence doesn't support confidently picking one of the above |

No evidence state established by M6.2 (`confirmed`/`observed`/`unresolved`/etc.) is redefined or changed by
any of this — a field can be `evidence_state: confirmed` and `classification: genuine_conflict`
simultaneously, exactly as the M6.4 brief specifies.

## Special Field Rules

- **Strictly stable** (title, quest level, XP, money): never legitimately vary at any checkpoint. Any real
  difference is a `genuine_conflict` candidate — **unless** the distinct values correlate perfectly with
  distinct observed builds, in which case it's reported as `ambiguous_difference` ("possible client
  change"), never silently assumed to be either explanation.
- **Checkpoint-progressive** (objectives): expected to legitimately evolve across checkpoints (0/8 →
  8/8). A difference *within the same checkpoint* is still a genuine conflict; a difference *across*
  checkpoints is `state_change`.
- **Checkpoint-embedded rewards** (choice items, guaranteed items, reputation): grouped by the checkpoint
  already embedded in each value's own stored shape. Reward data resolving differently at a later
  checkpoint (the real quest 92514 pattern) is `state_change`, never a conflict.
- **Giver**: a different NPC at a different checkpoint is `state_change`, explicitly citing the documented
  offering-vs-turn-in pattern (quest 92528, from earlier real-client testing — that specific quest ID
  is not present in *this* dataset's lineage, a real, separate finding noted below, but the pattern it
  established is the same one reused here for the explanation text). A different NPC at the *same*
  checkpoint would be a genuine conflict.
- **Gossip availability**: a `kind`/`level` change with a *consistent* title is `state_change` (the
  documented available→active progression). A title change alongside it is **not** assumed to be the same
  progression — reported as `ambiguous_difference` instead, per the explicit instruction not to invent an
  explanation the evidence doesn't support.

## Position Tolerance

**0.001** (map-fraction units, the same 0–1 scale the recorder already stores). Documented, deterministic,
and tested: the one real position difference M6.2 originally flagged (quest 92703) measured ≈0.0000336 —
ordinary noise from standing in a very slightly different spot between two real interactions. 0.001 is
roughly 30× that real noise, comfortably above it, while still tight — on a typical zone-sized map, 0.001
of the fraction is on the order of a couple of real yards, so anything at or beyond it reflects the player
genuinely standing somewhere materially different, not measurement jitter.

## Session/Run Provenance

Every classified field carries its own `sessions` list (recovered from the existing
`session:<id>|...`-prefixed `source_locator`, unchanged mechanism) and a `collection_runs` list, populated
**only** where M6.3's registry explicitly associates that session with a run — never inferred. In the
current dataset, `m6_collection_runs.json` has one registered run with **no sessions associated yet** (it
targets currently-unresolved quests that haven't been revisited), so every field in this report correctly
shows an empty `collection_runs` list right now — this is the honest, expected result, not a bug.

## Current Findings — Replacing M6.2's "47 Conflicts"

| Classification | Count |
|---|---|
| `single_observation` | 364 |
| `no_evidence` | 262 |
| `none` (consistent) | 240 |
| `state_change` | 142 |
| `position_variance` | 37 |
| `genuine_conflict` | **0** |
| `ambiguous_difference` | **0** |

**Zero genuine conflicts, zero ambiguous differences, anywhere in the current dataset.** The two field
categories M6.2 flagged as "conflicts" resolve cleanly:

- **Gossip availability**: exactly **46** — matching M6.2's original count precisely — all correctly
  reclassify as `state_change`, all legitimate `available`→`active` progressions, none involving a title
  change.
- **Interaction position**: M6.2's narrow same-checkpoint-only check found exactly 1 flagged case; this
  milestone's broader, tolerance-based, all-checkpoints comparison found **37** quests with real position
  spread beyond 0.001. This is **not a contradiction between the two reports** — M6.2 only ever compared
  values captured at the *identical* checkpoint; this milestone compares every real position reading for a
  quest against every other, which naturally surfaces more real (and entirely expected) variance between
  separate real visits. All 37 are `position_variance`, not conflicts, per the explicit project rule that
  player position is not NPC location and ordinary standing variance is not a data problem.

Per-field breakdown is in `out/m6_evidence_report.json`; every quest's full field-by-field classification
is preserved there, not summarized away.

## Evidence Summary

- **95 quests analyzed**, all 11 tracked fields each — 1,045 field-classifications total.
- **262 recommended collection targets** — every field currently at `no_evidence`, each identified
  individually by quest ID and field name in `out/m6_evidence_report.json`'s
  `recommended_collection_targets` list. No genuine-conflict or ambiguous-difference targets exist to add
  to this list right now, since none were found.

## Limitations

- Quest 92528 (the historically-documented giver-role-ambiguity example from earlier M4 real-client
  testing) is **not present in the dataset this milestone actually analyzed** — a real, separate finding
  about this project's data lineage, not a defect in this milestone's logic. The classification rule it
  originally motivated is still applied correctly here, demonstrated by quest 92460's real `state_change`
  result in this dataset.
- Zero genuine conflicts and zero ambiguous differences means this milestone's *rarer* code paths (the
  build-correlated stable-field case, the gossip-title-changed case) are tested only against synthetic
  fixtures, not real data — because the real data simply doesn't currently contain an example of either.
- The position tolerance (0.001) is a considered, documented, tested choice, not an empirically-derived
  statistical threshold — it has exactly one real prior data point behind it (quest 92703's ≈0.0000336
  spread) plus reasoning about map scale, not a distribution of many real measurements.
- Collection-run correlation currently shows empty for every field, since the one registered M6.3 run has
  no associated sessions yet — this will populate naturally once a real session is associated with a run
  and this report is regenerated.

## Implications for Future Collection

The 262 `no_evidence` fields (broken out precisely by quest and field in the JSON output) are the concrete
target list for M6.5. With zero genuine conflicts currently found, there is no immediate "resolve this
contradiction" priority — the dataset's real gap right now is coverage breadth, not evidence quality.
