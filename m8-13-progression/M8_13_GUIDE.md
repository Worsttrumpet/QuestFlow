# M8.13 Guide: Real-Client Validation of v0.7

About 5 minutes. No questing, no travel. The test route's quests (907, 959) are Barrens quests your character
doesn't have, so steps will show "in progress" or "can't detect" — that's expected and still tests the controls.

## Install

Exit WoW completely, then run the install script from the chat (it backs up v0.6 first).

## Test

1. Log in from character select. Type `/console scriptErrors 1`.
2. **Chat check:** look for `vm8-guide-addon-0.7 loaded` and
   `Progress: Barrens Level 18 (M8.3 test route), step 1 of 5 (no saved progress; starting at step 1).`
   Screenshot both.
3. `/fguide`, ROUTE tab. Status line: `Progress: in progress -- quest not accepted yet.` NEXT reads `NEXT ->`.
   Screenshot.
4. **No auto-advance:** wait ~15 seconds. Still step 1.
5. Click **NEXT** once → step 2. Status: `can't detect this step (no destination in route data)`. Screenshot.
6. Click **NEXT** once → step 3. Status: `quest is not in your quest log`.
7. Click **Undo** → back to step 2. Click **Skip** → step 3 again.
8. Click **Pause** → button reads `Resume`, status reads `PAUSED`. Click **Resume**.
9. Click **Reset Step** → still step 3, status re-checked.
10. Click **NEXT** → step 4. Click **Show on Map** → pin at Jorn Skyseer in the Barrens. On the QUESTS tab, select a
    quest and click **Show on Map** → pin works. Screenshot one.
11. **Persistence:** `/reload`. Chat should say `... step 4 of 5 (restored step 4).` Open `/fguide` → ROUTE tab is
    on step 4. Screenshot.
12. `/fguide progress status` → screenshot the line.

## Send back

- The screenshots, and whether any Lua error appeared.
- Optional: `WTF\Account\<YOUR ACCOUNT>\SavedVariables\ForeverQuestGuide.lua` (shows the saved route/step).

## Rollback

If anything is wrong, the install script's backup (`ForeverQuestGuide-v0.6-backup`) restores v0.6.
