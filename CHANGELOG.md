# Changelog

Forever Codex follows the version numbers in `forever-codex/docs/RELEASING.md` (`x.y.z`, patch digit 0-9). The first public release is described below; earlier builds were private test builds.

## [0.10.2] - release candidate for the first public release

Forever Codex: a free questing and leveling guide for WoW Forever.

### Quest guidance
- A tracker with **NOW** (the one thing worth doing), **ALSO COMPLETE / ALSO DO**, **READY TO TURN IN**, **DUNGEON QUESTS** and **NEW FOR YOU**, recomputed from your real position and quest log.
- Route styles (Efficient, Fast, Questing only, Completionist), a route zone you choose, skip / add quest, and a Hardcore option.
- A direction arrow and a waypoint that follows what Codex recommends, a minimap button and a world-map button, and an option to replace the game's quest tracker.
- Quests Codex cannot place on the map are still listed, with their objectives.
- Quest timers, quest-starting items, spell training and professions status, a journey log, and optional party progress cards.

### Honest quest data
- Quest availability is learned from what NPCs actually offer you; unconfirmed pickups are only ever "possible".
- Turn-in NPCs that are not known are said to be unknown, never assumed.
- Data from other sources (AllTheThings, optional QuestieDB) is labelled unverified; what the game client tells Codex always wins.

### Reward Advisor
- Icons on the game's own reward buttons: upgrade, not an upgrade, mixed, vendor (with the sell price beside the coin), not usable, unknown.
- A golden border and a star on the reward Codex recommends (hollow star = tentative); no recommendation means no border and no star.
- A one-line `CODEX: ...` addition to the game's tooltip.
- Legal equipment-slot handling (main hand, off hand, either hand, two-handed) and a conservative recommendation that never weighs different stats against each other, apart from a clear weapon-damage gain between two mixed weapons for Warriors and Rogues.

### Release preparation (this version)
- MIT licence and third-party notices (AllTheThings MIT notice, QuestieDB runtime-only note) now ship inside the addon.
- Public addon metadata (title, notes, author, licence) and no development-build labels in the interface.
- The diagnostic report (`/codex report`) is no longer called a playtest report.
- The release packager refuses stray files and skips hidden files; new tests cover the package contents.
- The repository was reorganised for public use (README, contributing guide, changelog, early experiments moved to `archive/`).
