# The observed pack's giver and position are role-ambiguous and usually turn-in-biased

Status: FINDING (documentation only). Written after the 0.6.9 real-client playtests of Q93065 "Prepare for Battle" and Q93836 "The Fate of Zephras". No addon,
planner, data, generator or recorder behaviour was changed by this document.

## 1. The finding in one paragraph

The observed pack `observed:m6` (`ForeverCodex/Data/Pack_Observed.lua`) carries one `giver` and one `pos` per quest. Those two values are NOT guaranteed to describe the
quest PICKUP. The M6 pipeline chooses the displayed value by checkpoint priority, latest checkpoint first, so for a quest whose offering NPC and turn-in NPC differ the
shipped giver and position are usually the TURN-IN side. Codex reads them as the giver and as the location of the ACCEPT action, so it can route a player to the wrong end
of a quest. The pack's `verified=true` label does not change this.

## 2. Provenance rule (read this before using any observed-pack value)

> "observed / verified=yes" means the quest information was RECORDED ON THE FOREVER CLIENT. It does NOT mean the shipped position is an NPC coordinate, and it does NOT
> mean the displayed giver is the pickup giver.

* `giver` in the observed pack is role-ambiguous: it may be the NPC who offers the quest or the NPC who takes it back. Codex cannot tell which, because the shipped pack has
  no checkpoint label per record.
* `pos` in the observed pack is the PLAYER's map position at one recorder checkpoint (a player standing in a dialog), never an NPC coordinate, and usually the turn-in
  checkpoint (section 4).
* Title, quest level and objective text are a different matter: they were recorded and reproduced on the client and the pack's label is appropriate for them.
* Codex (since 0.6.9) says so in `/codex report`, section NOW CANDIDATE EVIDENCE: the position is "the PLAYER's position at a recorder checkpoint ... NOT an NPC
  coordinate", and `verified=yes` is explained as "recorded on the Forever client". It deliberately does NOT claim which checkpoint a given record came from, because the
  shipped data does not say.

## 3. What the recorder captures

`m5-production-recorder/addon/ForeverRecorder/`:

* `core/Dispatcher.lua` listens for `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`, `QUEST_TURNED_IN`, `QUEST_FINISHED`, `GOSSIP_SHOW`. Each opens a CHECKPOINT:
  `quest_detail` (the offer dialog), `quest_progress`, `quest_complete_immediate` (the turn-in dialog, in the `QUEST_COMPLETE` handler) and `quest_complete_delayed`
  (the same dialog, captured again 1.5 s later on `C_Timer.After`).
* `observers/GiverIdentity.lua` runs at those checkpoints. For the `npc` unit and the `target` unit it records the parsed creature id (never the raw GUID), the name, the
  level and a few unit facts, plus `PositionUtil.Capture()`.
* `core/PositionUtil.lua`: map id and x, y from `C_Map.GetBestMapForUnit("player")` and `C_Map.GetPlayerMapPosition(map, "player")`. Its header: "this always captures the
  PLAYER's own position at the moment of interaction ... NOT the NPC's/giver's world position. Never converted into an NPC-location claim anywhere in this addon." The
  recorder's own known limitation (kept, not fixed): a quest can show different NPCs at different checkpoints, e.g. quest 92528.
* Each observation also carries the checkpoint name, the session id, the build, and `recorded_at`.
* Timing: the `quest_detail` capture runs synchronously inside the `QUEST_DETAIL` handler, so the NPC and the position are read as the dialog opens.
* NOT available to the recorder at all: the NPC's own position, and any progression state of the player. Nothing in the recorder stores a progression stamp.

## 4. How M6 picks the displayed value (the cause)

`m6-dataset-baseline/scripts/coverage.py`, `_field_coverage`: every raw value is kept in `all_values`, but the single displayed `value` is the row from the latest
checkpoint by this priority:

1. `QUEST_TURNED_IN`
2. `quest_complete_delayed`
3. `quest_complete_immediate`
4. `quest_detail`
5. `GOSSIP_SHOW`

The code comment calls this "a DISPLAY choice only; every raw value remains in `all_values`". The guide dataset (`guide_data.py`) and the M8 generator
(`generate_addon_data.py`) carry only the displayed `value` forward, and `build_codex_data.py` writes it into `Pack_Observed.lua` as `giver` and `pos`. The checkpoint
label and the earlier values do not reach the pack. The role ambiguity itself was already documented (M4 "offering-vs-turn-in", `M6_EVIDENCE_CONFLICT_REPORT.md`,
`M6_GUIDE_DATA_REPORT.md`, `CODEX_PLANNING_MODEL.md`), and `guide_data.py` notes giver and position are capped at the "observed" tier for that reason. What was not recorded
anywhere is that the displayed value is systematically the TURN-IN side.

## 5. Repository evidence

Scope: this repo's M6 snapshot (`m6-dataset-baseline/out/m6_coverage.json`) can be checked against 70 of the 96 quests in the shipped pack; the other 26 come from a later
dataset whose raw per-checkpoint values are not in the repository. The recorder session behind these records is one session (id `2e787541803171`) on build 69977, older
than the 70205 client now in use. Giver values in `all_values` carry no checkpoint label; "first recorded giver" below means the first value in the list. That is read as
the offer checkpoint because the position values ARE labelled and line up (examples below), and because a live offer (The Turncoat, section 6) matched it. It is an
inference, not a stored fact.

