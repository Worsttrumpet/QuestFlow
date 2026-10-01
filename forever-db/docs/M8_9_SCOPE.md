# M8.9: Quest Objective Progress Investigation

**Status: scope defined, probe built and stub-tested, awaiting real-client test.** No production addon, route
data, route logic, recorder, M8.7, or M8.8 file is created or modified. ForeverQuestGuide v0.6 is frozen.

**Scope date:** 2026-09-30. Intended destination: `forever-db/docs/M8_9_SCOPE.md`.

## 1. The question

> Does WoW Forever expose enough reliable client-side information to detect quest objective progress and
> completion?

Sub-questions, each answered separately:

1. Does `QUEST_LOG_UPDATE` fire when an objective progresses?
2. Does `UNIT_QUEST_LOG_CHANGED` fire when an objective progresses?
3. Can either be associated with the correct quest ID?
4. Can the objective's state be read reliably after the event?
5. Is state already updated when the event fires, or is there a delay?
6. Can objective completion be detected reliably?
7. Does event behaviour differ between objective progress and unrelated quest-log changes?
8. Does the client's objective order correspond to the route data's `objective_index`?
9. Can multiple objectives within one quest be told apart?
10. Does it work across more than one objective type, if practical?

Designing or implementing progression is out of scope.

## 2. Why this is harder than M8.7/M8.8

`QUEST_ACCEPTED` and `QUEST_TURNED_IN` each carry the quest ID. The candidate objective events do not name an
objective, and on modern clients `QUEST_LOG_UPDATE` carries no arguments at all. Detection therefore has to
come from **reading quest-log state and comparing it with the previous reading**. M8.8 showed that state read
at the instant of an event can lag (`IsOnQuest` still true at one `QUEST_TURNED_IN`, false at another), so
timing is measured explicitly rather than assumed.

## 3. Candidates under test

**Events** (none assumed to work; registration results recorded):

| Event | Prior evidence on Forever |
|---|---|
| `QUEST_LOG_UPDATE` | Registers and fires (M8.7/M8.8), no arguments observed; never tied to objective progress |
| `UNIT_QUEST_LOG_CHANGED` | Registers and fires with `"player"` (M8.7/M8.8); never tied to objective progress |
| `QUEST_WATCH_UPDATE` | Never tested. Added because on Blizzard clients it is the one candidate that carries an identifier (quest ID or log index); a registration error is recorded as a finding |

**Read APIs** (availability recorded per session; modern first, legacy fallback):

| Purpose | Modern | Legacy fallback |
|---|---|---|
| List quests in log | `C_QuestLog.GetNumQuestLogEntries`, `C_QuestLog.GetInfo(i)` | `GetNumQuestLogEntries`, `GetQuestLogTitle(i)` |
| Objectives | `C_QuestLog.GetQuestObjectives(questID)` → text, type, finished, numFulfilled, numRequired | `GetNumQuestLeaderBoards` + `GetQuestLogLeaderBoard(j, i)`, counts parsed from text |
| Quest completion | `C_QuestLog.IsComplete`, `C_QuestLog.ReadyForTurnIn` | — |

