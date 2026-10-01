# Forever Codex: Planner + Action/Target Contract (design)

**Status: design only.** Nothing here is implemented. No addon code, data, telemetry, tests or UI were changed.
Builds on `CODEX_DESIGN_AUDIT.md` (read first) and `CODEX_PLANNING_MODEL.md`. Where the audit and the code differ, the
code was treated as the source of truth; differences are called out in section 2.

Status tags used on every field/mechanism:

| Tag | Meaning |
|---|---|
| **[PROVEN]** | Confirmed on the Forever client (M-series milestones / 0.1 playtest) |
| **[EXISTS-INSUFFICIENT]** | Exists in the repo today but cannot carry the new model |
| **[PROPOSAL]** | Design proposal, no dependency on unproven APIs or missing data |
| **[API?]** | Requires Forever API verification before depending on it |
| **[DATA?]** | Requires data Codex does not have today (never invented) |
| **[DEFERRED]** | Intentionally not designed in detail yet |

---

## 1. Executive summary

The Engine answers "which single action scores highest from here?" and builds its sequence by repeating that question
greedily. The playtest showed that real decisions are about **sequences and trips**: finish what is in this area, batch
the turn-ins, use the walk you are already doing, accept something because of what it unlocks.

Proposal in one paragraph: add a **Planner** (separate module, pure function) that takes the candidate actions from the
providers, projects short sequences of **stops** (places where one or more actions can be done), prices each sequence by
**value gained per unit time**, where time includes a pluggable **transit cost** and the **interruption cost** (the
marginal time an action adds to the trajectory), and returns a small **Plan**: exactly one `now`, at most one `alsoDo`,
and an optional `then`. Actions gain a structured **Target** list (giver / objective / turn-in / service / area, each
with a location status that can be `unknown`) and structured **reason codes** instead of display strings. Provenance
stays on every input and is never upgraded. Strategies stay weight sets over the same model. Navigation, markers, UI and
the Quest Map are consumers of the Plan; none of them is a planner dependency.

Three decisions worth flagging for review:

1. **Value is a labelled policy currency, not XP.** No quest in the data has an XP value (ATT has none; observed XP is
   learned only after a turn-in). The planner therefore cannot rank by XP/hour today. It ranks by *policy value per unit
   time* with each component labelled `policy | observed | calculated | estimated | unknown`, and swaps in XP/telemetry
   components automatically when they exist.
2. **Travel and interruption are relational, not action fields.** They depend on where you are and what comes before,
   so they belong to the sequence evaluator, not to an action's own data.
3. **The Engine is kept**, narrowed to "provider output + per-action facts + policy value". The planner is new.

## 2. Current architecture findings

Read directly from the code (`forever-codex/ForeverCodex/`):

- `Engine.Compute(ctx)` (321 lines) does five things in one function: collect from providers, global filters (Hardcore,
  style allow-list, skipped), static scoring (kind base, level fit, breadcrumb, hub cluster), a **greedy chain**
  (repeatedly pick best `score = static - min(distCap, dist/distScale) + zone bonus`, `CHAIN_LENGTH = 8`), TRAVEL
  insertion at 150 yd, and a distance-sorted "nearby" list (radius `prefs.hereRadius`, default 200, max 5).
  **[EXISTS-INSUFFICIENT]**
- **Engine mutates action objects** (`_score`, `_dist`, `_static`, `_cluster`, `reasons`) and cannot be reused for
  hypothetical evaluation without re-entrancy care. A planner needs side-effect-free evaluation.
- Base scores (`TURN_IN=100`, `OBJECTIVE=70`, `ACCEPT=40`) are *urgency by kind*. With a distance penalty capped at 60,
  a completed quest can never lose to nearby work: this is the "100 dominates" behaviour from the playtest, and it is
  structural, not a tuning problem.
- **Quest provider** (`Providers/Quest.lua`): one action per quest *state*: ACCEPT at the giver, TURN_IN at the giver
  ("assumed: ATT has no turn-in NPC field"), OBJECTIVE at `objCoords[1]` **only** (additional objective coordinates are
  dropped). Eligibility requires `view.loc` (giver location) so unknown-location quests are filtered out as
  `noLocation`. Prerequisites are ATT `sourceQuest`, **any-of** by parser limitation. Player-facing strings (including
  "(ATT, unverified)") are built here. **[EXISTS-INSUFFICIENT]**
- **Identity is already ID-based where it matters**: action ids `Q:<id>:ACCEPT|TURN_IN|OBJECTIVE`, skip keys
  `Q:<id>` / `QT:<id>`, completion via `ctx.isCompleted(id)` (`C_QuestLog.IsQuestFlaggedCompleted`). Name is used only
  for display and for the Add-box search. **Good; keep.** One gap: skip keys differ between accept (`Q:`) and
  in-progress (`QT:`) states, so a quest has two independent skip flags.
- **Quest log reader** (`Context.lua`) recorded only `{id, title, complete}` per entry in the original 0.1 build.
  *Correction (review of Section 27):* per-objective progress is **[PROVEN]**: `C_QuestLog.GetQuestObjectives`
  returns `text, type, finished, numFulfilled, numRequired`, current at `UNIT_QUEST_LOG_CHANGED("player")` (M8.9,
  15/15 steps). Phase 1 now reads it into `ctx.log[id].objectives`.
- **Context has no** XP/XP-max, inventory, money, dead/ghost, bind location, spells/trainers, discovered flight nodes.
  It reads `GetNumGroupMembers`/`IsInGroup` only. **[EXISTS-INSUFFICIENT]**
- **Flight provider**: ATT flight nodes as `hereOnly` hints; cannot know if discovered. **Planned provider**: registers
  inert types/systems (TRAINER, PROFESSION, GATHER, CAMP, DUNGEON, PET_UPGRADE, RESPAWN_SKIP, CLASS_PROGRESSION, GROUP)
  with no `generate()`. The Registry plumbing for future providers is sound. **[PROVEN architecture, no data]**
- **Strategies** are `{ w = weights, allow = {types} }` tables. Fine as a mechanism; the weights are Engine-shaped
  (`distScale`, `cluster`, ...). **[EXISTS-INSUFFICIENT]** (must grow time/value/detour terms, see section 14).
- **State** recomputes the whole plan when dirty (events) or every 3 s while the window is open. Stateless: there is no
  memory of the previous NOW, so no stability. **[EXISTS-INSUFFICIENT]**
- **Consumers of the plan today** (grep): UI reads `plan.next`, `plan.upcoming`, `plan.nearby`, `plan.inProgress`,
  `plan.warnings`, `plan.stats`, `plan.strategy`, `plan.routeZone/routeMap`; Diag reads `plan.next`, `plan.sequence`,
  `plan.stats`, `plan.warnings`; Route/MapPin read an action's `target`. This small surface makes an adapter practical
  (section 24).
- **Navigation**: `MapPin.Place` is invoked only from the Window's Show on Map button; `MapPin.Clear` (which calls
  `C_Map.ClearUserWaypoint` if present) is never called. The stale waypoint is therefore a lifecycle gap, not a
  placement bug. *Correction:* `C_Map.ClearUserWaypoint` is **[PROVEN]** (M8.6-B confirmed list; the operator's clear in
  M8.10 fired `USER_WAYPOINT_UPDATED` and removed the pin), as are `C_Map.HasUserWaypoint` / `C_Map.GetUserWaypoint`
  (exact map + coordinates on every read, M8.10). Caveat from M8.10: quests reclaim super-tracking from the user
  waypoint and one pin vanished without a command, so Codex cannot assume its pin stays.
