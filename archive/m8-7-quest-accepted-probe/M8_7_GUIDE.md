# M8.7 Guide: QUEST_ACCEPTED Probe Test

About 5 minutes. One quest you'd accept anyway. No grinding.

## Install

1. Exit WoW (or sit at character select).
2. Copy `addon/ForeverProbeM87` into `E:\World of Warcraft\_classic_beta_\Interface\AddOns\`.
   Leave ForeverQuestGuide and ForeverRecorder installed; nothing collides.
3. Log in. At character select, make sure **Forever Probe M8.7 (QUEST_ACCEPTED)** is enabled.

## Test

1. In game, type `/console scriptErrors 1`.
2. Confirm this chat line appeared on login:
   `[FProbeM87] m8-7-probe-0.1 loaded (session N). QUEST_ACCEPTED: ...`
   Note what it says after `QUEST_ACCEPTED:` — `registered` or `registration_error: ...`.
3. Go to any normal quest giver and open a quest you haven't accepted yet.
   Avoid escort or party-shared quests. Chat should show
   `[FProbeM87] QUEST_DETAIL: offer screen for "<quest>" (id <number>).`
4. Click **Accept**. Watch chat for `[FProbeM87] QUEST_ACCEPTED fired (#1). args: ...`
   (or note that nothing appeared).
5. *Optional, recommended:* open the quest log, abandon that same quest, go back to the giver and accept it
   again. Watch for `QUEST_REMOVED fired` and a second `QUEST_ACCEPTED fired (#2)`.
6. Type `/fprobe87`. Screenshot the three summary lines.
7. Type `/reload`. **Do this before logging out** — logout saves are unreliable on this client.

## Send back

- The screenshot from step 6, plus any from steps 2–5 if easy.
- The file `E:\World of Warcraft\_classic_beta_\WTF\Account\<YOUR ACCOUNT>\SavedVariables\ForeverProbeM87.lua`.
- Whether any Lua error popped up.

## Afterwards

Once the result is analysed the probe can be deleted from AddOns. It writes nothing anywhere except its own
SavedVariables file.
