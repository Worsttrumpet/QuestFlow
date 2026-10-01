# Forever Codex: planning model (design checkpoint)

**Status: design / documentation only.** Nothing in this document is implemented. It records what the first real-client
playtest taught us and defines the planning model we want to build toward. No code, data, UI, test, telemetry or
behaviour was changed to produce it.

Sources: a real-client playtest of Forever Codex 0.1 "First Light" with a fresh level 1 Orc Warrior in Durotar, played
naturally from level 1 to level 5 (reported by the player; Codex telemetry was not used as evidence here), plus
inspection of the code and data as committed at `a47c275`. Where this document states a fact about the code or data it
was read from the repository; where it states a playtest observation it is attributed to the playtest; where something
is a design intent it says so. Nothing is invented beyond that.

---

## 1. Executive summary

Codex 0.1 answers **"what is the next action?"** It ranks single actions, then chains them greedily by distance. The
playtest showed that a player does not think that way. A player thinks in **short sequences**: "I'll do this while I'm
here, then that, then I'll leave." They batch objectives that share an area, delay turn-ins until the local work is
done, treat travel itself as productive, and use shortcuts (including an intentional death) to save a long run.

The behaviour we want is:

> From this character's *actual current state and location*, what is the best **short sequence of useful actions**,
> and which of them are worth doing **now, while I'm here**, versus **later**?

Conclusions (detailed below):

1. The planning unit becomes a **short local sequence** with three roles: **NOW**, **ALSO DO**, **THEN**.
2. "Nearby" is not enough. An opportunistic action must be worth the **cost of interrupting** the current work; the
   planner optimizes *useful sequences*, not the *number* of actions.
3. A completed quest does **not** imply "turn it in now". Turn-in timing is a decision.
4. The quest **giver and turn-in NPCs are different** and the data model must be able to say so (today it cannot).
5. Quest identity is the **quest ID plus state**, never the name (the playtest saw consecutive same-name quests, and
   the data already shows name/capitalisation hazards).
6. One underlying action/data model, **no per-strategy route databases**. Strategies change weighting and selection.
7. Observed Forever evidence stays distinguishable from ATT/inferred data; **unknown stays unknown**.
8. The player stays in control. Codex recommends; it recomputes from observed state and never assumes the player
   followed it.
9. The right place for the sequence planner is a **separate module on top of the existing action candidates**, not a
   growth of `Engine.lua` (section 16 and the closing recommendation).

---

## 2. Current model

What exists today (all of it committed and covered by the stub tests):

* **Context** (`Context.lua`): a read-only snapshot per recompute: character (name, level, class, race, faction), location
  (map, position, zone, subzone, world coordinates), quest log with per-quest `complete`, `IsQuestFlaggedCompleted`,
  group size. It does **not** read inventory, money, bags, death/ghost state or trainer availability.
* **Providers** (`Providers/Quest.lua`, `Flight.lua`, `Planned.lua`): turn data plus quest log into *actions*:
  `ACCEPT` (not in log, eligible), `OBJECTIVE` (in log, incomplete), `TURN_IN` (in log, complete). A quest's single
  location is its giver's. Planned systems are registered but inert.
