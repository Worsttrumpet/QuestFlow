# Changelog

Quest Flow follows the version numbers in `questflow/docs/RELEASING.md` (`x.y.z`, patch digit 0-9). Earlier builds were private test builds under the working name Forever Codex and are not listed.

## [0.13.0] - a proper welcome for new characters

- **A first-run welcome in three short steps.** (1) What Quest Flow is, with NOW and ALSO DO explained in a line each, and a note that it uses what the game itself offers rather than assuming every quest it knows is available. (2) How it looks and what is on screen: the theme (the window changes as you pick), the quest tracker, the map waypoint and the direction arrow. (3) Your route: where to level, how to play, and what else to look out for, then **Get Started**.
- Each character gets its own welcome. A character that used Quest Flow before this version sees it once, and nothing it saved is touched. `/qflow setup` (or "Run setup again" in Options) shows it again without resetting anything.
- Quest Flow works normally while the welcome is open.

## [0.12.2] - real flights are now recorded

- **A flight you take is now measured and remembered.** Before, a completed flight was missed because Quest Flow could not tell which destination the game's flight call meant. It now follows each flight from selection to landing, records the real time, and the planner uses that time for that flight from then on (other flights still use a labelled estimate).
- A flight only counts when it started and you landed near the destination. A flight that never started, ended early or could not be matched to a destination is counted but never becomes a route, and no time is made up for it.
- `/qflow report` now keeps the stages apart: paths listed, paths you have, flights offered, flights taken, started, completed, measured, and an observed route registered.
- The "What Quest Flow knows" page now scrolls, and its seven buttons fit the window.

## [0.12.1] - fixes from the first level 17 dungeon test

- **Dungeon hand-ins are no longer dropped for being on the next map.** Quest Flow treated only the map you stand on as "here", so the Ruins of Lordaeron hand-ins just outside Undercity (a different map, about 240 yards away) were left out of the plan. "Here" is now your map or anything within 600 yards, and work toward your dungeon goal is never dropped for being on another map.
- **The arrow now shows for a hand-in at a named NPC from up to 1500 yards** (it appeared only inside about 650 yards before). Objective areas still need 600 yards, because an area's centre is not a place.
- **Weak chain links are no longer a reason.** A low quest now survives only if it leads to a quest within 3 levels of yours (or one you hold, or a dungeon quest), and is then worth less than that quest.
- **Hearthstone:** if the client has no item-count function, Quest Flow now finds the Hearthstone by scanning your bags.

## [0.12.0] - what comes next is what is worth doing, not what is closest

### Better recommendations
- Being available no longer makes a quest a recommendation. Quests are now judged by level (current, low, gray, above) and by whether they serve what you are doing before they are valued.
- Gray quests (far below your level) and quests far above you are left out unless there is a reason: you added them, they are dungeon quests, or they lead to a quest you hold or a fitting one. Low quests are discounted.
- If your quest log holds dungeon quests, those hand-ins and the quests leading to them now count for more, and low quests need a reason to be suggested.
- Seasonal and holiday quests are left out of the normal route. `/qflow seasonal on` includes them, and they are still only suggested when the game itself offers them.

### Explains itself
- `/qflow report` gains a PLANNER FUNNEL section: the quests rejected (with the reason), penalised or boosted, your current goal, and why NOW was chosen.

### Compatibility
- No setting, saved data or command changed except the new `/qflow seasonal`. Quests with no known level are not judged by level.

## [0.11.0] - world and travel knowledge

### Flight paths and travel
- Quest Flow now reads **your** flight paths from the game's own taxi map when you open a flight master. It keeps "this flight path exists" apart from "you have it": a path never seen on your taxi map is unknown, never assumed.
- When a flight you have is offered and quicker than walking, the plan shows a **Fly** step that leads you to the flight master first, then the walk from where you land. Flight times use the real time of a flight once you have taken it (estimates are labelled).
- The Hearthstone is suggested only when it is ready, you have bound at an innkeeper while Quest Flow was running, and it saves a lot of walking.
- Flight hints are no longer shown for paths your taxi map has already shown. Boats and zeppelins are not routed (no reliable data); a quest's own text still tells you to follow them.

### What Quest Flow learns as you play
- Vendors (with repair), trainers, flight masters and innkeepers you open, and dungeon entrances (recorded when you enter a dungeon from outside). `/qflow services` lists them.
- Money and Hearthstone state are read for the planner.

### Clearer knowledge page
- Appendices > What Quest Flow knows is now seven categories (Quests, World, Travel, You, Planner, Navigate, More), computed from what Quest Flow actually holds, and honest about what is not known yet.
- `/qflow report` gains a World and Travel section with PASS / FAIL / PENDING checks for this client.

### Compatibility
- No existing setting, saved data or command changed. With no taxi or bind evidence, recommendations are exactly as before.

## [0.10.6] - release candidate for the first public release

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
- The diagnostic report and the shipped data manifest no longer show the internal data tag or the old working name; a test now scans every command's output, the windows, the report and the feedback text for any leftover "Codex".
- Characters with a first and last name (WoW Forever returns them as two values) are shown in full, for example in the diagnostic report. Saved settings are still keyed by the first name only, so nothing saved is lost.
- The minimap button, the world-map button and the add-on list entry (set with the `.toc` `IconTexture` line) now show the Quest Flow logo, and the old logo is gone from the addon. The add-on list icon and the buttons use the same 128 x 128 picture: the list shows it as a small square icon and the buttons draw it inside the game's round ring, so no separate file is needed.
- MIT license and third-party notices (AllTheThings MIT notice, QuestieDB runtime-only note) ship inside the addon. The release packager refuses stray files.