- **Telemetry** is independent and records session-timed events (`GetTime` resets each session). **[PROVEN design]**

Differences from the audit: the audit said "Engine computes value per action". More precisely it computes *urgency by
kind + proximity*; there is no value model at all. This design therefore introduces value components rather than reusing
Engine scores as value. The Engine's useful low-level facts are geometry (`Distance`), eligibility, hub density and
level fit, which the planner reuses.

## 3. Current Action model

Fields produced today (via `R.NewAction`): `id`, `type`, `kind`, `quest`, `skipKey`, `title`, `lines[]` (display text),
`reasons[]` (display text), `target` (single `{map,x,y,label,src,verified,approx}`), `src`, `verified`, `nameSrc`,
`giver` (name), `pinned`, `reqLevel`, `level`, `breadcrumb`, `noLocation`, `unknown`, `hereOnly`, `forId`, `dist`;
plus Engine-private `_score/_dist/_static/_cluster/_cx/_cy`.

Problems: display strings mixed with data; one target; `src/verified` describe only the location; no state enum; no
requirement structure; no cost/value separation; no way to say "location unknown" except by omitting `target`; mutable.

## 4. Proposed Action contract

An Action is an **immutable fact record** produced by a provider. It does not contain a score, a distance, a rank or a
display sentence. Planner results live in the Plan, not on the action.

| Field | Req | Nature | Tag | Notes |
|---|---|---|---|---|
| `id` | required | derived (deterministic) | proposal; keeps current scheme `Q:<questID>:<KIND>` | Stable across recomputes; the identity used by navigation, skip, hysteresis, telemetry. Never contains a name. |
| `type` | required | derived | exists | Registered action type (QUEST, TRAVEL, FLIGHT, TRAINER, GRIND, ...). |
| `kind` | required | derived | exists | Verb within a type: ACCEPT, OBJECTIVE, TURN_IN, DISCOVER, TRAIN, VISIT, ... |
| `ref` | required for subject-bound actions | observed id | proposal | `{ kind = "quest" \| "npc" \| "flightNode" \| ..., id = <number> }`. Quest identity = quest ID, never name. |
| `state` | required | observed (from client) / derived | proposal | Enum, section 12. The planner only sequences `ELIGIBLE`, `ACTIVE`, `READY`. |
| `stateWhy` | optional | derived | proposal | Reason code when `BLOCKED`/`SKIPPED`/`UNKNOWN` (e.g. `LEVEL_TOO_LOW`, `PREREQ_MISSING`). Diagnostics-grade. |
| `targets[]` | required (may be empty = no known location) | per-target provenance | proposal | Section 5. Replaces single `target`. |
| `targetMode` | required if >1 target | derived | proposal | `ALL` (visit every target, e.g. several objectives) or `ANY` (one of several equivalent places, e.g. spawn points). |
| `requirements[]` | optional | observed/ATT-labelled | proposal | Structured predicates with a tri-state result, section 4.2. |
| `dwell` | optional | **estimated or unknown** | proposal / data? | Intrinsic seconds spent *at* the target(s) excluding transit (talk ~ few s; kill 8 boars ~ minutes). Unknown by default: planner then uses a labelled policy constant per `kind`. Never `observed` unless from telemetry (quest accept->complete durations are observed per quest only after the fact). |
| `risk` | optional | unknown | deferred | Reserved (Hardcore, elite, group-required). Not populated now. |
| `value` | required | per-component labelled | proposal | Section 4.3. |
| `unlocks[]` | optional | derived | proposal / data? | Action/quest ids made available by completing this (reverse of prerequisites). Provenance = the prerequisite data's (ATT any-of caveat). |
| `chain` | optional | derived | proposal | `{ position, length }` only if the data supports it; else nil. |
| `completion` | required | derived | proposal | What observable change means "done": `{ watch = "quest", id = Q, until = "ACCEPTED"\|"OBJECTIVES"\|"TURNED_IN" }`. Lets navigation and State detect completion without name matching. Quest transitions are PROVEN observable (QUEST_ACCEPTED, QUEST_TURNED_IN, log diff). |
| `optional` | required | policy | proposal | `true` for opportunities (flight discovery, trainer visit): may appear as ALSO DO but never NOW unless the strategy says so. |
| `hereOnly` | optional | policy | exists | Retained: "only meaningful if you are already here" (flight hints). |
| `pinned` | optional | player | exists | Player-added quest; strong preference, not a command. |
| `prov` | required | observed | proposal | Per-field provenance map, section 20 (`title`, each target, each requirement, each value component). |
| `evidence` | required | derived (weakest link) | proposal | Summary label for diagnostics only: `observed`, `mixed`, `unverified`, `unknown`. Computed from `prov`; **never** set by hand or upgraded by the planner. |
| `name` | optional | observed/ATT | exists | Raw name for presentation. Not used for identity or logic. |

Removed from the action: `lines[]`, `reasons[]` (display text), `skipKey` (derivable from `ref`), `_score`/`_dist`.

### 4.2 Requirements

`requirements[] = { kind, ..., result, prov }` with `result = true | false | nil`. `nil` = unknown (never coerced to
false or true). Kinds supportable now: `level` (min level, ATT `req`: **required** level, not quest level
[PROVEN by importer analysis]), `prereqQuest` (`anyOf = {ids}`; any-of caveat), `faction`, `race`, `class`
(ATT restrictions, resolvable from Context). Kinds that need future data/APIs: `item`, `money`, `skill`, `reputation`,
`spell` **[DATA?/API?]**. An action with any `false` requirement is `BLOCKED`; with only `nil` it stays eligible but
carries `UNKNOWN_PREREQ` as a reason (confidence reduced, see section 8).

### 4.3 Value components

```text
value = {
  xp         = { v = number|nil, basis = "observed"|"calculated"|"estimated"|"unknown" },
  progress   = { v, basis = "policy" },   -- finishing what is started; weight comes from strategy
  chain      = { v, basis = "policy"|"derived" },   -- near-term unlocked value (section 13)
  discovery  = { v, basis = "policy" },   -- flight node, quest-giver hub, unknown quest
  class      = { v, basis },              -- trainer/ability opportunity       [DATA?]
  profession = { v, basis },              --                                    [DATA?]
  levelFit   = { v, basis = "policy" },   -- (replaces Engine levelFit)
}
```

A component with `v = nil` is **unknown** and is excluded from the sum; the sum carries a `known/total` coverage figure
so the planner can lower confidence. `xp` is currently `nil` for every quest (no source); it becomes `observed` only for a
quest this character already turned in (not useful for planning) and `calculated/estimated` only once a data source for
quest XP exists **[DATA?]**. The planner must never present `policy` points as XP.

Existing / insufficient / proposal: provenance on `src/verified` per action = existing but insufficient; per-field `prov`
= proposal.

## 5. Proposed Target contract

A Target is *a place and/or an entity involved in an action*. An action has zero or more.

```text
Target = {
  role     = "GIVER" | "OBJECTIVE" | "TURN_IN" | "DESTINATION" | "SERVICE" | "AREA",
  service  = nil | "TRAINER" | "VENDOR" | "INN" | "FLIGHT" | "PROFESSION" | "PET" | "GRAVEYARD" | ...,
  entity   = { kind = "npc"|"object"|"item"|"area"|"unknown", id = number|nil, name = string|nil },
  where    = {
     status = "known" | "approx" | "unknown",       -- "unknown" carries NO coordinates
     points = { {map, x, y}, ... },                  -- >= 1 if known/approx; several = alternatives (spawns)
     radius = number|nil,                            -- yards; for AREA targets (grind area, cave)
     kind   = "exact" | "area" | "player_position",  -- how the coordinate was obtained
  },
  order    = nil | integer,                          -- only when the game forces an order (e.g. cave inner room)
  -- (objective progress is NOT a Target field: it is quest-log state, `objectiveState`, on the action)
  done     = true | false | nil,                     -- nil = unknown
  prov     = { src = "att"|"observed"|..., verified = bool, ... },   -- per target, never merged
}
```