| Measure (70 checkable quests unless stated) | Result |
|---|---|
| Displayed position taken from `quest_complete_delayed` (turn-in side) | 62 of 70 |
| Displayed position taken from `quest_detail` (offer side; no later checkpoint existed) | 8 of 70 |
| First-recorded giver id differs from the pack's giver id | 14 of 70 |
| Quests with a recorded `quest_detail` position | 66 |
| ...of those, pack position more than 0.5 map-percent units from the offer position | 15 of 66 |
| Quests where offer and turn-in are the same NPC or spot | most of the rest (no effect) |

## 6. Concrete examples

All positions are percent of the map, map 2521 (Zephras Isle).

**Q93065 Prepare for Battle**
* offer checkpoint: giver Valennia Stormfist creature 252383, player at about 66.2, 76.6
* turn-in checkpoints: giver Valennia Stormfist creature 253844, player at about 61.1, 70.9
* `Pack_Observed.lua` keeps the turn-in side: giver 253844, `pos` 61.1, 70.9
* gossip evidence for it is only an ACTIVE listing (seen when ready to hand in), never an available one
* Codex therefore routed the ACCEPT action to the turn-in-side spot. The "46 yd, Nearby" recommendation was a distance to the wrong side of the quest, not merely an
  imprecise estimate of the right place. The offer-time values place the offerer at the hub, a few hundred yards away.
* Related: Q92947 Making Our Move was offered (quest_detail) by Valennia 253844 at 61.1, 70.9, and the pack shows its turn-in giver Hyusaa Quickbreeze instead.

**Q93836 The Fate of Zephras**
* offer checkpoint: giver Ayessa Dawnsinger 251968, player at about 59.1, 79.7 (Ayessa's own spot)
* turn-in checkpoints: giver Talaanis Shadowsong 252476, player at about 66.2, 76.5
* `Pack_Observed.lua` keeps the turn-in side: Talaanis, 66.2, 76.5
* Codex therefore treats Talaanis as the pickup destination, although the available client evidence has never shown Talaanis offering it (the available lists in
  Talaanis's dialogs in the playtest reports never included it).

**Corroboration**
* Q92643 The Turncoat: recorded giver values Talaanis (252476), then Dead Cultist (253372). The pack keeps Dead Cultist. In the playtest the live client offered it at
  Talaanis (QUEST_DETAIL, creature 252476), which matches the first recorded value.
* Q92646 Confront Lorthuna: first recorded giver a Valennia (creature 253590) at about 65.2, 50.4; the pack keeps Ayessa (251968) at 59.1, 79.7. Ayessa's complete
  dialog list did not include it in the playtest.
* Older note in `CODEX_PLANNING_MODEL.md`: the observed *Wayward Weapons* (97279) lists Kzan Thornslash as `giver`, whom the player reports is the turn-in NPC.

## 7. How Codex uses these values today (unchanged)

1. `Registry.merge` takes `giverNpc` and `giverName` from the highest-priority layer that has them (observed, priority 100).
2. The observed layer has `pos`, not map/x/y, so `merge` uses it only as the labelled fallback location, kind `player_position`, when no other layer has a giver
   coordinate. A QuestieDB coordinate is ignored when its giver differs from the observed giver (`guardGiver`).
3. `Providers/Quest.lua` builds the ACCEPT target at that point: approximate, with `verified` copied from the pack (true).
4. `Contract.Evidence` derives `evidence=observed` from the targets' `verified` flags. `Planner.Confidence` applies only the "approximate" discount, and skips the 0.9
   unverified-pickup discount for `evidence=observed`.
5. The report and route label the stop by the giver's name ("Travel to <giver> (N yd)").
So the turn-in side's NPC name and spot become the pickup's name and spot. Nothing in this chain is wrong in isolation; the input is mis-described.

## 8. Valennia Stormfist has more than one creature id

The same name appears under at least three creature ids in the recorded data: 252383 (hub, Valanaar), 253590 (Confront Lorthuna's offer) and 253844 (Making Our Move's
offer and Prepare for Battle's turn-in, on the road). The playtests recorded dialogs with 252383 only. Whether the others are separate spawns, phases or stages is not known
from any data in the repository.

Consequence for matching: `OfferProbe.NpcContext` falls back from creature id to NPC name ("the same NPC seen once with an id and once without"). With several ids behind
one name, a name-only match can pair a quest's giver id with a different NPC's dialog. 0.6.9 makes this visible in the report ("matched BY NAME ONLY (both creature ids are
known and they differ)"). The matching logic itself was NOT changed.

## 9. What is known, what is not

Known: how the recorder captures, the generator's selection rule, the repo-snapshot counts above, the two concrete examples, and that the shipped pack drops the checkpoint
label.
Not known: the mapping of unlabelled giver values to checkpoints for every quest (inferred); the 26 pack quests the repo snapshot cannot check; why a Valennia at the
road position was not visible in the playtest; whether the other creature ids are phases; how any of this behaves on builds after 69977.

## 10. Explicitly NOT done (by decision)

No change to `Planner.lua`, the UNKNOWN pickup policy, offer-state behaviour, NPC matching, `Registry.merge`, QuestieDB/ATT handling, `Pack_Observed.lua`, the generators or
the recorder. No per-quest checkpoint was invented inside the pack, and no user-facing text claims a particular record came from `QUEST_DETAIL`. The future data task is
`CODEX_BACKLOG.md` item C-12.
