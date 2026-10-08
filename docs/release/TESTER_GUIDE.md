# Quest Flow: tester guide

Thank you for trying Quest Flow. It shows what you could do now, what to hand in, how to get there, and which quest reward looks best. It never accepts, completes or turns in a quest for you, and it never uploads anything.

## Install
1. Quit WoW. Unzip `QuestFlow-<version>.zip` into `World of Warcraft/_classic_/Interface/AddOns/` so you end up with `AddOns/QuestFlow/QuestFlow.toc` (not one folder deeper). Replace any older `QuestFlow` folder.
2. Log in. The first time on a character you get a short welcome. Type `/qflow` any time to open the window.
3. Optional: `/console scriptErrors 1` shows a Lua error on screen if one happens.

## What to try (about ten minutes of normal play)
- Play as you normally would for a while. Does **NOW** make sense? Does it change when you do something else?
- Open a quest reward window. Do the small icons and the tooltip line show up?
- Take a flight, a boat or a zeppelin if you can. Afterwards run `/qflow report` and look for the line about flights or rides.
- Click the quest name under NOW: its details should open.

## What we are most interested in
- Anything that looks wrong, confusing or slow.
- Classes and factions other than Horde druid: the author's testing so far is mostly one Horde druid.
- Quests with no place shown ("Place not known"): they are a known gap, but tell us which ones matter to you.

## How to send feedback
1. Run `/qflow report`, press Ctrl+C in the box to copy it, and paste it into a new issue at https://github.com/Worsttrumpet/questflow/issues (the issue form tells you what to add). The report includes your character name and realm in a few lines: edit them out first if you like.
2. Or use the **Feedback** button in the window for a shorter summary without your name or realm.
3. Say what you expected and what you saw. One sentence is enough.

Nothing leaves the game on its own: you copy and paste everything yourself.
