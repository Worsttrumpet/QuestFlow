# M4 item-retry follow-up: exactly what changed

Forked from `m4-pre-experiment/addon/ForeverProbeM4/ForeverProbeM4.lua`, which is **not** modified.
`m3-experiment/` and `M4_PLAN.md` are also untouched. One question only: can a guaranteed-reward item
name that initially reads as an empty string (`""`) resolve to a real name later, and at which
checkpoint/retry?

## The one behavioral change

Before (M4 pre-experiment):
```lua
v1_is_nil = (ok and v1 == nil)
```
After (this fork):
```lua
v1_unresolved = (ok and (v1 == nil or v1 == ""))
```

That's it. This is the only line that changes what the probe *does*. Everything downstream that reads
this flag (`saw_unresolved_first_value`, `maybeArmRetry`, the retry-arming logic, the `MAX_RETRIES = 3`
bound) is unchanged in behavior — only renamed consistently (`v1_is_nil` → `v1_unresolved`,
`saw_nil_first_value` → `saw_unresolved_first_value`) so the field name matches what it now actually
means. A field still called "is_nil" that also fires on empty string would be a real, later-confusing
inaccuracy, so the rename went with the fix rather than being left stale.

## Confirmed unchanged

- Choice-reward capture logic — identical code, re-verified by a regression test (below).
- Gossip capture (`extractGossipQuestList`, `GOSSIP_SHOW` handler) — byte-identical, not touched.
- NPC/GUID handling — byte-identical, no raw GUID exported, same as the M4 pre-experiment.
- The three checkpoints (`QUEST_DETAIL`, `QUEST_COMPLETE` immediate, `QUEST_COMPLETE` delayed) and the
  bounded retry (max 3) — same mechanism, now armed by the corrected condition.
- No reference to `GetQuestReward`, `AcceptQuest`, `CompleteQuest`, or `TurnInQuest` anywhere except in
  comments and one chat-message string — confirmed by grep against the exact delivered file.

## Renamed (to avoid any collision with the two probes already on your client)

| | M4 pre-experiment | This follow-up |
|---|---|---|
| Folder / files | `ForeverProbeM4` | `ForeverProbeM4Retry` |
| SavedVariables global | `ForeverProbeM4DB` | `ForeverProbeM4RetryDB` |
| Slash command | `/fprobe4` | `/fprobe4r` |
| Chat prefix | `[FProbeM4]` (orange) | `[FProbeM4R]` (blue) |

All three probes (M3's `ForeverProbe`, the M4 pre-experiment's `ForeverProbeM4`, and this one) can be
installed at the same time with zero conflict.

---

## Stub-test results

Tested with the exact scenario the real client produced (item name `""`, not `nil`), before any real use:

| Test | Result |
|---|---|
| `luac5.1 -p` syntax check | **Pass** |
| Empty-string reward item correctly flagged `v1_unresolved = true` (the specific fix) | **Pass** — asserted directly |
| Delayed checkpoint still shows unresolved (stub hasn't "resolved" yet) | **Pass** |
| `GET_ITEM_INFO_RECEIVED` retry 1, still unresolved | **Pass** |
| Retry 2, after the stub resolves the item: real name captured, `v1_unresolved = false` | **Pass** |
| A third, unrelated `GET_ITEM_INFO_RECEIVED` after resolution adds no further checkpoint | **Pass** — asserted |
| **Regression check**: choice-reward capture, run fresh, produces identical real names and `v1_unresolved = false` — confirms nothing about choice handling was disturbed | **Pass** |
| Safety: no raw GUID anywhere in stored data | **Pass** — asserted |
| Safety: zero actual calls to `GetQuestReward`/`AcceptQuest`/`CompleteQuest`/`TurnInQuest` (source grep) | **Pass** |
| Edge case: `C_Timer` missing | **Pass** — records `scheduling_failed = true`, no crash |
| Edge case: `GetQuestID` missing at `QUEST_DETAIL` | **Pass** — event still recorded, item checkpoint correctly skipped |

No bugs found this time — the M4 pre-experiment's own testing already caught the one-checkpoint-only
positional-array issue, so this fork inherited a clean base.
