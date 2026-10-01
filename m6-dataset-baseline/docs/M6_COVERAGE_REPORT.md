# M6.2: Coverage Report

**Scope: M6.2 only.** This is a view/coverage layer built on top of existing M4 assertions — it does not
replace raw observations, does not modify the M4 importer/schema/policy, does not modify M5, and does not
collect any new real-client data. M6.3–M6.6 are not started.

Every claim below is labeled **[data-verified]** (computed directly from the real export by
`scripts/coverage.py`), **[code-verified]** (follows from reading existing source), or **[reported]**
(carried over from the M6 plan or the M6.1 baseline without independent re-derivation here).

## 1. Executive Summary

The coverage layer imports the real `1662`-observation export through the existing, unmodified M4 importer
and builds a field-level, evidence-tagged view for every quest and NPC that has at least one assertion.
**95 quests** and **63 NPCs** are represented. Every field carries its own evidence state — nothing is
collapsed into one whole-quest status. Two real, worth-explaining discrepancies against the M6.1 baseline
were found and resolved *in the coverage view's own query logic*, not by changing M6.1 or any importer
code — both are documented in Sections 3 and 5. Zero conflicts were found in the fields where disagreement
would actually be concerning (title, level, XP, money, objectives, reputation, choice items, guaranteed
items); the 47 flagged "conflicts" are concentrated entirely in two fields with an ordinary, expected
explanation, detailed in Section 10.

## 2. Dataset Used

Same source as M6.1: `out/latest_export_ForeverRecorder.lua`, 1662 observations, imported through
`src/foreverdb/harvest/importer.py` unmodified [code-verified: byte-identical file hash to the one used in
M6.1]. The import itself was re-run for this milestone (not reused from a cached result) and produced the
same 1809-assertion result already established during M5/M6.1 [data-verified].

## 3. Quest Coverage

**95 quests** have at least one assertion [data-verified] — **one more than M6.1's reported 94**. This is
a real, explained discrepancy, not an error in either report: M6.1 counted `unique_quest_ids_touched` from
each observation's own top-level `quest_id` field. Quest `99196` never appears as a top-level `quest_id`
anywhere — it exists only *inside* a `Gossip` observation's sample list, which the importer correctly fans
out into its own quest-scoped `availability.harvest_gossip_seen` assertion. M6.2's definition ("has at
least one assertion") is the more complete one; M6.1's definition ("was the direct subject of an
observation") was accurate for what it specifically measured. Both numbers are correct for what they
define.

## 4. Field Coverage

| Field | Covered | Missing | Evidence tier when present |
|---|---|---|---|
| Title | 85 | 10 | confirmed |
| Quest level | 85 | 10 | confirmed |
| Objectives | 68 | 27 | confirmed |
| XP | 85 | 10 | confirmed |
| Money | 85 | 10 | confirmed |
| Choice items | 30 | 65 | confirmed |
| Guaranteed items | 12 | 83 | **observed** (not confirmed — see Section 8) |
| Reputation | 69 | 26 | confirmed |
| Giver | 94 | 1 | observed |
| Interaction position | 94 | 1 | observed |
| Gossip availability sightings | 76 | 19 | observed |
| Prerequisites | 0 | 95 | — (no data source exists at all) |
| Completion (derived) | 85 | 10 | confirmed when a turn-in-lifecycle checkpoint was seen |

[data-verified] Every count above comes directly from `field_summary` in `out/m6_coverage.json`. Tier
assignment follows the M6 plan's own worked example for quest 92515 exactly (title/level/objectives/xp/
money/reputation/choice-items = confirmed; giver/position/gossip-sightings/guaranteed-items = observed).

## 5. NPC Coverage

**63 unique NPCs** [data-verified] — matching M6.1's figure exactly, but only after a real gap was found
and fixed *in this coverage view's query, not the importer*: a quest-scoped `GiverIdentity` observation
(a real `quest_id` was present) never creates its own `entity_type='npc'` assertion row at all in the
current importer's entity model — the NPC only exists as the `npc_id` value nested inside that quest's
`giver.npc` assertion. Querying `entity_type='npc'` alone silently missed **10 of the 63 real NPCs**
(all of which were seen *only* in a quest-giver capacity, never via a standalone gossip sighting). Fixed by
also reading `npc_id` values out of every `giver.npc` assertion — a broader query against existing data,
not a schema or importer change.

- **53 NPCs** have at least one NPC-scoped sighting (`entity_type='npc'` directly)
- **10 NPCs** are known *only* through a quest's `giver.npc` value — no standalone sighting exists for them
- **46 NPCs** have at least one quest relationship recorded

