# Opportunity System: investigation of the 0.5.3 planner and the next step (no code changed)

Labels: **FACT** (read in the repository), **ASSUMPTION**, **DESIGN IDEA** (proposed, not existing), **NEEDS REAL-CLIENT VALIDATION**.
Supersedes the loose parts of `CODEX_OPPORTUNITY_SYSTEM_DESIGN.md`; where they differ, this document is the one read against the code at 0.5.3.
Line references are to `ForeverCodex/Planner.lua` unless stated.

## 1. Current planner architecture (FACT)
Pipeline: providers -> `Engine.Candidates` (collect + global filters; `Engine.lua:193`) -> `Planner.Compute` -> `PlanAdapter.ToLegacy` -> Presenter / Overlap / Nearby / Navigation / Arrow / Diag.
| Responsibility | Lives in |
|---|---|
| Candidate generation | `Providers/Quest.lua` (`Q.Generate`: every known quest id -> accept/progress action), `Providers/Flight.lua` (optional hints) |
| Filtering | `Quest.Eligibility` (repeatable, event, faction, race list, class list, level, tooLow via `maxGap`, no location, prereqs); `Engine.Candidates` (strategy `allow`, skip, log full, `hereOnly`); `Planner.usable` (skip, state) |
| Stops | `makeStops` (:378): located items within `STOP_RADIUS` 60 yd share one stop; stop `val` and `dwell` are the sums |
| Sequences | `rankStops` (:421) keeps the best `BEAM_K` 8 stops by solo net (route zone / local-first filters first); `searchSequences` (:~490) enumerates ordered sequences of up to `DEPTH` 3 (400 in the latest run) |
| Scoring | `net = sum(stop.val) - lam * (walk + dwell)`; `val` = `valueOf` policy points x `Confidence`; `lam` = `timeValue` 0.30 |
| Distance / route | `seconds()` = `Engine.Distance / RUN_SPEED` (7 yd/s, estimated); straight line in world yards when a conversion exists; `nil` = unmeasurable (other continent) |
| Urgency | only `Engine.LevelFit` points inside `valueOf` (ACCEPT) and `maxGap` hiding low quests. Nothing about "going gray" |
| Same-stop | `makeStops` (aggregation) and `bestOf` (order inside a stop: hand-in, objective, pickup) |
| Interruption / detour | `chooseAlsoDo` (:579), the only place that prices "insert this into the route" |
| Presentation data | `plan.now / alsoDo / thenAction / reminders / diag`; reason codes in `addReasons`; `PlanAdapter` text; `Nearby.List`, `Overlap.List`, `Diag` |
| Provenance / confidence | Contract `prov`, `evidence`; `Pl.Confidence` multiplies value (approx/assumed 0.8, unverified ACCEPT 0.9, log unavailable 0.5) |
| Inputs | `ctx` (player map/position/world, quest log with objectives, `isCompleted`, character, prefs, group) |
Post-search policy blocks (all FACT): WORK_HERE, DEFER_TURN_INS (batch / on-route tests), StayLocal, TURN_IN_FIRST, stickiness.
Note (FACT): pickups are NOT "optional" in the planner. They are ordinary `items`, so they form stops and compete in the beam. Only `optional` / `hereOnly` actions (flight hints) go to the `extras` pool (:342).