Design decisions:

1. **Roles, not "the target".** Quest = `GIVER` (on ACCEPT), `OBJECTIVE` x N (on OBJECTIVE), `TURN_IN` (on TURN_IN). The
   Thazz'ril's Pick example: ACCEPT.targets = `{GIVER: Foreman Thazz'ril}`; OBJECTIVE.targets =
   `{OBJECTIVE: object "Thazz'ril's Pick", where = known(exact) 43.7,53.8}` (this coordinate is *observed*; ATT does not
   have it); TURN_IN.targets = `{TURN_IN: Foreman Thazz'ril}`. Whether the turn-in target is the same NPC as the giver
   is a **fact stored per target** (`prov` says "assumed same as giver" vs observed).
2. **Unknown is a value.** `where.status = "unknown"` with no points. The planner may still *sequence* such an action
   (e.g. "turn in the quest in your log") but cannot compute transit, so it is eligible only for NOW when nothing located
   beats it and **never** for ALSO DO or markers/navigation. No coordinate is ever inferred from a zone or quest name.
3. **Multiple locations** exist at two levels: `targets[]` (several *different* things to do: objective A, objective B)
   with `targetMode = "ALL"`, and `where.points[]` (several places where the *same* thing can be done, e.g. spawn
   points) with the planner picking the nearest. The current engine's single `objCoords[1]` becomes "all known
   objective coordinates, status approx, provenance att".
4. **Per-target provenance**, because one action routinely mixes sources (giver from ATT, objective from observation,
   turn-in assumed). Merge rules stay in the Registry (observed over ATT, field by field).
5. **Services** (trainer, vendor, inn, flight, graveyard) are the same structure with `role = "SERVICE"`, so
   future providers need no new shape. **[DATA?]** none of these have data today except 14 ATT flight nodes.
6. **Entity identity matters beyond coordinates.** A marker (section 18) can only attach to a unit/object it can
   identify, so `entity.id` (NPC id) is kept even when `where` is known. Creature id parsing from `UnitGUID` is
   **[PROVEN]** (M3, 14 NPCs); object ids are **[API?]**.
7. **Coordinates are map-space `{map,x,y}`** as today; world-yard conversion stays in Context (`worldOf`) and is
   **[PROVEN]** (M8.10). `exact` vs `area` vs `player_position` replaces the current `approx` boolean.

## 6. Proposed Plan contract

```text
Plan = {
  rev        = integer,           -- increments whenever now / alsoDo / then change identity or target
  stamp      = { ctx = ..., strategy = "fast", prefsRev = n },
  now        = PlanItem | nil,    -- exactly one, or nil with plan.noNow = reasonCode
  alsoDo     = PlanItem | nil,    -- at most ONE (see section 8)
  next       = PlanItem | nil,    -- "THEN": at most one (section 9); named `thenItem` in code to avoid the keyword
  noNow      = nil | "NO_CANDIDATES" | "ALL_BLOCKED" | "NO_CONTEXT" | ...,
  inLog      = { PlanItem... },   -- quests in log with no location (reminders) [see section 23]; not part of NOW/ALSO DO/THEN
  diag       = { ... }            -- developer data: candidates, filtered counts, per-sequence scores, dropped reasons, warnings
}

PlanItem = {
  actionId  = "Q:123:TURN_IN",
  actionRef = <the immutable Action>,        -- UI/Navigation never copy fields from it
  category  = "QUEST_ACCEPT" | "QUEST_OBJECTIVE" | "QUEST_TURN_IN" | "TRAVEL" | "FLIGHT" | "TRAIN" | "GRIND" | ...,
  why       = { { code = "ON_THE_WAY", args = {...} }, ... },   -- structured, ordered by relevance
  leg       = { targetIndex = 2 } | nil,     -- which target is the current leg (for multi-target actions)
  nav       = { targetIndex, point } | nil,  -- present only if the leg has a known/approx point
  stopId    = "...",                          -- the stop this item belongs to (section 10)
  progress  = nil | { have, need },
}
```

Rules: `diag` is the only place scores/ids/provenance appear. `PlanItem` holds an action *reference*, and the UI obtains
human text via the **Presenter** (section 23), never from the planner. A plan is a value: recomputation returns a new
table; the previous plan is retained only for hysteresis (section 15).

## 7. NOW semantics

- Exactly one `PlanItem` or `nil`. `nil` is a legitimate answer with a reason code (nothing eligible), never filled
  with a placeholder action.
- NOW is the **first action of the best-scoring short sequence**, not the closest or highest-scoring action. Concretely
  the planner may select NOW = "kill Sarkoth (50 yd away)" even though "turn in X" is a higher-urgency kind.
- NOW is an *action leg*, i.e. a concrete next thing with a target: "go to X and do Y" is one NOW whose `leg` is the
  first target; TRAVEL is not a separate NOW unless transit itself is the point (leaving a zone, taking a flight,
  using a hearth/graveyard). Rationale: the player's NOW should name the *purpose*, with travel implicit, matching "look,
  do, look again".
- Never `COMPLETED`/`SKIPPED`/`BLOCKED`. Respects Hardcore (RESPAWN_SKIP dropped in the candidate filter, as today).
- Stable: changes only under the rules in section 15.

## 8. ALSO DO semantics

- **At most one** `alsoDo` in the player-facing contract. The planner may *internally* keep a ranked shortlist in
  `diag` for diagnostics, but nothing downstream (UI/markers) consumes more than one. (Decision recorded because the
  audit said 1-3; the later simplification to one marker per symbol supersedes it.)
- Meaning: an action that can be done **while doing NOW or from the position you will already be in**, with a *small
  marginal cost relative to its value*. Formally: `alsoDo` = argmax over candidates `a` of
  `value(a) - w_t * interruption(a | NOW trajectory)` subject to `interruption(a) <= tolerance` and
  `value(a) >= floor`, where `tolerance`/`floor` are strategy parameters. If nothing qualifies: `nil`. **Silence is the
  default**; it is an explicit non-goal to fill the slot.
- It must not be an action already in the NOW stop, nor a prerequisite of NOW, nor one that conflicts (e.g. same
  single-target slot).
