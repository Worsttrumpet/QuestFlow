# M4 pre-experiment: what changed from the final M3 probe, and why

Per M4_PLAN.md §3a. This is a fork, not a modification — `m3-experiment/` is untouched. Nothing here
draws conclusions about Forever; it only documents the code and the stub-environment test results.
Real-client interpretation happens only after real-client data comes back (see the STOP at the end).

## Discrepancy found while inspecting M3 before forking (read this first)

While reviewing the final M3 probe to plan this fork, I found that **M3 already tested and confirmed**
`C_GossipInfo.GetAvailableQuests()`/`GetActiveQuests()` work on Forever — `M3_PROBE_FINDINGS.md` (session
1) shows both returning real structured data (`{questLevel=21, questID=878, isLegendary=false...}`,
12 keys). That's `[V]`, not `[?]`. `M4_PLAN.md`'s research-pass revision mischaracterized this as
"genuinely untested," and that's an error I'm carrying forward from my own document, not a new finding.
I'm building the gossip half of this experiment anyway, since it was explicitly requested and a cleaner
capture method is worth having — but the honest expectation going in is **reconfirmation**, not a
genuine unknown. `M4_PLAN.md`'s wording should be corrected once this experiment concludes; not done now,
since that's a documentation fix outside this task's scope.

## Naming — deliberately distinct from M3

Renamed throughout, so this can be installed alongside (or instead of) the still-possibly-present M3
addon without any file collision or SavedVariables mixing:

| | M3 (unchanged, frozen) | M4 pre-experiment (this fork) |
|---|---|---|
| Folder | `ForeverProbe` | `ForeverProbeM4` |
| Lua/TOC filenames | `ForeverProbe.lua/.toc` | `ForeverProbeM4.lua/.toc` |
| SavedVariables global | `ForeverProbeDB` | `ForeverProbeM4DB` |
| Slash command | `/fprobe` | `/fprobe4` |
| Chat prefix | `[FProbe]` (green) | `[FProbeM4]` (orange) |
| Probe version string | `m3-probe-0.1` | `m4-pre-experiment-0.1` |

## Removed: raw GUID export

M3's `captureNPCInfo` stored the raw `UnitGUID` value alongside the parsed creature ID, deliberately, to
validate the GUID-parsing technique itself (so a wrong split would be visible in the data). That
technique is now proven (`[V]`, 14 NPCs, zero parse failures, per M3). This experiment tests different
things and has no remaining reason to keep the raw GUID, so it's dropped — hardening toward the harvest
contract's "no raw GUIDs" principle (M4_PLAN.md §4.3) starting now rather than later. Only
`guid_ok`, `parsed_creature_id`, and `parse_note` are kept.

## Added: item-reward checkpoint capture (goal 1)

New function `captureItemRewardCheckpoint(checkpoint, questID)`, called at three points:

- **`QUEST_DETAIL`** — also newly calls `GetQuestID()` here, which M3 only ever called at
  `QUEST_COMPLETE`. Whether it resolves during `QUEST_DETAIL` at all is itself untested; recorded either
  way, not assumed.
- **`QUEST_COMPLETE`, immediately** — same moment M3 already captured money/XP at.
- **`QUEST_COMPLETE`, after a 1.5s delay** — via `C_Timer.After`, guarded with `safecall` like everything
  else; if unavailable, that absence is itself recorded (`scheduling_failed = true`), not silently skipped.

At each checkpoint: `GetNumQuestRewards()`, `GetNumQuestChoices()`, then `GetQuestItemInfo("reward", i)`
and `GetQuestItemInfo("choice", i)` for each index. **`GetQuestReward()` is never referenced anywhere in
this file** — confirmed by grepping the actual source (see stub-test results below); the only mentions of
that name are in comments explaining why it's absent.

**Return values are stored as named fields (`v1`..`v6`) plus an explicit `v1_is_nil` boolean, not a plain
positional array.** This was a real bug I caught during testing, not a stylistic choice: a Lua table
`{nil, "texture", 1, 2, 12345}` is ambiguous once read back — `ipairs()` stops at the first hole, so a nil
first value can silently look like "no values at all" to anything reading the export later. Since
detecting exactly that nil is the entire point of this experiment, an explicit `v1_is_nil` flag removes
the ambiguity rather than relying on Lua's table-hole behavior.

## Added: `GET_ITEM_INFO_RECEIVED` retry logic

