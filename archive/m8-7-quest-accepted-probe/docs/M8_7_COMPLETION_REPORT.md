# M8.7 Completion Report: QUEST_ACCEPTED Existence & Reliability

**Result: PASS.** `QUEST_ACCEPTED` exists on WoW Forever, fired exactly once per accept (2 of 2), about 0.39 s
after the Accept click, and its single argument is the quest ID, matching the offer screen. It also fired on
re-accepting a quest that had been abandoned. No production code, route data, or recorder file was touched.

**Test date:** 2026-09-30. Client: `1.60.1`, build `70124` (Sep 29 2026), interface `16001`.
Evidence: `ForeverProbeM87.lua` SavedVariables (2 sessions, saved via `/reload`), plus 4 operator screenshots.

## Results against the M8.7 criteria (`M8_7_SCOPE.md` §7)

| Criterion | Result | Evidence |
|---|---|---|
| `QUEST_ACCEPTED` registers | PASS | Both sessions: `registration.QUEST_ACCEPTED = "registered"` |
| Fires exactly once per accept | PASS | Session 2: `AcceptQuest` clicks = 2, `QUEST_DETAIL` = 2, `QUEST_ACCEPTED` = 2; no duplicates in the stored event sequence |
| Fires within 0–5 s of the Accept click | PASS | 0.394 s (The Book of Ur), 0.387 s (Light's Justice) |
| An argument identifies the accepted quest | PASS | Single argument = quest ID; matches `QUEST_DETAIL`'s `GetQuestID()` both times (1013, 92421); resolves via `C_QuestLog.GetTitleForQuestID`, `IsOnQuest = true` |
| Fires again on re-accept after abandon | PASS | Light's Justice (92421) abandoned in session 1, re-accepted in session 2, event fired with the correct ID |
| No false firing | PASS | Operator's attempted wool-quest accept that did not happen produced no offer event, no click, and no `QUEST_ACCEPTED` |
| No Lua errors | PASS | Operator confirmed no Lua errors with `/console scriptErrors 1` enabled |

## Event sequence observed (session 2, both accepts identical)

```
QUEST_DETAIL            GetQuestID() = 1013, title "The Book of Ur"      t = 967.235
AcceptQuest (hook)      player click                                     t = 967.819  (+0.584)
UNIT_QUEST_LOG_CHANGED  "player"                                         t = 968.213  (+0.394)
QUEST_ACCEPTED          (1013)                                           t = 968.213  (same frame)
QUEST_LOG_UPDATE x2                                                      t = 968.228, 968.260
```

## Side findings (recorded, not acted on)

1. **Argument shape is the modern one:** `QUEST_ACCEPTED(questID)`, a single number. Not the older
   `(questLogIndex, questID)` form.
2. **Forever quest IDs above the classic range work normally:** Light's Justice is 92421.
3. **At the moment of the Accept click the offer frame is already closing:** `GetQuestID()` returns `0` and
   `GetTitleText()` returns `""` inside the `AcceptQuest` post-hook. The quest ID is available at
   `QUEST_DETAIL` and in `QUEST_ACCEPTED`'s argument, not at click time.
4. **Abandon path (session 1):** `C_QuestLog.AbandonQuest` exists and hooks cleanly; the legacy globals
   `AbandonQuest` and `SetAbandonQuest` do not exist on this client. Abandoning fired
   `QUEST_REMOVED(92421, false)` 0.344 s after the call. The second argument appears to be the modern
   "was replay quest" flag; unconfirmed.
5. **`C_QuestLog.GetNumQuestLogEntries()` counts header rows, not quests:** accepting The Book of Ur moved the
   count 9 → 11 (quest plus a new zone header); Light's Justice moved it 11 → 12 (existing header). It must
   not be treated as a quest count.
6. **`QUEST_DETAIL` carries one numeric argument, `0` in both cases.** On modern clients this is the
   quest-starting item ID (0 = offered by an NPC); unconfirmed on Forever.

## Update to `docs/M8_2_SCOPE.md` §9 and §15

| M8.2 deferred item | Status after M8.7 |
|---|---|
| Map / minimap marker | Resolved (M8.6-B) |
| Directional arrow | Partial evidence (M8.6-B: `C_SuperTrack` waypoint arrow works) |
| Semi-automatic progression | **Unblocked for ACCEPT steps.** `QUEST_ACCEPTED(questID)` is a reliable, correctly identified accept signal. The §9 manual-vs-semi-automatic decision can now be made on evidence. |

## What this means for later progression design (not designed here)

- An ACCEPT step can be matched directly by comparing `QUEST_ACCEPTED`'s argument to the step's `quest_id`.
  No pairing with `QUEST_DETAIL` is needed.
- `QUEST_REMOVED(questID)` exists as a matching "undo" signal for an abandoned quest.
- Nothing here covers TURN_IN, OBJECTIVE, or TRAVEL steps. `QUEST_TURNED_IN` is already confirmed from M3+,
  but its fit for progression has not been evaluated.
- Whether progression should confirm with the player or advance on its own remains a design decision for a
  later milestone.

## Scope kept

No change to ForeverQuestGuide v0.6, route data, route logic, or ForeverRecorder. The probe collected 15
stored events across two short sessions, with no quest grinding. It can now be removed from `AddOns`.

```text
M8.7 STATUS: COMPLETE AND LOCKED — PASS (real-client validated, 2026-09-30)
```
