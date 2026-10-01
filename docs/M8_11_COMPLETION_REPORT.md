# M8.11 Completion Report: Progression Architecture and Design

**Result: design complete.** The progression architecture is documented in `PROGRESSION_DESIGN.md`, grounded in
the ForeverQuestGuide v0.6 source and the M8.7–M8.10 real-client evidence. The user-facing progression mode is
**not** chosen; the concrete differences are documented for that decision. No production Lua, route data, route
schema, ForeverRecorder, M8.7–M8.10 file, or `M8_2_SCOPE.md` was modified. No client probe was run.

**Date:** 2026-09-30.

## Architecture summary

One **progression controller** module owns the route pointer and a per-step state machine
(`WAITING` / `UNDETECTABLE` / `MET` (latched) / `ADVANCED` / `SKIPPED` / `ROUTE_COMPLETE`, with a `PAUSED`
overlay). Thin **event adapters** turn game events into signals; **pure evaluators**, one per step kind, decide
satisfaction; the **UI** only renders and forwards button presses. Detection results are recomputed from game
state after every load, never persisted. Manual Next/Previous remain in every mode, plus Skip, Reset step, Undo
(for automatic advances), and Pause.

## Classification

### VERIFIED on the real client

| Fact | Source |
|---|---|
| `QUEST_ACCEPTED(questID)`: once per accept, correct ID, ~0.39 s | M8.7 |
| `QUEST_TURNED_IN(questID, xp, money)`: once per turn-in, correct ID, 0.16–0.23 s after the click, none on cancel | M8.8 |
| `QUEST_REMOVED` fires on both abandon and turn-in with identical arguments; its order relative to `QUEST_TURNED_IN` varies | M8.7–M8.9 |
| Objective progress readable at `UNIT_QUEST_LOG_CHANGED("player")`, state already current (15/15) | M8.9 |
| `UNIT_QUEST_LOG_CHANGED` also fires for other units | M8.9 |
| `QUEST_WATCH_UPDATE(questID)` fires before state updates; missed 1/15 | M8.9 |
| Turn-in reset trap: quest reads un-complete for a moment at turn-in | M8.9 |
| Objective names blank for up to ~0.2 s after accept; counts correct immediately | M8.9 |
| Client objective order stable within a session and across two reloads | M8.9 |
| `C_QuestLog.GetQuestObjectives`, `IsComplete`, `ReadyForTurnIn`, `GetInfo`, `IsOnQuest`, `GetLogIndexForQuestID` return correct values mid-session | M8.7–M8.9 |
| A quest-log read **3 s after** `PLAYER_ENTERING_WORLD` returned the full log | M8.9 baseline |
| `C_Map.GetUserWaypoint` returns exact map + coordinates | M8.10 |
| Addon-computed same-continent distance reliable; cross-continent unavailable | M8.10 |
| Game navigation, arrow, and `NAVIGATION_DESTINATION_REACHED` follow the game's own target; quests reclaim super-tracking | M8.10 |
| `/reload` SavedVariables saves reliable; logout/character-select saves failed twice, cause unknown | M8.0 §2 (as cited in v0.6 source) |

### VERIFIED by existing code (v0.6)

| Fact | Where |
|---|---|
| Route pointer is `currentRouteID` + `currentStepIndex`, memory only; every load starts at step 1 of the first route | `UI.lua` |
| Advancing is `routeNext`/`routePrevious` → `renderRouteStep`; no progression logic exists | `UI.lua` |
| One account-wide SavedVariable `ForeverQuestGuideDB` with `theme`, `uiMode`, `welcomePopupDisabled` | `ForeverQuestGuide.toc`, `Preferences.lua` |
| Only `ADDON_LOADED` is registered anywhere | `Core.lua` |
| Steps carry string IDs; route source SHA-256 exists only as a comment | `RouteData.lua` |
| The only TRAVEL step (`s2`) has `destination = nil`; the destination shape `{ kind, ui_map_id, x, y }` exists (TURN_IN `s4`); no radius field | `RouteData.lua` |
| The only OBJECTIVE step has `quest_id` 907 and `objective_index` 1; no objective text or type in route data | `RouteData.lua` |
| `build()` has 56 upvalues; 22 are used only by its route-pane section | `luac -l -l` on `UI.lua` |

### UNVERIFIED

| Item | Why it matters |
|---|---|
| `C_QuestLog.IsQuestFlaggedCompleted` at startup | The only way to know a TURN_IN step (or a vanished quest) was completed before the addon loaded |
| `IsOnQuest` / `GetQuestObjectives` / position reads immediately at login (earlier than the 3 s deferral) | Timing of startup reconciliation |
| `SavedVariablesPerCharacter` on Forever | Per-character progression storage option |
| `UnitName("player")`, `GetRealmName()` as a character key | Per-character sub-table option |
| Whether logout/character-select persistence has changed since M8.0 | Whether saved progression survives a normal logout |

### DESIGN DECISION NEEDED

1. **Progression mode:** manual, semi-automatic, or automatic (differences in `PROGRESSION_DESIGN.md` §1).
2. **Per-character storage method:** `SavedVariablesPerCharacter` vs a keyed sub-table (both UNVERIFIED).
3. **Behaviour with no persisted state:** start at step 1 (v0.6 behaviour) vs suggest the first unsatisfied step.
4. **OBJECTIVE matching approach:** index, text, type, quest-level completion, or a combination (§7).
5. **Abandon handling:** what an ACCEPT-satisfied step does if its quest is abandoned later.
6. **TRAVEL radius policy** and **destination provenance** accepted for TRAVEL steps.
7. **Placement of new controls** (Skip, Reset, Undo, Pause) in the route pane and `/fguide`.

### FUTURE DATA WORK

1. TRAVEL destinations for TRAVEL steps (none exist).
2. A radius field in the route schema and generator.
3. A route version key as a data field (the SHA is only a comment today).
4. Objective text/type in route data, only if the chosen OBJECTIVE approach needs it.
5. Real routes: the single test route is the only one, and the guide's 96 quests barely overlap the quests being
   played.
6. Incorporating the M8.7–M8.10 addenda into `M8_2_SCOPE.md` (deferred, documentation only).

## Readiness

**Recommended architecture** (independent of mode): the controller/adapter/evaluator split above, in new files;
`UI.lua` reduced to rendering plus button forwarding; detection recomputed, never persisted; step IDs persisted
instead of indexes; latching for `MET`; manual controls always available.

**Implementable without new client testing:** the `buildRoutePanel` refactor; the controller, state machine,
adapters, and evaluators for ACCEPT, TURN_IN, OBJECTIVE-by-quest-level-completion, and TRAVEL-by-distance (all
signals are real-client verified); Skip/Reset/Undo/Pause; persisting the step ID in the existing account-wide
table as a hint; stub-environment self-tests for every evaluator.

**Still needs real-client validation:** `IsQuestFlaggedCompleted` and other reads at startup; per-character
storage; whether saved progression survives logout; per-objective index mapping (only if chosen); every new UI
control and the refactor itself (visual check).

```text
M8.11 STATUS: COMPLETE — design only; no production code changed
```