- Located only: an action with unknown location cannot be ALSO DO (no marker, no transit, no honest "while you are
  here").
- `optional=true` actions (flight discovery, trainer visit) compete for this slot only; they can become NOW only when
  the strategy explicitly allows (e.g. Completionist) or when they unblock NOW.
- Reduced confidence: if the value or the target of the candidate is mostly `unknown/approx`, require a stricter
  tolerance (planner confidence term, section 11).

## 9. THEN semantics

- At most one item: the first action *after* NOW's stop in the chosen sequence, **only if it adds information**: i.e.
  it changes where you will go next (a different stop) or explains why NOW is worth doing (e.g. "then turn in at
  Orgrimmar" for a chain). Omitted when `then` would be the same stop, an obvious repeat, or unknown-location.
- It is context, never a queue and never navigated/marked. The UI may hide it entirely at small sizes.
- It is *not* a promise: it is recomputed from scratch each time and may change when the player acts.

## 10. Sequence reasoning model

### 10.1 Representation

- **Stop**: a maximal set of candidate targets within `STOP_RADIUS` yards (same map/continent, via `E.Distance`), plus the
  actions doable there. A stop with several actions (turn in A, turn in B, accept C at the same NPC/hub) is evaluated
  once for transit, so **batching falls out of the cost model** rather than being a special rule. `STOP_RADIUS` is a named
  parameter; initial value must be justified from observation (NPC interaction range and the existing `CLUSTER_CELL`
  neighbourhood), not guessed, and is calibratable with telemetry movement data.
- **Sequence**: ordered list of stops, length `<= DEPTH` (initially 3-4 stops, a named constant), starting from the
  player's current position. A pure-transit leg is implicit between stops.
- **Projected state**: after hypothetically doing a stop, the simulated quest state advances (ACCEPT makes that quest's
  OBJECTIVE and TURN_IN actions exist; completing all objectives makes TURN_IN `READY`). Projected actions are flagged
  `projected = true`, carry the same provenance as the data they come from, and are only produced if their targets are
  known/approx (otherwise they contribute chain value but are not sequenced; unknown stays unknown).

### 10.2 Evaluation

```text
rate(seq)  =  ( sum over actions in seq: strategyWeight . value(a)  *  confidence(a) )
              -------------------------------------------------------------------------
              ( sum over legs: transit(leg) + sum over stops: dwell(stop) + interruption_extra )
```

- `value` as in section 4.3 (policy currency by default; swaps to XP when known).
- `transit(leg)` from the **Transit model** (section 11). `dwell` = action `dwell` or a labelled policy constant.
- `confidence(a) in (0,1]` discounts value for unknown/approx pieces (approx location, unknown requirement). It is a
  *strategy-independent, explicit* factor so low-quality data is ranked lower rather than hidden or silently trusted.
- Optional bounded refinement: sequences are scored with a small beam search over the top-K candidates by single-action
  value density (K and DEPTH constants). Cost is bounded by `K^DEPTH` stops before pruning; recompute is event-driven
  (State dirty flag) plus the existing 3 s tick while the window is open. Determinism: stable ordering, ties broken by
  action id, no randomness.
- The planner never mutates actions; hypothetical state is a local overlay.

### 10.3 Why this resolves the observed failures

| Failure | Mechanism |
|---|---|
| "100 dominates" | Turn-in value does not *decay* by waiting; its cost-of-delay is only what it unlocks or leaving the area. A sequence "objectives here, then turn-in" has the same value and less transit than "turn-in, back, objectives", so it wins on `rate`. |
| Greedy, myopic | Sequences compared on whole-trip rate. |
| One target | Multi-target actions evaluated as legs; stops combine targets. |
| Missing chain value | Projected successors (section 13). |

### 10.4 Worked scenarios (design validation, not implementation)

**A. Batching (Cutting Teeth ready; Sting of the Scorpid + Vile Familiars in progress; player near the scorpid/Vile area).**
Candidates: T1 = turn in Cutting Teeth at Gomek-area (S_home); O1/O2 = objectives at S_far (scorpids 46.5,58.4 and Vile
Familiars 45.3,56.8 are in the same stop). Sequences: [S_home, S_far, S_home] vs [S_far, S_home]. The second omits
one round trip; same value; lower transit. Plan: NOW = O1 (objective, one stop), ALSO DO = O2 only if it were a distinct
stop within tolerance; here O1+O2 share a stop so NOW's stop contains both, `then` = "turn in at S_home (3 quests)".
No rule says "delay turn-ins"; it is path length.

**B. Travel productivity.** Player at P heading toward quest giver G (NOW). An objective O lies near the path P-G.
`interruption(O | trajectory) = d(P,O)+d(O,G)-d(P,G)`, small, so O qualifies as ALSO DO (or merges into NOW's stop if
under `STOP_RADIUS` of the path); the sequence [O, G] beats [G] alone because the added transit is below the value.
Note the planner uses the *chosen NOW's* trajectory, which is why the evaluation is relative to a trajectory, not a
point.

**C. Local density.** NOW candidate X is 375 yd away (high single-action urgency); a stop S with 3 objectives lies 50 yd
away. `rate([S])` = 3 values / (50 yd transit + dwell) vs `rate([X])` = 1 value / (375 yd + dwell). S wins unless X's
value is large enough, which is the intended trade, and it is entirely parameterised by strategy (a Fast strategy weights
transit more heavily).

**D. Chain lookahead.** See section 13.

**E. Level breakpoint.** See section 13.2. Needs XP state; deferred.

## 11. Interruption / travel cost model

### 11.1 Transit (pluggable)

`Transit.cost(a, b) -> { seconds, mode, basis }`. Default mode `WALK`: `yards / RUN_SPEED`, with yards from the proven
world conversion (`E.Distance`; 5000-yd sentinel for different continents / not comparable).
`RUN_SPEED` is a **game constant, not yet validated on Forever**; label the result `estimated` and prefer the observed
speed from telemetry (`PLAYER_MOVE` dist/dur, `observed`) when `TelemetryMetrics` has enough movement. Other modes are
**providers of edges**, not planner special cases:

| Mode | Needs | Status |
|---|---|---|
| WALK | map/world positions | **PROVEN** |
| FLIGHT | discovered nodes, flight time, node-to-node edges | **[API?][DATA?]** (cost API absent; discovery unknown) |
| HEARTH | bind location, cooldown | **[API?]** (`GetBindLocation` unprobed) |
| RESPAWN (death shortcut) | graveyard coordinates, ghost-walk cost, non-Hardcore | **[DATA?][API?]** and filtered for Hardcore |
| MOUNT/speed changes | speed API | **[API?]** deferred |

`transit` takes the minimum over available edges, so an intentional-death shortcut (observed ~543 yd and ~350 yd
trips in the playtest) can later be expressed purely as a RESPAWN edge with its own cost and the Hardcore filter.

### 11.2 Interruption cost

Definition (proposal): **interruption(a | trajectory) = marginal plan time of inserting `a`**, i.e.
`time(sequence with a) - time(sequence without a)`, excluding the action's own dwell (that is its cost, not its
interruption). This is general: it equals the detour for geometric cases (B, C), is zero when `a` lies on the route or
shares a stop, and grows with distance. Components considered:

| Component | Include? | Rationale |
|---|---|---|
| Travel distance | Yes (via transit) | Proven geometry. |
| Estimated travel time | Yes | distance / speed, labelled estimated. |
| Route deviation (detour) | Yes: this is the primary definition | Captures "on the way". |
| Action transition cost (talk <-> fight, ...) | Named hook, default 0 | No evidence of magnitude yet; telemetry downtime share could calibrate later. Not guessed. |
| Context switching beyond transition | No | Not measurable; deferred. |

No fixed penalty numbers are proposed: the *scales* (`w_t`, tolerance, floor, STOP_RADIUS, K, DEPTH) are strategy/planner
parameters that must be calibrated against playtest scenarios (section 26) and telemetry before being frozen.

### 11.3 Confidence

`confidence(a) = product of component confidences` where `exact/known = 1`, `approx/area < 1`, `unknown requirement < 1`,
`projected` successors discounted. Values are named parameters, not magic numbers in code, and the discount applies to
*value*, never to provenance labels.

## 12. Quest state / identity model

Identity: **quest ID** everywhere (action ids, skip, hysteresis, telemetry, navigation). Names are display-only. The
"Sarkoth" and "Simple Parchment" same-name quests are distinguished by ID; the Add-box search already lists id with
name.

State enum (derived each recompute from client state, authoritative over anything Codex expected):

| State | Derived from | Plannable? |
|---|---|---|
| `AVAILABLE` (eligible to accept) | not in log, not completed, requirements true | yes (ACCEPT) |
| `ACTIVE` | in log, objectives incomplete | yes (OBJECTIVE) |
| `READY` | in log, objectives complete | yes (TURN_IN) |
| `COMPLETED` | `IsQuestFlaggedCompleted(id)` **or** turned in this session | **never** actionable |
| `BLOCKED` | any requirement `false` (level, prereq, class, race, faction) | no (kept for the Quest Map/tooltips) |
| `SKIPPED` | player skip flag on that id | no (unless pinned? see open questions) |
| `UNKNOWN` | state unavailable (no quest log API, no data) | no (diagnostic) |

"Objective progress": per-objective `have/need/finished` is **[PROVEN M8.9]** via `C_QuestLog.GetQuestObjectives` and
lives in the action's `objectiveState` (quest-log state), never on a Target. Ready-to-turn-in comes from
`IsComplete`/`ReadyForTurnIn` **[PROVEN M8.9]**. When the objective list cannot be read, `objectiveState.known = false`
(unknown), not "complete". Known quirks (M8.9): objective names are blank for ~0.2 s after accept (counts are right);
a quest reads un-done for a moment at turn-in; client objective order is stable but its mapping to ATT/route objective
indexes is unverified, so ATT objective coordinates are **not** tied to objective indexes.

**Caveat (new): `C_QuestLog.IsQuestFlaggedCompleted` is still UNVERIFIED on Forever** (M8.11 lists it as unverified at
startup; Codex 0.1 uses it, and the playtest exercised it only implicitly). It is how `COMPLETED` and pre-install chain
steps are known, so it must be verified (tiny `/run` check on a quest the character really turned in, before and after a
relog) before the Planner treats "completed quests are never actionable" as a hard dependency. Until then the existing
behaviour is preserved and `ctx.isCompleted` cannot express "unknown" (it coerces to false).

Rule: completed status is checked by **ID** at the provider *and* re-checked by the planner when projecting successors,
so a same-named quest can never revive an actionable item. A projected successor is identified by its own quest ID and
re-evaluated against the same rule. Skip flags unify to one flag per quest ID (the current accept/in-progress skip-key
split is noted as a defect to fix at implementation).

## 13. Quest-chain lookahead

### 13.1 Chains

- Data: ATT `sourceQuest` gives *prerequisites*; the reverse index `unlocks[q] = {quests whose prereq includes q}` is
  **derived** (provenance att, unverified, with the existing any-of ambiguity). **[EXISTS: prereq; PROPOSAL: reverse index]**
- Bounded lookahead: when valuing action `a` (typically an ACCEPT or TURN_IN), add `chain = gamma * (value of the best
  successor that is (i) eligible after `a`, (ii) has a known location, (iii) within a bounded distance/stop count)`, with
  `gamma < 1` per hop and **max 1-2 hops**. No game-tree solve. Successors that are location-unknown contribute a
  *discounted, labelled* chain value but are never sequenced.
- Breadcrumb quests (ATT flag) keep their current negative weight; they are "lead-ins" and only valued through what they
  unlock.
- Because `a`'s value includes its successor's value, "turn in Quest X to unlock Quest Y a few yards away" is
  correctly preferred without enumerating Y as a separate stop.

### 13.2 Level breakpoints (design only)

A pseudo-action type `GRIND` (or `LEVEL_BREAKPOINT`), generated *only if* the data and the metrics exist:

- Value = `unlockValue(L+1)`: sum of values of actions currently `BLOCKED` solely by `level` whose `req <= L+1`
  and which have known locations (from ATT `req`, **[PROVEN data]**), plus any trainer/class opportunity at `L+1`
  **[DATA?]**.
- Cost = time to the next level = `(xpMax - xp) / xpRate`. Needs `UnitXP/UnitXPMax` **[API?]** and an `xpRate`
  from telemetry `observed/calculated` (`TelemetryMetrics.xp.perMinute`, session-only) **[API?]**. If either is `nil`,
  the GRIND action **is not generated** (unknown stays unknown); the planner never assumes a rate.
- Targets: `AREA` with `radius`, location from the character's current/route-zone area; mob/level information needs
  data **[DATA?]**, so the first version could only say "keep killing here" with no marker.
- Interaction with strategy: Fast weights breakpoints; Questing disables GRIND entirely (type not allowed).

## 14. Strategy interaction

Strategies remain **parameter sets over one model**. No route data per strategy.

```text
Strategy = {
  key, label, active,
  allow  = types allowed (e.g. Questing excludes GRIND),
  filter = { maxGap, hideRepeatable, ... },                      -- eligibility policy (existing: maxGap)
  w      = {                                                      -- existing Engine weights stay valid for the Engine
            value = { xp, progress, chain, discovery, class, profession, levelFit },   -- per component
            time = <weight of transit+dwell in the rate denominator>,
            detourTolerance, alsoDoFloor, stickiness, depth, beam,
            confidenceFloor },
}
```

| Strategy | Intent expressed as parameters |
|---|---|
| Balanced / Efficient | Moderate time weight; progress+chain+levelFit; modest detour tolerance; shows ALSO DO when cheap. |
| Fast | High time weight; low detour tolerance; weights XP/breakpoint when known; skips low-value (`maxGap`); batching emerges from rate; GRIND allowed once data exists. |
| Questing-only | `allow = {QUEST, TRAVEL}`; weights progress/chain; no GRIND; reasonable detour tolerance. |
| Completionist | Low time weight; weights discovery; wide `depth`; `maxGap = false`; higher `alsoDo` tolerance (surfaces more content). |
| Solo / Dungeon-friendly / Hardcore (planned) | Hardcore: risk term + RESPAWN filter (already independent); Dungeon: needs group data. **[DEFERRED]** |

Existing `w` Engine weights are preserved so the legacy Engine and the adapter keep working while the planner adds the
`plan`-side parameters with defaults that reproduce current behaviour where possible. Changing strategy forces an
immediate recompute with stickiness disabled (section 15).

## 15. Player deviation handling

Principle: **the character's actual state is authoritative; the plan is a recommendation recomputed from state, with no
commitment memory except a small stability aid.**

| Deviation | Handling |
|---|---|
| Does an action outside Codex (turns in, kills, accepts elsewhere) | Detected by quest-log/completion state; action becomes `ACTIVE/READY/COMPLETED` by ID; plan recomputed. No notion of "off route". |
| Accepts an unrelated quest | New ACTIVE actions enter the pool; nothing special. |
| Moves to another zone / far from NOW | Planner is position-based; NOW re-evaluated from the new position. The player's *route zone preference* is a strategy bonus (player's choice), not a constraint; `stickiness` is suspended when the player is not approaching NOW (revealed preference). |
| Levels up | Eligibility recomputed (`req`, level fit); level-up events are PROVEN-adjacent but `PLAYER_LEVEL_UP` is **[API?]**; the periodic recompute + `UnitLevel` read (PROVEN) catches it regardless. |
| Changes strategy / route zone / systems | Immediate full recompute, no stickiness. |
| Joins a group | `ctx.group` changes the eligible set and weights (`GROUP` actions later) **[DEFERRED]**. |
| Intentionally dies / respawns | Position changes; transit edges (RESPAWN) later. Never recommended in Hardcore. |
| Ignores NOW indefinitely | Nothing is recorded as a skip; only the explicit player Skip persists. |

