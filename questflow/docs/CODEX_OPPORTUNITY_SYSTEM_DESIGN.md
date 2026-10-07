# Forever Codex: Opportunity System, architecture proposal

Status: DESIGN ONLY. Nothing here is implemented, no code changed, no build made. Written after reading `Planner.lua`, `Engine.lua`, `Contract.lua`, `PlanAdapter.lua`,
`Overlap.lua`, `Presenter.lua`, `Providers/*.lua`, `Telemetry.lua`, `Registry.lua`, `Strategies.lua`, `Preferences.lua` and the real-client reports of 0.4.x-0.5.x.

Evidence labels: **[V]** verified by reading this repository; **[R]** observed on the real Forever client (recorded in repo docs or reports, build 70205);
**[U]** unverified: an API or another addon's behaviour that must be checked before anything is built on it.

The one-sentence version: **the Opportunity System is not a second planner. It is (1) more kinds of optional actions produced through the existing Contract, (2) a
small pure library that classifies an action's cost and value relative to the route the planner already chose, and (3) a wider "ALSO DO" channel. The planner stays
the only decision maker.**

---

## 1. What the planner already does that IS opportunity reasoning [V]

Almost everything in the brief already exists under other names. The mapping (the left column is the brief's concept):

| Opportunity concept | Where it already lives | Status |
|---|---|---|
| Required action vs optional opportunity | `Contract`: an action has `optional = true` (flight hints, future gather nodes); `Planner.gather` puts `optional` / `hereOnly` actions in `S.extras` (never sequenced), the rest in `S.items` | exists |
| "On the way" cost | `chooseAlsoDo` / `interruption()`: for each candidate, the cheapest extra seconds to insert it between consecutive nodes of `player -> stop1 -> stop2 -> ...`. Detour, direction of travel and backtracking are all inside this one number | exists, reuse |
| Same-stop bundling | `makeStops`: actions within `STOP_RADIUS` (60 yd) share one stop and one trip; value and dwell add. Batching "falls out of the cost model" | exists |
| Hub value | stop value = sum of its actions' policy values; `Engine.applyStaticScores` also has a grid-cell cluster count for hub detection (legacy scoring) | exists (stop level) |
| Productive travel | sequence score `net = sum(value) - lambda * (walk + dwell)` over sequences of up to 3 stops, beam 8 | exists |
| Deferred turn-ins, route-aligned hand-ins, batches, slot pressure | `DEFER_TURN_INS`, `ON_ROUTE_YD`, `BATCH_*`, `SLOT_PRESSURE_FREE` (0.4.3) | exists |
| "Work here comes first" | `LOCAL_FIRST`, `WORK_HERE*`, `StayLocal` | exists |
| Chain value | `chainValue`: a turn-in is credited with a share of the quest it unlocks within `CHAIN_RADIUS` | exists |
| Urgency | partly: `Engine.LevelFit` / strategy `maxGap` (hide quests far below the level), `levelFit`; "about to turn gray" is NOT modelled | partial |
| Stickiness | `stickiness` points, `bestPrev` | exists |
| Provenance / confidence | `Contract.Prov`, `evidence` (weakest link), `Planner.Confidence` (discounts value, never raises it), reminders for unlocated actions, `UNKNOWN_LEG_SECONDS` for unmeasurable legs | exists |
| Player agency | player skip / add / route zone / style / per-system toggles (`RegisterSystem`, `IsSystemOn`); `pinned` quests | exists |
| Why-codes (decision basis) | `diag.reasons[id]` = `{ code, ... }` (BEST_SEQUENCE, SAME_STOP, TURN_IN_WAITS, ON_THE_WAY, SMALL_DETOUR ...), `diag.rejected` (TOO_FAR, LOW_VALUE, UNKNOWN_TRANSIT), `diag.alsoDo` | exists |
| Overlap channel for objectives | `Overlap.List` ("ALSO COMPLETE THIS": unfinished objectives within 300 yd of NOW or the player) and `Overlap.Ready` (READY TO TURN IN) | exists, but a SECOND opportunity channel with its own rules |
| Service targets | `Contract` already defines `role = SERVICE` with `service = FLIGHT | TRAINER | VENDOR | INN`; `Providers/Planned.lua` registers inert systems `trainers`, `professions`, `gathering`, `camping`, `dungeons`, `pets` with action types | scaffolding exists |
| Flight paths | `Providers/Flight.lua`: optional `DISCOVER` actions, `hereOnly`, state UNKNOWN (discovery undetectable) | exists, it IS an opportunity |

**What does not exist** (the real gap): more than one ALSO DO; a named cost class; opportunity kinds other than quest actions and flight hints; any knowledge of what the
player is doing right now; gather / trainer / profession / item-keep sources; a place to say which addons are present; urgency from level trivialisation; a decision-basis
section that reads like a sentence. That is a small list, and none of it needs a second planner.

## 2. Where the current architecture ends and the new work begins

The existing line is: providers -> `Engine.Candidates` -> `Planner.Compute` -> `PlanAdapter.ToLegacy` -> `Presenter` / `Overlap` / UI. The planner ends at "one NOW, one
ALSO DO, one THEN, reminders, diag". The new work begins **before** the planner (more optional actions, with provenance) and **after** it (a pure classification of what
the planner already computed, and a list instead of a single ALSO DO). The planner's core (stops, sequence search, `net`) is not replaced.