## 2. Exact source of TOO_FAR (FACT)
Only place: `chooseAlsoDo` -> inner `offer(it, cost)` (:606): `if cost > par.detour then rejected TOO_FAR {seconds = cost}`.
Call path: `Planner.Compute` -> after the best sequence is picked -> `chooseAlsoDo(S, seqStops, firstList, nowIt, inSeq)`.
* `cost` = `interruption(it)` (:~584): the cheapest INSERTION of the item between consecutive nodes of the polyline `player -> stop1 -> stop2 -> stop3` (the chosen sequence): `min over i of (seconds(node_i, it) + seconds(it, node_i+1) - seconds(node_i, node_i+1))`, or just `seconds(last, it)` after the last stop; floors at 0. Inside the first stop the cost is 0 (SAME_STOP).
* So `TOO_FAR` is **extra seconds against the chosen route**, not distance from the player. The user's "69 sec" for Prepare for Battle (311 yd away) means inserting it costs 69 s more than the route already takes.
* Threshold `par.detour` = 30 s (efficient), 20 s (fast), 45 s (completionist). `LOW_VALUE` is the second test: `net = val - lam * (cost + dwell) < alsoFloor 5`.
* Inputs: player position and the chosen stops; travel time via straight-line yards; the item's value and dwell. It knows the eventual route (only the chosen sequence's <= 3 stops), route direction and intermediate stops (via the polyline), and backtracking (the detour term). It does NOT consider downstream travel beyond stop 3, other opportunities at the same location (each item is priced alone), hub / cluster value, urgency, or player activity.
* Only ONE item can become ALSO DO (the best `net`). Everything else priced is dropped, and `diag.rejected` keeps the first 6 sorted by code then id (:~690), so the Rogue report's six TOO_FAR lines are a truncated sample, not the full set, and not the nearest.
* Meaning: "among things not already in the route, the best single one that fits within 30 s of extra time and still nets >= 5 points". It is a single-slot filter, not a route-corridor classifier.

## 3. Does route-corridor reasoning exist? (FACT, per example)
| Example | Handled? | Why |
|---|---|---|
| A: 250 yd away, directly on the route | YES for ALSO DO | polyline insertion cost ~0 -> FREE-like; reason `ON_THE_WAY` (cost <= 0.5 s) |
| B: 150 yd, opposite direction | YES | `a + b - direct` charges the out-and-back, so it is expensive |
| C: 300 yd, but three other useful givers there | PARTLY | those givers form ONE STOP (within 60 yd of each other) with summed value, so as a stop it competes in the sequence search at its summed value. Priced as an ALSO DO, each item is evaluated alone and the cluster value is ignored |
| D: leave the route and return | YES | the same insertion formula |
| E: slightly off route, passed later | YES if the later stop is in the chosen sequence's first 3 stops; NO beyond stop 3 | polyline only has the chosen stops |
Not present: a route-relation label (on / near / detour / reconnecting), a classification kept for presentation, more than one result, a cluster test applied to ALSO DO. The corridor arithmetic exists, but only as a hidden filter inside one function.
Smallest place to add the capability (DESIGN IDEA): lift `interruption()` out of `chooseAlsoDo` into a shared local helper returning `{extraSeconds, atLegIndex, sameStop}`; call it for every item; keep the filter semantics. No new geometry is needed.

## 4. Core route versus opportunities (FACT / DESIGN IDEA)
FACT: the architecture already separates the *chosen sequence* (core) from the *ALSO DO* (one opportunity), and `Overlap.List` (objectives within 300 yd, hand-ins as READY TO TURN IN) and `Nearby.List` (ALSO DO plus close flight masters) are two more, separately-rules presentation channels. There is no single list of opportunities, and the 6 priced-and-rejected items are invisible to the player.
DESIGN IDEA: this needs an EXTENSION OF PLANNER OUTPUT, not a new layer: `plan.onTheWay` = an ordered list of the items `chooseAlsoDo` already prices, each with its extra seconds, the stop it belongs to, and a relation label, built by the same function. `plan.alsoDo` stays as element 1 for existing consumers. No new candidate structure and no new planner.

## 5. FREE / CHEAP / MODERATE / EXPENSIVE
FACT available: extra seconds (`interruption`), same-stop test, dwell, net value, `par.detour` (the existing limit), `par.alsoFloor`.
DESIGN IDEA: cost is a LABEL derived from extra seconds relative to values the planner already owns, not a score:
* FREE: same stop, or extra seconds <= a small epsilon (the current `ON_THE_WAY` test is `cost <= 0.5`);
* CHEAP: <= `par.detour` (anything ALSO DO accepts today);
* MODERATE: above `par.detour` but net still positive after `lam * (extra + dwell)` (worth it only if the player wants it);
* EXPENSIVE: net <= 0 after paying the extra time.
Why these bounds: they come from the planner's own definitions (detour limit and net value), so changing a strategy changes the labels with no new constant. Thresholds are NOT invented here; the only candidate new number is the FREE epsilon (ASSUMPTION: the existing 0.5 s). Compound value and urgency enter through `val` (the numerator), not through the label bands. Downstream value (chain) is already in `val`. NEEDS REAL-CLIENT VALIDATION: whether `RUN_SPEED` 7 and straight-line yards match the walking time seen in play (e.g. mounted, terrain).

