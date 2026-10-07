# M8.12: Progression Startup-State Probe

**Status: real-client test complete; see `M8_12_COMPLETION_REPORT.md`.** No production Lua, route data,
route schema, ForeverRecorder, M8.7–M8.11 file, or `M8_2_SCOPE.md` is created or modified.

**Scope date:** 2026-09-30. Intended destination: `forever-db/docs/M8_12_SCOPE.md`.

## 1. The question

> When the addon loads, can quest progression state be reconstructed from the quest API — and from what moment
> is that state safe to read?

M8.11 marked this UNVERIFIED: `IsQuestFlaggedCompleted` at startup, and quest-log reads earlier than the 3-second
deferral M8.9 used.

Sub-questions:

1. Does `C_QuestLog.IsQuestFlaggedCompleted` exist?
2. Is it correct for quests already completed?
3. Is it correct for quests not completed?
4. Can an already-accepted quest be identified right after login/reload?
5. Can its objective state be read right after login/reload?
6. Does state differ between addon load / `PLAYER_LOGIN`, the first `QUEST_LOG_UPDATE`, and 0.5 s / 2 s later?
7. Does the log become readable only after a later event?
8. Which event is a reliable "reconciliation is now safe" trigger?
9. Can a quest turned in before load be identified from the quest API alone?
10. Existence and return values of every relevant API.

## 2. States, never conflated

| State | Meaning |
|---|---|
| `IN_LOG_INCOMPLETE` | In the quest log, not complete |
| `IN_LOG_COMPLETE` | In the log, `IsComplete` or `ReadyForTurnIn` true |
| `FLAGGED_COMPLETED` | Not in the log; completed flag true |
| `ABSENT_NOT_FLAGGED` | Not in the log; completed flag false — **not** evidence of turn-in, nor of anything else |
| `UNDETERMINED` | Flag unavailable or errored |

Absence from the log alone is never treated as a turn-in.

## 3. Checkpoints

`file_load` (earliest: the probe's top-level code), `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD` (with
its `isInitialLogin` / `isReloadingUi` arguments), the first `QUEST_LOG_UPDATE`, +0.5 s and +2.0 s after it, and
`PLAYER_ENTERING_WORLD` +3.0 s (the point M8.9 already proved readable). Every `QUEST_LOG_UPDATE` in the session is
also timestamped with the log size at that moment (first 40).

Each checkpoint records: API inventory; log entry count; every in-log quest with objectives (`have`, `need`,
`finished`, `text`, `type`), `IsComplete`, `ReadyForTurnIn`, completed flag and classification; the reference
set (§4); `GetAllCompletedQuestIDs` count and reference hits if that API exists; and a digest. After the last
checkpoint, each is marked as equal to or different from the final one.

## 4. Test cases from existing character state (no new questing)

| Case | Quest IDs | Expected | Basis |
|---|---|---|---|
| Completed | 92421, 92422, 92401, 95216, 97288, 97291, 95204, 428 | flag `true` | Turned in on this character in M8.7–M8.9 (observed in probe data and screenshots) |
| Not completed | 783, 7 | flag `false` | Alliance starter quests; this character is Horde |
| Unknown | 907 | — | Route test quest; status unknown |
| In log | whatever the log holds at login | classified live | M8.9 final snapshot suggests a mix of incomplete (e.g. 1013) and complete quests |

Cases that cannot be established from current character state are reported **UNTESTED**, not manufactured.

## 5. Probe

| | Value |
|---|---|
| Folder | `m8-12-startup-state-probe/addon/ForeverProbeM812` |
| SavedVariables | `ForeverProbeM812DB` (sessions appended) |
| Slash | `/fprobe812` (summary), `/fprobe812 q <questID>` (inspect one quest), `/fprobe812 now` (manual snapshot) |
| Chat prefix | `[FProbeM812]` |
| Version | `m8-12-probe-0.2` (v0.1 superseded; see §5) |

Read-only: quest-log and completion **reads** only; no hooks, no waypoints, no quest actions.

### Probe revision: v0.2 (2026-09-30)

v0.1 added its session to `ForeverProbeM812DB` when its file first ran. On the real client the saved file then
kept only the first session ever recorded, re-saved unchanged after every `/reload` (a fresh-login session seen
on screen at 4:18 was absent from the file written at 4:19). The likely cause: WoW restores SavedVariables
**after** an addon's files run and before `ADDON_LOADED`, replacing the table the file had just written into.
The M8.7–M8.10 probes attached their sessions at `ADDON_LOADED` and were unaffected.

v0.2 still captures the `file_load` checkpoint, but attaches the session at `ADDON_LOADED` and records whether
the saved table existed at file load and whether it was replaced before `ADDON_LOADED`, so the timing is
measured rather than assumed. The v0.1 reload-session data remains valid evidence; only its persistence was
affected.

## 6. Procedure outline

One fresh login from character select (initial login) and one `/reload` (reload path), each captured
automatically, then a final `/reload` to save both. No travel, no quest actions.

## 7. Classification in the report

Each finding: **VERIFIED ON FOREVER**, **VERIFIED BY EXISTING CODE**, **UNVERIFIED**, or **UNTESTED**.

## 8. Out of scope

Progression implementation, any production or data change, new questing, travel.

## 9. Files

```
m8-12-startup-state-probe/
  addon/ForeverProbeM812/ForeverProbeM812.toc
  addon/ForeverProbeM812/ForeverProbeM812.lua
  tests/run_probe_selftest.lua     -- 36 checks, lua5.1, stub environment only
  M8_12_GUIDE.md                    -- operator test procedure
  docs/M8_12_SCOPE.md               -- this document
  docs/M8_12_COMPLETION_REPORT.md   -- real-client results
  evidence/ForeverProbeM812.lua     -- raw SavedVariables (3 sessions)
```
