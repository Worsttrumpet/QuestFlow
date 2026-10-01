# Forever Codex 0.2 alpha: friend test guide

Forever Codex tells you **what to do right now**, what is worth doing **while you are there**, and (sometimes) what
comes **next**. It never accepts, completes or turns in a quest for you, and you can ignore it whenever you like.

This is an **alpha**. It was built and tested against a simulated game client; **it has not been run on the real
Forever client yet** (see `CODEX_PHASE3_NOTES.md`). Please tell us what happens. Nothing you do is uploaded: everything
Codex learns stays on your machine.

## Install

1. Quit WoW completely.
2. Unzip `ForeverCodex-codex-0.2-alpha.zip` so you end up with `...\Interface\AddOns\ForeverCodex\ForeverCodex.toc`
   (not one folder deeper). Start WoW and make sure **Forever Codex** is enabled at character select.
3. Log in. You should see one line: *Welcome! Type /codex to set up Forever Codex.*
4. Optional but helpful: type `/console scriptErrors 1` so any Lua error shows up on screen.

## First run

`/codex` (or the **C** button on the minimap) opens the window. The first time it shows **Here's your character.**
Pick where you want to level and how you like to play, then press **Start**. You can change this any time under
**Appendices > Settings**.

Normal play looks like this:

- **NOW**: the one thing to do. A short reason, how far it is (in words), and progress such as `4 / 6`.
- **ALSO WHILE YOU ARE HERE**: appears only when there really is something worth doing nearby. Often it is empty.
- **Then:** one small line, only when it helps.
- A **waypoint** (the game's own arrow) follows NOW automatically. If you set your own waypoint, Codex leaves it alone
  and stays quiet until it is gone.

Tabs: **Codex** (what to do), **World** (what is around you), **Journey** (what you have done),
**Appendices** (quest lookup, what Codex can and cannot see, Settings, Help Improve Codex, Party).

## What to try, and what to tell us

| # | Try | Expected | Tell us if |
|---|---|---|---|
| 1 | Log in, `/codex` | Setup panel, then the Codex page after Start | any Lua error, blank boxes, text cut off |
| 2 | Accept a quest, finish an objective, turn it in | NOW changes within a couple of seconds each time | NOW stays stale, or points at something you finished |
| 3 | Watch the waypoint | The game's arrow points at NOW and moves when NOW changes; it disappears when you arrive | it points at old things, or appears and vanishes repeatedly |
| 4 | Set your own waypoint (map, right-click) | Codex does not move or remove it | Codex overwrote or removed it |
| 5 | Remove Codex's waypoint yourself | Codex does not put it straight back for the same NOW | it fights you |
| 6 | Level up | the plan refreshes by itself | it needs a /reload |
| 7 | Two quests with the same name | each is handled on its own | a finished quest comes back |
| 8 | A character that is already leveled | sensible suggestions from the first minute | it recommends things you finished |
| 9 | `/reload`, then `/codex` | window position and setup are remembered | they are lost |
| 10 | In a party (friends also running Codex) | Appendices > Party and the Codex page show what they finished, next to your own progress | nothing appears, or chat spam |
| 11 | Appendices > Help Improve Codex | a plain count of what Codex has learned; View / Clear work | counts look wrong |
| 12 | `/codex markers probe` with an NPC targeted | tells you whether world markers can work on Forever | (new information either way) |

Party news (Appendices > Settings > *Party news*): **Off**, **In the window only** (default), **Party chat** (one plain
line when *you* finish or turn in a quest), or **Window and party chat**. Codex never posts to party chat unless you choose it.

## If something looks wrong

Type `/codex report`, select all in the box (Ctrl+A), copy (Ctrl+C) and paste it to us with a screenshot.
`/codex dev` opens the developer window; `/codex help` lists every command.
