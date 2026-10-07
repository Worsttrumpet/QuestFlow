# 0.8.6: a dungeon objective is not NOW from outside its dungeon

0.8.5 playtest: NOW "Finish Serpentbloom (Dungeon)", Wailing Caverns, ~3150 yd, while standing in Durotar.

- `Planner.lua` stage 1 (`take`): an OBJECTIVE whose quest the game tags as dungeon / raid (`Dungeons.IsDungeon`, the existing tag logic) goes to the planner's `extras` (lower-priority, on-the-way only) unless `Dungeons.PlayerInside(ctx, quest)`. It is counted in `diag.dungeonDeferred` and the report says so.
- `Dungeons.PlayerInside`: the client's own instance state (`ctx.instance`). Unknown state = outside. Inside an instance the quest's dungeon name (game area name, else quest log heading) is compared with the instance name when both are known; when either is missing the player is taken to be inside (never block a player who is in a dungeon).
- Unchanged: candidate data (`Engine.Candidates` still holds the quest), the DUNGEON QUESTS card, hand-ins of dungeon quests, Elite and untagged quests, everything open-world. ALSO COMPLETE still never lists dungeon quests.
- No new API or telemetry. Tests: `tests/dungeon_now_tests.lua`. No golden changed.
- Real client: confirm `IsInInstance` / `GetInstanceInfo` names inside a real dungeon match the quest's dungeon name (so a dungeon quest becomes NOW inside), and that a dungeon objective no longer takes NOW from outside.

## 0.8.7 follow-up: inside the dungeon its objectives lead
Real report (Ruins of Lordaeron): the client said `IsInInstance` true, name "Ruins of Lordaeron"; Q92422 is a dungeon quest with no objective position, so it was a planner reminder and NOW stayed an ordinary hand-in. 0.8.6 only kept dungeon objectives out of NOW from outside; inside, "normal" meant needing a location, which an instance never gives.
- `Presenter.Guidance(plan, ctx, true)`: while the client says the player is inside a dungeon, that dungeon's unfinished objectives (game tag + `Dungeons.PlayerInside`) lead as GUIDANCE (quest log's own objective text, no place, no arrow), even over the planner's NOW. The planner is not changed; its NOW hand-in moves to READY TO TURN IN so it does not vanish.
- `Dungeons.PlayerInside` matches the instance name against the quest's area name OR its quest log heading.
- Tests: `dungeon_now_tests.lua` (inside / other dungeon / outside). No golden changed.

## 0.8.8: skipped dungeon quests are hidden from the DUNGEON QUESTS card
`Dungeons.List` (the only builder of that card) read `ctx.log` directly and ignored skips; every other list (`Providers/Quest.lua`, `Pr.Guidance`, `Pr.Unplaced`, `Overlap`) drops a quest whose `QT:<id>` key is skipped. `Dungeons.List` now does the same. Detection, the instance APIs, lead selection, NOW / READY / ALSO are unchanged. Tests: `dungeon_now_tests.lua`. No golden changed.
