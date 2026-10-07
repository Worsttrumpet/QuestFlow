# World and travel knowledge (0.11.0)

This note records the audit that led to 0.11.0, what was built, and the exact limits. The rule behind all of it is the project's standing one: **evidence from the client beats data; unknown stays unknown; an assumption is never turned into a route.**

## Shared architecture

```
Quest -> NPC -> Location -> Travel options -> Transportation -> Destination -> Objective -> Next quest
```

* `Providers/*` and `Engine.Candidates` produce the quest, NPC and location side (unchanged).
* `Taxi.lua` records what *this character's* taxi map says (per character).
* `Services.lua` records the services the player opened, dungeon entrances and the bind point (account-wide, bind per character).
* `Travel.lua` is the single route model. It answers "cheapest evidenced way from A to B". The Planner reaches it through its one travel-time choke point (`Planner.lua seconds()`); `PlanAdapter` asks it for the steps to show; `Navigation` then points at the first step's target (the flight master, or the place to walk to).
* With no taxi, bind or transport evidence `Travel` returns nothing and every planner result is unchanged (the engine goldens did not move).

## Audit result (before 0.11.0)

| Area | Before | After |
|---|---|---|
| Quest knowledge: offer evidence, chains, prerequisites, objectives, turn-ins, levels, quest-starting items, rewards, cap, gray quests, overlap | working | unchanged |
| NPC locations for quest givers / turn-ins | working (data + QuestieDB) | unchanged |
| Vendors, innkeepers, repair, trainers, flight masters as *places* | static / missing | learned from the player's own visits (`Services`) |
| Dungeon entrances | missing | learned when a dungeon is entered from outside |
| Flight nodes | 14 ATT hints, discovery undetectable | existence (ATT + taxi map) kept apart from discovery (taxi map only) |
| Flight connections, costs, times | missing | direct-offer edges, costs, measured flight times |
| Travel in the planner | straight-line walk only | walk, flight, hearth, registered transports (evidenced only) |
| Plan steps and navigation for flights | none | `Fly:` step aimed at the flight master, then the walk from the landing |
| Player: money, Hearthstone state, bind | missing | read / learned |
| Knowledge page | four fixed sentences | seven categories computed from live evidence |
| Report | no taxi / service evidence | API status, counts and PASS / FAIL / PENDING lines |

## Exists is not discovered

* **EXISTS**: Quest Flow knows the flight path exists (ATT data, or a node a taxi map listed).
* **DISCOVERED (`YES`)**: this character's taxi map showed the node as the current node or reachable from it. Only this reaches routing.
* **LISTED**: on the map but neither current nor reachable. Not used for routing.
* A node never seen is **UNKNOWN**. It is never "not discovered".
* `Providers/Flight.lua` stops hinting at a node only when the taxi map showed it.

## Limits (documented, not hidden)

* The taxi nodes are read only while a flight master's map is open. A path learned by flying near it is unknown to Quest Flow until the map is next opened.
* An edge is "the map offered B while the character stood at A", one direction only. Chains are not composed beyond what the map offered directly.
* A flight time is an estimate (distance / a rough speed, flagged) until that flight has been timed once; then the measured time is used.
* Which taxi API family Forever answers with (`C_TaxiMap` or the classic `NumTaxiNodes` family) is a real-client question. Both are tried; the report says which one worked.
* Node positions come from the modern API when it gives them; otherwise a node is placed only if it matches an ATT node (unverified ATT coordinates).
* Boats, zeppelins and portals: no verified data ships, so none is routed. The model accepts registered edges (`Travel.AddTransport`, evidence required) for when data exists. A quest's own text naming a boat still turns the arrow off.
* The hearth is offered only when the Hearthstone is in the bags and off cooldown, the bind point was learned by watching the character bind, and it saves at least five minutes.
* Walking is a straight line. There is no path finding.
* The Planner does not yet weigh reward usefulness in the route (the Reward Advisor is separate), and "future quest value" is one chain hop.
* Pets, achievements and a recipe reader are not implemented.
* Services: an NPC's position is where the player stood; an entrance is the last outdoor place seen within 90 s before the instance loaded. A service never seen is unknown, not absent.

## Real-client validation

See `/qflow report`, section "WORLD AND TRAVEL KNOWLEDGE": each check is `[PASS]`, `[FAIL]` or `[PENDING]` (PENDING names what to do in the game). The manual steps are Part H of `docs/release/RC_MANUAL_TEST_CHECKLIST.md`.

## Saved data

* `ForeverCodexDB.chars[<character>].taxi`: `nodes`, `reach`, `flights`, `proof`, `stats` (bounded).
* `ForeverCodexDB.chars[<character>].travel.bind`: the learned bind point.
* `ForeverCodexDB.world`: `npcs`, `entrances` (account-wide, bounded).
* Nothing existing changed; a character with none of these behaves exactly as before.

## The flight lifecycle (0.12.2)

A flight is a small state machine and each state is separate evidence (`Taxi.lua`):

| State | Evidence | Written |
|---|---|---|
| LISTED | a taxi map listed the node | `nodes` |
| DISCOVERED | current or reachable on this character's map | `nodes[..].disc = YES` |
| OFFERED | the map offered B while standing at A | `reach` |
| SELECTED | `TakeTaxiNode(index)` resolved to a known destination; origin = the node the map was opened at | pending only |
| STARTED | `PLAYER_CONTROL_LOST` right after selecting, or `UnitOnTaxi` true | pending only |
| COMPLETED | control returned or `UnitOnTaxi` false, and the player is within 500 yd of the destination when both can be measured | `flights[A>B]` |
| ABORTED | never started in 12 s, ended away from the destination, implausible duration, unresolved destination | counters only |

`flights[A>B] = { secs (mean), n, last, min, max, src = "client observation", verified = true, arrival }`. `Taxi.Edges()` returns offered and completed edges as one list (`state` OFFERED or COMPLETED) and that is the list `Travel.Route` reads, so a completed flight is used with its measured time and an offer with a flagged estimate.

Why the first real flight was missed (0.12.0): the hook resolved the destination only through an index table filled by the classic taxi API. This client answers through `C_TaxiMap`, whose nodes carry `slotIndex`; that was never stored, so every `TakeTaxiNode` was dropped as "destination unknown". The index is now resolved by slot, then by node id, and an unresolved call is counted and explained in the report (with the slots the map listed).