* **Engine** (`Engine.lua`): `Compute(ctx)` collects provider actions, filters (faction, race, class, required level,
  prerequisites, completed, skipped, repeatable, style), computes a **static score** per action
  (`Strategies.lua` weights: `TURN_IN 100`, `OBJECTIVE 70`, `ACCEPT 40`, level fit, a coarse accept-hub bonus) and a
  **distance penalty** (capped at 60 points), then builds a **greedy chain** of up to 8 stops from the character's
  position, inserting a `TRAVEL` step when a stop is 150 yards or more away. It also lists proximity hits ("while
  you're here", within a radius) and an "in progress, location unknown" list.
* **Strategies** (`Strategies.lua`): route styles are scoring weights over the same actions (no per-style data).
* **Player choices** (`Preferences.lua`): route zone, style, system toggles, skips, added quests, hardcore. (There is
  no `Overrides.lua`; the override functions live in `Preferences.lua`.)
* **Route / evaluators** (`Route.lua`, `ProgressionEval.lua` copied from M8.13): adapt an action to the M8.13 step
  schema and describe live status (WAITING / SATISFIED / UNDETECTABLE). The M8.13 `Progression.lua` pointer machine was
  deliberately **not** copied: the plan is recomputed from world state instead.
* **UI** (`UI/Window.lua`): one **NEXT** card, a **Coming up** list (the greedy chain), a **While you're here** list
  (proximity), an in-progress line, Show on Map / Skip / Add, pickers, system toggles.
* **Navigation** (`MapPin.lua` copied from M8.13): places one game waypoint when the player clicks Show on Map.
* **Telemetry** (`Telemetry.lua`, `TelemetryMetrics.lua`): observation-only log (XP, kills, level-ups, quest events,
  movement segments, combat). It is independent of the engine and nothing reads it yet.
* **Data** (generated packs): ATT-derived quest records (`src=att`, `verified=false`) and the 96 observed quests
  (`src=observed`, `verified=true`), merged field by field at read time (observed first).

The model is **per-action ranking plus a greedy distance chain**. It has no notion of a sequence as a unit, of shared
physical destinations, of deferring a completed quest, or of what a completion unlocks.

---

## 3. Observed real-client behaviour (from the playtest)

Attributed to the player's report. Numbered to match the playtest notes.

1. **Starting/origin priority.** At spawn the character faced Kaltunk, who gives *Your Place in the World*. Codex
   initially preferred a nearby level-fitting quest over that immediate starting action.
   *Code/data note (read from the repo, not from the playtest):* the data does contain it, as ATT quest `4641`
   ("Your Place In The World", giver Kaltunk, Durotar 43.2, 68.4), but ATT flags it `breadcrumb = true`, and the
   engine applies a small breadcrumb **penalty** (`breadcrumb = -5`). There is no concept of an origin/start action.
   Note also the name casing differs from the client's ("In The World" vs "in the World").
2. **Giver and turn-in NPCs differ.** Kaltunk gives *Your Place in the World*; Gomek turns it in and gives *Wayward
   Weapons* and *Cutting Teeth*; Kzan Thornslash turns in *Wayward Weapons*; Gornek gives *Simple Parchment* and *Sting
   of the Scorpid*; Frang (Warrior trainer) turns in *Simple Parchment*.
   *Code/data note:* the quest provider **assumes the turn-in is at the giver** and says so on the card
   ("Turn-in location is assumed to be the giver's"). The observed pack's `giver` is also role-ambiguous (a known M4
   limitation: `giver.npc` does not distinguish offering from turning in); e.g. observed *Wayward Weapons* (id 97279)
   lists Kzan Thornslash as `giver`, who the player reports is the turn-in NPC.
3. **Same-name quest chain.** *Simple Parchment* appeared as consecutive separate quests of the same name. Identity
   must be quest ID and state. *Code/data note:* actions are keyed by quest ID (`Q:<id>:<KIND>`), so identity is already
   ID-based; the data holds one *Simple Parchment* (id 2383), so the second one the player received is not in the data.
4. **Batching while travelling.** On the way toward Hanazua/Sarkoth the player killed mobs, progressed *Cutting Teeth*,
   completed *Wayward Weapons* and reached level 2. Travel itself was productive; the player did not stop to do each
   objective in isolation.
5. **Local quest density.** After accepting *Lazy Peons* Codex suggested a ~375 yard trip to Innkeeper Grosk. The
   player would not make that trip then; they would do *Lazy Peons*, *Cactus Apples*, *Vile Familiars*, *Scorpid Worker
   Tails* and other nearby objectives, then leave once the local work was exhausted.
   *(The data holds *A Peon's Burden*, id 2161, whose giver is Innkeeper Grosk in Razor Hill; the suggestion is
   consistent with that stop. The playtest log was not inspected to confirm.)*
6. **Delayed turn-ins.** After completing *Cactus Apples* Codex recommended returning to Galgar immediately. The player
   deliberately stayed, did *Scorpid Worker Tails* and *Vile Familiars*, and returned later for turn-ins.
   *Code note:* a completed quest becomes a `TURN_IN` action with base score 100, the highest in the table, and the
   distance penalty is capped at 60, so a completed quest outranks almost any nearby work.
