# M8.13 Completion Report: Progression Controller Implementation

**Status: implemented; 82/82 stub tests pass; real-client validated (2026-09-30, build 70124).**
ForeverQuestGuide **`m8-guide-addon-0.7`** (from 0.6). Semi-automatic progression: the addon detects and latches
a satisfied step and shows it as complete, but moves only on the player's confirmation.

## 1. Implementation completed

### Files

| File | Change |
|---|---|
| `ProgressionEval.lua` | **New.** Pure evaluators for ACCEPT, TURN_IN, OBJECTIVE (quest-level), TRAVEL (same-continent distance), plus a read-only state reader. Never raises; errors become UNDETECTABLE |
| `Progression.lua` | **New.** Controller: route pointer by route/step ID, states `NOT_READY` / `WAITING` / `UNDETECTABLE` / `SATISFIED` (latched) / `ROUTE_COMPLETE` + `PAUSED` overlay; Next (confirm/manual/finish), Previous, Skip, Reset Step, Undo, Pause; persistence; thin event adapters |
| `UI.lua` | Route-pane section moved verbatim into `buildRoutePanel(frame)`; status line; NEXT label shows `CONFIRM ->` / `FINISH ->` / `Route Complete`; Skip / Reset Step / Undo / Pause row; Previous/Next routed through the controller; route pane +50 px taller for the new rows |
| `Preferences.lua` | Defaults re-applied at `ADDON_LOADED` via `ApplyDefaults()`; incorrect SavedVariables-timing comment corrected (M8.12) |
| `Core.lua` | Version `m8-guide-addon-0.7`; calls `ApplyDefaults()` at `ADDON_LOADED`; `/fguide progress pause\|resume\|skip\|reset\|undo\|status`; load message updated |
| `ForeverQuestGuide.toc` | Version, notes, load order (`ProgressionEval.lua`, `Progression.lua` before `UI.lua`) |
| `Data.lua`, `RouteData.lua`, `MapPin.lua`, `MinimapButton.lua`, `WelcomePopup.lua` | Unchanged |

### `build()` refactor

| Function | Upvalues |
|---|---|
| `build()` before (v0.6) | **56** / 60 |
| `build()` after refactor | **35** |
| `build()` after all M8.13 changes | **37** |
| new `buildRoutePanel()` | 28 |
| highest in any addon function | 37 |

Behaviour preservation was proven with a recording harness (`tests/ui_trace_harness.lua`): v0.6 and the
refactored build produced **byte-identical traces** of a scripted UI session (1,595 widget calls, 138 widgets,
both Show on Map paths), before any progression code was added.

### Architecture

- **Adapters** (bottom of `Progression.lua`) turn events into signals: `QUEST_ACCEPTED`, `QUEST_TURNED_IN`,
  `UNIT_QUEST_LOG_CHANGED` (unit `"player"` only), `QUEST_LOG_UPDATE` (re-check hint), `ZONE_CHANGED*` and a 0.5 s
  position tick that runs **only** while the current step is a TRAVEL step with a destination.
  `QUEST_REMOVED`, `QUEST_WATCH_UPDATE`, navigation, waypoint, and super-track events are not registered.
- **Evaluators** decide satisfaction for the current step only.
- **Controller** evaluates nothing before `PLAYER_LOGIN`; latches `SATISFIED`; the single place automatic
  advancement would go is marked `AUTO-ADVANCE HOOK`.
- **UI** renders controller state and forwards clicks.

### Startup and persistence

- `ADDON_LOADED`: read `ForeverQuestGuideDB.progress` (`routeID`, `stepID`, `complete`, `paused`, `skipped`).
  Missing route → first route, step 1. Step not in route → step 1. No saved progress → step 1.
- `PLAYER_LOGIN`: reconcile the current step against game state; chat reports route, step, and how the position
  was chosen.
- Before `ADDON_LOADED` the controller holds step 1 of the first route, so the pointer is never empty.
- Latches and detection results are never persisted; they are recomputed at login.

## 2. Unit/stub-test results

`tests/run_progression_tests.lua` (lua5.1): **82 passed, 0 failed.** Coverage against the brief:

| Required test | Covered |
|---|---|
| ACCEPT / TURN_IN / OBJECTIVE satisfaction | Yes (signal and reconciliation paths; `QUEST_REMOVED` never counts) |
| TRAVEL same-map / same-continent distance | Yes (real read layer against stubbed map APIs) |
| TRAVEL missing destination / cross-continent → undetectable | Yes (also position unavailable, unknown kind) |
| Latching; turn-in reset cannot undo | Yes |
| Manual advancement; skip; reset; undo; pause | Yes (controller API and real UI buttons) |
| Startup: no saved / valid saved / stale saved (step and route) | Yes; plus "events before `PLAYER_LOGIN` ignored" and "position sane before `ADDON_LOADED`" |
| Route completion | Yes (finish, skip-to-finish, undo, previous from complete) |
| Regressions: Previous, both Show on Map paths, `/fguide progress status`, preferences defaulting | Yes |
| Read-only (no quest-changing call) | Yes |

Issues found and fixed during testing:

1. A UI helper was placed before the button factory it uses; Lua would have resolved it as an undefined global at
   runtime. Moved; a bytecode scan of all changed files confirms only real WoW/Lua globals are referenced.
2. Undo after Previous popped a stale entry. Previous (and route selection) now clear undo history, so Undo only
   reverses the advance just made.
3. The controller had no route until `ADDON_LOADED`; it now starts at step 1 of the first route.
4. Found in the real-client run: the login help line listed `pause|resume|skip|reset`, and WoW chat treats `|r` as
   its "end colour" code, so it displayed as `pauseesume|skipeset`. Display-only; now listed with commas.
5. Found in the real-client run: Reset Step gave no visible feedback on a step that was not complete (the re-check
   returns the same answer), so it looked broken. It now reports "Step N reset and re-checked: <result>" in chat.

The project's own existing UI self-test (in the repository) was not available in this environment; run it locally
as well.

## 3. Real-client validation

Performed 2026-09-30 on build 70124 with the character's existing quest state; no grinding, no extra travel.
Operator reported **no Lua errors** at any point.

| # | Check (from the brief) | Result | Evidence |
|---|---|---|---|
| 1 | Addon loads without Lua errors | PASS | `vm8-guide-addon-0.7 loaded`; operator: no Lua errors |
| 2 | Existing guide UI still works | PASS | QUESTS/ROUTE tabs, detailed view, preview, theme; route pane renders all five steps |
| 3 | Saved progression loads through `ADDON_LOADED` | PASS | Fresh install: `no saved progress; starting at step 1`. After `/reload`: `restored step 1`, later `restored step 5` |
| 4 | Reconciliation happens after `PLAYER_LOGIN` | PASS | After `restored step 5`, the next line was `Step 5 complete: quest is in your quest log` — quest 959 (Trouble at the Docks) was already in the log; detected at login, not advanced |
| 5 | Detection does not advance automatically | PASS | Step 5 showed complete and waited; operator confirmed `Route complete.` appeared only after their click |
| 6 | Manual confirmation advances exactly one step | PASS | One CONFIRM on the last step finished the route; NEXT moved exactly one step each time; Previous walked 5 → 1 one step per click under rapid clicking |
| 7 | Pause prevents detection | PASS | Status `PAUSED -- detection is off; manual controls still work`; button relabelled `Resume`; resuming restored `in progress -- quest not accepted yet` |
| 8 | Reset and Skip behave correctly | PASS | Reset Step (after the fix below) reported the right result on every step: 5 `complete -- quest is in your quest log`, 4 `quest not turned in yet`, 3 `quest is not in your quest log`, 2 `no destination in route data`, 1 `quest not accepted yet`; Skip and Undo exercised; Undo correctly greyed with no history |
| 9 | No regression to map pins | PASS | Route step 4 pinned Jorn Skyseer (44.9, 59.1, map 1413); steps without a destination explained why and stayed dimmed |
| — | `/fguide progress status` | PASS | `route thunder-lizards-test-route, step 1, state WAITING (quest not accepted yet)`, matching the pane |
| — | TRAVEL without destination | PASS | Step 2: `can't detect this step (no destination in route data)` — undetectable, never complete |

