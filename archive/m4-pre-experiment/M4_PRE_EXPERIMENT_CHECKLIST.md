# M4 pre-experiment: in-game checklist

Read-only, same discipline as M3: you perform every quest action manually, the addon only observes.

## 1. Install

Copy the whole `addon/ForeverProbeM4` folder into your AddOns directory:
```
Interface/AddOns/ForeverProbeM4/
```
This can sit alongside M3's `ForeverProbe` folder without conflict (different names throughout).

## 2. Confirm it loaded

Log in. You should see (orange text this time, not green):
```
[FProbeM4] probe m4-pre-experiment-0.1 loaded. Read-only: ... never calls GetQuestReward().
[FProbeM4] GetBuildInfo() = ...
[FProbeM4] Slash commands: /fprobe4 scan | /fprobe4 status | /fprobe4 clear | /fprobe4 save
```

## 3. Run the scan once

```
/fprobe4 scan
```

## 4. Pick 2–3 quests **known to give an item reward** — this is the important part

`GetNumQuestRewards()` read `0` on every single quest M3 tested, because none of them happened to have
one. This experiment needs quests where you can see an item reward in the normal quest UI before turning
in (a weapon, armor piece, or a reward-choice screen). Any such quests you have available work — they
don't need to be related to each other.

For each one:
1. Talk to the quest giver, **open the gossip window** (tests goal 2 automatically).
2. **View the quest details before accepting** — this triggers the `QUEST_DETAIL` checkpoint.
3. Complete the objective normally.
4. Return and **open the turn-in dialog, but pause there for a few seconds before clicking Complete** —
   this gives the "delayed" checkpoint time to fire (1.5s after the dialog opens) and gives any
   `GET_ITEM_INFO_RECEIVED` retry a chance to fire too.
5. Turn it in normally.

Repeat for 2–3 quests with item rewards. More is fine if convenient, not required.

## 5. Check status

```
/fprobe4 status
```

## 6. Save and retrieve

```
/fprobe4 save
```
Then, same as before:
```powershell
Get-ChildItem "E:\World of Warcraft\_classic_beta_\WTF\Account" -Recurse -Filter "ForeverProbeM4.lua"
```
Attach that file. It's a different filename from M3's export (`ForeverProbeM4.lua`, not
`ForeverProbe.lua`), so there's no risk of confusing the two.

## 7. Cleanup (when you're done with this experiment)

```powershell
Remove-Item -Recurse "E:\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverProbeM4"
```