7. **Quest-chain lookahead.** The player prioritised *Lazy Peons* because they remembered it leads into useful
   follow-up. *Data note:* ATT prerequisite edges carry exactly this kind of chain: `5441 Lazy Peons -> 6394 Thazz'ril's
   Pick`, `788 Cutting Teeth -> 789 Sting of the Scorpid / 2383 Simple Parchment`, `792 Vile Familiars -> 794 Burning
   Blade Medallion -> 805 Report to Sen'jin Village`. Today these edges are used only to *hide* a quest until its
   prerequisite is done, never to look ahead.
8. **Cave/objective batching.** The player accepted *Thazz'ril's Pick* but deliberately did not complete the Pick yet,
   because other useful objectives were in the same cave. Intended: accept Pick, do *Burning Blade Medallion* and other
   cave work, complete Pick while inside, use the death shortcut, respawn near the turn-ins. Codex modelled it as accept
   Pick, travel to the objective area, turn in Pick.
9. **Intentional death as a travel shortcut.** The player died on purpose in the cave to respawn near the turn-ins, from
   about 543 yards away from Foreman Thazz'ril; earlier the same idea saved roughly 350+ yards. Death was a valid travel
   tool in that context.
10. **Trainer / class progression.** The player repeatedly thought "I'm already here, check the Warrior trainer." At
    level 2, Rank 1 Battle Shout cost 10 copper and the player could afford it after hypothetical vending. They later
    realised they had missed training at level 4 and at level 5 again wanted to check the trainer before leaving.
    The playtest suggests Forever may add class abilities every two levels; this is an **observed pattern to confirm**,
    not a rule.
11. **Vendor opportunities.** After jumping down a mountain the player noticed they had passed very close to a vendor,
    had not sold junk, and so lacked the copper to train: "I should have vendored when I was already there."
12. **Objective locations.** *Thazz'ril's Pick* is physically at **43.7, 53.8** (the player stood on it). The UI only said
    "Travel to objective area" and did not convey that it is inside the cave. The map pin itself worked.
13. **Locations unknown.** The grey in-progress diagnostic line showed quests with unknown locations, including *Sting
    of the Scorpid* and *Vile Familiars*. The player supplied observed coordinates: scorpids **46.5, 58.4**; Vile
    Familiars outside the cave **45.3, 56.8**. These are observed Forever coordinates (evidence, not inference) and are
    **not** added to any data by this document.
14. **Quest missing from the data.** *The Adventurer*, a journal on a barrel at **42.8, 69.2**, was not known to Codex
    and was accepted by the player. Codex still correctly showed "Report to Sen'jin Village" as primary progression.
    *Data note:* same-named records exist (ATT `96627` for Elwynn, `96628` for Dun Morogh, observed `96652` with giver
    Brakk), none is known to be this barrel journal. It is also **not** added to any data by this document.
15. **Level-ups.** The character reached levels 2, 4 and 5. At level 4 Codex's NEXT did not change, which was not wrong
    because the existing action stayed valid. Level-ups still create new opportunities (training, newly available
    quests, level-gated content, different route efficiency). Telemetry is designed to record `LEVEL_UP`.
16. **Waypoint lifecycle bug.** Show on Map worked, but after *Thazz'ril's Pick* was completed the old waypoint stayed
    until the player removed it by hand. See section 15.

---

## 4. Proposed short-sequence planning model

The planner's job changes from "rank actions, take the top" to "choose a short sequence".

* **Input**: the same candidate actions the engine already builds from the same data (no second database), plus
  character state, location, quest log, and later vendor/trainer/inventory/currency state.
* **Output**: a small structured plan: one **NOW**, a short **ALSO DO** set tied to NOW's physical context, and a
  **THEN** outlook. Each element carries its reasons and its provenance.
* **Objective**: the fastest *reasonable* progression sequence for the character's current state, valuing useful work
  completed per unit of time (travel included), not the number of actions.
* **Horizon**: short. A handful of steps and one level of lookahead (section 9), recomputed whenever state changes.
* **Statelessness**: the plan is a function of observed state (as today). It is recomputed, never "advanced".

## 5. NOW / ALSO DO / THEN

A planning model first and a UI concept second.

| Role | Meaning |
|---|---|
| **NOW** | The primary action Codex currently recommends. |
| **ALSO DO** | Useful actions that make sense *because* the player is already nearby, travelling through, or positioned to do them, **and** whose cost of interrupting NOW is low. |
| **THEN** | What Codex expects to make sense after the current local sequence is done (e.g. the return trip for turn-ins). |

Example from the playtest:

