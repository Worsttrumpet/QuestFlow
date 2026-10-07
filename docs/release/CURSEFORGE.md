# CurseForge: copy and metadata for Quest Flow (prepared in the repository; the project page itself is created by hand)

Nothing here was uploaded. Screenshots are taken later from the finished client and are not included.

## Project fields
| Field | Value |
|---|---|
| Name | Quest Flow |
| Summary (one line) | A questing companion for WoW Forever. See what's available. Choose what comes next. |
| Main category | Quests and Leveling (plus Map and Minimap, Tooltip, if you want more tags) |
| Game / version | WoW Forever client. Addon interface number 16001 (tested on client 1.60.1, build 70245) |
| License | MIT (repository `LICENSE`, confirmed by the owner) |
| Source | https://github.com/Worsttrumpet/questflow |
| File to upload | `questflow/dist/<major>.<minor>/QuestFlow-<version>.zip` (top folder `QuestFlow/`, `QuestFlow.toc` inside it) |
| Logo / icon | `docs/release/questflow-logo.png` (1254 x 1254, the owner's logo) is the source for the project icon you upload by hand; the in-game button and add-on list icon are `QuestFlow/Media/QuestFlowLogo.tga`, made from it by `questflow/generator/make_logo.py` |

## Project description (long)
**Quest Flow: a questing companion for WoW Forever.** *See what's available. Choose what comes next.*

Quest Flow reads your character and your quest log and shows you what you could do now. It is not a step-by-step leveling guide or an autopilot: you decide what to do, and it keeps up. It never accepts, completes or turns in quests, and it does not sell or equip anything.

**What it shows**
- **NOW**: the one thing worth doing right now, with a short reason and distance.
- **ALSO COMPLETE**: other objectives or pickups that fit in the same place.
- **READY TO TURN IN** and **DUNGEON QUESTS** lists, and **NEW FOR YOU** pickups. Dungeon objectives are not offered as NOW while you are outside the dungeon.
- A compact tracker (it can replace the game's own), a direction arrow and a waypoint that follows NOW, a minimap button and a world-map button.
- Route styles (Efficient, Fast, Questing only, Completionist), your own route zone, skip and add quests, and a Hardcore option.

**Reward advice**
- Small icons on the game's own quest reward buttons: Upgrade, Not an upgrade, Mixed, Vendor (with the sell price beside the coin), Not usable, Unknown.
- A golden border and a star on the reward Quest Flow recommends; a hollow star means tentative. No recommendation means no border.
- One short line, such as `QUEST FLOW: UPGRADE`, added to the game's tooltip.
- Handles main-hand, off-hand, one-handed and two-handed items, with no stat weights or spec guesses.

**Honest about its data.** WoW Forever is new and no complete quest database exists. Quest Flow learns what NPCs really offer you, trusts your game client first, labels every other source as unverified, and says "I don't know" instead of guessing a location or turn-in NPC.

**Also included**: spell training reminders, professions status, quest timers, quest-starting items, a journey log, optional party progress cards and a Report a problem button.

**Install**: unzip into `Interface/AddOns/` so you have `AddOns/QuestFlow/QuestFlow.toc`, then type `/qflow`.

**Optional**: the separate QuestieDB addon is used as an extra, unverified quest source if installed. Nothing from it is copied.

**Privacy**: nothing is uploaded; everything stays in your own saved variables.

**Compatibility**: built for WoW Forever (interface 16001), tested on client 1.60.1 build 70245. Other clients are untested.

**Not affiliated with Blizzard Entertainment or the WoW Forever project.**

## Release notes (paste into the file's changelog box)
Use the matching section of `CHANGELOG.md`.

## Third-party and licensing statement (for the project page)
Quest Flow is MIT licensed. It includes quest, flight-path and zone data derived from AllTheThings (MIT; notice included in the download) and quest facts observed on Forever by this project. It optionally reads the separately installed QuestieDB addon at runtime and copies nothing from it. See `THIRD_PARTY_NOTICES.md` (also inside the download).

## Notes
- No CurseForge-only files are needed in the repository or the ZIP. A `.pkgmeta` / CurseForge packager workflow was considered and not added: the addon lives in a sub-folder and the ZIP is built and checked by `questflow/generator/package_addon.py`, so a manual upload keeps one build path.
- The `## X-Curse-Project-ID` (and similar) TOC lines can be added after the project exists; they are optional.

## Manual steps (cannot be done from the repository)
1. ~~Rename the GitHub repository~~ **Done**: it is now `Worsttrumpet/questflow` (renamed from `wow-forever-guide`; GitHub redirects the old address). The README, `QuestFlow.toc` (`X-Website`) and this file already use `https://github.com/Worsttrumpet/questflow`.
2. Make the repository public when you are ready (read the history note in `questflow/docs/CODEX_DATA_SOURCES.md` first).
3. Create the GitHub Release and attach `QuestFlow-<version>.zip`, with the matching `CHANGELOG.md` text.
4. Create the CurseForge project from the fields above, upload the same ZIP, add screenshots and the logo (made by hand).
