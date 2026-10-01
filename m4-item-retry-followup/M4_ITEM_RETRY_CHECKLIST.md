# M4 item-retry follow-up: minimal checklist

One question only: does a guaranteed-reward item's empty-string name ever resolve to a real name, and
when? **Choice rewards do not need retesting** — skip past any quest with a "choose one of these
rewards" screen; we only need quests with a **guaranteed, non-choice** item reward (the "You will also
receive: [Item]" style, not a pick-one screen).

## 1. Install

Copy `addon/ForeverProbeM4Retry` into your AddOns folder. Safe to leave both other probes (`ForeverProbe`,
`ForeverProbeM4`) installed too — no conflict.

## 2. Confirm it loaded

Log in. Blue text this time:
```
[FProbeM4R] probe m4-item-retry-followup-0.1 loaded. ...
```

## 3. Find 1–2 quests with a guaranteed item reward

Check the reward screen before accepting — you want "You will receive: [Item]" (a fixed item, not a
choice). One is enough to answer the question; two gives a bit more confidence.

## 4. Play through each one normally

Accept, complete, then at the turn-in screen **pause a few seconds** before clicking through (same as
before — this lets the delayed checkpoint and any retry fire).

## 5. Save and retrieve

```
/fprobe4r save
```
```powershell
Get-ChildItem "E:\World of Warcraft\_classic_beta_\WTF\Account" -Recurse -Filter "ForeverProbeM4Retry.lua"
```
Attach that file — a different filename from both earlier probes, so nothing will be confused.

## 6. Cleanup

```powershell
Remove-Item -Recurse "E:\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverProbeM4Retry"
```

That's it — 1–2 quests, same play style as before, nothing else needed.