```
 native readers + optional adapters        (client / addon facts; each fact carries provenance)
            |
   providers (existing registry)           (turn facts into Contract actions; NEW providers: gather, trainer, item-keep ...)
            |
   Engine.Candidates                       (unchanged)
            |
   Planner.Compute  ------------------->   plan { now, alsoDo, thenAction, reminders, diag }   (core unchanged;
            |                                       NEW: extras ranked into plan.onTheWay, each with a cost class and value basis)
   Opportunity.lua (pure)                  (cost class, value basis, bundling label, activity alignment, urgency factor)
            |
   PlanAdapter / Presenter / Overlap       (ON THE WAY, WHEN YOU'RE HERE, KEEP ... presentation only)
```

Why this shape: the Contract is already the single normalized model of "a thing the player could do", with provenance, optionality and services. A separate
"Opportunity" object model would duplicate it and drift from it. So an **opportunity is an action that is optional or hub-attached, plus derived annotations**.

## 3. Opportunity data model

No new record type. An opportunity is a Contract action (`optional = true` and/or `hereOnly = true`) with a `ref.kind` and a `SERVICE` / `OBJECTIVE` / `AREA` target. Two
small additions to the contract, both optional fields:

```
action.opp = {                         -- set by the provider; FACTS only, no cost, no value
  type    = "GATHER" | "TRAIN" | "FLIGHT" | "QUEST_PICKUP" | ... (table below),
  source  = "client" | "questiedb" | "gathermate2" | "whats_training" | "observed" | "codex",   -- who said this exists
  needs   = { profession = "Mining" ... } | nil,       -- a relevance condition, UNKNOWN when it cannot be read
}
```
and, computed afterwards by the pure library (never stored on the action, which stays immutable):

```
Annotation = {
  cost    = { class = FREE | CHEAP | MODERATE | EXPENSIVE | UNKNOWN, detourSeconds, dwellSeconds, sameStop, basis },
  value   = { points, basis = { base, alignment, urgency, chain ... }, confidence },
  prov    = { class = CLIENT_PROVEN | OBSERVED | EXTERNAL_UNVERIFIED | ESTIMATED | UNKNOWN, weakest = "..." },
  tier    = ROUTE | STOP | EXTRA | CONTEXT,       -- how far it may influence planning (section 14)
  bundle  = { group = "hub:..." | "leg:..." | nil },
}
```

Opportunity types (quest actions keep their existing kinds; new kinds extend `Contract` kinds, they do not replace them):

