> **Superseded for players.** This guide covers the 0.1 engineering build and the developer window (`/codex dev`, which
> still has Show on Map, Skip, Add quest and the route pickers). Friends testing the player build (0.2 alpha) should use
> `CODEX_FRIEND_TEST_GUIDE.md`. Package names below refer to the old 0.1 zip, which is no longer in `dist/`.

# Forever Codex 0.1 "First Light": real-client test guide

About 20 minutes for the full pass; checkpoint 1 alone takes 2. Nothing here changes your characters: Codex never
accepts, completes or turns in quests. **Status: this has NOT been run on the real client yet.** The Lua stub tests
only prove Codex's own logic (see the test report); this guide is how we find out what Forever actually does.

## Install

1. Exit WoW completely (a brand-new addon is only detected on a fresh start).
2. Copy the folder `forever-codex/ForeverCodex` (or unzip `dist/ForeverCodex-codex-0.1-first-light.zip`) into
   `E:\World of Warcraft\_classic_beta_\Interface\AddOns\` so you end up with
   `...\AddOns\ForeverCodex\ForeverCodex.toc` (not nested one level deeper).
3. Start WoW. At character select click **AddOns** and confirm **Forever Codex (0.1 First Light, dev build)** is
   enabled. (ForeverQuestGuide can stay installed; the two minimap buttons sit one above the other.)
4. Log in with the character you want to test. Type `/console scriptErrors 1` so Lua errors pop up.

## Checkpoint 1 - the addon loads and detects the character (2 minutes)

On login you should see, in orange-teal `[Codex]` chat lines: `codex-0.1-first-light loaded...`, then
`data: 1118 quests (ATT-derived, unverified, plus 96 observed on Forever)...`, and usually `next: <something>`.

Type **`/codex diag`** and screenshot the chat. What we are checking:

| Line | Good looks like |
|---|---|
| `Character:` | your name, level, race, class (token), faction. If it says `APIs missing for character info: UnitClass ...` that is a real finding: tell me. |
| `Location:` | your zone / subzone, `map <id>`, coordinates, `position available: true`, `world coords: true` |
| `Choices:` | `style=efficient routeZone=auto ... systems on: flight` |
| `pack ...` | 4 quest packs and 1 flight pack, ATT ones `verified=false`, observed `verified=true` |
| `NEXT:` | an action, with `why:` |
| `APIs absent on this client:` | note which (a short list is expected and fine) |
| last line | `caught errors: 0` |

If a red Lua error popped up at any point, screenshot it and run `/codex diag` right after.

## Checkpoint 2 - the window (3 minutes)

1. Click the **C** minimap button (or `/codex`). Screenshot the whole window.
2. Check: header shows *Race origin / Route zone (your choice) / Now in*; a **NEXT** card with lines, a "Why:" line and
   a "Source:" line; **Coming up**; **While you're here**; the **Systems** grid.
3. The **Source:** line must say either `ATT (AllTheThings) - unverified on Forever` or `observed on Forever`.
4. Systems: only *Flight path hints* and *Hardcore* are live; everything else is greyed and says `(planned)`.
5. Everything should be readable (no blank boxes). Tell me if any text is cut off or overlaps.

## Checkpoint 3 - you are in control (5 minutes)

1. **Route style** `>` / `<`: cycles Efficient, Fast, Questing-only, Completionist (planned styles are skipped). The
   Next card / lists should change.
2. **Route zone** `>`: choose a zone other than the one you are in (e.g. Stranglethorn Vale). The first entry in
   Coming up should become **Travel to ...**. Set it back to **Auto** with `<`. (Your race and current zone must not
   change what you chose.)
3. **Skip** on the Next card: it should be replaced and not come back. `/codex unskip` restores skipped items.
4. **Add quest...**: type part of a quest name (e.g. `thunder`) or an id, click a result: Codex now recommends it first.
   `/codex remove <id>` takes it out.
5. Click a greyed system (e.g. Camping): it should explain it is planned and stay off. Click **Hardcore**: it toggles.

## Checkpoint 4 - navigation (3 minutes)

Click **Show on Map** on the Next card (or on any row in Coming up / While you're here). Expect: the world map opens
to the right zone, a pin is placed, and the game's own waypoint arrow appears and points at it (the proven M8.6-B
behaviour). The chat line says the position is *ATT-derived, unverified* or *observed*. Screenshot the map. Walk
toward it a little and run `/codex next` to see it refresh.

## Checkpoint 5 - it follows the game (5 minutes)

1. Accept a quest that Codex recommended. Within a few seconds the recommendation should move on (it is no longer
   offered), and if the quest is in your log it shows under the in-progress line.
2. Complete a quest that is in the log: Codex should now recommend the **turn-in** first.
3. `/reload`, open `/codex`: your route zone / style / skips should still be there (see the persistence note below).

## Checkpoint 6 - telemetry (observation only, 5 minutes)

Telemetry quietly records XP, kills, combat, movement and quest timings. It does not affect recommendations. Several
of its sources have **never been seen on Forever**, so this checkpoint is how we find out which actually work.

1. `/codex telemetry`: lists 9 event types, each `proven on Forever` or `UNPROVEN on Forever`, with `registered: true/false`.
   Any `registered: false` means that event does not exist on this client: tell me which.
2. Fight a few mobs and gain some XP, then `/codex telemetry` again: check `recorded this session` for `XP_GAIN`,
   `MOB_KILL`, `COMBAT_START`, `COMBAT_END`. `/codex telemetry events 15` shows the raw events.
3. Walk about 30 seconds in a line, stop, then `/codex telemetry events 5`: a `PLAYER_MOVE` with `dist` close to what you walked.
4. Accept, complete (objectives) and turn in one quest: `QUEST_ACCEPT`, `QUEST_COMPLETE`, `QUEST_TURNIN` (with `xp=`).
5. If you level up, a `LEVEL_UP` and an `XP_GAIN ... lvlup=true`.
6. After a couple of minutes of play: `/codex telemetry summary`. Numbers are labelled observed / calculated / estimated;
   `n/a (...)` just means there was not enough data yet.
7. `/reload`, then `/codex telemetry events 3`: the log should still be there. Include `/codex diag` in your report.
8. If the game feels slower during heavy combat, try `/codex telemetry off` and tell me the difference.

## Send back

* The `/codex diag` screenshot (checkpoint 1) and the window screenshot (checkpoint 2).
* `/codex report` opens a copyable box: paste its text into your message (Ctrl+A, Ctrl+C in the box).
* Anything that looked wrong, e.g. "recommended a quest I cannot take", "pin in the wrong place", "wrong zone label",
  "level seemed off" - with the quest name. ATT data is unverified, so mismatches are expected and valuable.
* Then `/reload` and send `E:\World of Warcraft\_classic_beta_\WTF\Account\<ACCOUNT>\SavedVariables\ForeverCodex.lua`
  (it contains your choices and the last 5 diagnostics).

## Useful commands

`/codex` open/close | `/codex next` | `/codex diag` | `/codex report` | `/codex style <key>` | `/codex zone <key|auto>` |
`/codex skip` / `unskip` | `/codex add <id|name>` / `remove <id>` | `/codex hardcore on|off` | `/codex where` | `/codex reset` | `/codex telemetry [status|summary|events|on|off|reset]` | `/codex help`

## Known limits

* The data is the pinned ATT snapshot (2026-09-26) plus 96 quests observed on Forever. It may not contain the new
  20-30 content; Codex works with what exists, shows quests in your own log even when unknown, and lets you Add by id.
* ATT gives a **required** level, not a quest level, so level fit is approximate.
* Turn-in location is assumed to be the giver's.
* Logout may lose your choices (`/reload` saves reliably); nothing else is stored.
* No custom arrow yet (it waits for the M8.14 probe measurements); use Show on Map.
