# M4 reputation follow-up: checklist

One question only: can our normal read-only addon capture quest reputation rewards on Forever?

## 1. Install

Copy `addon/ForeverProbeM4Rep` into your AddOns folder. Safe to leave all three other probes
(`ForeverProbe`, `ForeverProbeM4`, `ForeverProbeM4Retry`) installed too — no conflict.

## 2. Confirm it loaded

Log in. Purple text this time:
```
[FProbeM4Rep] probe m4-reputation-followup-0.1 loaded. ...
```

## 3. Find 1–2 quests that visibly award reputation

You already know how to spot this — you noticed it happening naturally last time. **No need to find a
quest with exactly one faction reward** — if a quest awards reputation with more than one faction, that's
useful evidence too (the API is designed to support multiple, per Blizzard's own code, so testing that
naturally if it comes up is a bonus, not something to seek out specially).

## 4. Play through each one normally

Accept, complete, then at the turn-in screen **pause a few seconds** before clicking through — same as
every prior round.

## 5. Save and retrieve

```
/fprobe4rep save
```
```powershell
Get-ChildItem "E:\World of Warcraft\_classic_beta_\WTF\Account" -Recurse -Filter "ForeverProbeM4Rep.lua"
```
Attach that file — a distinct filename from all three prior probes.

## 6. Cleanup

```powershell
Remove-Item -Recurse "E:\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverProbeM4Rep"
```

That's it — 1–2 quests, same play style as every round so far.