| Type | Represents | Discovered by | Codex has it today | Optional addon | Evidence it can have | UNKNOWN means | Location | Influence |
|---|---|---|---|---|---|---|---|---|
| QUEST_TURNIN / QUEST_PICKUP / QUEST_OBJECTIVE | existing actions | quest log, `GetQuestsOnMap`, QuestieDB | yes [R] | Questie (QuestieDB bundled) | client log = PROVEN, game map point = `src=game` unverified, QuestieDB = EXTERNAL_UNVERIFIED | position unknown -> reminder | `Planner.Locate` | ROUTE (already) |
| FLIGHT_PATH | learn a flight master | ATT nodes (unverified) | yes, hint only | none | EXTERNAL_UNVERIFIED; discovery undetectable [V] | whether already known | ATT node | EXTRA (as now) |
| TRAINER | train an ability while at a trainer | trainer NPC (QuestieDB NPC flags [U]), What's Training? [U], trainer window events [U] | no (inert system) | What's Training? | location EXTERNAL_UNVERIFIED; "can learn something" needs a trainer API probe | nothing known about what is trainable | NPC position | STOP (adds value to a stop already visited), never creates one at first |
| GATHERING_NODE | a node near the route | GatherMate2 [U]; no native node API known [U] | no (inert) | GatherMate2 | EXTERNAL_UNVERIFIED location; OBSERVED when the player was seen gathering there | whether the player has the profession (profession detection is unproven) | node coordinates | EXTRA only |
| PROFESSION_PROGRESS | skill-up / profession quest alignment | profession APIs [U] (skill-line APIs not found as globals [R]) | no | none / What's Training? | UNKNOWN until a profession source is proven | the profession state | none (it modifies another opportunity's value) | CONTEXT (modifier), not an action |
| ITEM_KEEP / ITEM_USE | keep, or use, an item now in the bags | `ItemFacts`, `Gear`, `Advisor`, QuestieDB `relatedQuests`/objectives [V] | facts yes, discovery no | Bagnon/BagBrother (not needed) | client facts PROVEN, requirement links EXTERNAL_UNVERIFIED | no known use (never "worthless") | the bag (no map position) | CONTEXT |
| FUTURE_REQUIREMENT | something a later quest or recipe needs | quest log objectives (item names, not ids [R]), QuestieDB objective item ids [V] | partial | none | EXTERNAL_UNVERIFIED | the requirement is not known | none | CONTEXT |
| EXPLORATION | an area worth visiting | map data [U] | no | none | none yet | whether exploring has value | area point | CONTEXT (no value model until proven) |
| USEFUL_MOB | mobs that also count toward an objective | quest objectives; no combat log on Forever [R] | partly (objective progress diffs) | none | OBSERVED via objective count changes | which mobs | objective area | CONTEXT |
| DUNGEON | a dungeon quest or dungeon | game quest tags (proven 0.4.1 [R]), area name | partly | DungeonJournal [U] | PROVEN tag | which dungeon | area | CONTEXT (red card exists) |
| OTHER | adapter-defined | adapter | no | any | whatever it declares | | | CONTEXT by default |

Why these merges: EXPLORATION, FUTURE_REQUIREMENT and PROFESSION_PROGRESS have no reliable location or no proven data, so they cannot be priced against a route. They
are modifiers or context, and the model says so rather than pretending otherwise.

## 4. Discovery / source architecture

Providers stay the discovery mechanism (`C.RegisterProvider`). Each new source is a provider that reads **facts** (through an adapter when the source is another
addon) and emits Contract actions. A provider never scores, ranks or decides.

* **Native readers** (client APIs, already proven where marked): quest log, map points, player position, bags, equipment, item facts, events.
* **Adapters** (`Integrations.lua`, new): one small table per optional addon: `{ key, label, detect(), read(), status }`. `detect()` answers INSTALLED / ABSENT / UNKNOWN using
  an addon-loaded API that must itself be verified on Forever [U]. `read()` is guarded and returns normalized facts with `src = adapter key` and `verified = false`.