**Context events** (to classify unrelated log changes): `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `QUEST_REMOVED`,
`UI_INFO_MESSAGE` (the on-screen "Thunder Lizard Blood: 2/3" style message; capped at 60).

## 4. Method

The probe keeps a snapshot of every quest's objectives and diffs it at three moments:

| Detected by | When | Answers |
|---|---|---|
| `event` | Inside the candidate event's handler | Is state already updated when the event fires? (Q5) |
| `delayed` | 0.1, 0.25, 0.5, 1.0, 2.0 s after each candidate event | If not, how long until it is? (Q5) |
| `poll` | Every 1 s, only when no delayed read is pending | Did state change with no candidate event within 2 s? (Q1/Q2) |

Each detected change records the quest ID, objective index, before/after (`have`, `need`, `finished`, `text`),
the triggering event and delay, and a full snapshot of the affected quest for ordering analysis. Candidate
events with no change are recorded too (Q7). Quest-level `IsComplete`/`ReadyForTurnIn` flips are recorded as
completion (Q6).

**Text versus progress:** each objective's text is classified `present`, `count_only_no_name` (e.g. `"0/1  "`),
or `missing`, separately from whether `have`/`need` are readable. Blank text is evidence, not an automatic
failure.

**Objective ordering (Q8):** answered offline. The client's objective order is compared (a) across snapshots
within a session, (b) across a `/reload`, and (c) against `Data.lua`'s objective list, which is what a route's
`objective_index` indexes into. Only 17 of `Data.lua`'s 96 quests have 2+ objectives, mostly low-level Skyborne
quests; the only route with an `objective_index` uses quest 907, which has one objective. (c) is therefore only
possible if a `Data.lua` quest happens to be in the operator's log; it needs no progress on that quest, just
presence.

**Timers:** a frame `OnUpdate` script (frames confirmed); `C_Timer` is recorded but not relied on. OnUpdate
tick count is recorded so timers that never ran are visible.

## 5. Probe

| | Value |
|---|---|
| Folder | `m8-9-objective-progress-probe/addon/ForeverProbeM89` |
| SavedVariables | `ForeverProbeM89DB` (sessions appended) |
| Slash command | `/fprobe89` (summary), `/fprobe89 snap` (print current objectives) |
| Chat prefix | `[FProbeM89]` (green) |
| Version | `m8-9-probe-0.1` |

Read-only: calls only quest-log read functions; installs no hooks; never calls `AcceptQuest`, `AbandonQuest`,
`CompleteQuest`, `GetQuestReward`. Caps: 600 records, 200 stored no-change events, 60 pending delayed reads.
Baseline snapshot 3 s after `PLAYER_ENTERING_WORLD`; final snapshot on `PLAYER_LOGOUT` (fired by `/reload`).

## 6. Result criteria

### Objective detection (Q1–Q7, Q9)

**PASS** requires all of:

- at least one candidate event fires on **every** observed progress step (at least 2 steps), and no progress
  step is detected **only** by the poll;
- every step is attributed to the correct quest ID and objective index (matching the game's own progress
  message/tracker);
- the new state is readable either at the event or within one consistent short delay (≤ 2 s) for every step;
- completion of at least one objective is detected (`finished` flag), plus quest-level `IsComplete` or
  `ReadyForTurnIn` if the quest itself completes;
- on a quest with 2+ objectives, progress on one leaves the others unchanged in the diff;
- candidate events with no objective change are distinguishable from progress (Q7);
- OnUpdate ran; no Lua errors.

**PARTIAL:** detection works but at least one of the above is unmet — e.g. some steps seen only by the poll,
inconsistent delays, no multi-objective quest was available, completion not reached, or one candidate event
never fires while another does. Each unmet item is recorded.

**FAIL:** objective state cannot be read (no objective API returns usable counts), or reads never change
although the game shows progress.

**INCONCLUSIVE (retest):** no objective progress occurred in the session, no baseline was taken, OnUpdate never
ran (timing unanswerable), or the saved file has no session.

### Objective ordering (Q8), reported as its own sub-result

- **Confirmed:** client order is stable within the session and across `/reload`, and matches `Data.lua` for
  every `Data.lua` quest present in the log.
- **Stable, not comparable:** stable in-client, but no `Data.lua` quest was in the log.
- **Mismatch:** order differs from `Data.lua`, or changes between snapshots/sessions.

A "stable, not comparable" result does not block detection PASS; it leaves Q8 open.

### Objective types (Q10)

Recorded if 2+ types are observed; not required for PASS.

## 7. What each result would mean later (not designed here)

- **PASS, state ready at the event:** OBJECTIVE steps could be evaluated directly when a candidate event fires.
- **PASS, state ready only after a delay:** any design must re-read after the measured delay.
- **Poll-only changes observed:** event-driven detection would miss progress; a design would need polling.
- **Fail:** OBJECTIVE steps stay manual.
- **Q8 confirmed:** a route's `objective_index` can index the client's objective list directly. **Mismatch:**
  objectives would need matching by another key (type/text; blank text complicates this) or OBJECTIVE steps
  would rely on quest-level completion only. **Not comparable:** mapping stays open.

## 8. Out of scope

Route progression, travel detection, distances, arrival radii, UI changes, production addon changes,
`M8_2_SCOPE.md` edits, broad data collection, quest grinding.

## 9. Files

```
m8-9-objective-progress-probe/
  addon/ForeverProbeM89/ForeverProbeM89.toc
  addon/ForeverProbeM89/ForeverProbeM89.lua
  tests/run_probe_selftest.lua     -- 33 checks, lua5.1, stub environment only
  M8_9_GUIDE.md                     -- operator test procedure
  docs/M8_9_SCOPE.md                -- this document
```

`M8_9_COMPLETION_REPORT.md` is written after the real-client test.

**M8.9 SCOPE DEFINED — probe ready for real-client test; no production code touched.**
