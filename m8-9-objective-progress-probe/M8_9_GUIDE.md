# M8.9 Guide: Objective Progress Probe Test

About 10 minutes of normal questing. No grinding.

## Pick the quest

Use a quest you're working on anyway. In order of preference:

1. A quest with **two or more objectives** (e.g. "kill X" and "collect Y"), where you can make at least two
   progress steps on one objective and ideally finish that objective.
2. Otherwise, any quest where you can make at least two progress steps and finish the objective.

Kills, item loot and "talk to / use" objectives all work; two different kinds is a bonus, not a requirement.

**Optional, for the ordering question:** if any quest from the guide's list (`/fguide` → QUESTS) is already in
your quest log, leave it there. It needs no progress, just to be in the log. Don't go pick one up specially.

## Install

1. Exit WoW (or sit at character select).
2. Delete `Interface\AddOns\ForeverProbeM88` (M8.8 is locked).
3. Copy `addon/ForeverProbeM89` into `E:\World of Warcraft\_classic_beta_\Interface\AddOns\`.
4. Log in; confirm **Forever Probe M8.9 (Objective Progress)** is enabled.

## Test

1. Type `/console scriptErrors 1`.
2. Check the login line (green `[FProbeM89]`): note whether each of `QUEST_LOG_UPDATE`,
   `UNIT_QUEST_LOG_CHANGED`, `QUEST_WATCH_UPDATE` says `registered`.
3. Wait for `[FProbeM89] baseline taken: N quest(s) in log. Ready.` (a few seconds after login).
4. **Before:** type `/fprobe89 snap`. Screenshot the line for your chosen quest.
5. **Progress:** do one objective step (one kill, one loot). Watch for a line like
   `objective: <quest> (id) #1 2/8 -> 3/8 | seen AT QUEST_LOG_UPDATE`
   (or `first seen 0.25s after ...`, or `seen by poll ...` — all three are valid results; just note which).
   Screenshot it together with the game's own progress message.
6. Do at least **one more step** on the same objective, then keep going until the objective is **finished** if
   that's naturally within reach. If the whole quest completes, watch for `IsComplete` / `ReadyForTurnIn` lines.
7. **After:** type `/fprobe89 snap` again and screenshot it.
8. Type `/fprobe89` and screenshot the summary.
9. Type `/reload`. Wait for the `baseline taken` line again, then `/reload` **once more**. (The second session's
   baseline is what shows whether objective order survives a reload.)

## Send back

- Screenshots from steps 4–8.
- `E:\World of Warcraft\_classic_beta_\WTF\Account\<YOUR ACCOUNT>\SavedVariables\ForeverProbeM89.lua`.
- Which quest and objective you worked on.
- Whether any Lua error popped up.

## Afterwards

Once analysed, delete `ForeverProbeM89` from AddOns. It writes only its own SavedVariables file.
