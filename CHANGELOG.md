# Changelog

Quest Flow follows the version numbers in `questflow/docs/RELEASING.md` (`x.y.z`, patch digit 0-9). Earlier builds were private test builds under the working name Forever Codex and are not listed.

## [0.15.2] - report: what the client exposes for Legacy, attunements and talents (probe only)

- Report only. A new FEATURE PROBE section asks the client, read-only, for the game's Legacy achievement categories (and the first achievements in them), any Legacy currency such as Legacy Points, global names that mention Legacy, Attunement or Keystone, and which talent functions exist. Nothing reaches the planner or the window: it only shows what a later feature could be built on.

## [0.15.1] - report: does the game's quest map know quests in other zones?

- Read-only probe, report only. For quests Quest Flow cannot place, the report now also asks the game's own quest map about every Kalimdor and Eastern Kingdoms zone map (not only the zone you stand in) and lists where the game puts each quest. Nothing reaches the planner yet: this only shows whether the game can fill the gap.

## [0.15.0] - boats and zeppelins you ride become routes

- Quest Flow ships no boat or zeppelin data, so it could never plan one. It now learns them from rides you make: when a loading screen takes you to another continent and nothing else explains it (no Hearthstone, flight, summon, spell, instance or death), you had been carried after standing still, and you stand still again at the far end, the ride is recorded (start place, dock place, shortest time, how often). Each recorded ride is offered to the planner as a transport, in the direction you rode it, only when it beats walking. The way back stays unknown until you ride it.
- The report lists the rides and why other jumps were not recorded. Nothing is recorded when any part is missing.

## [0.14.6] - one bind is counted once

- Binding at an innkeeper works on the real client (bind point learned on the right zone map, innkeeper recorded). The client reports one bind twice; the second report was counted as an "unplaced" bind in the report. It is now recognised as the same bind. Report wording only; nothing changes in what is learned or routed.

## [0.14.5] - a Hearthstone trip no longer records the loading-screen position

- The first real Hearthstone trip recorded the bind point on the whole-continent map (the client answers that way while the loading screen ends), not on the zone you arrived in. An arrival is now accepted only on a zone-level map, and only when it reads the same place twice in a row. An old record of that kind is ignored, so the bind point is learned again from the next trip (or from binding at an innkeeper).

## [0.14.4] - the bind point can be learned from a Hearthstone trip

- A character bound long ago never shows Quest Flow the innkeeper, so the Hearthstone route could never be offered. Now, when a Hearthstone cast completes and the character then arrives somewhere else, that arrival place is recorded as the bind point (marked as learned from the trip). Binding at an innkeeper still works as before.
- The report says how the bind point was learned and whether the client gives the bind location NAME (a name is never used as a place).
- Still nothing is guessed: no bind point is recorded from a cast alone, from a name, or from an arrival long after the cast.

## [0.14.3] - tracker: click the NOW quest; fold away "in your log, not on the map"

- **Clicking the NOW quest title now opens that quest's details** (it did nothing when the quest had a map position). The route is not changed by opening or closing the details.
- **"IN YOUR LOG, NOT ON THE MAP" can be minimised.** Click its header to fold it to one line with the count; the choice is remembered. It is now the last section of the list.
- Quests with no known objective place are a data gap (Questie/ATT coverage), not a planner fault; nothing is guessed for them.

## [0.14.2] - the report explains optional pickups correctly

- The report's "why it can be recommended" line for a pickup the game has not offered still said unknown pickups are allowed. Since 0.14.0 they are only optional, so it now says why it is only OPTIONAL (listed, may be an ALSO DO, never NOW / THEN until the game offers it). No planning change.

## [0.14.1] - flights confirmed; a quest with no place no longer outranks real work

- **Flights work on the real client.** A Thunder Bluff to Orgrimmar flight was recorded end to end (selected, started, completed, 207 s measured) and is now an observed route the planner uses with its real time.
- **A quest with no known place and no progress no longer becomes NOW ahead of your hand-ins.** Before, an unstarted quest such as one whose objective Quest Flow cannot place counted as "work in this area", so six ready hand-ins waited behind an instruction with no destination. Only work the quest log shows you have started now counts as work in the area.
- The NOW row for a quest with no known place now says "Place not known: see your quest log", next to the game's own objective counts.

## [0.14.0] - unknown pickups are suggestions, not route steps

- **Quest Flow no longer plans a route through a quest the game has not offered you.** A pickup is a committed step (NOW / THEN) only when the game itself offered it. One Quest Flow merely knows about from its data stays an optional suggestion: it can still appear as an ALSO DO beside your route, marked "not offered yet", or be listed in the report, but you are never sent somewhere as if it were available.
- If the NPC was asked recently and did not offer the quest, it is held back as before; an old "not offered" answer expires when you progress, as before. Quests already in your log, hand-ins and quests you added yourself are not affected.
- The report says why: `AVAILABLE: client offered`, `UNKNOWN: no client offer evidence`, `HELD: fresh not-offered evidence`, `OPTIONAL: unknown availability`, with the counts.
- With nothing offered yet (for example a new character), the tracker says how many pickups it knows of that have not been offered to you, and that talking to their givers lets Quest Flow plan them.

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