```
NOW:      Finish Scorpid Worker Tails
ALSO DO:  Finish Vile Familiars
          Finish Cactus Apples
THEN:     Return for turn-ins
```

This is preferable to `NEXT: Turn in Cactus Apples` when doing that immediately causes unnecessary travel.

Relation to today's UI: **NEXT** corresponds to NOW; **While you're here** (proximity list) corresponds loosely to ALSO
DO but is *not* tied to NOW or to interruption cost; **Coming up** (the greedy chain) corresponds loosely to THEN but
may already contain turn-ins early. The mapping is partial, which is the point of section 16.

## 6. Opportunistic action model

Design principles (not implementation requirements yet). An action is a good **opportunistic** action when:

1. It needs little or no additional travel.
2. It is already on the player's route.
3. It shares an objective area, cave, NPC or destination with the current work.
4. Doing it now avoids a future trip through the same area.
5. It unlocks useful follow-up content.
6. It is a useful class, trainer, vendor, flight or other progression action naturally available nearby.
7. It is a useful quest the player can pick up while already at the NPC.
8. It is worth doing given the player's level, inventory, currency or other context.

And, equally important:

* **Do not assume every nearby action should be recommended.** A nearby mob is not automatically worth killing; a quest
  400 yards away is not automatically worth a detour; a turn-in is not automatically worth doing immediately if a nearby
  objective can be finished before the return trip.
* The planner must weigh the **cost of interrupting** the current route against the value gained. Value is *useful
  progression*, not count of actions.
