# M8.7: QUEST_ACCEPTED Existence & Reliability Investigation

**Status: scope defined, probe built and stub-tested, awaiting real-client test.** No production addon, route
data, route logic, or recorder file is created or modified by this milestone. The validated v0.6
ForeverQuestGuide build (M8.6-B) is frozen and untouched.

**Scope date:** 2026-09-30. Intended destination: `forever-db/docs/M8_7_SCOPE.md`.

## 1. The one question

> Does WoW Forever expose a `QUEST_ACCEPTED` event that fires reliably — once per accept, with enough
> information to identify the accepted quest?

Nothing else. Designing or implementing semi-automatic route progression is explicitly out of scope; this
milestone only produces the evidence that design will depend on.

## 2. Update to `docs/M8_2_SCOPE.md` conclusions

M8.2 §15 deferred three navigation features, each behind its own unknown. Those conclusions are preserved as
written; this section records what has changed since, per the project's dated-addendum convention (the
original text is not rewritten). Recommend appending this section to `M8_2_SCOPE.md` as a dated note.

| M8.2 deferred item | M8.2 blocker | Status as of 2026-09-30 |
|---|---|---|
| Map / minimap marker | No map-pin API confirmed | **Resolved (M8.6-B).** `C_Map.SetUserWaypoint`, `C_Map.CanSetUserWaypointOnMap`, `UiMapPoint.CreateFromCoordinates`, `WorldMapFrame:SetMapID` real-client validated; pins confirmed on uiMapID 1413 (Barrens) and 1411 (Durotar). See `docs/M8_6_B_REAL_CLIENT_VALIDATION.md`. Eastern Kingdoms maps not yet tested. |
| Directional arrow | No cross-map distance math or yards conversion confirmed | **Partial evidence (M8.6-B).** `C_SuperTrack.SetSuperTrackedUserWaypoint(true)` is confirmed and the game's own waypoint arrow now exists as a capability, so a custom arrow may not be needed. Still unconfirmed: the arrow's behaviour on the same continent as the pin, and any distance/yards value. The cross-map math question itself is unchanged. |
| Semi-automatic progression | `QUEST_ACCEPTED` never hooked | **Unresolved — this milestone.** |

M8.2's other conclusions stand unchanged: 0 of 153 prerequisites resolved, no NPC world coordinates (only
observed player positions), and the manual-vs-semi-automatic decision in §9 remains open until M8.7 reports.

## 3. What is already known (and not)

- **Confirmed quest events on Forever (M3–M7.7):** `QUEST_DETAIL`, `QUEST_COMPLETE`, `QUEST_TURNED_IN`,
  `QUEST_PROGRESS`, and `GetQuestID()` at the offer screen.
- **Never hooked anywhere in the project:** `QUEST_ACCEPTED`, `QUEST_REMOVED`, `QUEST_ACCEPT_CONFIRM`.
- **Unknown:** whether `QUEST_ACCEPTED` exists on this client at all, and if so its argument shape. Blizzard
  clients differ (`questID` alone on modern clients; `questLogIndex, questID` on older ones). The client's
  modern map API (M8.6-B) is suggestive but is not evidence about this event.

## 4. Test surface decision: disposable standalone probe

A new probe, `ForeverProbeM87`, following the M3/M4 convention (`ForeverProbe`, `ForeverProbeM4`,
`ForeverProbeM4Rep`, `ForeverProbeM4Retry`) — not a change to ForeverRecorder:

- The recorder is locked under the M7.7 manifest; adding a hook would reopen a validated component to answer a
  yes/no question.
- A probe can be installed beside the recorder and deleted afterwards with no residue in production data.
- The question is about one event, not about observation capture, so the recorder's observer pipeline adds
  nothing to the test.

| | Value |
|---|---|
| Folder | `m8-7-quest-accepted-probe/addon/ForeverProbeM87` |
| SavedVariables | `ForeverProbeM87DB` (sessions appended, never overwritten) |
| Slash command | `/fprobe87` (summary only) |
| Chat prefix | `[FProbeM87]` (cyan) |
| Version | `m8-7-probe-0.1` |

## 5. What the probe records

- **Registration result** for `QUEST_ACCEPTED`. An unknown event makes `RegisterEvent` raise an error; the
  probe records that error as a finding instead of failing.
