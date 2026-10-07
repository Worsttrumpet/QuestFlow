# M4 reputation follow-up: exactly what was added

Forked from `m4-item-retry-followup/addon/ForeverProbeM4Retry/ForeverProbeM4Retry.lua`, which is **not**
modified. `m3-experiment/`, `m4-pre-experiment/`, and `M4_PLAN.md` are also untouched. One question only:
can our normal read-only addon observation capture quest reputation rewards on WoW Forever?

## API investigation (from the proposal, restated for the record)

Source: Blizzard's own shipped default-UI code (`FrameXML/QuestInfo.lua`, mirrored on GitHub from real
client builds) — not third-party guesswork:

```lua
for i = 1, GetNumQuestLogRewardFactions() do
    factionId, amount = GetQuestLogRewardFactionInfo(i)
    factionName, ..., isHeader, ..., hasRep = GetFactionInfoByID(factionId)
    amount = floor(amount / 100)  -- raw value is in hundredths
end
```

`[2nd]` — a strong secondary source (Blizzard's own code), but **zero** of it has been tested on Forever.
This project's own track record (`GetQuestLogRewardMoney`/`XP` looked correct and returned zero for 15/16
real quests; item names came back as empty string instead of the documented nil) is reason enough not to
trust this without a real test.

## What was added

- **API scan**: `GetNumQuestLogRewardFactions`, `GetQuestLogRewardFactionInfo`, `GetFactionInfoByID` added
  to the existing `type()` scan list (now 44 entries total, up from 41).
- **`captureReputationCheckpoint(checkpoint, questID)`**: new function, called at the exact same three
  checkpoints already proven for item rewards — `quest_detail`, `quest_complete_immediate`,
  `quest_complete_delayed`. No new checkpoint machinery was invented.
- **No retry mechanism for reputation.** Item names needed a retry because item data can be
  server-round-trip-cached (`GET_ITEM_INFO_RECEIVED`). Faction data is a small, always-loaded client-side
  table with no equivalent async-load event, so a retry loop isn't expected to be needed. If real data
  proves this wrong, that itself becomes a finding to report, not something this probe tries to route
  around.
- **`reputation_checkpoints`** new top-level table in `ForeverProbeM4RepDB`, parallel to `item_checkpoints`.
- Everything else — item-reward capture, gossip capture, NPC/GUID handling, event registration, slash
  commands beyond the two additions below — is byte-for-byte unchanged from the item-retry follow-up.

## A real bug caught during testing, fixed before delivery

Testing against `GetFactionInfoByID`'s real 11-value signature (`name, nil×7, isHeader, nil, hasRep`)
exposed a genuine, previously-latent bug in the shared `safecall()` helper every probe in this project has
used since M3: it builds a results table via `{pcall(fn, ...)}` and returns it via `unpack(results)`.
**When the real return list has `nil` values sitting in the middle followed by real values (like `false`
or `true` deep in a long list), Lua 5.1's `unpack()` can silently drop those trailing real values** — this
is a known Lua ambiguity (the `#` length operator is undefined on tables with holes), not a mistake
specific to this codebase, but it had simply never been exercised by any API this project called before,
since none had a return list this long with holes this deep.

**Confirmed directly**, isolated from the probe entirely:
```lua
local function fn() return "Windshapers", nil, nil, nil, nil, nil, nil, nil, false, nil, true end
-- unpack(...)-based safecall(): f9 and f11 come back nil, even though the function returned false/true
```

**The fix**: a new, separate, local helper (`safecallIndexed`), used *only* by the reputation capture code
added in this fork. It builds the same `{pcall(...)}` table but reads values back via explicit numeric
indexing (`results[9]`, `results[11]`, ...) instead of `unpack()` — indexing a Lua table directly is always
correct regardless of holes; only `unpack`/`ipairs` are affected. **The shared `safecall()` used by every
other call site in this file, and in all three prior probes, was deliberately left untouched** — fixing it
generally was out of scope for an experiment that's supposed to stay strictly limited to reputation
rewards, and every prior real-client result already collected remains valid (past calls either had short
return lists or didn't have this specific nil-then-real-value-behind-it shape).

This is worth being direct about: this specific class of bug could theoretically have affected earlier
data if any earlier probe had ever called something with a similarly nil-heavy long return list — a check
of the actual API calls made in M3 and the two prior M4 forks shows none did (all had either short lists,
or nils only at the very front with nothing consequential behind them). No retroactive correction needed.

## Fields captured per reputation checkpoint

- `checkpoint`, `quest_id`
- `GetNumQuestLogRewardFactions`: `{ok, value}`
- `faction_rewards[]`, one entry per faction reward index:
  - `index`, `api = "GetQuestLogRewardFactionInfo"`, `args`, `ok`
  - `r1`..`r6` (raw positional return values — `r1` is the presumed `factionId`, `r2` the presumed raw
    amount, per Blizzard's own usage, but never assumed beyond "worth trying to resolve")
  - `faction_info_lookup`: `{api = "GetFactionInfoByID", args, ok, f1..f12}` if `r1` was a number, or
    `{attempted = false, reason}` if not — so a wrong-shaped `r1` is visible, not silently skipped

## Stub-test results

| Test | Result |
|---|---|
| `luac5.1 -p` syntax check | **Pass** |
| Two-faction-reward scenario (tests "can one quest have multiple reputation rewards") | **Pass** — both entries captured distinctly, correct values, at all three checkpoints |
| `GetFactionInfoByID`'s `isHeader`/`hasRep`-style trailing booleans correctly captured | **Pass**, after the fix above (confirmed `false`/`true` came through, not `nil`) |
| `GetNumQuestLogRewardFactions` missing entirely | **Pass** — `ok=false`, empty `faction_rewards`, no crash |
| `GetNumQuestLogRewardFactions` returns a real `0` | **Pass** — recorded as `0`, not treated as an error |
| `GetQuestLogRewardFactionInfo` returns an unexpected type (a string, not a number) | **Pass** — recorded as-is; `GetFactionInfoByID` correctly *not* called with a bad argument |
| `GetFactionInfoByID` missing entirely | **Pass** — `ok=false`, no crash |
| Regression: item-reward/choice-reward capture (from the retry follow-up) | **Pass** — completely unaffected |
| Safety: no raw GUID anywhere in the stored data | **Pass** — asserted directly |
| Safety: zero actual calls to `GetQuestReward`/`AcceptQuest`/`CompleteQuest`/`TurnInQuest` | **Pass** — source grep, comments/strings only |

## Renamed (avoids collision with all three prior probes)

| | Item-retry follow-up | This follow-up |
|---|---|---|
| Folder / files | `ForeverProbeM4Retry` | `ForeverProbeM4Rep` |
| SavedVariables global | `ForeverProbeM4RetryDB` | `ForeverProbeM4RepDB` |
| Slash command | `/fprobe4r` | `/fprobe4rep` |
| Chat prefix | `[FProbeM4R]` (blue) | `[FProbeM4Rep]` (purple) |

All four probes (M3's `ForeverProbe`, `ForeverProbeM4`, `ForeverProbeM4Retry`, and this one) can be
installed simultaneously with zero conflict.