* "Nearby" is a *feature* of the decision, not the decision. Distance alone (today's "while you're here" radius) is
  insufficient.

Conceptually, each candidate gets an **opportunity assessment** relative to NOW: added travel, shared physical
destination, avoided future trip, unlocks, state-dependence (level, money, inventory), and a verdict
(include / mention / ignore). The player can always override.

## 7. Local quest density

Observed: the player works a **local quest cluster** to exhaustion and then leaves, rather than hopping to the next
single best action (observations 5, 6, 8).

* A cluster is a group of actions that share an area or destination (an NPC hub, an objective area, a cave).
* Today the engine has only a coarse **accept-hub bonus** (a 40 x 40 map grid, `cluster` weight, ACCEPT actions only).
  It does not model objective areas, does not cluster OBJECTIVE/TURN_IN actions, and does not treat "finish the cluster,
  then leave" as a goal.
* Desired: recognise that finishing several objectives in one area before leaving beats a series of single hops, and
  order the cluster's work so the departure trip is taken once.

## 8. Batching and delayed turn-ins

* A **completed quest is not an instruction to turn in immediately.** It is a *ready* action whose best timing depends on
  what else can be done first (observation 6).
* The planner should compare **the cost of a turn-in trip now** with **the useful work that can be completed first**
  and the **return trip later** (often the same trip, taken once).
* **Travel is productive** (observation 4): objectives completed on the way count toward the sequence and need not be
  scheduled as separate stops.
* **Shared physical destinations** (observation 8): several quests whose objectives are in the same place should be
  planned as one visit. Today an action has a single `target`, so *Accept Pick -> Travel to objective area -> Turn in
  Pick* is the only shape it can express.
* Turn-in value does not vanish when deferred. The planner should still surface it (THEN), so it is not forgotten.

## 9. Lookahead

Short-horizon lookahead, documented as a requirement, **not implemented**:

```
current action -> completion -> newly unlocked action -> how that follow-up fits the upcoming route
```

* Observation 7: the player chose *Lazy Peons* partly because it leads on to useful follow-up (*Thazz'ril's Pick*).
* The data already contains the necessary edges (ATT prerequisite relations). Using them forward ("what does finishing
  this unlock, and is the unlocked action near my route?") is new; today they are only used to hide quests.
* Limits to respect: ATT prerequisites are unverified for Forever, treated ANY-OF when several are listed, and Forever
  has quests ATT does not know (observation 14). Lookahead must degrade to "unknown" gracefully, never guess.
* Horizon stays short: one unlock step, weighed against the local sequence, not a full-route optimizer.

## 10. Travel optimization

* Observed: travel has structure the engine does not see (observation 9): at ~543 yards the player chose *complete
  nearby cave work -> die intentionally -> respawn at the graveyard -> turn in* over a run; the same idea earlier saved
  roughly 350+ yards.
* Design principle: **death is not inherently bad.** In some contexts an intentional death is a valid travel shortcut.
  It must remain a **player-chosen, non-Hardcore** option. The existing Hardcore toggle already removes
  `RESPAWN_SKIP` actions in the engine; that guarantee must be preserved.
* **Do not implement yet, and do not recommend automatically yet.** A trustworthy recommendation needs *observed*
  evidence that does not exist yet: where graveyards are, respawn locations, and real travel and respawn timing for the
  situation. The current telemetry does not record death or respawn, and a graveyard respawn would currently register
  only as an anomalous position jump, not as a measured shortcut.
* Other known shortcuts (flight paths, hearthstone) belong to the same future travel-cost model; their data and timing
  are not available either (flight data is ATT-derived and discovery status is unknown to Codex).

## 11. Class / trainer / vendor opportunities

Observations 10 and 11 describe a family of opportunities that are **not quests**:

* **Class progression**: trainer nearby, new abilities potentially available, level appropriate, enough currency, and
  training naturally on the route. Desired surfacing: `ALSO DO: Warrior Trainer - new training may be available`.
  The player must never be forced to train.
* **Vendor**: nearby vendor, sellable items in inventory, selling may *enable* another useful action (e.g. training),
  vendor naturally along the route.
* Preconditions are state Codex does not read today: **inventory, money, trainer/vendor locations, known abilities**.
  `TRAINER`, `PROFESSION`, `CLASS_PROGRESSION` exist as registered, inert, greyed-out systems; no vendor type exists yet.
* **Do not hard-code "every two levels" as a Forever rule.** It is an observed pattern requiring confirmation.
* Level-up is the natural trigger for re-evaluating these (observation 15): the planner should react to
  **character-state changes**, not only quest-state changes.

## 12. Player agency

Codex is a companion, not a railroad. The player may skip quests, accept unexpected quests (observation 14), turn things
in out of order, grind, wander, die, take shortcuts, ignore recommendations, install Codex at a higher level, or have
partial quest chains already completed.

* Codex must **recompute from observed character state** (quest log, completion flags, level, location) and must not
  assume "the player followed Codex, therefore everything before this is done." This is already how the engine works
  (stateless, no step pointer); the model must keep it.
* Existing controls stay central: route zone, style, system toggles, Skip, Add, Hardcore. The new roles must be
  overridable per action (skip an ALSO DO item, pin something into NOW).
* Quests unknown to the data must never be hidden or mishandled: unknown quests in the log are already shown as
  reminders; the model extends that to discovered-in-the-field quests.

## 13. Fast mode: future definition

Fast should **not** mean "follow the shortest quest route". It should eventually mean:

> Find the fastest *reasonable* progression sequence for the character's current state.

Potential future inputs (none are consumed today): actual location; quest state; objective locations; travel time;
XP/hour; observed mob XP; quest completion time; local quest density; level breakpoints; vendor/trainer opportunities;
future quest unlocks; batching opportunities; known travel shortcuts; player-specific observed behaviour.

Examples of the reasoning Fast should eventually be able to express:

* "Don't turn in Cactus Apples yet. Finish nearby Scorpid Worker Tails first."
* "You're already entering the cave. Complete the Pick while you're there."
* "You're 543 yards from the turn-in. A respawn shortcut may save travel time." (player-chosen, never Hardcore)
* "You're level 4 and a trainer is naturally along the route."

Telemetry (`TelemetryMetrics`) already defines calculators for XP/minute, downtime share and quest durations, each
labelled observed / calculated / estimated, precisely so Fast can later ask for evidence instead of assuming. **Not
implemented**, and telemetry must not make route decisions itself.

## 14. Data and provenance implications

Constraints for everything above:

* **Do not create a second hardcoded route database**, and **no separate route data per strategy**. One underlying
  action/data model; strategies change **weighting and selection**, not the world data.
* **Observed Forever data stays distinguishable** from inferred/external data. ATT is never treated as verified Forever
  data. Player-observed evidence carries provenance (who/what observed it, when, how). **Unknown stays unknown.**
* The playtest produced observed coordinates (13, 12) and an unknown quest (14). They are **evidence to be captured with
  provenance through a legitimate, deliberate evidence path**, not data to be patched in by hand. This document adds
  none of them.
* Data model gaps the playtest exposed (documentation, not a change): turn-in NPC/location separate from the giver;
  more than one location per quest (giver, turn-in, objective area, exact objective point); a location *kind* and
  *confidence* (broad area vs exact verified point vs contextual tag such as "inside a cave"); origin/start status;
  quest identity by ID with name only as a display label (names differ in casing between ATT and the client).
* Identity hazards seen in the data: one name, several IDs (*The Adventurer*: 96627, 96628, 96652); the same quest with
  different capitalisation across sources; observed role-ambiguous giver labels.

## 15. Known bugs and gaps

Kept separate from the design above. **None of these is fixed or investigated by this document.**

### 15.1 Confirmed bugs

**A. Stale waypoint after the objective completes (confirmed, playtest observation 16).**
Expected: objective completes -> stale waypoint cleared or updated. Actual: the old waypoint stays until the player
manually opens the map and removes it. *Read from the code (not a diagnosis):* Codex places a waypoint only from the
Show on Map button (`UI/Window.lua`, one call to `MapPin.Place`); `MapPin.Clear()` exists (copied from M8.13) but no
Codex module calls it, and nothing ties a waypoint to the action it was placed for. Track as a separate future fix.

**B. Protected-action error at first login (confirmed, UNRESOLVED).**
During the first real-client login with the fresh test character WoW displayed:

> "ForeverCodex has been blocked from an action only available to the Blizzard UI. You can disable this addon and
> reload the UI."

Observed: it appeared immediately on login; the player chose **Ignore** (not Disable); the character loaded normally;
movement worked; the Codex minimap button opened the Codex UI; the addon remained usable through the whole level 1 to 5
playtest; quest tracking, progression updates, recommendations and map pins continued to work. **The protected
action/API responsible has not been identified.** The source is not obvious from this document's inspection and is not
speculated about here. This is a separate startup/compatibility bug that needs a **future, targeted investigation**
(e.g. capturing which call is blocked, and when, on a clean login) before any fix. It must not be conflated with the
planning-model work.

### 15.2 Gaps relative to the playtest (not bugs in existing behaviour)

* Origin/start priority: no concept; a `breadcrumb` flag lowers a start quest's score (observation 1).
* Turn-in location is assumed to be the giver's; observed `giver` is role-ambiguous (observation 2).
* Objective locations are mostly unknown; the card says only "Travel to objective area" (the label Codex builds for an
  ATT objective coordinate), with no exact point and no context such as "inside the cave" (observation 12).
* In-progress quests with no location are only listed in grey, never sequenced (observation 13).
* Quest coverage is incomplete (observation 14); the second *Simple Parchment* is not in the data (observation 3).
* No state for inventory, money, trainer/vendor availability, death or respawn (observations 9-11).
* No lookahead and no concept of a shared physical destination (observations 7, 8).
* No reaction to character-state changes beyond re-filtering by level (observation 15).
* Telemetry does not record death or respawn; its XP/kill/combat sources are still unproven on Forever.

## 16. Architecture implications

Existing modules likely relevant. Nothing here is changed by this document.

| Module | Reusable? | Too linear / limiting today | Future role |
|---|---|---|---|
| `Context.lua` | Yes: the right place for the *observed state* snapshot | reads no inventory/money/death/trainer state | gains character-state fields; stays a pure reader |
| `Engine.lua` | Filtering, scoring, `Distance`, travel insertion are reusable | one greedy chain; per-action score cannot express "defer this turn-in because X is cheaper"; `TURN_IN` base 100 dominates; single `target` per action | keep as candidate generation + atomic scoring; sequence logic should *not* grow here |
| `Strategies.lua` | Yes: weights stay the way strategies differ | weights are per action kind, not per sequence/opportunity | gains sequence-level weighting (interrupt cost, batching, deferral) |
| Overrides (**in `Preferences.lua`**; no `Overrides.lua`) | Yes: skip/add/pin already centralised | keyed to a single action | extends to ALSO DO / pin-into-NOW |
| `Route.lua` | Step adapter + evaluators reusable | maps one action to one step | maps a plan's roles to steps; evaluators describe live status |
| `Providers/Quest.lua` | Eligibility, provenance wording reusable | turn-in = giver; one location; breadcrumb treated as a penalty | emits separate turn-in targets, area/exact/context locations, origin status |
| Travel (**derived inside `Engine.lua`**; no `Providers/Travel.lua`) | the 150 yd TRAVEL insertion | cost-blind, one hop at a time | becomes an explicit travel-cost model (walk, shortcut, flight, respawn) |
| `Providers/Flight.lua` | Yes | hints only, discovery unknown | feeds the travel-cost model |
| `Providers/Planned.lua` | Yes: the inert registry is the extension seam | `TRAINER`, `CLASS_PROGRESSION`, `RESPAWN_SKIP` exist; **no vendor type** | real providers replace the inert entries |
| `Telemetry.lua`, `TelemetryMetrics.lua` | Independent evidence source for later | no death/respawn; XP/kill/combat unproven | later supplies measured rates and travel/respawn times; **stays decision-free** |
| `UI/Window.lua` | widgets, provenance wording | NEXT / Coming up / While you're here are hard-wired; (no `NextCard.lua`; the card is inside `Window.lua`) | renders NOW / ALSO DO / THEN from a plan structure |
| `Data/Zones.lua` | n/a: **does not exist**; zones are derived from pack metadata | | unchanged |
| Generated quest data | reusable | location/turn-in/identity gaps (section 14) | more observed packs, evidence-backed |
| `ProgressionEval.lua`, `MapPin.lua` (M8.13 bridge) | evaluators and the proven pin path | waypoint never cleared; not linked to the action it serves | waypoint lifecycle tied to the plan |

**Where a short-sequence planner could fit:** between the providers' candidate actions (the engine's collect/filter/score
stages) and the UI. It consumes candidates and character state and produces a structured plan; it does not generate
candidates and it does not render.

**What should remain independent:** Telemetry (observation only), the data generator and packs (provenance), Context
(pure reader), MapPin (navigation), the UI (renders a plan, holds no logic), strategies as data (weights, not routes).

**What should NOT be coupled:** the planner to the UI; telemetry to any decision; strategies to world data; observed to
ATT data; the waypoint lifecycle to ad-hoc UI clicks; death/respawn recommendations to Hardcore characters.

No giant rewrite is proposed. The existing candidate generation, filtering, distance and provenance code is the
foundation.

## 17. Explicit non-goals for the next implementation phase

* No optimizer for Fast mode and no use of telemetry in decisions.
* No automatic recommendation of intentional death or respawn shortcuts.
* No hard-coded "new abilities every two levels" rule.
* No new data: the observed coordinates and *The Adventurer* are not added by hand.
* No second route database, no per-strategy data.
* No UI redesign beyond what a plan structure minimally needs, and no analytics UI.
* No machine learning, no external services, no networking.
* No investigation or fix of bug 15.1 B bundled into planning work; no waypoint fix bundled either (separate changes).
* No assumption that nearby actions should always be recommended.

## 18. Suggested future implementation phases

None of these is started. Each should be a small, separately tested change.

0. **Triage (independent of planning).** (a) Targeted investigation of the protected-action login error 15.1 B.
   (b) Waypoint lifecycle fix 15.1 A. Both separate from the model.
1. **Evidence capture path.** A deliberate way to record player-observed coordinates and unknown quests with
   provenance (who, when, how), kept separate from ATT. No hand edits to the packs.
2. **Data-model groundwork.** Turn-in NPC/location separate from giver; multiple locations per quest with kind and
   confidence; origin/start flag handling; ID-based identity with names as labels.
3. **Plan structure.** A sequence planner (separate module) producing NOW / ALSO DO / THEN from the existing candidates,
   behind the current `plan` shape so the UI can migrate gradually. Interrupt-cost and local-cluster reasoning first.
4. **Batching and delayed turn-ins.** Shared physical destinations; compare turn-in-now with finish-local-work-first.
5. **Short lookahead.** One unlock step using prerequisite edges, degrading to "unknown".
6. **Character-state opportunities.** Read inventory/money/level-up state; class-trainer and vendor opportunities as
   real providers replacing the inert `TRAINER` / `CLASS_PROGRESSION` entries (and a new vendor type).
7. **Travel-cost model.** Walk, flight, hearthstone and, only with observed evidence (graveyards, respawn timing) and
   only for non-Hardcore players, respawn shortcuts as a player-chosen option.
8. **Fast mode.** Consume telemetry-derived metrics (XP/minute, downtime, quest durations) once their sources are proven
   on Forever, for strategy weighting only.
