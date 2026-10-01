# M8.8 Guide: QUEST_TURNED_IN Probe Test

About 5 minutes. One quest that is already ready to turn in. No grinding.

## Install

1. Exit WoW (or sit at character select).
2. **Remove the old M8.7 probe:** delete `Interface\AddOns\ForeverProbeM87`. M8.7 is locked; leaving it
   loaded adds new sessions to its SavedVariables file and mixes its `[FProbeM87]` lines into this test.
3. Copy `addon/ForeverProbeM88` into `E:\World of Warcraft\_classic_beta_\Interface\AddOns\`.
   The folder must be named exactly `ForeverProbeM88`, containing `ForeverProbeM88.toc` and `.lua`.
4. Log in. At character select, confirm **Forever Probe M8.8 (QUEST_TURNED_IN)** is enabled.

## Test

1. Type `/console scriptErrors 1`.
2. Confirm the login line (magenta `[FProbeM88]`, not cyan `[FProbeM87]`):
   `[FProbeM88] m8-8-probe-0.1 loaded (session N). QUEST_TURNED_IN: registered. Complete-click hook: installed.`
3. Go to the turn-in NPC for a quest that is **already complete** — ideally a normal (non-dungeon) quest.
4. **Cancel check:** open the quest's reward screen. Chat shows
   `QUEST_COMPLETE: reward screen OPEN for "<quest>" (id N). Not turned in yet.`
   Close it **without** clicking Complete (Escape or the close button). Chat shows `QUEST_FINISHED: quest dialog closed.`
   There should be **no** `QUEST_TURNED_IN` line.
5. **Turn-in:** talk to the NPC again, open the reward screen, choose a reward if offered, click **Complete Quest**.
   Watch for, in order:
   - `Complete Quest clicked (reward taken).`
   - `QUEST_TURNED_IN fired (#1). args: ... | arg 1 matches reward screen quest "<quest>" | 0.xx s after Complete click`
6. *Only if another quest is already ready to turn in:* repeat step 5 for it. Don't go complete one specially.
7. Type `/fprobe88`. Screenshot the summary lines.
8. Type `/reload` **before logging out**.

## Send back

- The `/fprobe88` screenshot, plus any from steps 2–5 if easy.
- `E:\World of Warcraft\_classic_beta_\WTF\Account\<YOUR ACCOUNT>\SavedVariables\ForeverProbeM88.lua`.
- Whether any Lua error popped up.

## Afterwards

Once analysed, delete `ForeverProbeM88` from AddOns. It writes only its own SavedVariables file.