**Detection paths observed on the real client:** the startup/state path (step 5 via quest already in the log).
**Not observed in this run:** the live `QUEST_ACCEPTED` path. Quest 907 could not be accepted (see the route-data
finding below: it sits deep in a quest chain the character has not done); the event itself is real-client verified by M8.7, and its handling by the stub tests. TURN_IN and
OBJECTIVE satisfaction were not reached without questing; both rest on M8.8/M8.9 evidence and the stub tests.

**Fixes made during the run** (both in the stub tests and the package):

- Login help text displayed `pauseesume|skipeset`: WoW chat reads `|r` as a colour code. Now lists commands with
  commas (`Core.lua`).
- Reset Step gave no visible feedback when the step was not complete. It now reports
  `Step N reset and re-checked: <result>` (`Progression.lua`).

**Route-data finding:** at level 20, Jorn Skyseer did not offer *Enraged Thunder Lizards* (907); he offered
*Melor Sends Word* (1130). Checked against classic quest data (Warcraft Wiki / Wowpedia, classic databases), 907
is the **9th quest of the Sergra Darkthorn chain** (Sergra Darkthorn → Plainstrider Menace → The Zhevra → Prowlers
of the Barrens → Echeyakee → The Angry Scytheclaws → Jorn Skyseer → Ishamuhale → Enraged Thunder Lizards), with
Ishamuhale as its direct prerequisite and a level requirement of only 10. *Melor Sends Word* is an **unrelated**
level-30 (requires 20) quest from the same NPC, leading to Steelsnap — not a prerequisite. The test route's step
1 therefore silently assumes eight earlier chain quests; a player following it would be blocked at step 1. This
is the prerequisite gap recorded in M8.2 (0 of 153 prerequisites resolved), now observed in game.

In-game check (operator, same session): `C_QuestLog.IsQuestFlaggedCompleted` and `IsOnQuest` for the whole chain
— 860, 844, 845, 903, 881, 905, 3261, 882, 907 — returned `false false` for all nine. The character has not started
the chain, which explains why Jorn offered only *Melor Sends Word*. Quest IDs come from classic quest databases
(845 from memory, unconfirmed); the chain order is classic WoW's, and matched what was observed on Forever. Reaching
907 would require the full chain from the Crossroads, so the live `QUEST_ACCEPTED` path was not pursued.

## 4. Known limitations

- **Logout persistence is not guaranteed** (M8.0 §2; M8.12 saved only via `/reload`).
- **Progress is account-wide**: all characters share one saved position (no `SavedVariablesPerCharacter`, per brief).
- **TRAVEL requires route destination data.** The only TRAVEL step (`s2`) has none, so it shows as
  "can't detect this step (no destination in route data)".
- **TRAVEL radius is a provisional design value** (20 yd, `ProgressionEval.lua`), not a measurement; the schema has
  no radius field.
- **Cross-continent TRAVEL is not automatically detected.**
- **OBJECTIVE uses quest-level completion**, not `objective_index`; a step for one objective of a multi-objective
  quest is satisfied only when the whole quest is.
- **Automatic advancement is intentionally not implemented.**
- **Game navigation/waypoint/super-track state is never used as a progression signal.**
- Only steps on the current pointer are evaluated; events for later steps are not remembered (re-checked from state
  on arrival where the state supports it — ACCEPT, TURN_IN via the completed flag, OBJECTIVE; not TRAVEL).

## 5. Deferred

- Automatic mode (hook in place).
- Per-objective matching (needs M8.9's ordering question closed).
- TRAVEL destinations and a radius field in route data/schema.
- Per-character progress.
- Incorporating M8.7–M8.13 addenda into `M8_2_SCOPE.md`.
- Clipped window edge; "M8.7" labels in `MapPin.lua` comments (both pre-existing).

```text
M8.13 STATUS: COMPLETE — PASS (82/82 stub tests; real-client validated, build 70124, 2026-09-30)
```