**Stickiness (hysteresis)** to prevent flapping markers/waypoints: the previous NOW is kept unless (a) it is invalid
(completed, blocked, skipped, unreachable), (b) a new candidate's sequence rate exceeds it by `stickiness` margin
(parameter), or (c) the player is demonstrably not approaching it (distance not decreasing over a window) while
approaching something else. Ties broken deterministically by action id. The previous plan's `now.actionId` is the only
cross-run state the planner needs.

## 16. Engine vs Planner boundary

Verified against the code, the proposed layering is **right in spirit, with one correction**: the Engine today is not a
separable "evaluation" stage; collection, filtering, scoring and chaining are one function with private helpers.

Proposed responsibilities:

| Layer | Responsibility |
|---|---|
| Providers | Discover actions + their targets/requirements/state/provenance from data + context. No scoring, no text. |
| Eligibility/filter (extracted from Engine) | Global filters (Hardcore, allow-list, skipped, hereOnly) and per-type eligibility. Shared by Engine and Planner. |
| Engine (kept) | **Single-action facts**: `Distance`, level fit, hub density, urgency-by-kind score. Used (a) by the legacy greedy path, (b) as a *value-component source* for the planner (levelFit, hub). It must stop being the sequencing authority. |
| Planner (new) | Stops, sequences, transit/interruption, value-per-time, NOW/ALSO DO/THEN, stability. |
| Presenter (new, small) | Plan + Action -> human text and viewmodel; reason code -> sentence. |
| Navigation / Markers / Quest Map / UI | Consumers. |