If any checkpoint sees `v1_is_nil = true` (the presumed name slot), a bounded retry is armed
(`pendingRetryQuestID`, max 3 retries). On `GET_ITEM_INFO_RECEIVED`, if a retry is pending, the same
checkpoint capture re-runs and is recorded as `retry_after_get_item_info_received_N`. This event can fire
for unrelated items during ordinary play, so it's a no-op unless a retry is actually pending — confirmed
in testing (see below) that a stray fire after resolution adds nothing.

## Added: cleaner gossip quest-list capture (goal 2)

New function `extractGossipQuestList`, replacing M3's generic `describe()`-based capture for
`C_GossipInfo.GetAvailableQuests`/`GetActiveQuests`. M3's `describe()` caps table summaries at 6 arbitrary
keys — the same class of bug that silently dropped the `title` field during M3's own title-capture issue.
The new function records **every key name present** (so an unexpected shape is visible, not hidden) plus
values for a small explicit whitelist of known non-identifying fields (`questID`, `questLevel`,
`isLegendary`, etc. — no player data involved in either API's return shape).

## Unchanged from M3 (kept as-is, not the focus of this experiment)

`resolvePath`, `safecall`, `describe` (still used for non-critical summaries), `say`, `printAssumptions`,
the API existence scan (extended with 4 new entries: `GetNumQuestChoices`, `GetQuestItemInfo`,
`GetQuestID`, `C_Timer.After` — nothing removed), `capturePosition`, `captureQuestLogFields`,
`findQuestLogIndexByID`, the `QUEST_TURNED_IN`/`QUEST_FINISHED` handlers, and all slash commands other
than the two new ones matching the renamed globals.

---

# Files created inside `m4-pre-experiment/`

```
m4-pre-experiment/
  M4_PRE_EXPERIMENT_NOTES.md   this file
  M4_PRE_EXPERIMENT_CHECKLIST.md   what to do in-game
  M4_OBSERVATION_FORMAT.md     proposed result format
  addon/ForeverProbeM4/
    ForeverProbeM4.toc
    ForeverProbeM4.lua
```

Nothing under `m3-experiment/` or `forever-db/` was touched.

---

# Stub-environment test results

Tested with a plain Lua 5.1 interpreter and a hand-built stub WoW environment (forked from M3's own
`stub_env.lua`), before any real-client use, per the required discipline.

| Test | Result |
|---|---|
| `luac5.1 -p` syntax check | **Pass** |
| Full lifecycle simulation (load → scan → `QUEST_DETAIL` → `GOSSIP_SHOW` → `QUEST_COMPLETE` → delayed timer fire → 3× `GET_ITEM_INFO_RECEIVED`) | **Pass**, no errors |
| `quest_detail` checkpoint captured, `v1_is_nil = true` for the stub's deliberately-uncached item | **Pass** |
| `quest_complete_immediate` checkpoint captured, same nil pattern | **Pass** |
| `quest_complete_delayed` checkpoint fires only after the timer is manually triggered (not immediately) | **Pass** |
| Retry 1 (`GET_ITEM_INFO_RECEIVED` while still unresolved): re-captures, still shows `v1_is_nil = true` | **Pass** |
| Retry 2 (after the stub "resolves" the item): re-captures, now shows `v1_is_nil = false`, real name present | **Pass** |
| A third, unrelated `GET_ITEM_INFO_RECEIVED` after resolution adds **no** further checkpoint (bounded/no-op confirmed) | **Pass** — asserted programmatically, not just eyeballed |
| `GOSSIP_SHOW`: `GetAvailableQuests`/`GetActiveQuests` captured via the new extractor, correct `total_count` and sample fields | **Pass** |
| Safety scan: no raw GUID string anywhere in the stored `ForeverProbeM4DB` table (recursive search) | **Pass** — asserted programmatically |
| Safety grep: zero calls to `GetQuestReward`/`AcceptQuest`/`CompleteQuest`/`TurnInQuest` in the source (comments only) | **Pass** |
| Edge case: `C_Timer` entirely absent | **Pass** — records `scheduling_failed = true`, no crash |
| Edge case: `GetQuestID` entirely absent at `QUEST_DETAIL` | **Pass** — `QUEST_DETAIL` event still recorded; item checkpoint correctly skipped (no quest ID to key on) |
| `/fprobe4 status` / `/fprobe4 clear` | **Pass** |

One real bug was caught and fixed during this testing, before delivery: the initial design stored
`GetQuestItemInfo`'s return values as a plain positional array, which is ambiguous exactly where it
matters most (see "named fields" note above). Fixed and re-tested before this file was finalized.
