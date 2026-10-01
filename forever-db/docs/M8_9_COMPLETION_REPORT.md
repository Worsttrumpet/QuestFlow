# M8.9 Completion Report: Quest Objective Progress Investigation

**Result: Objective detection PASS. Objective ordering (Q8): stable, not yet comparable (left open).**

Every one of 15 observed objective progress steps was detected **at** `UNIT_QUEST_LOG_CHANGED("player")`, with
the quest-log state already updated at that moment. The correct quest and objective index were identified
every time, objective and quest completion were detected, two objectives in one quest were told apart, and no
change was found only by a delayed read or the background poll. Client objective order was stable within the
session and across two reloads, but none of the quests played are in `Data.lua`, so the correspondence to route
`objective_index` remains untested. No production code, route data, recorder, M8.7, or M8.8 file was touched.

**Test date:** 2026-09-30. Client `1.60.1`, build `70124`, interface `16001`.
Evidence: `ForeverProbeM89.lua` SavedVariables (3 sessions, 203 records, saved via `/reload`), operator
screenshots, operator confirmation of no Lua errors (`/console scriptErrors 1`).

## Answers

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | Does `QUEST_LOG_UPDATE` fire on progress? | **Yes**, 15/15, always 0.000–0.020 s **after** `UNIT_QUEST_LOG_CHANGED` | Session 3 timeline |
| 2 | Does `UNIT_QUEST_LOG_CHANGED` fire on progress? | **Yes**, 15/15, with unit `"player"` | Session 3 timeline |
| 3 | Can either be tied to the quest ID? | **Not from the event**: `QUEST_LOG_UPDATE` has no arguments; `UNIT_QUEST_LOG_CHANGED` carries only a unit. The quest and objective come from diffing state. `QUEST_WATCH_UPDATE(questID)` does carry the correct ID (see below) | Event args |
| 4 | Is state readable after the event? | **Yes**: `C_QuestLog.GetQuestObjectives` returned `numFulfilled`/`numRequired`/`finished`/text/type for every quest | All snapshots |
| 5 | Updated immediately or delayed? | **Immediately at `UNIT_QUEST_LOG_CHANGED`**: 15/15 changes seen in that event's own handler; 0 by the 0.1–2.0 s delayed reads; 0 by the poll | `objective_change:event` = 24 (15 progress + turn-in resets + name fills), `:delayed` = 0, `:poll` = 0 |
| 6 | Completion detectable? | **Yes**: `finished` set on 5 objectives reaching their target; `IsComplete` and `ReadyForTurnIn` false → true for The Dead Fields and A Recipe For Death, at the same event as the final step | Session 3 |
| 7 | Progress distinguishable from unrelated changes? | **Yes, by diff**: 84 candidate events had no change; accepts appear as `quest_added`, turn-ins as `quest_removed`; progress is the only case where `have` increases. One trap, below | All sessions |
| 8 | Client order vs route `objective_index`? | **Stable, not yet comparable** (open) | See §Ordering |
| 9 | Multiple objectives told apart? | **Yes**: A Recipe For Death #1 (6 steps) and #2 (6 steps) each changed alone; The Dead Fields #1 and #2 likewise | Session 3 |
| 10 | More than one objective type? | **Yes**: `item` (14 steps, from kill-loot and a looted quest item) and `event` (1 step, "Enter the Dead Fields"). `monster` objectives were read but not progressed | `type` field |

## Candidate events compared (15 progress steps)

| Event | Fired | Carries quest ID | State fresh when it fires |
|---|---|---|---|
| `UNIT_QUEST_LOG_CHANGED("player")` | 15/15 | No | **Yes, 15/15** |
| `QUEST_LOG_UPDATE` | 15/15 (after UQLC) | No | Inferred yes: it always followed a UQLC whose read already saw the new state; not independently measured, because the UQLC read consumed the diff first |
| `QUEST_WATCH_UPDATE(questID)` | 14/15 (missed the `event`-type objective) | **Yes**, correct every time | **No**: fired 0.000–0.169 s **before** the state updated; a read inside it returned the old value every time |

`UNIT_QUEST_LOG_CHANGED` also fired once with unit `"targettarget"` and no quest change; only `"player"` is
relevant.

## Timing detail

Typical progress step (A Recipe For Death, Grizzled Bear Heart 1/6 → 2/6):

```
QUEST_WATCH_UPDATE(447)         t = 520.695   state still 1/6
UI_INFO_MESSAGE "Grizzled Bear Heart: 2/6"   t = 520.695
UNIT_QUEST_LOG_CHANGED("player")  t = 520.831   state reads 2/6  <- detected here
QUEST_LOG_UPDATE                t = 520.838, 520.984
```

