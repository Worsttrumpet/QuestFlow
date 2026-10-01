# M6.6: Guide Data Report

**Scope: M6.6 only.** This milestone assembles existing M6.2/M6.4 evidence into guide-ready structures — it
introduces no new evidence or conflict system, collects no new data, and does not begin quest chains,
routes, or map work. `coverage.py` and `evidence_report.py` are called exactly as they already exist;
neither was modified.

## What M6.6 Computes

For every quest `coverage.build_coverage()` already knows about, a guide record merges that function's
per-field `evidence_state` (M6.2, authoritative for evidence strength) with
`evidence_report.build_evidence_report()`'s per-field `classification` (M6.4, authoritative for conflict/
difference classification) — passed through unchanged, never reinterpreted.

**`guide_ready` rule, computed live from actual evidence, never hardcoded**:
```
guide_ready = (title.evidence_state == "confirmed"
           AND quest_level.evidence_state == "confirmed"
           AND objectives.evidence_state == "confirmed")
```
`giver` and `interaction_position` are deliberately excluded from this rule — both are capped at `observed`
tier by design (the already-documented role-ambiguity and player-position caveats), so requiring
`confirmed` for either would demand a stronger claim than the pipeline is built to ever make.

## Real Results — Current Full Dataset

| | Count |
|---|---|
| Total quests known | **121** |
| `guide_ready` | **84** |
| Insufficient evidence | **37** |

Blocking-field breakdown across all 37 insufficient quests (not limited to Run-001's 10):

| Field | Quests blocked on this field |
|---|---|
| `objectives` | 36 |
| `title` | 8 |
| `quest_level` | 8 |

`objectives` is, by a wide margin, the most common blocker dataset-wide — a useful, real signal for where
future collection effort would help the most broadly, not just within Run-001's specific target list.

## Run-001 Regression Check

Verified directly against the real dataset, and asserted as an explicit, falsifiable test
(`test_real_data_run001_smoke_test_exactly_8_of_10`) — **not** the readiness rule itself, which is tested
independently of any specific quest ID or count:

**Exactly 8 of the 10 Run-001 targets are `guide_ready`**: `92516, 92517, 92553, 93318, 93319, 93951,
94411, 97970`. **Not** `guide_ready`: `95350, 99196` — matching the honest M6.5 result exactly, for the
same real reasons already documented (95350 likely completed before this recorder existed; 99196 blocked
by an unmet material requirement).

## No Fabrication, Verified Directly

Both remaining-unresolved quests (95350, 99196) are still present in the output with `guide_ready: false`
— never excluded. 99196's gossip-sourced name ("A Donation of Wool") is **not** promoted into its formal
`title` field, which correctly still shows `unresolved` — confirmed by a dedicated test mirroring this
exact real case.

## Tests

**10 new M6.6 tests, all passing**, covering: the readiness rule computed correctly from live evidence
states (not a fixed list), a missing required field correctly blocking readiness while the record stays
present, a `genuine_conflict` classification preserved and passed through untouched, the gossip-promotion
guard, confirmation that `giver`/`interaction_position` are excluded from the threshold by design,
correct `None`-vs-`"none"` handling for the two fields M6.4 doesn't classify (`prerequisites`, `completion`),
idempotent regeneration, the real-data Run-001 regression check, and confirmation that every known quest
appears in the output regardless of readiness.

**Full regression suite**: 62 M6 tests (M6.2 + M6.3 + M6.4 + M6.6) and 141 M4 tests all pass. `coverage.py`,
`collection_runs.py`, `evidence_report.py`, and `inventory.py` are all byte-identical to before this
milestone — confirmed by hash, not assumed.

## Limitations

- The `guide_ready` threshold (title + level + objectives) is a judgment call approved for this milestone,
  not a rule derived mechanically from the original M6 master plan — stated plainly, not implied as more
  authoritative than it is.
- No quest in the current dataset has ever produced a `candidate` or `placeholder` evidence state, so this
  module's handling of those two tiers (falling through to the same `evidence_state`-driven logic) remains
  untested against real data — only against the readiness rule's own logic in the abstract.
- `coverage.py`'s known non-deterministic JSON-ordering issue (documented in the M6.5 report, not fixed
  here) means two independently-generated `m6_coverage.json` files may differ in internal list ordering
  even with identical underlying data; this module's own idempotency test sorts its own output
  independently rather than relying on `coverage.py`'s ordering.
- `giver`'s exclusion from the readiness threshold is a direct consequence of a limitation already
  documented since M4 (the offering-vs-turn-in role ambiguity) — this milestone works around it rather than
  resolving it, exactly as scoped.

## Frozen

`forever-db/` (M4), the Observation Lab, the M5 recorder, and `inventory.py`/`coverage.py`/
`collection_runs.py`/`evidence_report.py` — all confirmed byte-identical to their pre-M6.6 state.

## Not In Scope (Unchanged From the Approved Plan)

Quest chains, leveling routes, quest hubs, zone progression, travel paths, map visualization, QuestV2/ATT/
Era ingestion, fixing `coverage.py`'s ordering issue, resolving the `giver.npc` role-ambiguity limitation,
further real-client collection, and any milestone after M6.6.