Correction to the earlier diagram: the Planner should call the **provider+filter stage directly** rather than consume
`Engine` output as if Engine produced "evaluated candidates"; the Engine's greedy output is *replaced*, not wrapped.
The Engine remains as a library and as the fallback/regression oracle during migration.

## 17. Navigation contract

NavigationController (not implemented here) consumes the Plan and owns the waypoint lifecycle:

```text
onPlan(plan):
  if plan.now == nil            -> clear(owned waypoint)           ; reason "no NOW"
  elseif plan.now.nav == nil    -> clear(owned waypoint)           ; reason "NOW has no known location"
  elseif plan.now.actionId ~= nav.actionId or nav.point changed
                                -> clear(), place(plan.now.nav.point), nav.actionId = plan.now.actionId
  else keep
onCompletion(actionId) -> same as plan change (the planner recomputes; navigation does not guess completion)
```

- Navigation state = `{ actionId, targetIndex, point, owned = true }`. It is **tied to the action ID**, not to a click.
- Completion/invalid is detected through the planner's recompute (State dirty on quest events), so navigation needs no
  quest logic of its own.
- Backend 1 (first implementation): the built-in user waypoint: `UiMapPoint.CreateFromCoordinates` +
  `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint` **[PROVEN]** (map 1413 confirmed; other maps not
  recorded as proven). `C_Map.ClearUserWaypoint` is **[PROVEN]** (M8.6-B, M8.10); whether it also ends super-tracking
  was not separately recorded.
- Backend 2 (later): Codex-owned arrow (M8.14 probe v0.2, results outstanding) **[DEFERRED]**.
- Player-set waypoints: the controller should only clear a waypoint it placed (`owned`). Detecting that the player
  replaced it can be done by reading the waypoint back: `HasUserWaypoint` / `GetUserWaypoint` are **[PROVEN]** (M8.10,
  exact map + coordinates), so ownership = "the readback equals the coordinates Codex placed". There is no owner tag;
  whether a pin survives `/reload` or relog is unproven.
- The Show on Map button is removed in the player UI once this exists; dev access stays via slash/diag.
- Multi-target actions: `nav` is the *current leg* (nearest unfinished target, or the forced `order`), so the waypoint
  advances inside one action without changing `actionId` (nav changes by `targetIndex`).
- Cross-map targets: `nav` may point at a map the player is not on; the waypoint is placed on the target map (the user
  waypoint is per map), and transit (TRAVEL/flight) is the NOW until the player arrives **[API?: cross-map arrow
  behaviour not recorded as proven]**.

## 18. Marker contract

Markers are a **sink** of the Plan; the planner never calls marker APIs and never depends on whether markers work.