## Ordering (Q8)

- **Within a session:** A Recipe For Death (17 readings), The Dead Fields (7), Beren's Peril (5): one order each.
- **Across reloads:** Exploring the Horde (4 objectives), 10 readings across sessions 1, 2, and 3: one order.
- **Against `Data.lua`:** not possible. None of the 12 quests in the log (1013, 447, 1014, 93739, 421, 437, 493,
  516, 429, 428, 92401, 92422) is among `Data.lua`'s 96 quests.

**Sub-result: Stable, not yet comparable — left explicitly open.** No further real-client test is scheduled to
close it. It will be addressed only if and when a progression implementation needs the mapping, using one
suitable multi-objective route quest present in the log (no progress on it needed).

## Side findings (recorded, not acted on)

1. **Turn-in reset trap.** At turn-in, before the quest leaves the log, it reads as un-done for a moment:
   `IsComplete`/`ReadyForTurnIn` true → false and objectives 1/1 done → 0/1 (The Wrath of Rath'mael, A
   Frightened Request; Lost Deathstalkers showed the `IsComplete` flip). Naively read, this looks like progress
   being lost. In 2 of 3 cases the reset arrived **before** `QUEST_TURNED_IN` (by 0.044 s and 0.049 s), so the
   turn-in event cannot be relied on to have arrived first to explain it.
2. **`QUEST_REMOVED` preceded `QUEST_TURNED_IN` in 3 of 4 turn-ins here**, where M8.8 saw it follow. This is
   consistent with M8.8's finding that their relative timing varies and does not change M8.8's conclusion.
3. **Blank objective names are transient.** Newly accepted quests had correct counts immediately but names blank
   (`"0/6  "`, `"0/6   slain"`) for 0.017–0.218 s, filled in at a following `QUEST_LOG_UPDATE` (6 quests).
   Text availability and progress availability are separate, as the scope anticipated; the blank-name entries
   in earlier data captures are plausibly from this window.
4. **A quest appears at `QUEST_LOG_UPDATE`, not at `UNIT_QUEST_LOG_CHANGED`**, on accept: UQLC fired first with no
   change, then QLU showed `quest_added`.
5. **Objective text format varies by type:** `item`/`monster` texts carry counts; the `event` objective's text
   ("Enter the Dead Fields") and `log`-type text have none. Counts come from `numFulfilled`/`numRequired`, not text.
6. **"Speak with ..." objectives are typed `monster`** on Forever (Exploring the Horde).
7. **The `event` objective updated in state 17 s before its on-screen message**, which only appeared alongside
   the quest's other objective completing.
8. **API availability:** all modern `C_QuestLog` read functions used are present; legacy `GetQuestLogTitle` and
   global `GetNumQuestLogEntries` are absent; `GetQuestLogLeaderBoard` exists (unused); `C_Timer.After` exists
   (unused, untested).

## M8.2 addendum (for later incorporation into `docs/M8_2_SCOPE.md` §9/§15; not applied here)

| M8.2 deferred item | Status after M8.9 |
|---|---|
| Map / minimap marker | Resolved (M8.6-B) |
| Directional arrow | Partial evidence (M8.6-B) |
| Progression — ACCEPT steps | Signal proven (M8.7) |
| Progression — TURN_IN steps | Signal proven (M8.8) |
| Progression — OBJECTIVE steps | **Detection proven (M8.9)**: state diff read at `UNIT_QUEST_LOG_CHANGED("player")` (filtered to `"player"`); `QUEST_WATCH_UPDATE` not suitable as the primary signal; turn-in reset trap documented; mapping to route `objective_index` open |
| Progression — TRAVEL steps | Unresolved |

The §9 manual-vs-semi-automatic decision remains open.

## What this enables later (not designed here)

OBJECTIVE steps can be evaluated from quest-log state read at `UNIT_QUEST_LOG_CHANGED("player")`, which was
already current in every observed case; no delayed re-read was needed. `QUEST_WATCH_UPDATE` can name the quest
but must not be used to read state. A design would have to ignore the momentary reset at turn-in (side finding
1), and cannot index objectives by route `objective_index` until Q8 is compared against `Data.lua`.

## Scope kept

No change to ForeverQuestGuide v0.6, route data, route logic, ForeverRecorder, or any M8.7/M8.8 file. The
operator's normal questing; no grinding or extra data collection. The probe can now be removed from `AddOns`.

```text
M8.9 STATUS: COMPLETE AND LOCKED — Objective detection PASS (real-client validated, 2026-09-30)
            Q8 objective ordering: stable, not yet comparable (explicitly open)
```
