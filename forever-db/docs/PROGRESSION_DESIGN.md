# ForeverQuestGuide Progression Design (M8.11)

Design only. Nothing here is implemented. Labels used throughout:

- **[RC]** verified on the real Forever client (milestone cited)
- **[CODE]** verified by reading existing ForeverQuestGuide v0.6 code
- **[UNVERIFIED]** plausible, not proven on Forever
- **[DECISION]** a choice the project owner must make
- **[DATA]** future route/data work

---

## 0. The v0.6 architecture this builds on [CODE]

- **Route state is two file-local variables in `UI.lua`:** `currentRouteID` and `currentStepIndex` (1-based index
  into the route's `step_order`). They are not persisted: every load or `/reload` starts at step 1 of the first
  route (`build()` calls `selectRoute(routeOrder()[1])`).
- **Advancing is UI code:** `routeNext()` / `routePrevious()` change `currentStepIndex` and call
  `renderRouteStep()`, which clamps the index and redraws everything. There is no progression logic anywhere.
- **Persistence:** one SavedVariable, `ForeverQuestGuideDB` (account-wide, declared with `## SavedVariables`),
  holding `theme`, `uiMode`, `welcomePopupDisabled`, each defaulted per key in `Preferences.lua`.
- **Route data:** generated `RouteData.lua`. Each step has a string `id` (`"s1"`…), `kind`, `quest_id`,
  `objective_index`, `npc`, `destination`, `display_text`, `next_step_id`, `why`, `required`; routes have
  `id`, `title`, `first_step`, `steps`, `step_order`. The source-file SHA-256 appears only in a header
  **comment**, not as a data field.
- **Event handling today:** `Core.lua` has one loader frame for `ADDON_LOADED`; `UI.lua` registers no game events.
- **Defensive-call helper** `ns.Safe` exists in `Core.lua`.

---

## 1. Progression modes

All three share the same detection and state machine (§2–§3); they differ only in what happens when a step's
condition is detected. **Manual override is present in every mode** (§9). No mode is recommended here. [DECISION]

| Concern | A. Fully manual | B. Semi-automatic | C. Fully automatic |
|---|---|---|---|
| What happens on detection | Nothing (detection may be off entirely, or shown as an informational badge) | Step marked "Condition met"; player confirms to advance | Step advances immediately |
| **False positive** (condition wrongly detected) | No effect | Player sees a wrong "met" badge; can ignore it. No state damage | Route advances past a step the player hasn't done. Needs undo |
| **Missed event** (addon not loaded, event lost) | No effect | Badge never appears; player advances manually | Route stalls on a completed step until reconciliation or manual Next |
| **Reload** | Step index lost unless persisted (§5) | "Met" is recomputed from quest state on reload for ACCEPT/OBJECTIVE/TRAVEL; TURN_IN depends on an UNVERIFIED check (§4) | Same as B, but a re-detected step may auto-advance again immediately after load |
| **Quests already in progress** | Player must find their place manually | Reconciliation can show which steps look already done; player confirms | Reconciliation could fast-forward several steps at once — highest risk if any startup check is wrong |
| **Ambiguous objectives** (mapping unproven, §7) | No effect | Wrong "met" possible; player judges | Wrong advance possible |
| **TRAVEL radius** | No effect | Radius too large → premature badge; too small → no badge. Player compensates | Radius errors directly skip or stall steps |
| **Player accidentally advancing** | Possible via Next (as today) | Possible via Next or via confirm | Less player input, but the addon itself can "accidentally advance" |
| **Debugging / recovery** | Trivial: nothing automatic happened | Easy: every advance was a player action; the badge shows what was detected | Needs a transition history to explain why a step was skipped |
| **Disabling/overriding** | N/A | Toggle hides badges; Next always works | Toggle must stop advancement; Next/Back/Undo must always work |
| **Implementation cost beyond shared core** | None (or badge only) | Confirm control + "met" rendering | Undo history + guard against repeated auto-advances (e.g. chains of already-satisfied steps) |

Notes that apply to every mode:

- The turn-in reset trap (M8.9) makes OBJECTIVE steps briefly look *un*-satisfied at turn-in [RC]. A mode that
  shows or acts on "met" must **latch** satisfaction per step instance (§2) so it is never reverted by that flicker.
- TURN_IN detection is event-only while the addon is running [RC]; after a reload it depends on
  `IsQuestFlaggedCompleted` at startup, which is [UNVERIFIED] (§4).

---

## 2. Step state machine

States apply to the **current step instance** only (the step the route pointer is on).

```
          (route selected / pointer moves here)
                        |
                        v
   +-------------->  WAITING  ----(condition detected)----> MET
   |                   |  ^                                 |
   |       (step has   |  | (reset step)          mode B: player confirms
   |     no detector)  |  |                       mode C: immediately
   |                   v  |                       mode A: n/a (stays MET as a badge)
   |              UNDETECTABLE                               |
   |                   |                                     v
   |                   +----(player Next)---------------> ADVANCED ---> next step: WAITING
   |                                                         |          or ROUTE_COMPLETE
   |   (player Skip) ------------------------------------> SKIPPED ---> next step: WAITING
   |
   +---- (player Back / Reset / reconciliation moves pointer)
```

| State | Meaning | Enter by | Leave by |
|---|---|---|---|
| `WAITING` | Current step; condition not yet met | Pointer arrives; Reset | Detection → `MET`; Next → `ADVANCED`; Skip → `SKIPPED` |
| `UNDETECTABLE` | Current step has no usable detector (e.g. TRAVEL with no destination; OBJECTIVE whose mapping is unresolved; cross-continent TRAVEL) | Pointer arrives on such a step | Next / Skip only |
| `MET` | Condition detected and **latched** | Detector fires or reconciliation finds it satisfied | Confirm/auto → `ADVANCED`; Next → `ADVANCED`; Reset → `WAITING` |
| `ADVANCED` | Step done; transient — pointer moves on | Confirm, auto, or Next | Immediately: pointer → next step |
| `SKIPPED` | Player chose to skip | Skip | Immediately: pointer → next step |
| `ROUTE_COMPLETE` | Pointer past the last step | Advance/skip from last step | Back; select another route |
| `PAUSED` (overlay) | Progression disabled by the player | Toggle | Toggle; detection results are ignored while paused, manual controls still work |

**Latching:** once a step instance is `MET`, later regressions of the underlying state (turn-in reset trap,
`IsComplete` true → false) do not return it to `WAITING`. Only Reset or Back clears it.

**What to persist** (see §5 for reliability): the route ID, the current **step ID** (string, not the index — see
§5), the set of step IDs the player explicitly skipped, the progression mode and paused flag, and a route
version key [DATA]. **Not persisted:** `MET` / latch state and any detection result — these are recomputed from
the quest log and position after every load, because persisted detection could be stale and cannot be trusted
across the logout-save problem.

---

## 3. Event architecture

### One controller, thin adapters

```
 game events                adapters (no logic)           controller                      UI
 ----------------           --------------------          ---------------------------     -----------------
 QUEST_ACCEPTED   ------->  signal{ACCEPTED, qid}   ---+
 QUEST_TURNED_IN  ------->  signal{TURNED_IN, qid}  ---+-> Progression.OnSignal(sig)  ---> onChange callback
 UNIT_QUEST_LOG_CHANGED --> signal{QUEST_STATE}     ---+    - looks up current step          -> renderRouteStep()
   (only unit=="player")                               |    - calls evaluator[step.kind]
 travel tick (throttled) -> signal{POSITION}        ---+    - applies state machine
 hints (see below)  ----->  signal{RECONCILE}       ---+    - persists pointer on change
```

- **Adapters** register events on one frame in a new progression module and translate each into a small signal
  table. They contain no step logic, so every event handler stays trivial.
- **Evaluators** are one pure function per step kind: `evaluate(step, signal, readState) -> MET | NOT_MET |
  UNKNOWN`. They read quest/position state through a small read layer (wrapping `ns.Safe`), so they can be unit
  tested with the same stub-environment approach as the M8.7–M8.10 probes.
- **The controller** owns the pointer and state machine, applies the mode (§1), latching, pause, and persistence,
  and notifies the UI through a single callback. `UI.lua` keeps rendering only; `routeNext`/`routePrevious`
  become calls into the controller.

### Signal map

| Step kind | Primary signal | Evaluation | Evidence |
|---|---|---|---|
| ACCEPT | `QUEST_ACCEPTED(questID)` | `questID == step.quest_id` | [RC] M8.7: once per accept, ~0.39 s, correct ID |
| TURN_IN | `QUEST_TURNED_IN(questID, …)` | `questID == step.quest_id` (argument only; never quest-log state at that instant) | [RC] M8.8: once per turn-in, 0.16–0.23 s after click, correct ID; no false fire on cancel |
| OBJECTIVE | `UNIT_QUEST_LOG_CHANGED` with unit `"player"` | Read the step's quest objectives now; compare per §7 | [RC] M8.9: 15/15 detected at the event, state already current |
| TRAVEL | Throttled position tick while the current step is TRAVEL and has a destination | Addon-computed distance ≤ radius, same continent only | [RC] M8.10: world-position and map-size distances agree; readback exact |

The TRAVEL tick should run only while the current step is a TRAVEL step with a same-continent destination
(e.g. one reading per 0.5–1 s, as the M8.10 probe did); otherwise no position polling at all.

### Hints and reconciliation triggers — never completion signals

| Event | Role |
|---|---|
| `QUEST_LOG_UPDATE` | Re-run evaluation of the current step (it always follows the UQLC that carried the change, M8.9) |
| `QUEST_REMOVED` | Re-evaluate / flag possible abandon of an ACCEPT-satisfied quest. **Never** TURN_IN (M8.8/M8.9: identical args on abandon and turn-in; order vs `QUEST_TURNED_IN` varies) |
| `QUEST_WATCH_UPDATE(questID)` | Optional hint of which quest changed; fires *before* state updates and missed 1/15 (M8.9) |
| `PLAYER_ENTERING_WORLD` | Schedule startup reconciliation (§4) |
| `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA` | Re-evaluate a TRAVEL step (map may have changed) |
| `NAVIGATION_DESTINATION_REACHED` | Ignore for progression (follows the game's navigation target, M8.10) |
| `SUPER_TRACKING_CHANGED`, `USER_WAYPOINT_UPDATED` | Ignore for progression; Show on Map remains a display feature |
| `UI_INFO_MESSAGE` | Ignore |

---

## 4. Startup reconciliation

### What can be read at startup

| Check | API | Status |
|---|---|---|
| Quest is in the log | `C_QuestLog.IsOnQuest(qid)`; `C_QuestLog.GetLogIndexForQuestID` | Exists and returned correct values mid-session [RC M8.7/M8.8]. At login: **[UNVERIFIED]** |
| Objective progress | `C_QuestLog.GetQuestObjectives(qid)` (`numFulfilled`, `numRequired`, `finished`) | [RC M8.9], including in a baseline read **3 s after** `PLAYER_ENTERING_WORLD`. Earlier reads (e.g. at `ADDON_LOADED`): **[UNVERIFIED]** |
| Quest ready to hand in | `C_QuestLog.IsComplete`, `C_QuestLog.ReadyForTurnIn` | [RC M8.9] (same timing caveat) |
| Quest already turned in | `C_QuestLog.IsQuestFlaggedCompleted(qid)` | Exists; returned `true` once and `false` once at the `QUEST_TURNED_IN` instant [RC M8.8, not reliable at that instant]. **At startup: [UNVERIFIED]** |
| Player position | `C_Map.GetBestMapForUnit`, `GetPlayerMapPosition`, `GetWorldPosFromMapPos` | [RC M8.10] mid-session; at login: **[UNVERIFIED]** but the same 3-second deferral pattern is the safe default |

**Rule:** reconcile after `PLAYER_ENTERING_WORLD` plus a short deferral (the M8.9 probe's 3 s worked [RC]),
never at `ADDON_LOADED`.

### Scenarios

| Scenario | What reconciliation can conclude |
|---|---|
| Quest already accepted | ACCEPT step for it is satisfied if `IsOnQuest` is true [UNVERIFIED at login] |
| Objective already completed | OBJECTIVE step satisfied if the objective reads `finished` / quest `IsComplete` (subject to §7 mapping) |
| Quest already turned in | Only via `IsQuestFlaggedCompleted` **[UNVERIFIED]**. Without it, "not in log" is ambiguous: never accepted, abandoned, or turned in |
| Standing at a TRAVEL destination | Distance ≤ radius on load → condition met. Arguably coincidental; mode matters (§1) [DECISION] |
| Reload after completing a step but before advancing | ACCEPT/OBJECTIVE/TRAVEL: re-detected from state. TURN_IN: needs the UNVERIFIED flagged-completed check; otherwise shows `WAITING` and the player advances manually |
| Reload with no persisted state | Pointer starts at step 1 (today's behaviour) — or, as a [DECISION], reconciliation suggests the first step not already satisfied. Any fast-forward depends on the UNVERIFIED startup checks |

---

## 5. Persistence

**Facts:**

- `ForeverQuestGuideDB` is account-wide [CODE]; one table for all characters.
- `/reload` saves are confirmed reliable; logout/character-select saves failed twice, root cause unknown
  (`M8_0_SCOPE.md` §2 as cited in `Preferences.lua`/`Core.lua`) [RC per earlier milestones]. No later milestone
  re-tested this.
- `SavedVariablesPerCharacter` has never been used or tested on Forever [UNVERIFIED].

**Therefore:**

- **Safe to persist** (small, recoverable if lost): route ID, current step ID, skipped step IDs, mode, paused flag,
  route version key — keyed by character. Keying by character needs either `SavedVariablesPerCharacter`
  [UNVERIFIED] or a per-character sub-table in the account table using the player's name and realm
  (`UnitName("player")`, `GetRealmName()` — not yet exercised by this project [UNVERIFIED]). [DECISION]
- **Cannot be assumed to persist** across logout or character select. The design must treat saved progression
  as a *hint* that may be stale or missing.
- **Persist the step ID, not the index.** An index silently points at a different step if a route is regenerated
  with steps inserted or reordered; a step ID either still exists or is detectably missing.
- **Stale or missing state:** if the saved route ID no longer exists, or the step ID is not in the route, or the
  route version key differs, fall back to "no persisted state" (§4). A missing version key is [DATA]: the
  generator writes the route SHA only in a comment today.
- **Reconciling pointer vs quest state:** the pointer is where the player was; quest state is what is true now.
  If the step at the pointer is already satisfied by quest state, it becomes `MET` (latched) and the mode decides
  what follows. The pointer is never moved *backwards* automatically.

---

## 6. TRAVEL contract (no schema change here)

| Layer | Requirement | Status |
|---|---|---|
| **Client capability** | Read player map/position; convert to world position; compute distance to a destination on the same continent | [RC] M8.10 |
| | Cross-continent distance | Not available [RC] → TRAVEL across continents is `UNDETECTABLE` |
| **Route data** | A destination per TRAVEL step: map ID + x/y | Absent today: the only TRAVEL step (`s2`) has `destination = nil` [CODE] [DATA] |
| | An arrival radius per step (or a route default) | Absent [DATA] |
| **Schema** | `destination = { kind, ui_map_id, x, y }` already exists (used by TURN_IN `s4`) [CODE] | Reusable as is |
| | A radius field | Does not exist → schema change in a later milestone [DATA] |
| | A cross-continent flag | Not needed: derivable at runtime from the continent returned by `GetWorldPosFromMapPos` for the destination vs the player |
| **Provenance** | Every destination states its source, as existing ones do (`OBSERVED_PLAYER_POSITION`, `SOURCE_DERIVED_ATT`) [CODE] | A TRAVEL destination needs an agreed source (observed position, ATT-derived, or route-author-supplied) [DECISION]/[DATA] |

**Minimum TRAVEL step for automatic detection:** destination `{ kind, ui_map_id, x, y }` + radius + provenance.
**When destination data is missing:** the step is `UNDETECTABLE`; it behaves exactly like v0.6 (manual Next),
and Show on Map stays disabled for it as in v0.6.

**Radius:** the game's own arrival radius was ~10 yd (3/3) [RC], but that belongs to the game's navigation, not
to this addon. The addon radius must be an explicit value; the right size depends on what the destination
represents (a point vs an area) and on the destination's provenance precision (an observed player position is
already approximate). [DECISION]/[DATA]

---

## 7. OBJECTIVE matching

**What the route contains today** [CODE]: `quest_id` and `objective_index` only (the single OBJECTIVE step uses
quest 907, index 1; 907 has one objective). No objective text or type.

**What the client provides** [RC M8.9]: an ordered objective list per quest with `text`, `type`
(`item`, `monster`, `event`, `log`), `finished`, `numFulfilled`, `numRequired`. Order was stable across the
session and two reloads; text is blank for up to ~0.2 s after accept; `event`/`log` texts carry no counts;
"Speak with" objectives are typed `monster`.

| Approach | Needs in route data | Strength | Weakness |
|---|---|---|---|
| **By index** | `objective_index` (present) | Simple; client order stable [RC] | Mapping from route/`Data.lua` order to client order **unproven** ("stable, not yet comparable") |
| **By text** | Objective text or name per step (absent) | Human-readable | Blank-name window; count formats differ by type; text could change between builds; not assumed reliable |
| **By type** | Type per step (absent) | Cheap disambiguation | Many quests have several objectives of the same type; types can be surprising ("Speak with" = `monster`) |
| **Quest-level completion** | Nothing new (`quest_id` present) | `IsComplete` / `ReadyForTurnIn` verified [RC]; no mapping needed | Can only express "all objectives done", not a specific objective |

A combination is possible (e.g. index as the key, validated by a stored type), but any per-objective approach
depends on closing the mapping question. Choice: [DECISION]. Closing the mapping: one multi-objective route quest
present in the log with a probe (as noted in M8.9), only if the chosen approach needs it.

---

## 8. The `build()` 60-upvalue problem

**Cause** [CODE]: `build()` constructs every widget of both tabs and writes them into file-level locals, so each
widget variable it assigns and each helper it calls is an upvalue. `luac -l -l` lists 56 upvalues:
7 layout constants, 5 quest-detail FontStrings, 17 route-pane widgets/state (`routeTitleFS` …
`routeDestFS`, `routeProgressRow`, `previewToggleBtn`, `previewCollapsed`, `routePrevBtn`, `routeNextBtn`), and
the helpers/functions they use.

**Measured:** 22 of the 56 are used **only** inside the route-pane section of `build()` (source lines ~948–1045):
the 13 route FontStrings, `routeProgressRow`, `previewToggleBtn`, `previewCollapsed`, `routePrevBtn`,
`routeNextBtn`, `routeNext`, `routePrevious`, `renderRouteStep`, `routeCount`, `buildRouteMapButton`,
`newWideButton`. Six more are shared with the rest of `build()`.

**Minimal refactor** (not implemented): move that route-pane section verbatim into a new file-level function
`buildRoutePanel(frame)` defined just before `build()`, and call it from `build()` where the section is now —
the same pattern M8.6-B already used for `buildSearchRow`, `buildQuestMapButton`, `buildRouteMapButton`, and
`buildToggleButtons`. Expected result: `build()` ≈ 56 − 22 + 1 = **35** upvalues; `buildRoutePanel` ≈ **28**.
No widget, anchor, or behaviour changes; only which function the statements live in. Verify with
`luac -l -l` and the existing self-tests, then one real-client visual check.

Progression code itself should live in its own file(s), so it adds nothing to `build()`; at most the route pane
gains a few controls (§9), which land in `buildRoutePanel` with ample headroom.

---

## 9. Manual override and recovery

Available in every mode, including while paused:

| Control | Behaviour | Notes |
|---|---|---|
| **Next** (existing) | Advance one step regardless of state | Unchanged from v0.6 |
| **Previous** (existing) | Move back one step; that step returns to `WAITING` (its latch cleared) | Unchanged pointer behaviour |
| **Skip** | Mark current step `SKIPPED`, advance | Distinguishes "skipped" from "done" in history and persistence |
| **Reset step** | Clear the current step's latch → `WAITING`; re-evaluate | For a false "met" |
| **Undo last automatic advance** | Return to the step before the most recent automatic transition | Needed for mode C; keep a short in-memory history (not persisted) |
| **Pause progression** | Stop acting on detection; manual controls unaffected | Persisted preference; also `/fguide` subcommand, mirroring the existing `theme`/`mode` arguments |
| **Recover after false positive** | Mode B: ignore or Reset. Mode C: Undo, then Reset or Pause | |

UI placement is a later decision [DECISION]; the route pane's bottom row already holds Previous, Next, and
Show on Map.
