# Forever Codex

**A free questing and leveling guide for WoW Forever.**

Forever Codex looks at your character (class, race, faction, level, where you are, and what is in your quest log) and tells you what to do next. It shows a compact quest tracker, points a small arrow at your current target, and helps you choose quest rewards. You stay in control: it makes suggestions, it never plays for you.

> Status: pre-release. Built for the WoW Forever client (interface 16001) and tested on client 1.60.1, build 70245. See [Known limitations](#known-limitations).

## What makes it different

- **It plans around you, not a fixed script.** There is no fixed levelling path. Codex recomputes from your real position and quest log, so doing something unrelated, skipping a quest or changing zone simply changes the plan.
- **It is honest about what it knows.** Quest data for a brand new server is incomplete. Codex labels where each fact came from, treats anything it has not seen on Forever as unverified, and says "I don't know" instead of guessing a location or a turn-in NPC.
- **It learns from the client.** What an NPC actually offered you, what your quest log says, what the game reports as usable: that outranks any database.
- **It is read-only.** It never accepts, completes or turns in quests, never sells or equips anything, and does not use protected game functions.
- **Nothing leaves your computer.** There is no network access in WoW addons. What Codex notices is saved in your own saved variables.

## Main features

### Quest routing and planning
- **NOW**: the one thing worth doing right now, with a short reason and how far away it is. Work you can finish where you are standing is favoured over long trips, and quests you are already working on are favoured over starting new ones far away.
- **ALSO COMPLETE / ALSO DO**: only when something genuinely fits on the way (another objective in the same place, a pickup close to your route).
- **READY TO TURN IN**, **DUNGEON QUESTS** and **NEW FOR YOU** lists. Dungeon objectives are not made NOW while you are outside that dungeon.
- **Route styles**: Efficient, Fast, Questing only, Completionist. Choose your route zone, skip any recommendation, add a quest yourself, or mark a Hardcore character.
- Quests Codex cannot place on the map still appear, with their objectives, so nothing in your log is hidden.

### Nearby guidance, tracker and arrow
- A compact tracker window (`/codex`, or the minimap button, or the button on the world map) that can replace the game's own tracker.
- The game's own map waypoint follows NOW, and an optional on-screen direction arrow points at it. Your own waypoints are left alone.

### Quest availability and actionability
- Codex remembers what each NPC actually offered you. A quest whose giver was asked at your current progress and did not offer it is held back instead of being sent to you as if it were available.
- Unconfirmed pickups are shown as possible, kept as small extras, and never as certain.
- Where a turn-in NPC is not known, Codex says so rather than assuming it is the quest giver.

### Reward Advisor
When you open a quest reward with several choices, Codex adds small icons to the game's own reward buttons so you can see its opinion without opening anything:

| Icon | Meaning |
|---|---|
| Up arrow | UPGRADE over what you wear |
| Down arrow | NOT AN UPGRADE |
| Up and down arrows | MIXED: gains some stats, loses others |
| Coin, with the sell price | VENDOR: nothing here is for you, this is what it sells for |
| X | NOT USABLE by your character |
| ? | UNKNOWN: Codex cannot tell (for example when the client gives conflicting answers about whether you can use it) |

Hovering a reward adds one line to the game's tooltip, such as `CODEX: UPGRADE`. The game's own tooltip already has the item's stats, so Codex does not repeat them.

### Recommendation and the golden border
When Codex actually recommends one reward, that reward gets a **golden border** and a **star**, so you can see at a glance which to take. A solid star is a firm recommendation; a hollow star is a tentative one (Codex has a best choice, but something it needs to be sure of, usually whether you can use the item, is unclear). The border is separate from the icons: a MIXED reward can still be the recommended one.

If Codex has no recommendation there is no border and no star, just the icons for each reward.

The advisor is deliberately conservative. It compares each reward with the item you wear in every legal slot (main hand, off hand, one-handed, two-handed and so on), does not use stat weights or spec guesses, and only makes a recommendation when the facts support one.

### Vendor recommendations
Sell values are shown directly beside the coin, so you do not need the tooltip to compare them. When none of the choices is equipment, Codex tentatively recommends the one that sells for the most. It never recommends selling gear on a guess.

### Also included
Spell training (class spells the trainer window listed, for you to decide), professions status, quest timers (a timed quest becomes urgent as the clock runs down), quest-starting items in your bags, a journey log of your progress, optional party progress cards with other Codex users, and a "Report a problem" button.

## Installation

1. Quit WoW.
2. Download the latest `ForeverCodex-<version>.zip` from the project's Releases page.
3. Unzip it into your AddOns folder, for example `World of Warcraft/_classic_/Interface/AddOns/`, so that you end up with `.../AddOns/ForeverCodex/ForeverCodex.toc`. If you are updating, replace the old `ForeverCodex` folder.
4. Start WoW and make sure **Forever Codex** is enabled on the character select screen.
5. Log in. You will see a short welcome line. Type `/codex` to open Codex and choose where you want to level and how you like to play.

Optional: install the separate **QuestieDB** addon if you want Codex to use its quest data as an additional, unverified source. It is not required (see [Third-party notices](#license-and-attribution)).

## Basic usage

- `/codex` opens or closes the tracker. The first time it asks where you want to level.
- Follow **NOW**. Press **Show on Map** to place a waypoint, **Skip** to move on, or ignore Codex entirely; it will adapt.
- Open a quest reward with several choices and look at the icons. Gold border and star means Codex recommends it.
- Something wrong? Use the **Feedback** button in the window (see below).

## Slash commands

`/codex` (or `/fcodex`):

| Command | What it does |
|---|---|
| `/codex` | Show or hide the tracker |
| `/codex options` / `world` / `journey` / `appendices` | Open that tab |
| `/codex setup` | Run the first-time setup again |
| `/codex next` | Print the recommended next action |
| `/codex style [key]` | List or set the route style |
| `/codex zone [key\|auto]` | List or set the route zone |
| `/codex skip` / `unskip` | Skip the current recommendation / bring skipped items back |
| `/codex add <id\|name>` / `remove <id>` | Add or remove a quest on your route |
| `/codex arrow [on\|off\|flip\|reset]` | The direction arrow |
| `/codex tracker [on\|off]` | Hide the game's tracker so Codex's replaces it |
| `/codex nav [on\|off]` | The waypoint that follows what Codex recommends |
| `/codex party [off\|ui\|log]` | Party progress cards |
| `/codex hardcore on\|off` | Hardcore character (never suggests anything that needs you to die) |
| `/codex questiedb [on\|off]` | Use QuestieDB data if installed |
| `/codex spells`, `/codex professions` | Spell training and professions status |
| `/codex feedback` | Report a problem |
| `/codex report` | The diagnostic report, in a window you can copy |
| `/codex help` | List every command |

## Compatibility

- Built for the **WoW Forever** client (interface 16001). Developed and tested on client 1.60.1, build 70245.
- Other clients or versions have not been tested.
- QuestieDB is optional. Other addons are not required and are not read.

## Known limitations

- **Quest data is incomplete.** WoW Forever is new and no complete, verified quest database exists. Codex combines a small set of quests observed on Forever, the AllTheThings Forever data, and (optionally) QuestieDB, and labels all but the first as unverified. Some quests have no known location and are listed without an arrow.
- **Availability is learned as you play.** A quest can only be called available once an NPC has offered it to you; before that Codex can only call it possible.
- **The Reward Advisor is conservative.** It handles equipment and vendor value. It does not know your spec, does not weigh different stats against each other, and does not know future needs such as professions. For a Warrior or a Rogue it treats intellect and spirit as irrelevant. When the client's answers about whether you can use an item disagree, Codex says so and marks its choice tentative instead of claiming certainty.
- **The tooltip line and reward icons depend on the game's reward window.** They have been checked on the Forever client; a different interface skin could move them.
- Quest-item use, spec-aware advice and custom routes are not part of this release (see [docs/FUTURE_IDEAS.md](docs/FUTURE_IDEAS.md)).

## Reporting bugs

Use the **Feedback** button in the Codex window and paste the text it gives you into a new GitHub issue. For a fuller report type `/codex report`, copy the text (Ctrl+C) and attach it. Reports contain your class, level, faction, race, position and quest log, but not your character name, realm or account, and nothing is ever sent for you.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to run the tests and how releases are built.

## Repository layout

```
forever-codex/ForeverCodex/   the addon (this folder is what gets installed)
forever-codex/tests/          Lua 5.1 stub-client tests
forever-codex/generator/      data-pack generator and release packager (with tests)
forever-codex/docs/           design notes, data sources, release process
forever-db/                   the offline dataset tooling used to build and audit the data
docs/, manifests/, research/, m5-*/, m6-*/   research material behind forever-db
archive/                      early experiments, kept for history only
```

## License and attribution

Forever Codex is released under the [MIT License](LICENSE).

It includes quest, flight-path and zone data derived from [AllTheThings](https://github.com/ATTWoWAddon/AllTheThings) (MIT), plus quest facts observed on Forever by this project. Optionally it reads the separately installed QuestieDB addon at runtime; nothing from it is copied or redistributed. Full notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), which also ships inside the addon.

World of Warcraft is a trademark of Blizzard Entertainment, Inc. Forever Codex is an independent fan-made addon and is not affiliated with or endorsed by Blizzard Entertainment or the WoW Forever project.
