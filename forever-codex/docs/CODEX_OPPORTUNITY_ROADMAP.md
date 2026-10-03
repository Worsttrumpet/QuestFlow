# Opportunity System roadmap and what 0.6.0 implements

Principle: one planner. Opportunities are route-relative context around the core route; the player decides.

## Inspected (FACT)
0.5.4 already prices every candidate against `player -> stop1 -> stop2 -> stop3` (`chooseAlsoDo`) and records it in `diag.opps`. Before 0.6.0 that was diagnostics only and the tracker showed ONE planner ALSO DO plus Overlap's objective rows. The old distance gate (`Overlap.ALSO_ACTION_YD` 300 yd from the player) would hide a same-stop pickup in a hub 593 yd away.

## Implemented in 0.6.0: Phase A + B
* **A: the normalised opportunity.** `plan.onTheWay[i] = { id, action, cost (extra seconds), relation, costClass, net, value, dwell, sameStop, stopId, stopSize, from, to, evidence, status, actionability, reason = { code[, seconds] }, decision }`. It is built from the item the planner already priced; no second representation, no new scoring.
* **B: several on-the-way opportunities.** Every candidate that clears BOTH existing ALSO DO bars (detour limit, net floor) is carried, best net first, capped at `Planner.ON_THE_WAY_MAX` (4). `onTheWay[1]` is exactly the ALSO DO (same tie rule). `plan.alsoDo`, NOW, THEN, the sequence and every constant are unchanged; the golden baselines are byte-identical.
* `Planner.Actionability(action)`: NOT_APPLICABLE (not a pickup), IN_LOG, OBSERVED (a QUEST_DETAIL dialog was recorded), else UNKNOWN. Never derived from class / race / level rules or from database presence.
* Tracker: `Overlap.List` lists the carried pickups (up to `Overlap.MAX_ACTIONS` 4) with distance, NPC and the planner's reason, and no longer hides a priced opportunity because it is more than 300 yd from you. Hand-ins stay in READY TO TURN IN. The card keeps the 0.5.5 names (ALSO PICK UP / ALSO COMPLETE / ALSO DO).
* `/codex report` OPPORTUNITIES gets an "on the way" line.
* Plan shape: `plan.onTheWay` (legacy adapter carries it).

## Not implemented yet, and why (conflicts with the full vision)
* **C hub bundles.** Pricing stops as wholes already exists as a diagnostic (`diag.opps.hubs`). Using it to promote or demote anything changes route behaviour, so it needs its own reviewed phase against the golden baselines. The diagnostics show the effect (3 individually EXPENSIVE givers, net positive as one trip).
* **D urgency.** Needs a trusted "turns gray" rule for Forever. The level-fit points are the only existing urgency; do not invent a new number.
* **E actionability gating.** Only the label exists. Gating needs real-client evidence: does QUEST_DETAIL fire on offers, and do gossip available-quest APIs answer (unprobed).
* **F activity, G integrations, H items, I Hardcore.** Telemetry already holds movement / combat / objective diffs; spellcast, gather, trainer and taxi events are unprobed. The `actionability`, `evidence`, `relation` and `reason` fields leave room for a future `risk` field without changing the shape.
* "NEAR_ROUTE" is still not derived (would need a distance threshold); the cost class carries it. Backtracking shows only as a larger cost.
* Real-client validation needed: that predicted extra seconds match walking, that the extra rows do not crowd the tracker, and the hub-distance behaviour on a real character (Aamelia case).
