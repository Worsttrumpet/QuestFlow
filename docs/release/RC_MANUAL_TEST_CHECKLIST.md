# Release candidate: manual test checklist (real WoW Forever client)

The automated tests use a simulated client. These are the things only the real client can prove. Do them with the release ZIP (a clean copy in `AddOns/`), not a development folder.

## Install and load
1. Delete any old `ForeverCodex` folder and unzip the release ZIP so you have `AddOns/ForeverCodex/ForeverCodex.toc`. Start the game: the AddOns list shows **Forever Codex**, the right version, the Notes text, and no "out of date" warning.
2. Log in with `/console scriptErrors 1`. You see one welcome line and **no Lua errors**.
3. `/reload` twice. Settings, window position and skips are remembered, still no errors.
4. A character you have never used Codex on: setup appears, Start works, the tracker fills in.

## Core guidance
5. NOW changes within a couple of seconds after you accept, progress and turn in a quest. The waypoint follows NOW and clears when you arrive. Your own map waypoint is left alone.
6. Walk into a dungeon quest area and out: the dungeon objective is NOW only inside the dungeon.
7. A quest with no map location is listed, with objectives, and clicking its entry shows details.
8. `/codex report` opens a window with text you can copy (Ctrl+C) and the first line says DIAGNOSTIC REPORT and the release version. The Feedback button works.

## Reward Advisor
9. Open a reward with several choices (the Q5730 Hidden Enemies reward is a good case): the icons appear on each reward, bottom right, not covering item names, in **both columns**, and nothing is cut off at the window edge.
10. If Codex recommends a reward it has a golden border and a star; the border is not clipped in the right-hand column. If there is no recommendation there is no border and no star.
11. A vendor reward shows the coin followed by the sell price (for example `2s 15c`), readable and not overlapping the icon next to it.
12. Hover each reward for several seconds, including moving between rewards: the game's tooltip stays and shows one line `CODEX: ...`; it does not flicker or disappear.
13. Close the reward window, then open it again, and take a reward: nothing stays on screen afterwards.

## Interface and settings
14. Options: arrow on/off, replace the game's tracker on/off and back, world-map button, theme. Each change takes effect and survives `/reload`.
15. Resize and move the window, `/reload`: size and place are kept.
16. With QuestieDB installed and not installed: Codex loads and works either way, and `/codex questiedb off` turns it off.

## Before publishing
17. Take the screenshots for the project page from this build.
18. Confirm the version in the AddOns list matches the ZIP name and `CHANGELOG.md`.