| Symbol | Source | Rule |
|---|---|---|
| Star | `plan.now` target entity | max 1; moves/removes with NOW; removed when NOW is nil, unknown-location, or entity not identifiable |
| Diamond | `plan.alsoDo` target entity | max 1; only when `alsoDo ~= nil`; never "because something is nearby" |
| Green triangle | one relevant flight master | chosen by a separate small `relevantFlight(plan, ctx)` selector (e.g. NOW is a FLIGHT action, or a flight is NOW's transit mode); max 1 |
| Moon | one relevant inn | same pattern; needs inn data **[DATA?]** |

Constraints: one marker per symbol; Forever allows one active marker per symbol (given). Marker placement on arbitrary
NPCs/world objects is **[API?]** and must not be assumed; marker attachment needs `entity.id` and a way to resolve a
unit in range, so a target with only coordinates cannot be marked. Marker sync input: `plan.rev` plus
`{now.entity, alsoDo.entity}`; output: set/clear symbols, idempotently.

## 19. Quest Map boundary

The World/Quest Map answers "what is around me?" and is **not** a planner view. It reads a `WorldIndex`
(read-model over packs + Knowledge + quest state, using the same Target/state types so a quest looks the same everywhere),
supports filters (available, active, turn-ins, objectives, Codex recommendations, optional opportunities, completed,
unknown/unverified), and may accept a set of `highlight` action ids from the Plan (`now`, `alsoDo`) to emphasise them. It
works with no plan at all. Pin placement on the map canvas **[API?]**; ATT/observed/unknown must be visually distinct.
Questie is conceptual inspiration only; no code, data structure, UI or asset is reused. **[DEFERRED]**

## 20. Provenance handling

Rules (carry the existing philosophy into the new contracts):

1. Provenance is **per field** (`prov` on targets, requirements, value components, name), never a single action flag.
2. `src="att", verified=false`; `src="observed", verified=true` (existing convention); estimated/calculated/policy are
   *basis* labels on values, not data sources.
3. The planner **reads** provenance and **never writes `verified`**. It may attach `confidence` (a number) and a
   derived `evidence` label that follows a **weakest-link** rule: any `att`/`estimated`/`unknown` input pulls the label
   down; the label can never be higher than the weakest input that influenced the decision.
4. Observed `player_position` coordinates stay labelled `kind = player_position` (approx), as today.
5. Projected/derived values (chain value, breakpoint unlock) carry `basis = derived` and the provenance of their inputs.
6. Unknown remains unknown: `nil`, `where.status = "unknown"`, tri-state requirement results.
7. Player-facing contract carries **no** provenance. If the UI must communicate approximate quality it receives a neutral
   `quality = "exact" | "approximate" | "unknown"` derived from the target (not the source name).
8. Observed learned locations (e.g. Thazz'ril's Pick) stay in the observed layer (per character locally, or a pack from
   the observation harvest later), never merged into ATT rows.

## 21. Future system integration points

A future system plugs in through four narrow interfaces; the planner is unchanged:

| Interface | Used for |
|---|---|
| `Provider.generate(ctx) -> actions` | New action types (TRAIN, VENDOR, GRIND, ...) |
| `Transit edges` | FLIGHT, HEARTH, RESPAWN, mounts |
| `Knowledge feed` | Discovered flight nodes, trainers seen, recipes known (observed, per character) |
| `Context fields` | XP, level breakpoints, money, inventory, death state, group state |

| System | Planner needs | Possible now | Needs |
|---|---|---|---|
| Trainers | TRAIN actions with SERVICE targets; level-breakpoint triggers | no | trainer data + spell/ability APIs **[DATA?][API?]** |
| Vendors | VISIT actions that *enable* a TRAIN (money) | no | vendor data, money/inventory APIs |
| Professions / Pets | profession/pet value components | no | data + APIs |
| Flight paths | discovery value; transit edges | partly (14 ATT nodes as hints) | discovered-node API **[API?]**, flight time |
| Inns | moon marker; rest value | no | inn data |
| Grinding | GRIND area actions, breakpoint value | no | XP APIs + metrics + mob data |
| Dungeons / Party | group-aware weights, shared objectives | no | group events, comms **[API?]** |
| Character knowledge / Journey | knowledge-feed + history (not planner inputs) | no | stores **[PROPOSAL]** |
| Discoveries | `discovery` value | partly | observation stores |

## 22. Telemetry integration boundary

- One-way read via a narrow `PlannerInputs.metrics()` returning only `TelemetryMetrics.Summary` values whose
  `value ~= nil`, keeping their `kind` (`observed | calculated | estimated`) and `n`. The planner never reads raw
  events and never fails when metrics are missing: it falls back to **labelled policy constants**.
- Candidate uses, each *only if present*: observed movement speed (transit estimate), XP/min (breakpoint cost),
  quest accept->complete seconds (dwell estimate; per quest ID only after the quest has been done once, which is not
  useful for the first attempt, so a *kind*-level average is used with `estimated` label), combat share, level-ups.
- Outbound: the planner emits observation events (`PLAN_NOW_CHANGED` with action id and reason codes, no scores) to
  Telemetry; Telemetry never influences the planner except through the metrics interface. No telemetry redesign.
- Caveats carried over: telemetry windows are single-session (`GetTime` resets); XP/combat/level events are **[API?]**
  (UNPROVEN); metrics are therefore optional inputs, never required.

## 23. UI contract

The UI consumes a **viewmodel produced by the Presenter** from `Plan` + the actions it references:

```text
ViewModel = {
  now     = { title, subtitle?, icon, progress?, whyShort?, whyDetail[], nav = bool },
  alsoDo  = same | nil,
  thenItem= { title, icon } | nil,
  inLog   = { { title, state } ... },          -- reminders of quests in log with unknown location
  empty   = nil | { message },                  -- "nothing to recommend", from noNow reason
}
```

- Text is produced by the Presenter from reason codes and structured fields through a code->sentence table (single place
  for wording, testable, localisable). Titles come from `name` + kind verb.
- **Forbidden in the viewmodel**: source/provenance labels ("ATT"), `verified`, quest/action ids, coordinates, map ids,
  scores, internal state names, "waiting", raw reason arrays. Those live in `plan.diag` and the diagnostics views.
- Neutral quality words ("approximate", "location unknown") derive from `where.status`/`kind`, not from `src`.
- Skip/Add remain reachable through context actions and slash commands; they act on action/quest ids, never on titles.
- Tooltips (later) render `why[]` codes plus quest details through the same Presenter.

## 24. Migration strategy

Practical with the current architecture because the plan consumers are few (section 2):

1. **Spec-first, no behaviour change**: add contract types as documentation + test fixtures; nothing runs.
2. **Provider output extension (additive)**: providers keep emitting today's fields and additionally `ref`, `state`,
   `targets[]`, `requirements[]`, `completion`, `prov`. Old fields remain so Engine/UI/Route are untouched. (Dual-write
   is safe because actions are plain tables.)
3. **Extract the collect/filter stage** from `Engine.Compute` into a callable (behaviour-preserving refactor with the
   existing 316 tests as the guard).
4. **Planner v1 behind a flag** (`/codex planner on|off`, off by default): computes a `Plan`; the **legacy adapter**
   maps it to the current shape: `plan.next = now`, `plan.upcoming = {then}`, `plan.nearby = {alsoDo}`,
   `plan.sequence = {now, alsoDo?, then?}`, `plan.inProgress = inLog`, with stats/warnings copied. The existing UI then
   shows the new decisions unchanged. A/B comparison via Diag (both plans stored).
5. **NavigationController** consumes `Plan` (adapter not required): fixes the stale waypoint independently of any UI
   work.
6. **UI rebuild** against the ViewModel only after the Plan contract has survived playtests.
7. Remove the legacy path last, keeping Engine facts as a library.

Risks: adapter hides ALSO DO's single-item rule from the old UI (acceptable); dual-written fields can drift (mitigate with
a test that asserts old and new fields agree for the same provider output).

## 25. Testing strategy (designed, not written)

Harness: the existing Lua 5.1 stub-client harness (`tests/run_codex_tests.lua`), deterministic fixtures with explicit
coordinates and levels (synthetic, labelled as fixtures; no real quest data invented), plus mutation checks (as used
for the probe) on the planner's key rules.

**Quest state**: available; active; objective partially complete (from the proven `GetQuestObjectives` shape, supplied by the
stub); objective complete -> READY; ready-to-turn-in; completed (never actionable); **duplicate names** (two quests,
same name, different ids, one completed -> only the other is actionable); unknown state (no log API -> no actionable
claims, a warning).

**Sequence reasoning**: turn-in vs nearby objective (batching, scenario A); two objectives in one stop; useful action
along the route (interruption ~ 0, scenario B); dense local area vs distant action (C); chain lookahead (successor
value changes the ranking; max 2 hops; unknown-location successor adds no sequenced action); level breakpoint
(**only** with XP + rate provided; absent -> no GRIND action generated); no useful ALSO DO -> `nil`; no valid NOW ->
`nil` + reason; NOW changes after completion; determinism (same input twice -> identical plan; permuted provider order
-> identical plan); bounded work (candidate count 500 stays within the beam cap).

**Player deviation**: action completed outside Codex; unrelated quest accepted; moved to another zone (stickiness
suspended); level up (eligibility changes); strategy change (immediate, no stickiness); player ignores NOW (no skip
recorded); flapping guard (two near-equal candidates, tiny position jitter -> NOW stable).

**Navigation**: NOW changes -> old cleared, new placed; NOW completes -> cleared; NOW invalid -> cleared; NOW has no
location -> cleared and no stale pin; leg advance within an action; waypoint API missing -> no error, diagnostic;
only an owned waypoint is cleared.

**Provenance**: ATT-derived inputs never produce `verified=true`; observed target stays distinct from the ATT target in
the same action; unknown stays `nil`/`unknown` through projection and presentation; weakest-link `evidence` never rises;
ViewModel contains no forbidden strings/ids/coordinates (extends the existing claims-scan test).

**Markers/Quest Map** (later): max one per symbol; never driven without a plan.

**Real-client checkpoint**: `/codex diag` extended with plan diagnostics; playtest scenarios in section 26 replayed on a
fresh character, with the old and new plans logged side by side.

## 26. Real playtest validation

Each observation is expressed through the *mechanism* that must be able to explain it (not hard-coded routes):

