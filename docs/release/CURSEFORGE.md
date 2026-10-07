# CurseForge: copy and metadata (prepared in the repository; the project page itself is created by hand)

Nothing here was uploaded. Screenshots are taken later from the finished client and are not included.

## Project fields
| Field | Value |
|---|---|
| Name | Forever Codex |
| Summary (one line) | A free questing and leveling guide for WoW Forever: what to do next, a quest tracker and arrow, and a reward advisor. |
| Main category | Quests and Leveling (plus Map and Minimap, Tooltip, if you want more tags) |
| Game / version | WoW Forever client. Addon interface number 16001 (tested on client 1.60.1, build 70245) |
| License | MIT (the license choice is the owner's; the repository has an MIT `LICENSE`) |
| Source | https://github.com/Worsttrumpet/wow-forever-guide (change if the repository is renamed) |
| File to upload | `forever-codex/dist/<major>.<minor>/ForeverCodex-<version>.zip` (top folder `ForeverCodex/`, `.toc` inside it) |
| Logo / icon | made by hand later; the addon has no logo requirement |

## Project description (long)
**Forever Codex is a free questing and leveling guide for WoW Forever.**

It looks at your character (class, race, faction, level, where you are and what is in your quest log) and tells you what to do next. It never plays for you: it will not accept, complete or turn in quests, and it does not sell or equip anything. Ignore it whenever you like and it simply adapts.

**Quest guidance**
- NOW: the one thing worth doing right now, with a short reason.
- ALSO COMPLETE and ALSO DO: only when something genuinely fits on the way.
- READY TO TURN IN, DUNGEON QUESTS and NEW FOR YOU lists.
- Route styles: Efficient, Fast, Questing only, Completionist. Pick your route zone, skip anything, add quests, mark a Hardcore character.
- A compact tracker, a direction arrow, a waypoint that follows what Codex recommends, a minimap button and a world-map button.

**Honest about its data**
WoW Forever is new and no complete quest database exists. Codex learns what NPCs really offer you, uses what your game client reports first, labels every other source as unverified, and says "I don't know" instead of guessing a location or turn-in NPC.

**Reward Advisor**
- Small icons on the game's own quest reward buttons: Upgrade, Not an upgrade, Mixed, Vendor (with the sell price beside the coin), Not usable, Unknown.
- A golden border and a star on the reward Codex recommends. A hollow star means a tentative recommendation. No recommendation means no border.
- One short line, such as `CODEX: UPGRADE`, added to the game's tooltip.
- Handles main-hand, off-hand, one-handed and two-handed items, without stat weights or spec guesses.

**Also included**: spell training reminders, professions status, quest timers, quest-starting items, a journey log, optional party progress cards, and a Report a problem button.

**Install**: unzip into `Interface/AddOns/` so you have `AddOns/ForeverCodex/ForeverCodex.toc`, then type `/codex`.

**Optional**: the separate QuestieDB addon is used as an extra, unverified quest source if installed. Nothing from it is copied.

**Privacy**: nothing is ever uploaded; everything Codex learns stays in your own saved variables.

**Compatibility**: built for WoW Forever (interface 16001), tested on client 1.60.1 build 70245. Other clients are untested.

**Not affiliated with Blizzard Entertainment or the WoW Forever project.**

## Release notes (paste into the file's changelog box)
Use the matching section of `CHANGELOG.md`.

## Third-party and licensing statement (for the project page)
Forever Codex is MIT licensed. It includes quest, flight-path and zone data derived from AllTheThings (MIT; notice included in the download) and quest facts observed on Forever by this project. It optionally reads the separately installed QuestieDB addon at runtime and copies nothing from it. See `THIRD_PARTY_NOTICES.md` (also inside the download).

## Notes
- No CurseForge-only files are needed in the repository or the ZIP. A `.pkgmeta` / CurseForge packager workflow was considered and not added: the addon lives in a sub-folder and the ZIP is built and checked by `forever-codex/generator/package_addon.py`, so a manual upload keeps one build path.
- The `## X-Curse-Project-ID` (and similar) TOC lines can be added after the project exists; they are optional.
