# M8.8 Completion Report: QUEST_TURNED_IN Existence & Reliability

**Result: PASS.**
`QUEST_TURNED_IN` fired exactly once per successful turn-in (2 of 2), 0.16–0.23 s after the Complete Quest
click, never on window-open, and not at all for a reward screen that was opened and cancelled. Its first
argument is the quest ID and matched the reward screen both times. No production code, route data, recorder
file, or M8.7 file was touched.

**Test date:** 2026-09-30. Client `1.60.1`, build `70124` (Sep 29 2026), interface `16001`.
Evidence: `ForeverProbeM88.lua` SavedVariables (1 session, 33 stored events, saved via `/reload`), plus
operator screenshots of every step and the `/fprobe88` summary.

## Results against `M8_8_SCOPE.md` §6

| Criterion | Result | Evidence |
|---|---|---|
| `QUEST_TURNED_IN` registers | PASS | `registration.QUEST_TURNED_IN = "registered"`; `GetQuestReward` hook `installed` |
| Exactly one event per successful turn-in | PASS | `hook:GetQuestReward` = 2, `QUEST_TURNED_IN` = 2; no other `QUEST_TURNED_IN` anywhere in the 33-event sequence |
| Prompt, and after the reward is actually taken | PASS | 0.227 s (The New Plague) and 0.158 s (Unending Torment) after the Complete click; 6.55 s and 1.85 s after the reward screen opened — it tracks the click, not the window |
| An argument identifies the quest | PASS | Argument 1 = quest ID; argument shape `(questID, xp, money)` = `(95216, 8300, 0)` and `(97288, 5300, 0)`; XP matches the client's "Experience gained" lines |
| ID matches the quest turned in | PASS | `arg_matching_reward_screen = 1` both times; reward-screen `GetQuestID()` 95216 and 97288 |
| Consistent on a second turn-in | PASS | Unending Torment behaved identically to The New Plague |
| No false event from open-and-cancel | PASS | Unending Torment's reward screen opened at t = 168.567 and was closed without Complete at t = 196.638; no `QUEST_TURNED_IN` until the real Complete click at t = 230.789 |
| No Lua errors | PASS | Operator confirmed no Lua errors with `/console scriptErrors 1` enabled |

## Timeline (both turn-ins; cancel shown for Unending Torment)

```
The New Plague (95216)
  QUEST_PROGRESS           t = 037.441   "Continue" screen
  CompleteQuest (hook)     t = 040.975   Continue clicked
  QUEST_FINISHED           t = 041.263   progress screen closing
  QUEST_COMPLETE           t = 041.263   reward screen OPEN
  GetQuestReward (hook)    t = 047.590   Complete Quest clicked (choice 1)
  QUEST_TURNED_IN          t = 047.817   (95216, 8300, 0)       +0.227 s
  QUEST_REMOVED            t = 047.817   (95216, false)

Unending Torment (97288) — cancel
  QUEST_COMPLETE           t = 168.567   reward screen OPEN
  QUEST_FINISHED x2        t = 196.638   closed without Complete — no QUEST_TURNED_IN

Unending Torment (97288) — turn-in
  QUEST_COMPLETE           t = 229.095   reward screen OPEN
  GetQuestReward (hook)    t = 230.789   Complete Quest clicked (choice 0)
  QUEST_TURNED_IN          t = 230.947   (97288, 5300, 0)       +0.158 s
  QUEST_REMOVED            t = 231.161   (97288, false)         +0.214 s after QUEST_TURNED_IN
```

(Times are `GetTime()` seconds with the leading `1168` omitted.)

## Excluded observation

**Crest of Lordaeron (95204)**, turned in earlier, was observed only by the old M8.7 probe (still installed at
the time), which does not listen for `QUEST_TURNED_IN`. It is excluded as **Inconclusive**, not counted
either way. It did show `QUEST_REMOVED(95204)` alongside a genuine turn-in, consistent with the pattern above.

## Side findings (recorded, not acted on)

1. **Quest state at the moment of the event is not consistent.** At The New Plague's `QUEST_TURNED_IN`, the
   quest was already out of the log (`IsOnQuest = false`) and flagged completed; at Unending Torment's, it was
   still in the log (`IsOnQuest = true`) and not yet flagged. The event's own argument was correct both times;
   state lookups made at that instant are not reliable.
2. **`QUEST_REMOVED` cannot tell a turn-in from an abandon.** It fires on both, with an identical second
   argument (`false` on both turn-ins here and on the M8.7 abandon). Its timing relative to
   `QUEST_TURNED_IN` also varies (same frame vs +0.214 s). `QUEST_TURNED_IN` is the signal that distinguishes
   them.
3. **`QUEST_FINISHED` is noisy:** it fires on the progress-to-reward transition, sometimes twice per close, and
   after a completed turn-in as well as a cancel (9 in this session). It cannot identify a cancel on its own.
4. **Unlike M8.7's `AcceptQuest` hook, `GetQuestID()` inside the `GetQuestReward` hook still returned the
   correct quest ID** (95216, 97288); the reward frame had not yet closed.
5. **`GetQuestReward`'s argument is the reward-choice index** as expected on Blizzard clients: `1` for The New
   Plague (a choice was offered, Plaguefang received), `0` for Unending Torment (no choice). Unconfirmed
   beyond these two cases.
6. **Forever quest IDs above the classic range** (95216, 97288) behave normally.

## M8.2 addendum (for later incorporation into `docs/M8_2_SCOPE.md` §9/§15; not applied here)

| M8.2 deferred item | Status after M8.8 |
|---|---|
| Map / minimap marker | Resolved (M8.6-B) |
| Directional arrow | Partial evidence (M8.6-B) |
| Semi-automatic progression — ACCEPT steps | Signal proven (M8.7: `QUEST_ACCEPTED(questID)`) |
| Semi-automatic progression — TURN_IN steps | **Signal proven (M8.8: `QUEST_TURNED_IN(questID, xp, money)`)** |
| Semi-automatic progression — OBJECTIVE steps | Unresolved; no completion signal identified |
| Semi-automatic progression — TRAVEL steps | Unresolved; no destination data or arrival measure |

The §9 manual-vs-semi-automatic decision remains open. M8.7 and M8.8 together supply evidence for the two step
kinds that correspond to discrete server events.

## What this enables later (not designed here)

A TURN_IN step can be matched by comparing `QUEST_TURNED_IN`'s first argument with the step's `quest_id`,
exactly as M8.7 allows for ACCEPT steps. The match should rely on the event argument, not on quest-log state
read at that moment (side finding 1), and not on `QUEST_REMOVED` (side finding 2).

## Scope kept

No change to ForeverQuestGuide v0.6, route data, route logic, ForeverRecorder, or any M8.7 file. Two quests the
operator was turning in anyway; no grinding. The probe can now be removed from `AddOns`.

```text
M8.8 STATUS: COMPLETE AND LOCKED — PASS (real-client validated, 2026-09-30)
```