* **Observed facts** (Codex's own recording, like `EligibilityEvidence`): "the player gathered at x,y", "this trainer window opened". These are the only route to OBSERVED.
* **Conflicts and duplicates between sources**: a node reported by GatherMate2 and by observation is ONE opportunity keyed by (type, rounded position, entity id when known),
  provenance = the strongest source for existence and the weakest for position; disagreement is kept as `conflicts`, never silently resolved (same rule as the evidence layer).

## 5. Provenance / evidence model

Reuse what exists; add one mapping table, not a new system.

| Class | Meaning | Existing equivalent |
|---|---|---|
| CLIENT_PROVEN | a client API returned it in this session | `PROVEN` (ItemFacts), `src=client` |
| OBSERVED | Codex recorded it from play | `OBSERVED` (EligibilityEvidence), `observed:m6` packs |
| EXTERNAL_UNVERIFIED | another dataset or addon said so (QuestieDB, ATT, GatherMate2, game quest map point) | `verified = false` |
| ESTIMATED | Codex arithmetic (walk time from yards, assumed turn-in place) | `estimated`, `assumed` |
| UNKNOWN | nothing | `UNKNOWN`, `state = UNKNOWN` |

Rules carried through every calculation: provenance only **discounts** (`Planner.Confidence` already multiplies value by <= 1 and never raises it); an opportunity's
class is its weakest input; UNVERIFIED location + FREE cost is still shown as "unverified" and is never promoted to a route-shaping tier. A known record is not proof that
Forever behaves the same way: QuestieDB / ATT / GatherMate2 data enter as EXTERNAL_UNVERIFIED and only become OBSERVED through Codex's own recording.

## 6. Cost model

Cost is **three numbers and a class**, not one distance:

1. `detourSeconds`: the existing `interruption()` result: extra time to insert the opportunity into `player -> stop1 -> stop2 -> stop3`, i.e. the cheapest insertion point.
   This already encodes route distance, direction of travel and backtracking (a node behind the player costs the there-and-back; a node on the line costs ~0).
   Zero when the opportunity is in the same stop as an action the planner already chose. Nil (UNKNOWN) when a leg cannot be measured.
2. `dwellSeconds`: time spent doing it (already a per-kind policy constant: `dwell`).
3. `confidence`: from provenance (section 5).

Class (derived from `detourSeconds` and `sameStop`, thresholds in ONE configurable table, strategy-scoped like `BASE` / `PER_STRATEGY`):

```
FREE        sameStop, or detourSeconds <= free   (default 5 s)
CHEAP       detourSeconds <= cheap               (default half of the ALSO DO detour limit, 15 s)
MODERATE    detourSeconds <= detour              (the existing ALSO DO limit: 30 s; 20 s in "fast")
EXPENSIVE   anything above, i.e. what ALSO DO rejects today as TOO_FAR
UNKNOWN     the detour cannot be measured
```
Examples: a node 15 yd off the path ~ 4 s -> FREE; a trainer in the next quest hub = same stop -> FREE; a node 400 yd behind ~ 114 s -> EXPENSIVE; a trainer across the zone
-> EXPENSIVE. "Fast" has a smaller `detour`, so its MODERATE ceiling is lower with no new code. The names are kept because they match how the planner already
rejects (`TOO_FAR`), but the class is a label for presentation and diagnostics; the planner continues to use net value.

Not new: `chooseAlsoDo` already requires `cost <= par.detour` and `net >= par.alsoFloor`. The class simply names the bands inside that existing window and gives
diagnostics a word for what was rejected.

## 7. Value model

Value stays **policy points** in the planner's own units: `net = value - lambda * (detour + dwell)` with lambda = 0.30 points per second (0.45 in "fast"). What a point
means: 1 point is the value of lambda^-1 ~ 3.3 seconds of the player's time. So a 20-point action is "worth about a minute of walking". It is not XP, not gold and not a
claim of precision. New kinds get **tiers**, not decimals, in one table next to `BASE.value`:

```
trivial 3   small 8   medium 20   large 40      (policy; tunable; strategy-scoped like the rest)
```
Contextual adjustments are multiplicative and bounded, each recorded in `value.basis` so the decision can be explained:

* confidence <= 1 (provenance; never raises)
* activity alignment 1.0 .. 1.5 (section 11), only when the activity is a proven signal
* urgency 1.0 .. 1.5 (section 8), only from proven facts
* a modifier from another opportunity (a profession quest whose materials are on the route raises that quest's value; it does not add a stop)

Value drivers from the brief, and where each already is or would be: quest completion and chains (exists: `value`, `chainValue`), pinned (exists), slot pressure (exists as a
rule), travel saved and batching (exist as the cost model), flight path (`DISCOVER` 3 points; remains a hint), trainer / gather / keep (new tiers), future requirements
and profession progress (modifiers), reward value (comes from the Reward Advisor's facts, not from a score: not wired in at first).

## 8. Urgency model

Today: level fit and `maxGap` only. The new factor is deliberately small:

* `urgency(a)` = 1.0 by default. It exceeds 1.0 only from a **proven** reason: the quest's level, the character's level and a *proven* trivial-level rule. On Forever the
  trivial threshold is **unproven** (UNKNOWN), so urgency stays neutral until a source exists (a client API, or recorded observations of when a quest turns gray, which the
  evidence layer pattern already supports). Nothing assumes Classic's rule.
* It multiplies value (bounded, e.g. <= 1.5) and therefore competes with travel cost like everything else; it is never a "do this before it goes gray" rule.
* Profession-training urgency is the same mechanism: an approaching profession quest raises a trainer opportunity's value only if both facts are proven.
Why: urgency without proven inputs would be an invented rule, which the project forbids.

## 9. Local hub reasoning

The planner already treats a stop as one trip with summed value and dwell, so "a productive hub" is mostly already a result. The missing piece is **naming it** and letting
services join: add `hubRadius` (a parameter larger than `STOP_RADIUS`, e.g. 120 yd) so a trainer, flight master or vendor within the hub radius of a chosen stop
becomes a same-hub opportunity (cost FREE/CHEAP because the player is already there). A **hub summary** is derived, pure, from the chosen first stop: counts by kind, the
services present, summed value, summed dwell, and `netIfStopped`. "Productive stop" = the first stop's `net` is above the floor and it holds two or more distinct kinds. This is
spatial and action-based, not "more quests = better": a hub of five trivial pickups still scores low if their values are low.

## 10. Bundling

Replace the single `alsoDo` by an ordered list, keeping `alsoDo` as the first element for compatibility.

* `onTheWay` = extras accepted greedily in net order, **recomputing the interruption cost after each insertion** (inserting one changes the cost of the next), capped at 3.
* Group by place: same stop -> "WHEN YOU'RE HERE"; along a leg between stops -> "ON THE WAY".
* Anything EXPENSIVE or UNKNOWN stays out; it can appear as OPTIONAL context only if the player enabled that system.
* It never exceeds the existing detour budget in total, so four small things cannot add up to a long detour. Why: the player must not get four separate instructions.

## 11. Player activity alignment

Activity is a **pure function over recent telemetry**, evaluated when the plan is made (no polling):

```
Activity = { kind = TRAVELLING | FIGHTING | WORKING_OBJECTIVE(quest) | LOOTING | IDLE | UNKNOWN, since, evidence = event names }
```
What can be observed on Forever today:

| Signal | Status |
|---|---|
| Movement segments (`PLAYER_MOVE`) | PROVEN [R] |
| Combat start / end (`PLAYER_REGEN_DISABLED / ENABLED`) | registered; real reports show recorded events (`rec > 0`) so they fire, though the static table still labels them UNPROVEN [R] |
| Objective progress (quest-log diff) | PROVEN [R]: this is the reliable "you are working on quest X" signal and needs no combat log |
| XP gain, bag changes (`BAG_UPDATE_DELAYED`), loot | XP events recorded [R]; bag event fires [R] |
| Kill credit by name / mob id | NOT available: `COMBAT_LOG_EVENT_UNFILTERED` is blocked on Forever [R] |
| Gathering / fishing spell casts (`UNIT_SPELLCAST_*`, loot window) | UNPROBED [U]: must be checked once |
| Profession knowledge | skill-line functions not found as global or namespace names [R]; another API UNPROBED [U] |

Alignment only multiplies the value of an already-existing opportunity (e.g. objective progress in the last minutes raises "kill more of these" and the same-area
pickup) and chooses wording ("You're already fighting here: these also count for X"). It never creates a route and never reorders NOW. Unknown activity = neutral.

## 12. Item and future-requirement opportunities

Facts exist; discovery and classification do not. `ItemSource` (derived, EXTERNAL_UNVERIFIED unless the client says otherwise):

```
ALWAYS_AVAILABLE   a vendor sells it or common mobs drop it (QuestieDB: `vendors`, `npcDrops`, `objectDrops` [V])
QUEST_GATED        its only known source is a quest objective (QuestieDB objectives / `relatedQuests` [V])
VENDOR             sold by a vendor
PROFESSION_GATED   a profession produces it (no data source yet: UNKNOWN)
UNKNOWN            nothing known (the default; never "worthless")
```
Output is ITEM_KEEP / ITEM_USE as **context only**, with the wording rule from the brief: a common, tradable item may be "KEEP: used by a later quest" if the player has one;
nothing ever says "go farm this". A quest-gated drop is flagged because it cannot be bought later. These come from combining `Items.Facts`, `Gear`, the quest log's objective
text and QuestieDB; no new database.

## 13. Optional addon integration architecture

`Integrations.lua` is a registry of adapters plus a status report:

```
INTEGRATIONS
 + QuestieDB: bundled (runtime, 1.0.4)           + Client quest APIs: available
 o Questie / GatherMate2 / What's Training? / BagBrother: not detected     o DBM, GTFO: not supported by Codex
```
Rules: Codex works with none of them; native APIs are preferred; an adapter returns normalized facts with provenance and never writes into another addon; no data is copied
into the repo. What must be verified [U], addon by addon, with the addon installed on a real client: how to detect it (`IsAddOnLoaded` / `C_AddOns` form), whether it exposes
a read API or only SavedVariables, and its license for any use beyond reading at runtime. Likely shapes (unverified): GatherMate2 node databases (position lists by node type),
What's Training? (no documented API known), BagBrother (SavedVariables, only for other characters; not needed for the current one), DungeonJournal (unknown). Questie itself
beyond QuestieDB is internal and is not a target. Titan Panel and BlizzThreatPlates have no opportunity value and are listed only as "not supported".

## 14. Planner integration (one planner)

Minimal, staged, behind a flag (`Pl.OPPORTUNITIES`, default off until validated, so existing behaviour and the golden baselines are untouched):

1. **Tiers decide how far an opportunity may influence planning**:
   * ROUTE: quest actions, as today (stop-forming `items`).
   * STOP: a service/opportunity whose provenance is at least OBSERVED or CLIENT_PROVEN and that sits within `hubRadius` of an already-chosen stop adds its value to that stop
     (it never creates a new stop).
   * EXTRA: everything optional goes through the extras pool and `chooseAlsoDo`'s interruption/net test, producing `plan.onTheWay`.
   * CONTEXT: never planned; surfaced only.
   New external-data opportunities start as EXTRA at most. Promotion to STOP requires evidence, so unverified data can never bend the route.
2. `valueOf` gets the new kinds' tiers and bounded modifiers (confidence, alignment, urgency): additions to the existing function, the same `lam`, the same units.
3. `chooseAlsoDo` becomes `chooseOnTheWay` (a loop with re-costing); `plan.alsoDo` is kept as the first entry; `plan.onTheWay` is new.
4. `diag.opportunities` records each candidate with cost class, value basis, provenance and the reason code for acceptance or rejection (the existing `rejected` list, extended).
5. Conflicts: two extras at one place or from two sources collapse by the key in section 4; between conflicting opportunities the higher net wins and the other is listed as `conflict`.
Why not a separate planner: extras already share lambda, the interruption function and the reason-code pipeline with the main plan; two planners would disagree on units.

## 15. Player agency and presentation

* Channels, from most to least directive: **NOW** (one), **ALSO DO / WHEN YOU'RE HERE** (same stop, one line each), **ON THE WAY** (at most 3, FREE/CHEAP), **OPTIONAL**
  (context, only when a system is enabled), **KEEP** (items), **DEFERRED / LATER** (what already exists as READY TO TURN IN and reminders).
* Language is factual, never scolding. Nothing re-plans around the player's own detours: the plan recomputes from where they are, so fishing or exploring just changes the inputs;
  stickiness stops flicker. Opportunity systems are opt-in through the existing per-system toggles (`gathering`, `trainers`, `professions`), off or inert by default.
* Compact by design: one `ON THE WAY` card of up to three lines replaces separate cards; `Overlap` ("ALSO COMPLETE THIS") becomes one source of that list rather than a parallel channel.

## 16. Pure logic versus client integration

Pure (stub-testable, no client): cost class from seconds, value basis and tiers, bundling and re-costing, hub summary, urgency factor, activity inference from an event list,
alignment multiplier, provenance combination, conflict and duplicate merging, tier / promotion rules, planner integration decisions (the planner already has a deterministic
stub harness: `planner_eval.lua`).

Client-dependent: player position, quest log, bags, equipment (all proven), trainer / taxi / profession detection (unproven), addon detection and reads, spell-cast and loot
events (unprobed), observed interactions. All through guarded readers like `Context.reader` and `ItemProbe`, event-driven only (no per-frame work; the existing 1 Hz
telemetry tick remains the only timer).

## 17. Test strategy

The existing planner harness is extended with opportunity scenarios (a new list appended to `planner_eval.lua`, assertions only for the deterministic ones; the Phase 2.5
baseline stays byte-identical because new kinds are off by default):

* cost class: FREE (same stop; 5 s), CHEAP, MODERATE, EXPENSIVE (400 yd behind), UNKNOWN (unmeasurable leg)
* same-stop bundling; route-aligned (on the line) vs behind-player; local hub clustering; several small opportunities that together make a hub worth stopping at; a low-value
  long detour that stays out
* urgency neutral when the trivial rule is unproven; urgency raised only with a proven rule; future requirement shown only as context
* provenance: UNKNOWN provenance, UNVERIFIED location never promoted past EXTRA; weakest-link rule; confidence never raises value
* adapters: addon unavailable (status ABSENT, no output) and available (fake adapter, facts normalized, provenance `verified=false`)
* activity: aligned (objective progress recently) vs unknown (neutral); alignment cannot create a route
* an opportunity that does change the route (STOP tier with OBSERVED provenance) vs one that is only context
* conflicts between opportunities and duplicates from two sources (merge key, strongest existence / weakest position)
* regression: with `Pl.OPPORTUNITIES` off, every existing test and the golden baseline pass unchanged.

## 18. Minimal real-client validation

Existing evidence already covers position, quest log, bags, equipment, item facts, reward dialogs, events and `C_Item.IsUsableItem`. The smallest set of new checks, each done by
**passive capture during normal play** and reported in a compact capability section (the ITEM PROBE pattern), nothing to grind:

1. Which addon-detection API exists on Forever, and whether `IsAddOnLoaded`-style calls answer for an installed addon.
2. Trainer window events and the trainer-service API (opened by the player naturally).
3. `UNIT_SPELLCAST_*` and `LOOT_OPENED` firing for gathering and fishing (only when the player happens to gather).
4. A profession-state API (skill lines are not found as globals; look for a namespace or spellbook form).
5. With GatherMate2 / What's Training? installed: whether a read API exists, or only SavedVariables.
Anything not seen simply stays UNKNOWN. No level target is required.

## 19. Staged implementation plan

1. **Integrations + capability probes** (read-only): `Integrations.lua`, the `INTEGRATIONS` and capability report lines, activity events registered as unproven telemetry. No behaviour.
2. **Pure library**: `Opportunity.lua` (cost class, value basis, bundling, hub summary, urgency, alignment, merging) with its tests, not wired in.
3. **Planner annotation only**: `diag.opportunities` and cost classes on the existing ALSO DO / extras (flight hints), flag still off, zero behaviour change.
4. **On the way**: `chooseOnTheWay` and `plan.onTheWay`; presentation of up to three lines; `Overlap` becomes a source of the list.
5. **First new source** behind its system toggle: whichever is proven first (likely the trainer or gathering service at an already-visited hub), as EXTRA, then STOP when observed.
6. **Items**: ITEM_KEEP / FUTURE_REQUIREMENT context from existing facts.
7. **Report reorganisation** into the sections in the brief, with DECISION BASIS built from `diag.reasons` and `diag.opportunities`.
Each stage is a normal release with its own tests, and stage 3 onward only changes behaviour when the flag is on.

## 20. Risks and unresolved questions

* **Two scoring worlds**: avoided only if every new kind uses `lam`, `BASE`-style tiers and the same interruption function. Review any stage that adds a second formula.
* **Nagging / flicker**: capped list, stickiness, and the per-system opt-in. Needs real play to tune the caps.
* **Unverified external locations** (GatherMate2, ATT) steering the route: prevented by the tier rules; the open question is what counts as enough OBSERVED evidence for promotion.
* **Profession detection is unproven**: without it, gathering and training relevance is UNKNOWN. Decision needed: show nothing, or show "if you have <profession>".
* **Trivial-level rule on Forever is unproven**: urgency stays neutral; open question whether to record observations of quest colours (a client API for it is unprobed).
* **Value tiers are policy**: they will be tuned from playtests; the design keeps them in one table and prints the basis.
* **Performance**: extras are not in the beam; cost is extras x nodes per recompute (cheap), but recomputes are frequent, so `onTheWay` must be limited to the first N extras by solo net.
* **Addon licenses and APIs** are unchecked; nothing is copied, and each adapter needs a license check before it ships.
* **Overlap duplication**: `Overlap` and `onTheWay` must merge in stage 4 or the window will show two lists.
* Open question for you: should opportunities ever appear for systems the player has not enabled (a hub summary that mentions a trainer), or strictly only when enabled?

## 21. Files and modules expected to be involved

New: `Opportunity.lua` (pure library), `Integrations.lua` (adapter registry and status), `Activity.lua` (pure activity inference), `Providers/Gather.lua`, `Providers/Trainer.lua`,
`Providers/ItemKeep.lua` (each registered like `Providers/Flight.lua`), tests `opportunity_tests.lua`, `integrations_tests.lua`, and additions to `planner_eval.lua`.
Modified: `Planner.lua` (extras pool, `chooseOnTheWay`, `valueOf` tiers and modifiers, `diag.opportunities`), `Contract.lua` (the optional `opp` field and new kinds, additive),
`PlanAdapter.lua`, `Presenter.lua`, `UI/PageCodex.lua` (ON THE WAY card), `Overlap.lua` (becomes a source), `Telemetry.lua` (activity events registered unproven),
`Diag.lua` (OPPORTUNITIES, INTEGRATIONS, DECISION BASIS), `Providers/Planned.lua` (planned systems become real as sources land), `Strategies.lua` (per-strategy cost bands).

## 22. What I recommend NOT changing, and why

* The planner core (`gather -> makeStops -> rankStops -> searchSequences -> chooseAlsoDo`) and its constants: it is validated on the real client and by the Phase 2.5 baseline; the new work attaches to its existing seams.
* The Contract's immutability and provenance rule: every opportunity should reuse them; annotations are computed, not stored on actions.
* Reward Advisor, Eligibility and EligibilityEvidence: they are fact and classification layers; opportunities may read their output but not alter it.
* `Overlap` semantics in the first stages: merge it later, not first, so the window does not change under the player's feet.
* QuestieDB and ATT handling: they stay EXTERNAL_UNVERIFIED; no promotion to OBSERVED without Codex's own recording.
* No new database and no copied addon data: everything new is derived from facts that already exist or from adapters read at runtime.
