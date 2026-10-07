# M8.8: QUEST_TURNED_IN Existence & Reliability Investigation

**Status: scope defined, probe built and stub-tested, awaiting real-client test.** No production addon, route
data, route logic, recorder file, or M8.7 file is created or modified by this milestone. ForeverQuestGuide
v0.6 (M8.6-B) and M8.7 remain frozen.

**Scope date:** 2026-09-30. Intended destination: `forever-db/docs/M8_8_SCOPE.md`.

## 1. The question

> Is `QUEST_TURNED_IN` a reliable progression signal on WoW Forever?

Specifically:

1. Does it reliably fire when a normal quest is successfully turned in?
2. Does it fire exactly once per successful turn-in?
3. How quickly does it fire relative to the player's turn-in action?
4. Does its argument identify the quest being turned in?
5. Does that quest ID match the quest being completed?
6. Does it behave consistently for a second turn-in, if one is naturally available?
7. Does opening and cancelling a turn-in produce a false `QUEST_TURNED_IN`?

Also: does it fire when the reward is actually **taken** (the "Complete Quest" click), rather than when the
reward window **opens**?

Designing or implementing progression is out of scope.

## 2. What is already known, and why it doesn't answer this

- **M3 (`M3_PROBE_FINDINGS.md`):** `QUEST_TURNED_IN` fired on 16 turn-ins with `(questID, xp, money)`; its
  XP/money arguments were the reliable reward source on this build (the corrected M3 finding). The quest ID
  was present on every event.
- **Not measured by M3:** exactly-once firing, timing against the player's click, behaviour on a cancelled
  reward screen, or whether it fires on window-open versus reward-taken. M3 was a data-capture probe, not a
  reliability test. Those are exactly the progression-relevant properties, so none of them is assumed.
- **M8.7:** `QUEST_ACCEPTED(questID)` is a proven accept signal; `QUEST_REMOVED(questID, bool)` fired on
  abandon. Whether `QUEST_REMOVED` also fires on turn-in is unknown and is recorded here as context only.

## 3. Test surface: disposable standalone probe

`ForeverProbeM88`, the same convention as `ForeverProbeM87` and the M3/M4 probes. ForeverRecorder is locked
(M7.7 manifest); M8.7's probe is part of a locked milestone and is not reused or modified.

| | Value |
|---|---|
| Folder | `m8-8-quest-turned-in-probe/addon/ForeverProbeM88` |
| SavedVariables | `ForeverProbeM88DB` (sessions appended) |
| Slash command | `/fprobe88` (summary only) |
| Chat prefix | `[FProbeM88]` (magenta) |
| Version | `m8-8-probe-0.1` |

## 4. What the probe records

- **Registration result** for `QUEST_TURNED_IN` (a registration error is recorded, not raised).
- **Ground truth for "reward taken":** a `hooksecurefunc` post-hook on `GetQuestReward`, the function the
  reward screen's "Complete Quest" button calls. Observe-only; the probe never calls it. A post-hook on
  `CompleteQuest` (the progress screen's "Continue" button) is also recorded.
- **Every `QUEST_TURNED_IN`:** all arguments by position with types and count; for numeric arguments,
  read-only `C_QuestLog.GetTitleForQuestID`, `IsOnQuest`, `IsQuestFlaggedCompleted` (legacy
  `IsQuestFlaggedCompleted` fallback); which argument, if any, equals the quest ID of the last reward screen;
  seconds since the last Complete click and since the reward screen opened.
- **Timeline controls:** `QUEST_PROGRESS` and `QUEST_COMPLETE` (both confirmed since M3, with `GetQuestID()` and
  title), `QUEST_FINISHED` (dialog closed; unconfirmed), `QUEST_REMOVED`, and throttled `QUEST_LOG_UPDATE` /
  `UNIT_QUEST_LOG_CHANGED`.
- **Cap:** 300 stored events per session.

**Read-only guarantee:** never calls `GetQuestReward`, `CompleteQuest`, `AcceptQuest`, `AbandonQuest`, or any
other quest-state-changing function; enforced by the self-test and a source grep.

## 5. Persistence

Logout/character-select saves are unreliable on this client (`M8_0_SCOPE.md` §2); `/reload` saves are
confirmed. The procedure ends with `/reload`.

## 6. Result criteria

**PASS** requires all of:

- `QUEST_TURNED_IN` registers;
- each successful normal turn-in (a Complete click recorded) produces exactly one `QUEST_TURNED_IN`;
- it fires promptly after the Complete click (within 5 s);
- an argument equals the quest ID shown on that turn-in's reward screen;
- opening and cancelling the reward screen produces no `QUEST_TURNED_IN`;
- no Lua errors.

**PARTIAL:** some of the above hold but not all — for example it fires but without a matching ID, fires more
than once, fires late, fires on the cancelled screen, or fires on window-open rather than on the click. Each
failed property is recorded as its own sub-finding.

**FAIL:** the event fails to register, or never fires although the controls show a Complete click and the
quest left the log.

**INCONCLUSIVE (retest):** the probe did not observe the interaction — no `QUEST_COMPLETE` or Complete click
recorded, the `GetQuestReward` hook failed to install and timing cannot be established, no session in the
saved file, or the cancel step was not performed (the false-event criterion is then unanswered, and the
result is at most Partial-pending).

## 7. What a successful result would enable later (not designed here)

A route's TURN_IN step could be matched directly by comparing `QUEST_TURNED_IN`'s quest-ID argument with the
step's `quest_id`, the same way M8.7 enables ACCEPT steps. Together, ACCEPT and TURN_IN would cover the two
step kinds in the current test route that correspond to discrete server events. OBJECTIVE and TRAVEL remain
separate, unanswered questions.

## 8. Out of scope

Route progression, objective completion, travel detection, distances, arrival radii, UI changes, production
addon changes, `M8_2_SCOPE.md` edits (an addendum goes in the completion report), quest grinding.

## 9. Files

```
m8-8-quest-turned-in-probe/
  addon/ForeverProbeM88/ForeverProbeM88.toc
  addon/ForeverProbeM88/ForeverProbeM88.lua
  tests/run_probe_selftest.lua     -- 25 checks, lua5.1, stub environment only
  M8_8_GUIDE.md                     -- operator test procedure
  docs/M8_8_SCOPE.md                -- this document (copy to forever-db/docs/)
```

`M8_8_COMPLETION_REPORT.md` is written after the real-client test.

**M8.8 SCOPE DEFINED — probe ready for real-client test; no production code touched.**