- **Every `QUEST_ACCEPTED` firing:** all arguments by position with their Lua types and an explicit count;
  for each numeric argument, read-only lookups (`C_QuestLog.GetTitleForQuestID`, `IsOnQuest`,
  `GetLogIndexForQuestID`, legacy `GetQuestLogIndexByID` / `GetQuestLogTitle`) so the argument can be
  identified whichever shape the client uses; quest-log entry count.
- **Control events,** so a missing `QUEST_ACCEPTED` can be told apart from a probe that wasn't running:
  `QUEST_DETAIL` (confirmed since M3), `QUEST_REMOVED`, `QUEST_ACCEPT_CONFIRM`, `QUEST_TURNED_IN`, and a
  throttled `QUEST_LOG_UPDATE` / `UNIT_QUEST_LOG_CHANGED` (counted always, stored only within 5 s of an
  accept or abandon, max 5 per window).
- **Ground truth:** `hooksecurefunc` post-hooks on `AcceptQuest`, `AbandonQuest`, `SetAbandonQuest`, and
  `C_QuestLog.AbandonQuest` timestamp the player's own clicks. These are observe-only.
- **Hard cap** of 300 stored events per session.

**Read-only guarantee:** the probe never calls `AcceptQuest`, `AbandonQuest`, `CompleteQuest`,
`GetQuestReward`, or any other quest-state-changing function (enforced by the stub self-test).

## 6. Persistence

`docs/M8_0_SCOPE.md` §2 records that logout/character-select SavedVariables saves are unreliable on this
client while `/reload` saves are confirmed. The procedure therefore ends with `/reload` before any logout,
and the operator sends the file written by that reload.

## 7. Result criteria

**PASS:** `QUEST_ACCEPTED` registers, fires exactly once per accept, 0.0–5 s after the `AcceptQuest` click,
and at least one argument resolves to the accepted quest (its ID matches `QUEST_DETAIL`'s `GetQuestID()` or
it resolves to the same title). If the optional abandon/re-accept is done, it fires again on re-accept.

**FAIL:** registration error (event does not exist), or it registers but never fires while the controls
(`QUEST_DETAIL`, `AcceptQuest` hook) show the probe was live and the quest entered the log.

**PARTIAL:** fires, but with no argument identifying the quest; fires more than once per accept; fires on the
first accept but not the re-accept; or delay beyond 5 s. Each is recorded as its specific sub-finding.

**INCONCLUSIVE (retest, not fail):** the control events and `AcceptQuest` hook also did not fire, or the
SavedVariables file shows no session (probe did not load or the reload did not save).

## 8. What each result means for later progression design (not designed here)

- **PASS:** semi-automatic progression (the addon suggests "step done" when the step's quest is accepted, the
  player confirms) becomes a viable option for M8.2 §9, for ACCEPT steps only. Other step kinds
  (TURN_IN, OBJECTIVE, TRAVEL) have their own evidence questions not covered here.
- **FAIL:** progression stays manual (current v0.6 behaviour). A fallback such as comparing quest-log
  contents on `QUEST_LOG_UPDATE` could be investigated separately; it is not assumed to work.
- **PARTIAL:** the specific sub-finding decides it (e.g. no quest ID → pair the event with the
  `QUEST_DETAIL` ID captured just before; duplicate firing → de-duplicate by quest ID). Any such workaround
  would itself need validation.

## 9. Out of scope

Automatic or semi-automatic progression, route logic, any change to ForeverQuestGuide v0.6 or its route data,
recorder changes, TURN_IN/OBJECTIVE detection, arrow or distance work, new evidence collection, and quest
grinding.

## 10. Files

```
m8-7-quest-accepted-probe/
  addon/ForeverProbeM87/ForeverProbeM87.toc
  addon/ForeverProbeM87/ForeverProbeM87.lua
  tests/run_probe_selftest.lua     -- 19 checks, lua5.1, stub environment only
  M8_7_GUIDE.md                     -- operator test procedure
  docs/M8_7_SCOPE.md                -- this document (copy to forever-db/docs/)
```

**M8.7 SCOPE DEFINED — probe ready for real-client test; no production code touched.**