| Observation (Orc Warrior 1-5) | Mechanism |
|---|---|
| Kaltunk -> Gomek origin quest flow | Chain value (turn-in of the origin quest unlocks the next giver); origin priority as a `pinned`/policy `progress` term; separate giver/turn-in targets (Kaltunk vs Gomek). |
| Gomek offering several quests | One stop (hub) with several ACCEPT actions: transit paid once; ACCEPT values + chain. |
| Wayward Weapons objectives while traveling | Interruption ~ 0 (on-trajectory) -> ALSO DO or merged into the stop. |
| Cutting Teeth done opportunistically | Local density / rate (scenario C). |
| Sarkoth killed while nearby | ALSO DO by low interruption; identity by ID despite same-name quests. |
| Returning to batch turn-ins | Stop merging + path cost (scenario A); no "delay" rule. |
| "Simple Parchment" same-name chain | ID identity; chain successors by ID; completed one never reappears. |
| Lazy Peons local batching | Multi-target ALL-mode action / shared stop. |
| Cactus Apple / Scorpid / Vile Familiars | Same as A; Galgar turn-in delayed until the trip ends. |
| Finishing nearby objectives before leaving | Rate over the sequence includes the objectives in the stop. |
| Intentional cave death to save travel (~543, ~350 yd) | RESPAWN transit edge (needs graveyard data + non-Hardcore). Cannot be produced today; the design reserves the place. |
| Thazz'ril's Pick location inside the cave | Observed OBJECTIVE target (exact point) distinct from ATT; `AREA`/point targets; "learned something new" is a Knowledge event. |
| Burning Blade Medallion while already nearby | Interruption ~ 0 / same stop. |
| Checking the trainer after leveling | TRAIN action triggered by a level-up event; needs trainer data/APIs **[DATA?][API?]**. |
| Vendoring before training | VISIT action that *enables* TRAIN (money requirement unmet); needs money API/vendor data. |
| The Adventurer discovered independently | State derived from the client: it simply appears in the log; unknown-to-data quests go to `inLog` (no location), never invented. |
| Adapting to actual state | Stateless recompute from state + stickiness limited to stability; no committed route. |

Where the mechanism exists in design but the data/API does not (trainer, vendor, respawn edge), the playtest
validation is explicitly **deferred**, not claimed.

## 27. Open questions

1. **Value currency**: confirm policy value (with XP slotted in later) is acceptable, since XP is unavailable per quest.
2. **STOP_RADIUS, K, DEPTH, tolerances, stickiness**: need calibration scenarios from real play; propose a small set of
   recorded situations (positions/quests from playtest) as fixtures. Do we have exact positions beyond the coordinates in
   the notes?
3. **Skip semantics**: unify `Q:`/`QT:` skip keys to one per quest ID; should a pinned (Added) quest override a skip?
4. **Unknown-location quests in the log** (e.g. The Adventurer): `inLog` reminders only, or may they be NOW when
   nothing located is worth doing?
5. **Waypoint ownership**: the readback APIs are **[PROVEN]** (M8.10); open: does a pin survive `/reload` / relog, and
   who removed a vanished pin (quest tracking can).
6. **Per-objective progress API**: **resolved**, `C_QuestLog.GetQuestObjectives` is **[PROVEN]** (M8.9). Open: mapping
   ATT objective coordinates to objective indexes (no evidence).
7. **Turn-in NPC**: ATT has none; until observed, `TURN_IN` target = giver (labelled assumed). Do we surface "assumed"
   as neutral "approximate" in the UI?
8. **Where does ALSO DO's candidate shortlist live for diagnostics** and for the Quest Map highlight set?
9. **Death-shortcut policy**: required data (graveyards), Hardcore interplay, and whether Codex should *ever* suggest it
   or only account for it silently in transit cost.
10. **Cross-map NOW**: how navigation/markers behave when NOW is on another map **[API?]**.
11. **Stale quest data**: how to treat quests the pack lists but the client no longer offers (e.g. removed content).

## 28. Recommended implementation order

1. **Contract in code, no behaviour change**: add `ref/state/targets/requirements/completion/prov` to providers
   (dual-write); fixtures + tests; extract the collect/filter stage. (Section 24 steps 1-3.)
2. **NavigationController** over `Plan`-like input (works with the legacy plan's `next` first, then the Plan), using only
   the proven waypoint, with the owned-waypoint rule and clear-on-change (fixes the stale waypoint).
3. **Planner v1** with stops, walk transit, rate-based sequence evaluation, stickiness, NOW/ALSO DO/THEN, behind a
   flag + legacy adapter, with the scenario tests (A-C first; D with the reverse prereq index).
4. **Presenter + ViewModel** and the reason-code table; then the compact UI.
5. Probes (separate small addons): `IsQuestFlaggedCompleted` at startup, waypoint survival across reload/relog,
   XP/level/combat events, marker APIs,
   trainer/spell/taxi events, `GetBindLocation`.
6. Knowledge/Context extensions per probe results; level-breakpoint and service actions.
7. Markers, Quest Map, Codex arrow, party, sharing: each later, each a Plan consumer.

**Do not implement yet:** value/XP optimizer, GRIND/breakpoint generation, transit edges beyond WALK, markers, Quest Map,
arrow, party, trainer/vendor/profession/pet data, uploads, UI redesign, telemetry changes, new quest data.

---

## 29. Phase 2 as implemented (first real Planner)

`ForeverCodex/Planner.lua` (+ `PlanAdapter.lua`, a temporary bridge to the existing window). Where the implementation
differs from, or narrows, the design above:

| Topic | Design said | Phase 2 does | Why |
|---|---|---|---|
| Sequence score | value per unit time (a ratio) | **net = sum(value) - timeValue x (walking + doing)**, positive exactly when the sequence earns more than `timeValue` points per second | a plain ratio over sequences of different length always prefers the single cheapest action, i.e. "turn it in first" (reproduced while testing) |
| Search | beam over top-K stops, depth 3-4 | top 8 stops by solo net value, ordered sequences up to 3 stops (at most 400 scored); deterministic | bounded work |
| NOW | first action of the best sequence | same: best-valued action of the sequence's first stop | |
| ALSO DO | cheap insertion into the sequence | at most one: another action in the same stop (interruption 0), or one outside the sequence whose extra time is within `detour` seconds and whose net value clears `alsoFloor`. An action that is positive enough to be worth a stop is part of the sequence instead (it is NOW or THEN, with reason code ON_THE_WAY when it lies on the way) | keeps ALSO DO a decision rather than a runner-up |
| THEN | next contextual step | best action of the second stop, nil when there is none | |
| Value | policy points by component | policy points: kind value + level fit (the Engine's, so `levelFit`/`fitMul`/`maxGap` still apply) + 1-hop chain credit + pinned bonus, times a data-confidence factor. **No XP** | no quest XP exists before turn-in |
| Time | transit model + dwell | walking = yards / 7 (ESTIMATED game constant, unverified on Forever) + policy seconds per kind; progress counts from the quest log shorten an objective's time but never move its location | |
| Cross-continent | transit unknown | a leg whose time cannot be known ranks after every fully-known sequence (except into a quest the player added) | unknown stays unknown |
| Unlocated actions | reminder lane | `plan.reminders`; the adapter lists them under the old "location unknown" line | |
| Chain | bounded lookahead | one hop: a turn-in is credited with a share of the follow-up quest it makes available within `CHAIN_RADIUS` (derived from ATT prerequisites, unverified, any-of) | |
| Route zone | player's choice | when the chosen route zone has anything to do, only its stops are sequenced (others can still be an ALSO DO) | the old engine's "choice beats convenience" |
| Added quests | explicit choice | a stop containing an added quest starts the sequence; the data's requirements (ATT, unverified) do not veto it | player control |
| Skip | one flag per quest ID | the planner honours the logical skip (either legacy key); Preferences still writes both keys | |
| Stability | previous NOW + approach check | previous NOW kept within `stickiness` points; **the "is the player approaching it" check is not implemented** | later |

Not in Phase 2 (unchanged): navigation controller, waypoint lifecycle, markers, quest map, the final UI, grind and
level-breakpoint actions, death shortcuts, trainer/vendor/inn/pet/profession actions, telemetry as a planner input.
`/codex planner off` runs the previous engine (kept as the compatibility path; the Phase 1 golden snapshot pins it).
