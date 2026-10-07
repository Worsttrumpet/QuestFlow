# M8.13: Progression Controller Implementation

**Status: complete; see `M8_13_COMPLETION_REPORT.md`.** First production progression
milestone. ForeverQuestGuide `m8-guide-addon-0.6` → **`m8-guide-addon-0.7`**. No route data, route schema,
ForeverRecorder, M8.7–M8.12 file, or `M8_2_SCOPE.md` is modified.

**Scope date:** 2026-09-30. Intended destination: `forever-db/docs/M8_13_SCOPE.md`.

## Decisions (from the milestone brief)

| Decision | Choice |
|---|---|
| Progression mode | **Semi-automatic**: detect, latch, show "Step complete", advance only on explicit player confirmation. Architecture leaves one hook for automatic mode later |
| No saved position | Start at **step 1**; no position guessing from quest state |
| OBJECTIVE matching | **Quest-level completion** (`IsComplete` / `ReadyForTurnIn` / flagged completed); `objective_index` not used; no text matching |

## Evidence used (all real-client verified)

| Step | Signal | Source |
|---|---|---|
| ACCEPT | `QUEST_ACCEPTED(questID)` | M8.7 |
| TURN_IN | `QUEST_TURNED_IN(questID, xp, money)`; never `QUEST_REMOVED` | M8.8 |
| OBJECTIVE | `UNIT_QUEST_LOG_CHANGED("player")` + quest-log read; latch against the turn-in reset | M8.9 |
| TRAVEL | addon-computed world distance, same continent; no navigation/waypoint/arrow/super-track state | M8.10 |
| Startup | read saved position at `ADDON_LOADED`; reconcile at `PLAYER_LOGIN`; nothing earlier | M8.12 |

## Work

1. Minimal `build()` refactor: move the route-pane section verbatim into `buildRoutePanel(frame)` (M8.11 §8);
   prove unchanged behaviour; record upvalues before/after.
2. `ProgressionEval.lua`: pure evaluators + read-only state reader.
3. `Progression.lua`: controller (pointer by route/step ID, state machine, latching, pause, skip, reset, undo,
   persistence) + thin event adapters.
4. `UI.lua`: status line, NEXT/CONFIRM label, Skip / Reset Step / Undo / Pause row; Previous/Next routed through the
   controller.
5. `Preferences.lua`: re-apply defaults at `ADDON_LOADED` (M8.12 SavedVariables finding).
6. `Core.lua`: version bump; `/fguide progress pause|resume|skip|reset|undo|status`.
7. Stub tests for every case listed in the brief.
8. Minimal real-client validation with existing quest state; no grinding.

## Out of scope

Automatic advancement, per-objective matching, route data/schema changes (including TRAVEL destinations and a
radius field), `SavedVariablesPerCharacter`, UI redesign, new probes.
