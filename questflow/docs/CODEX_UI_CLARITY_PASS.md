# UI clarity pass (0.5.5): presentation only

No planner, scoring, route, filtering, Reward Advisor, Eligibility, telemetry or performance change; no new timer, OnUpdate or event.

## What the screenshot showed and what it meant
* The green "Nearby" line in the NOW card was NOW's distance (the old rule: under 150 yd = "Nearby"), not a section. The tracker has no NEARBY card, so nothing needed hiding; the word was misleading. It now prints a number ("300 yd", "Here" under 30 yd), followed by the quest level when the data has one ("300 yd - Lv 9").
* "Then: Accept X" now has a second dim line: distance from you and the NPC when named ("700 yd - Nazgrel").
* The ALSO card is named for what its rows are: ALSO COMPLETE (all objectives), ALSO PICK UP (all pickups), ALSO DO (mixed). Rows show distance; a pickup's dim line is "distance - NPC - reason" where the reason is the planner's own code (same stop / on your way / a short detour (about N s)); objectives share one dim line ("Close to what you're doing." or "In the same area as what you're doing." when only the zone is known).
* READY TO TURN IN rows have a dim line: distance (with thousands separator), the hand-in NPC, and "opens N more quests".

## What the code does and does not know
* NPC: pickups carry the quest giver (QuestieDB / ATT, unverified like the quest name). For hand-ins the new `turnInNpc` flag is set only when the data names a turn-in NPC; otherwise no name is shown (the giver is where the quest was given, not necessarily where it is handed in). NOW's hand-in line follows the same rule now.
* Level: the quest level where the data has one (`view.level`), never the required level.
* "Opens N more quests": QuestieDB prerequisite lists (existing `Planner.unlocksOf` index, exported read-only as `Planner.Unlocks`) filtered by the same pickup eligibility rules, run as if the quest were done. It undercounts when a follower needs a higher level than you have; it never counts quests already done or in the log. Unverified data, so the wording is "opens".
* Not available: why a quest "is worth completing before it turns gray" (no urgency model), cheap-detour pricing for rows other than the planner's ALSO DO, NPC names for objectives.
* NEEDS REAL-CLIENT VALIDATION: line widths at the real font and window width (long NPC/quest names), and that QuestieDB turn-in NPC names match what the game shows.

## 0.6.2: fixes from the real-client screenshots of 0.6.0
* Reasons shortened to fit the line ("Detour about 9 s" instead of "A short detour (about 9 s)"; it was cut off at the card edge).
* The shared "Close to what you're doing." line shows only when EVERY row is an objective; under a mix it sat below the pickups and read as describing them.
* A priced opportunity inserted AFTER the last stop (`AFTER_ROUTE`, e.g. a pickup 1,350 yd away near where the route ends) is still carried in `plan.onTheWay` and listed in `/codex report`, but is not listed in the tracker: it is not on the way now.
* A little more space between pickup entries. No planner, scoring, selection or cap change.

## 0.6.3: objective rows say what the count is of; objective distance is marked approximate
* An ALSO objective whose objective has its own wording is now drawn as a heading (quest name - distance) with the objective as the row ("Windsong Crawler Meat 4/6"). The compact one-line form (quest name beside the count) is kept only when the objective has no wording. Real-client report: "Crab Season - 350 yd 4/6" did not say what 4 of 6 was.
* An objective is an AREA. FACT (code): for a quest in the log with no objective coordinates, Codex's target is the single point the game's quest map (`C_QuestLog.GetQuestsOnMap`) returns for it (only the first entry per quest is kept); ATT/observed objective coordinates are also single points. The map's blue blobs (the real spawn areas, which can cover a whole lake shore) are NOT available to Codex, so the distance (and the planner's extra-seconds price) is to that one point and can be far from the nearest real spawn. Objective distances are therefore printed with "~" ("~350 yd"). Pickups and hand-ins are NPCs at a point and are unmarked. The planner's pricing is unchanged.
* NEEDS REAL-CLIENT VALIDATION: whether the client exposes the quest-area polygons or the blob (e.g. a quest POI / highlight API) so that distance could be to the nearest part of the area; not probed.
