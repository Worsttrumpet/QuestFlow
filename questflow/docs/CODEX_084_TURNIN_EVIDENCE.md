# 0.8.4: no assumed hand-in locations

## Root cause (Q264 "Until Death Do Us Part")
`Providers/Quest.lua` `turnInPlace(view)` returned `"assumed"` whenever the merged quest view had no turn-in record, and `progressAction` / `questTargets` then built the hand-in target from the GIVER's position (contract kind `assumed_giver`, status `approx`, planner confidence 0.8). ATT has no turn-in field, and QuestieDB gives none when the finisher is not a creature, so for those quests the giver's spot was routed to as a real stop. For Q264 the giver stands in Thunder Bluff (QuestieDB position) and the hand-in is in Silverpine.

Data flow: giver NPC and position come from the highest-priority pack with one (`Registry.merge`: observed player position, ATT, QuestieDB); the turn-in NPC comes only from QuestieDB `finishedBy` (`QuestieBridge.Record`, `turnIn`); `Providers/Quest.lua` decides the hand-in place; `Contract.K.FromLegacyTarget` stamps `approx`; `Planner.Locate` / `Navigation` consume the target as any other.

## Behaviour now
| data | hand-in |
|---|---|
| turn-in NPC known, different, has a position | that position (QuestieDB, unverified) |
| turn-in NPC known, different, no position | no location (unchanged) |
| the data says giver and turn-in are the same NPC | the giver's position, approximate, flagged, unverified (unchanged) |
| no turn-in data (ATT only, or no creature finisher) | **no location**; no NPC named; the giver is not shown as the hand-in NPC |
| the game's own quest-map point exists | used (client evidence), labelled "game quest map" (unchanged) |

A hand-in with no location is a planner reminder: never NOW, never routed, no arrow. It appears in READY TO TURN IN as a click area, or as the guidance NOW card, and opens QUEST DETAILS (0.8.3).

## Cost, stated plainly
Without QuestieDB, ATT-only quests no longer route to their (usually correct) giver spot for hand-in. Hand-ins of such quests are reminders until the quest-map point or QuestieDB supplies where they are. With QuestieDB enabled the common case (finisher = starter) is unchanged.

## Test and golden changes
Fixtures built with `H.attPack` now carry an explicit same-NPC turn-in by default (`turnIn = false` opts out); the fake QuestieDB sets a finisher only where its source record has turn-in data. `golden/engine_plan.golden` changed only for the two real-ATT hand-ins (Q7, Q87 lose their "travel to the giver" legs); `golden/planner_eval_baseline.txt` changed only for the real-data scenarios A0, A1, A2, E2 whose ready turn-ins are ATT-only. New: `tests/turnin_evidence_tests.lua`.

## Real client
No new API or telemetry. Still needed: Q264's actual QuestieDB `finishedBy` on Forever (object, unreadable NPC, or the same NPC) via `/codex report` NOT PLACED lines.
