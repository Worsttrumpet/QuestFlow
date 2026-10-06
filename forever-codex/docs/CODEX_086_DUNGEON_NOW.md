# 0.8.6: a dungeon objective is not NOW from outside its dungeon

0.8.5 playtest: NOW "Finish Serpentbloom (Dungeon)", Wailing Caverns, ~3150 yd, while standing in Durotar.

- `Planner.lua` stage 1 (`take`): an OBJECTIVE whose quest the game tags as dungeon / raid (`Dungeons.IsDungeon`, the existing tag logic) goes to the planner's `extras` (lower-priority, on-the-way only) unless `Dungeons.PlayerInside(ctx, quest)`. It is counted in `diag.dungeonDeferred` and the report says so.
- `Dungeons.PlayerInside`: the client's own instance state (`ctx.instance`). Unknown state = outside. Inside an instance the quest's dungeon name (game area name, else quest log heading) is compared with the instance name when both are known; when either is missing the player is taken to be inside (never block a player who is in a dungeon).
- Unchanged: candidate data (`Engine.Candidates` still holds the quest), the DUNGEON QUESTS card, hand-ins of dungeon quests, Elite and untagged quests, everything open-world. ALSO COMPLETE still never lists dungeon quests.
- No new API or telemetry. Tests: `tests/dungeon_now_tests.lua`. No golden changed.
- Real client: confirm `IsInInstance` / `GetInstanceInfo` names inside a real dungeon match the quest's dungeon name (so a dungeon quest becomes NOW inside), and that a dungeon objective no longer takes NOW from outside.