Every NPC's `quest_relationships` list carries the explicit caveat that appearing as a quest's `giver.npc`
does not establish exclusive or permanent quest-giving — matching the already-documented `giver.npc`
role-ambiguity limitation (quest 92528's two different NPCs at different checkpoints).

## 6. Reward Coverage

Kept strictly separate, never collapsed [data-verified, from `field_summary`]:

| Reward type | Quests covered |
|---|---|
| XP/money | 85 |
| Choice items | 30 |
| Guaranteed items | 12 |
| Reputation | 69 |

## 7. Position Coverage

94 of 95 quests have at least one resolved interaction position [data-verified]. As throughout this
project: this is the *player's* position during the interaction, never converted into or labeled as the
NPC's location — the field is named `interaction_position`, not `giver_location` or `npc_location`,
enforced structurally (a dedicated test confirms no field named `npc_location` exists anywhere in the
output).

## 8. Evidence States

Applied field-by-field, per quest, exactly per the M6 plan's own model — no whole-quest single status
anywhere in the output. The one tier assignment worth restating precisely: **guaranteed items are tagged
`observed`, not `confirmed`**, deliberately weaker than choice items, reputation, and the other `confirmed`
fields — matching the M6 plan's explicit instruction that this distinction matters "especially" for quest
92515, which has exactly two same-quest observations rather than independent multi-quest confirmation.

## 9. Missing Fields

Per-quest `missing_fields` lists are present in every coverage record — nothing is summarized away. In
aggregate: prerequisites are missing for all 95 quests (no current data source produces this at all,
correctly marked `unresolved` rather than guessed); objectives are the next-largest gap at 27 missing;
guaranteed-item evidence is missing for 83 of 95 quests.

**A real limitation carried over precisely, not silently fixed**: `reward_items_evidence_note` (the
guaranteed-item evidence caveat) is present in the raw export but is **not** in the SQLite assertion — the
existing, unmodified M4 importer's field mapping for `reward_items.harvest_observed` only extracts
`{items, checkpoint}`. This coverage view reads the note directly from the **raw export**, not the
assertion, for this one field only, and labels it as such in the output (`evidence_note_source`) rather
than implying the assertion layer carries it.

## 10. Basic Conflicts

**47 conflicts flagged, concentrated in exactly two fields — and both have an ordinary explanation, not a
data-quality problem:**

- **46 in `gossip_availability_sightings`**: `GOSSIP_SHOW` is a repeatable checkpoint (it fires every time
  a player opens gossip with an NPC, not once per quest lifecycle), so the same quest legitimately shows
  `kind: "available"` in one interaction and `kind: "active"` in a later one — that's the quest's real
  state progressing between two separate real interactions, not a data disagreement. Conflict-grouping by
  `method` (module@checkpoint) — the only reliable way to recover which checkpoint produced a value, since
  most fields don't embed it in their own stored value — correctly can't distinguish "same checkpoint,
  same moment" from "same checkpoint, different real occasions" for a checkpoint this repeatable.
- **1 in `interaction_position`** (quest 92703): two real position readings differing by a few thousandths
  of a coordinate unit — ordinary floating-point variance from the player standing in a very slightly
  different spot between two separate real interactions, not a data error.

**Zero conflicts** were found in title, level, XP, money, objectives, choice items, guaranteed items, or
reputation — exactly the fields where a genuine disagreement would be concerning. This is a meaningfully
reassuring result and is stated plainly rather than let the raw "47" figure read as alarming.

Per the M6 plan's explicit instruction, **no conflict was resolved automatically** — all 47 remain fully
visible in `out/m6_coverage.json`'s `conflicts_found`, each traceable to its exact quest, field, and
distinct values.

## 11. Session/Build Provenance

Every field-level coverage record carries its own `sessions` and `builds` lists, recovered from
`source_locator`'s `session:<id>|...` prefix (the existing M4 mechanism, unchanged) and the assertion's own
`observed_build_id` column — no new provenance mechanism was invented. Nothing was erased; a field
observed across two builds retains both in its `builds` list.

## 12. Current Collection Gaps

Directly from Section 4, ranked by missing-quest count:

1. **Prerequisites**: 95 missing — no current data source at all; this is a data-availability gap, not a
   collection-priority gap, and won't close through more of the same kind of observation.
2. **Guaranteed items**: 83 missing (and the 12 present are weak, single-observation evidence for 11 of
   them) — the single highest-value real target for a future collection run.
3. **Choice items**: 65 missing.
4. **Objectives**: 27 missing.
5. **Reputation**: 26 missing.
6. **Title/level/XP/money/completion**: 10 missing each — the same 10 quests, almost certainly (viewed but
   never progressed to a resolved state).

## 13. Limitations

- This is a snapshot of one export, not a live view — re-running `coverage.py` against a newer export would
  produce a different result, by design.
- The 244/1418 recorder/Lab attribution established in M6.1 is not re-surfaced per-quest in this coverage
  view — session lists are present, but mapping them back to "which addon" still depends on the same
  external, non-data-structural knowledge M6.1 already documented.
- No QuestV2/ATT/Era candidate data was added, generated, or approximated — per the explicit instruction,
  the candidate-source interface (Section 8 of the M6 plan) is left ready for later ingestion, not filled
  with fabricated or reported-only numbers dressed up as coverage.
- Conflict detection (Section 10) is basic, as instructed — it does not attempt to classify severity,
  auto-resolve anything, or distinguish "expected variation" from "genuine disagreement" in the underlying
  data structure itself; that interpretation currently lives only in this written report, not in the JSON
  output's own fields. This is exactly the boundary M6.4 is scoped to fill.
- `evidence_note` is read from the raw export for exactly one field (Section 9); no other field has an
  equivalent raw-export-only supplement, since no other field currently needs one.

## 14. Next-Step Recommendation

**M6.3: Collection Run Tracking** is the logical next milestone, per the M6 plan's own sequencing — this
coverage view now provides the concrete "what's missing" signal (Section 12) that a real collection run
would be organized around, without which run-tracking would have nothing meaningful to target yet.
