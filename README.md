# Quest Flow

**A questing companion for WoW Forever.**

*See what's available. Choose what comes next.*

Quest Flow is an addon for World of Warcraft: Forever. It reads your character and your quest log and shows you what you could do now: what is nearby, what you can hand in, which dungeon quests you are carrying, and which quest reward looks best. It is **not** a step-by-step leveling guide or an autopilot. You decide what to do; Quest Flow shows the options and keeps up as you play.

> Status: release candidate. Built for the WoW Forever client (interface 16001), tested on client 1.60.1, build 70245. See [Known limitations](#known-limitations).

## What it does

- **NOW**: the one thing worth doing right now, with a short reason and a distance. It follows what you actually do: finish something unrelated, skip a suggestion or change zone, and NOW changes with you.
- **ALSO COMPLETE**: other objectives or pickups that fit in the same place, shown only when they genuinely fit.
- **READY TO TURN IN**: quests you can hand in, and where.
- **DUNGEON QUESTS**: the dungeon quests in your log. A dungeon objective is not offered as NOW while you are outside that dungeon.
- **NEW FOR YOU** and **possible pickups**: quests you may be able to start. A quest only counts as available once an NPC has actually offered it to you; before that it is just possible.
- **Reward advice**: icons on the game's own quest reward window (below).
- **Your choice**: skip anything, add a quest yourself, pick a route zone and style (Efficient, Fast, Questing only, Completionist), or ignore Quest Flow entirely.
- A compact tracker (it can replace the game's own), a direction arrow, a waypoint that follows NOW, a minimap button and a world-map button.
- **Travel that learns from you**: flights you take (with the real time they took), boats and zeppelins you ride, and your Hearthstone once Quest Flow has seen where you are bound. A route is only suggested when it beats walking, and only for ways Quest Flow has actually seen work. Nothing is guessed.
- **First-run welcome**: a short setup the first time you log in on a character (theme, tracker, arrow, route style). You can reopen it later from the settings.
- Also: spell training reminders, professions status, quest timers, quest-starting items, a journey log and optional party progress cards.

Quest Flow is read-only. It never accepts, completes or turns in quests, never sells or equips anything, and uses no protected game functions. Nothing is uploaded: everything it learns stays in your own saved variables.

### Honest about its data
WoW Forever is new and no complete, verified quest database exists. Quest Flow combines a small set of quests observed on Forever, the AllTheThings Forever data, and optionally QuestieDB, and labels all but the first as unverified. What your game client tells it (your quest log, what an NPC offers, whether an item is usable) outranks any database. Where it does not know something, such as a turn-in NPC, it says so instead of guessing.

## Reward advice

When a quest offers a choice of rewards, Quest Flow adds small icons to each reward button:

| Icon | Meaning |
|---|---|
| Up arrow | **UPGRADE** over what you wear |
| Down arrow | **NOT AN UPGRADE** |
| Up and down arrows | **MIXED**: gains some stats, loses others |
| Coin, with the sell price | **VENDOR**: nothing here is for you; this is what it sells for |
| X | **NOT USABLE** by your character |
| ? | **UNKNOWN**: Quest Flow cannot tell, for example when the client gives conflicting answers about whether you can use the item |

Hover a reward and Quest Flow adds one line to the game's tooltip, such as `QUEST FLOW: UPGRADE`. The game's own tooltip already shows the item's stats, so Quest Flow does not repeat them.

**Recommendation.** When Quest Flow actually recommends a reward, that reward gets a **golden border** and a **star** (a solid star is a firm recommendation; a hollow star is tentative, usually because it is not sure you can use the item). If it has no recommendation there is no border and no star, only the icons. A MIXED reward can still be the recommended one: the border says "take this", the icon says what it is.

The advisor is deliberately conservative: it compares each reward with what you wear in every slot it could legally go in (main hand, off hand, one-handed, two-handed...), uses no stat weights or spec guesses, and recommends only when the facts support it. When none of the choices is equipment, it tentatively recommends the one that sells for the most.

## Installation

1. Quit WoW.
2. Download the latest `QuestFlow-<version>.zip` from the Releases page.
3. Unzip it into your AddOns folder (for example `World of Warcraft/_classic_/Interface/AddOns/`) so you end up with `.../AddOns/QuestFlow/QuestFlow.toc`. When updating, replace the old `QuestFlow` folder.
4. Start WoW and make sure **Quest Flow** is enabled at character select.
5. Log in and type `/qflow` to open it and choose where you want to level and how you like to play.

Optional: the separate **QuestieDB** addon, if installed, is used as an extra unverified quest source. It is not required.

## Basic usage

- `/qflow` opens or closes the tracker. Follow **NOW** if you like, or do something else.
- **Show on Map** places the game's waypoint; **Skip** drops a suggestion.
- Open a quest reward with several choices and read the icons. A golden border and star means Quest Flow recommends that reward.
- Something wrong? Use the **Feedback** button (see Reporting bugs).

## Slash commands

`/qflow` (also `/questflow`; the earlier working name `/codex` still works as an alias):

| Command | What it does |
|---|---|
| `/qflow` | Show or hide the tracker |
| `/qflow options` / `world` / `journey` / `appendices` | Open that tab |
| `/qflow setup` | Run the first-time setup again |
| `/qflow next` | Print the recommended next action |
| `/qflow style [key]`, `/qflow zone [key\|auto]` | Route style, route zone |
| `/qflow skip` / `unskip`, `add <id\|name>` / `remove <id>` | Skip, add or remove quests |
| `/qflow arrow [on\|off\|flip\|reset]` | Direction arrow |
| `/qflow tracker [on\|off]`, `nav [on\|off]` | Replace the game's tracker, waypoint following |
| `/qflow party [off\|ui\|log]` | Party progress cards |
| `/qflow hardcore on\|off` | Hardcore character |
| `/qflow questiedb [on\|off]` | Use QuestieDB data if installed |
| `/qflow spells`, `/qflow professions` | Spell training and professions status |
| `/qflow feedback` | Report a problem |
| `/qflow report` | The diagnostic report, in a window you can copy |
| `/qflow help` | List every command |

## Compatibility

Built for the WoW Forever client (interface 16001) and tested on client 1.60.1, build 70245. Other clients and non-English clients have not been tested. QuestieDB is optional; no other addon is required or read.

## Known limitations

- **Quest data is incomplete.** Some quests have no known location and are listed without an arrow. Quests are only called available once an NPC has offered them to you.
- **Some quests have no known objective place.** The data has no position for them, so Quest Flow says "Place not known: see your quest log" instead of guessing, and it will not make them your NOW until you have started them.
- **Travel is learned from your own play.** A flight, boat or zeppelin is only used after you have done it (or the flight map showed it), in the direction you did it. Times you have not measured are marked as estimates.
- **Tested so far on a small group of characters** (mostly one Horde druid). Other classes, Alliance characters and unusual setups may show problems we have not seen: please report them.
- **Reward advice is conservative.** It handles equipment and vendor value; it does not know your spec, does not weigh different stats against each other (apart from a clear weapon-damage gain between two mixed weapons for Warriors and Rogues), and does not know future needs such as professions. When the client's answers about whether you can use an item disagree, Quest Flow says so and marks its choice tentative.
- **Reward icons and the tooltip line depend on the game's reward window.** They were checked on the Forever client; a custom interface skin could move them.
- Using quest items from the tracker, spec-aware advice and custom routes are not part of this release ([docs/FUTURE_IDEAS.md](docs/FUTURE_IDEAS.md)).

## Reporting bugs

Use the **Feedback** button in the window and paste the text into a new GitHub issue; it contains your class, level, faction, race, position and quest log but not your character name, realm or account. For a fuller report type `/qflow report`, copy the text (Ctrl+C) and attach it; **that report does include your character name and realm** (in the first line, the character line and the saved-data line), so edit them out first if you prefer. Nothing is ever sent for you.

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Repository layout

```
questflow/QuestFlow/   the addon (this folder is what gets installed)
questflow/tests/       Lua 5.1 stub-client tests
questflow/generator/   data-pack generator and release packager (with tests)
questflow/docs/        design notes (written under the working name "Forever Codex"), data sources, release process
forever-db/            offline dataset tooling used to build and audit the data
docs/, manifests/, research/, m5-*/, m6-*/   research material behind forever-db
archive/               early experiments, kept for history only
```

## License and attribution

Quest Flow is released under the [MIT License](LICENSE). It includes quest, flight-path and zone data derived from [AllTheThings](https://github.com/ATTWoWAddon/AllTheThings) (MIT), plus quest facts observed on Forever by this project, and optionally reads the separately installed QuestieDB addon at runtime without copying anything from it. Full notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) (also shipped inside the addon).

World of Warcraft is a trademark of Blizzard Entertainment, Inc. Quest Flow is an independent fan-made addon, not affiliated with or endorsed by Blizzard Entertainment or the WoW Forever project.
