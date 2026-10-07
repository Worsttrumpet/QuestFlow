# Changelog

Quest Flow follows the version numbers in `questflow/docs/RELEASING.md` (`x.y.z`, patch digit 0-9). Earlier builds were private test builds under the working name Forever Codex and are not listed.

## [0.10.3] - release candidate for the first public release

**Quest Flow: a questing companion for WoW Forever.** See what's available. Choose what comes next.

### Quest guidance
- A tracker with **NOW**, **ALSO COMPLETE / ALSO DO**, **READY TO TURN IN**, **DUNGEON QUESTS** and **NEW FOR YOU**, recomputed from your real position and quest log. You stay in control: skip, add a quest, choose a route zone and style (Efficient, Fast, Questing only, Completionist), or ignore it.
- A direction arrow and a waypoint that follows NOW, a minimap button, a world-map button, and an option to replace the game's quest tracker.
- Quests Quest Flow cannot place on the map are still listed, with their objectives.
- Quest timers, quest-starting items, spell training and professions status, a journey log, and optional party progress cards.

### Honest quest data
- Availability is learned from what NPCs actually offer you; unconfirmed pickups are only ever "possible".
- Turn-in NPCs that are not known are said to be unknown, never assumed.
- Data from other sources (AllTheThings, optional QuestieDB) is labelled unverified; what the game client reports always wins.

### Reward advice
- Icons on the game's own reward buttons: upgrade, not an upgrade, mixed, vendor (with the sell price beside the coin), not usable, unknown.
- A golden border and a star on the reward Quest Flow recommends (hollow star = tentative). No recommendation means no border and no star.
- One line, such as `QUEST FLOW: UPGRADE`, added to the game's tooltip.
- Legal equipment-slot handling (main hand, off hand, either hand, two-handed) and a conservative recommendation that never weighs different stats against each other, apart from a clear weapon-damage gain between two mixed weapons for Warriors and Rogues.

### Naming and packaging
- The addon is now **Quest Flow** (folder `QuestFlow`, package `QuestFlow-<version>.zip`). Commands: `/qflow` and `/questflow`; the earlier `/codex` and `/fcodex` still work.
- Saved settings keep the saved-variable name `ForeverCodexDB`. Because the addon folder changed, the game stores it in a new file (`WTF/Account/<account>/SavedVariables/QuestFlow.lua`); to carry over settings from an earlier test build, copy `ForeverCodex.lua` there under that name while the game is closed.
- MIT license and third-party notices (AllTheThings MIT notice, QuestieDB runtime-only note) ship inside the addon. The release packager refuses stray files.