## 6. Hub / cluster compound value
FACT: `makeStops` (60 yd) already makes a hub a single stop with summed `val` and `dwell`; the Aamelia stop (593 yd, five actions) is exactly this and competes as one unit in the beam. `Engine.applyStaticScores` has a separate 40-yd grid hub count for legacy scoring.
Missing: (1) the `chooseAlsoDo` path ignores stops: it prices items one by one; (2) hubs are only formed from items that are `items`; (3) the BEAM (8 of 71 stops by solo net) may exclude a good cluster; (4) the cluster is not presented as a cluster.
DESIGN IDEA (no second scoring system): evaluate opportunities at STOP granularity: for each stop not in the sequence, `interruption(stop.pos)` and `stop.val - lam * (extra + stop.dwell)`. One formula, now applied to hubs. The "boundary" is the existing 60 yd stop; a larger hub radius is a later question (NEEDS REAL-CLIENT VALIDATION: do quest givers in a camp usually sit within 60 yd?).

## 7. "On the way" classification (DESIGN IDEA over FACT)
Derivable from numbers the planner already computes for each item/stop: `extra` and the insertion leg index.
* DIRECTLY_ON_ROUTE: same stop or extra ~0;
* NEAR_ROUTE: extra <= detour limit and inserted between existing nodes;
* RECONNECTING_DETOUR: extra > ~0 but inserted between two stops (leaves and rejoins);
* OFF_ROUTE: inserted after the last stop (cost is the whole trip, no rejoin);
* EXPENSIVE: net <= 0.
Names are conceptual. Presentation (ON THE WAY / WHILE YOU'RE HERE / CHEAP DETOUR / NOT WORTH IT with minutes) is text over these labels; "not worth the detour" is a deliberate display of what is already rejected.

## 8. Player agency (FACT / DESIGN IDEA)
FACT: the planner already recomputes from the player's actual position, so a player who wanders simply changes the input; stickiness avoids flicker; per-system toggles, skip, add, route zone are the player's controls. Nothing scolds.
DESIGN IDEA: opportunities are context only: never create stops, never alter `plan.now`; shown quietly and capped; wording factual ("Optional: ..."). Activity can lower prominence, never raise urgency.

## 9. Player activity / context
FACT in `Telemetry.lua`: events QUEST_ACCEPT / COMPLETE / TURNIN / OBJECTIVE (objective count diffs), PLAYER_MOVE (1 Hz sampled), XP_GAIN, COMBAT_START / END (registered; recorded in real reports), MOB_KILL unavailable (combat log blocked). No fishing, mining, herbalism, trainer, taxi or spell-cast events are registered or probed (FACT: absent from `WATCHED_EVENTS`).
DESIGN IDEA: a pure function over the telemetry list (no polling, no OnUpdate): last movement, last combat, last objective progress -> {TRAVELLING | FIGHTING | WORKING_OBJECTIVE | UNKNOWN}. NEEDS REAL-CLIENT VALIDATION: spell-cast / loot events for gathering and fishing; trainer and taxi frame events.

## 10. QuestieDB actionability and provenance (FACT / DESIGN IDEA)
FACT: an ACCEPT's availability is DERIVED, not observed. `K.QuestState` marks it AVAILABLE when `K.QuestRequirements` (level, prereq quests, faction (inferred from the starter NPC), race, class) find no false requirement. Specific limits in the code:
* race masks from QuestieDB are NOT enforced (`QuestieBridge.lua:28`);
* class is enforced only when every set mask bit is one of the known `CLASS_TOKENS` (`QuestieBridge.lua:219-224`: `cm < 2 ^ #CLASS_TOKENS`), so a mask with unknown/high bits, or no mask, leaves the quest unrestricted;
* an unverified ACCEPT is discounted only by 0.9 (`Pl.Confidence`), i.e. nearly full strength;
* `evidence` is "unverified" for QuestieDB (`prov.verified = false`), but nothing downstream distinguishes "known to exist" from "offered to this character".
So Taming the Beast (Q94979) can be a perfectly consistent output of the current rules: QuestieDB said it exists at that place with no class restriction Codex enforces. FACT-level cause is not established (the report did not print its class/race mask). Do not hardcode a class rule from external data.
DESIGN IDEA (state vocabulary kept separate from provenance):
* existence/location KNOWN (QuestieDB/ATT, unverified);
* ACTIONABLE-FOR-THIS-CHARACTER: UNKNOWN by default for a quest never offered; OBSERVED when Codex saw the quest offered to this character (QUEST_DETAIL / gossip list while at the NPC, or the quest appears in the log); REFUTED when the player stood at the giver and it was not offered (needs a proven signal).
* an unverified-actionable ACCEPT stays a legitimate candidate but is labelled "unconfirmed" in the opportunity list and cannot be promoted to a core-route driver on its own value alone (ASSUMPTION: more discount or an extras-only tier).
NEEDS REAL-CLIENT VALIDATION: client signals for actionable-quest detection: `QUEST_DETAIL` (already registered, FACT, by ItemProbe), gossip/greeting available-quest APIs (`GetNumAvailableQuests` / `C_GossipInfo.GetAvailableQuests`, unprobed), any quest-offer marker API (none known), and the quest's `classMask` for 94979 as the bridge reads it (one diagnostic line would answer why it was offered).

## 11. Opportunity data model
FACT reusable: Contract action (`ref`, `state`, `targets` with `where`, `optional`, `prov`, `evidence`), planner `item` (`pos`, `val`, `dwell`, `conf`, `comps`, `stop`), `diag.reasons`.
DESIGN IDEA: NO new record. An opportunity = a planner item (or stop) plus an annotation computed at the end of `Compute`:
`{ id, itemOrStop, extraSeconds, insertAfter (leg index | "same stop"), relation, net, bundleStopId, prov = evidence, actionability = KNOWN | OBSERVED | UNCONFIRMED, reasonCode }`.
Genuinely new fields: `relation`, `insertAfter`, `actionability`, `bundleStopId` (already `it.stop`). Everything else exists. It lives inside `Planner.lua` output (`plan.onTheWay`), computed from structures that already exist.

## 12. Architectural boundary
The hypothesis (facts -> discovery -> normalized opportunities -> cost/value -> existing planner -> core + context -> presentation) is mostly already how the code is organised: the Contract is the normalized opportunity, `valueOf`/`Confidence` price it, `chooseAlsoDo` prices detours. The repository suggests a smaller change than a new layer: (a) more producers behind the Contract (later), (b) one generalised pricing helper in the planner, (c) a list instead of a single ALSO DO, (d) `Overlap` and `Nearby` reading that list instead of keeping separate rules. Keep ONE source of truth for filtering (`Quest.Eligibility` / `usable`) and ONE for distance (`seconds`).

## 13. Performance (FACT from the 0.5.3 audit; DESIGN IDEA)
Pricing every located item/stop costs O(items x 4 nodes) `E.Distance` calls: ~110 items x 4 is trivial next to the 4,357-id scan. Bound it by pricing only the first N (e.g. 40) by solo value or distance. No QuestieDB rescans (the planner already holds the located items), no new events or timers; opportunity output is recomputed only when the plan recomputes (the existing dirty/3 s architecture, unchanged). Do not build opportunity objects for items that are not displayed.

## 14. Required report items
1-3 (architecture, TOO_FAR, corridor): sections 1-3. 4 direction-of-travel: PARTLY (the polyline is directional; no direction label, no heading from the player's motion). 5 SAME_STOP: section 6. 6 reusable: `interruption`, `makeStops`, `valueOf`, `Confidence`, reason codes, `diag.rejected`. 7 the Opportunity System should own: list assembly, relation labels, cost class, actionability label, presentation selection. 8 the planner keeps: the core sequence, scoring, policy blocks, `seconds`, `Locate`. 9-13: sections 11, 7, 5, 5, 6. 14: section 9. 15: section 10. 16: section 13.
17 Test strategy: stub scenarios in `planner_eval.lua` for each of examples A-E (a quest on the route, behind the player, a three-giver hub 300 yd away, leave-and-return, passes later) asserting relation and cost; chosen sequence and golden baselines byte-identical (new output only adds `plan.onTheWay`); duplicates (the same quest through ALSO DO and the list); UNCONFIRMED labelling; cap behaviour.
18 Minimal real-client validation: (a) a `/codex report` line printing the class/race mask and evidence for any ACCEPT shown as an opportunity; (b) observe whether QUEST_DETAIL fires on accepting offers and whether the gossip available-quest APIs answer while an NPC dialog is open; (c) compare the predicted extra seconds against a walked detour once. No grinding.
19 Files likely involved (implementation): `Planner.lua` (helper, `plan.onTheWay`), `PlanAdapter.lua` (carry and text), `Overlap.lua` / `Nearby.lua` (read the list), `Presenter.lua` / UI card, `Diag.lua` (OPPORTUNITIES section, un-truncated rejections), `QuestieBridge.lua` only for a diagnostic line, tests, docs.
20 Must NOT change: scoring constants, `TOO_FAR` / `par.detour`, the 0.5.3 performance counters and cadences, Reward Advisor, Eligibility, Gear, telemetry cadence, golden baselines.
21 Recommended phases:
1. Diagnostics only: un-truncate / extend `diag.rejected` into a priced list with extra seconds, relation, stop; print it in the report; print mask/evidence for offered ACCEPTs. No behaviour change.
2. Shared pricing helper in the planner (pure refactor, golden baselines unchanged).
3. `plan.onTheWay` (several, capped) + stop-level pricing for hubs; `alsoDo` unchanged as element 1; presentation of ON THE WAY / WHILE YOU'RE HERE.
4. Actionability states from observed offers (QUEST_DETAIL); discount/label unconfirmed ACCEPTs.
5. Merge `Overlap` / `Nearby` channels into the list.
6. Only then new sources (trainer, gathering, items) and activity alignment.

## Rogue playtest, read against the code (FACT where stated)
* The chosen route is a legitimate best sequence of three stops under the existing rule (net 115.6 over ~701 s). The pickups near the player sit at stops that are not in that sequence.
* They were priced by `chooseAlsoDo` against the polyline `player -> Aamelia -> Riaani -> far stop`; the six listed rejected items cost 46-177 s extra, over the 30 s limit. That part is working as written.
* What the architecture cannot say: the cheaper pickups (212, 287, 289, 311 yd) were presumably not accepted either, but only six rejections are kept, so the report cannot show them; no ON THE WAY list exists; the 593 yd hub's pickups are in the route (not "extra"); and one unverified ACCEPT (Taming the Beast) is treated as nearly certain.
* NEEDS REAL-CLIENT VALIDATION: the polyline stops after the third stop (the 1325 yd leg), so anything beside the first two legs competes only as an insertion.

## Phase 1 implemented (0.5.4): diagnostics only
* `Planner.lua` `chooseAlsoDo`: `interruption()` now also returns the node the item is inserted after (the cost is computed exactly as before); each priced candidate is recorded in `diag.opps` (`list` capped at `Pl.OPP_CAP` = 40, cheapest extra time first then id; `total`, `class` and `decision` counts cover all; `hubs` = up to 5 off-route stops with 2+ actions priced as a whole, diagnostic only). The existing `diag.rejected` (6 entries) is untouched. Reset every recompute, not saved.
* Pure helpers `Pl.RouteRelation` (DIRECTLY_ON_ROUTE <= 0.5 s or same stop / RECONNECTING_DETOUR / AFTER_ROUTE / UNKNOWN) and `Pl.CostClass` (FREE / CHEAP / MODERATE / EXPENSIVE / UNKNOWN). A NEAR_ROUTE label is not derived: it would need a distance threshold the planner does not have. Backtracking shows only as a larger cost.
* Decisions: ACCEPTED, OUTRANKED (cleared both bars, a better item won; the planner always did this silently), TOO_FAR, LOW_VALUE, UNKNOWN_TRANSIT. `TOO_FAR` is the unchanged `cost > par.detour`.
* `Diag.lua` `/codex report` OPPORTUNITIES section: counts, limits in force, up to 24 candidate lines, provenance line per candidate (evidence, location status, database source, class/race mask for ACCEPTs, actionability UNKNOWN unless a QUEST_DETAIL dialog for that quest was recorded), and the hub lines.
* Stub cost: +0.75 ms and +126 KB garbage per recompute at 93 candidates (stub ratios only). Golden baselines unchanged.
