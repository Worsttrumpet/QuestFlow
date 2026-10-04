# Pickup availability evidence in the planner, and quest-starting items (0.6.7)

## The problem (real 0.6.6 playtest)
Codex recommended "The Ties That Bind" although the NPC could not offer it yet (it opens after "Feathers for Binding"). For Forever-added quests the data has no prerequisite, so the quest passed every filter: a database record plus a location was treated as "available". Separately, a quest-starting item (Ripped Missive, id 265476) was only an ordinary bag item.

## Evidence model for a pickup (existing OfferProbe layer, now read by the planner)
| Level | Source | Meaning |
|---|---|---|
| KNOWN | database / observed pack (where it starts, name, level) | the quest exists; supporting evidence only |
| ELIGIBLE | existing filters (level, prerequisites in the data, faction, race, class, event) | nothing in the data rules it out; unchanged and still blocks unmet data prerequisites outright |
| OBSERVED | the client offered it (QUEST_DETAIL, or the NPC's available list carried its id) | strong positive; no discount |
| NOT_OFFERED | the giver's dialog, read at the character's CURRENT progression, did not offer it (empty list, or a complete id list without it) | contextual negative; strong value discount (`confidence.notOffered` 0.25), NOT a rule about the quest and NOT a removal |
| UNKNOWN | no client evidence, or a negative that progress has made stale | the existing small discount only; stays recommendable (best effort) |

`Planner.OfferState(action)` reduces OfferProbe's evidence to OBSERVED / NOT_OFFERED / UNKNOWN. `Planner.Confidence` uses it for ACCEPT actions only. With no client evidence the confidence is exactly what it was, so the planner golden baselines are unchanged.

## Progression stamp (staleness)
`OfferProbe.Stamp()` = level : quests turned in (as Journey saw them) : quests finished and waiting to be handed in, taken from the context being planned. Every NPC listing stores the stamp it was read at.
* A negative listing whose stamp differs from the current one is STALE: treated as UNKNOWN (re-check at the NPC). This is the "Feathers for Binding turned in, so The Ties That Bind opened" case.
* A positive observation is not undone by progress (an offered quest stays offered until accepted / completed, which the existing log / completed filters handle). A NEWER complete listing at the CURRENT stamp that no longer lists a previously observed quest contradicts it (NOT_OFFERED); that contradiction goes stale with the next progress.
* Assumption (NEEDS REAL-CLIENT VALIDATION): offers do not regress with progress; time-limited or conditional quests are the exception and are not modelled.
* Limit: the stamp does not see availability changes that follow neither a level, a turn-in Codex observed, nor a finished quest (e.g. a quest completed outside Codex's view, or a state that needs an active quest). Such a negative stays in force until progress of one of those kinds, or a fresh dialog.

## Player-facing
When a pickup row (NOW, or an ALSO row) is NOT_OFFERED it says "Not offered by <NPC> the last time you asked." instead of implying you can accept it. Nothing else in the UI changed for pickups.

## Quest-starting items (generic; no item ids hard-coded)
`QuestItems.lua` + `Providers/QuestItem.lua` + a NEW QUEST ITEM card.
* **Evidence**, strongest first: (1) the client's `C_Container.GetContainerItemQuestInfo(bag, slot)` answering with a quest id (src `client`, verified; whether it answers usefully on Forever is UNPROVEN until a report shows it, and is tallied PROVEN / UNPROVEN / FAILED in the report); (2) QuestieDB's `Item.startQuest` through `Items.External` (src `questiedb`, unverified; QuestieDB has no Forever-added items, so it is silent for those). With neither, the item is not a quest starter as far as Codex knows. When they disagree the client wins and the conflict is recorded. A tooltip "begins a quest" flag was NOT implemented: it gives no quest id, so no completed / in-log / skipped filtering would be possible.
* **Bag detection** reuses the shared Gear snapshot (ItemFacts per stack, event-maintained); scanning is cached per snapshot (no polling, no timers).
* **Actionable** when the quest is not completed, not in the log, not active per the client, not skipped (`Q:` / `QT:` of the quest, or `QI:<item id>` for the item), the item's own proven required level is not above the character's, and, when Codex has data for the quest, `Quest.Eligibility` (level, prerequisites, faction, race, class, event) does not rule it out (a missing map location is not a reason: an item quest has none). A quest Codex has no data for is still offered when the client said the item starts it.
* **Planner flow:** a normal provider through the candidate funnel (skip list, strategy filter, `stats.filtered.questItem*` reasons). The action is an optional hint with the player's position; kind USE has no planner value, so it never takes NOW or an ALSO slot. `PlanAdapter` hands the surviving hints to the Presenter; the tracker shows "NEW QUEST ITEM / <item> / This item starts a quest. Use it to continue your progression." (unverified source: "Codex's data says this item starts a quest. ..."), under NOW.
* **Handover:** once the item is used the quest enters the log; the existing telemetry / OfferProbe (QUEST_DETAIL) / quest-log flow takes over and the item entry disappears (IN_LOG).
* The report has a QUEST-STARTING ITEMS section (API status, items found with evidence and verdict, remembered items; bounded to 100).

## Limitations
* Whether `GetContainerItemQuestInfo` works on Forever is unknown; if it does not, Forever-added quest items (like Ripped Missive) stay invisible until a source exists (no data would otherwise tell us the item starts a quest).
* Repeatable item quests are filtered by the existing eligibility rule (conservative).
* The tracker card is not marked "seen": it stays while the item is in the bags and actionable (use it, or `/codex skip QI:<item id>`).

## 0.6.8: NOT_OFFERED is a hold, not a price (real 0.6.7 playtest: Disrupting Logistics at Yorana Windyreed)
In 0.6.7 a pickup whose giver had just shown an empty dialog was only discounted (x0.25 value). A pickup at the stop the player stands at costs no travel, so it could still net positive and be chosen as NOW ("Accept Disrupting Logistics") although the NPC had just not offered it. The evidence model was right (UNKNOWN actionability, EMPTY_AT_NPC evidence, `OfferState` NOT_OFFERED); the planner's use of it was too soft.
* Three levels stay separate: DATABASE knowledge (exists, giver known: ELIGIBLE), CLIENT availability evidence (OBSERVED: strongly actionable), RECENT NEGATIVE observation (the giver was asked at this progression and did not offer it).
* `Planner.gather` now HOLDS BACK a pickup whose `OfferState` is NOT_OFFERED: it is not made a route item, so it can be neither NOW, THEN, in the sequence nor an ALSO DO. It is not removed from the candidate universe: `diag.held` counts and lists it (cap 20) and the report prints it under OPPORTUNITIES as HELD BACK, with the evidence kind, the NPC and the age.
* "Recent" is the existing progression stamp (level : turn-ins : finished quests), not a timer. Any change makes the negative stale, `OfferState` returns UNKNOWN and the quest is considered normally again. A positive observation (QUEST_DETAIL, or an available list that carries its id) makes it OBSERVED and lifts the hold; a newer complete list at the same progression that omits an earlier observed quest holds it again.
* `Planner.Actionability` is unchanged (UNKNOWN is still "no proof about the quest itself"); only the planner's use of the contextual negative changed. A quest the player ADDED is the player's call and is never held. The x0.25 `notOffered` confidence stays for that case and for other readers of `Pl.Confidence`.
* Limits: the hold lasts until progress of one of the three stamp kinds or a fresh dialog (talking to the NPC again does not lift it unless the client now lists the quest); an NPC whose dialog the client reports with a page that omits quests would be mis-read only if the list were marked complete, which the probe never does for partial lists.

## 0.6.9: report diagnostics for a pickup's availability and location evidence (no behaviour change)
Real 0.6.8 playtest: Codex put "Accept Prepare for Battle" (Q93065) at NOW and the NPC could not be found. The report could not show why the 0.6.8 hold did not apply, because it printed neither the progression stamp nor whether a negative was fresh or stale, and an observed-pack record's "verified" label read like a verified position.
New in the report only (nothing the planner reads or decides changed; `Planner.lua` is untouched):
* `OfferProbe.Explain(quest, giverNpcId, giverName)`: a read-only function, called only by the report. It returns the NPC dialog the planner's lookup would use, HOW it was matched (creature id; name only with both ids known and different; name with one side lacking an id), the stamp that dialog was read at, whether that equals the current stamp, and any positive offer evidence. It records and writes nothing.
* A report section NOW CANDIDATE EVIDENCE for the plan's NOW, ALSO DO and THEN pickups: actionability and planner offer state, positive client offer (via, NPC, age, stamp), negative client evidence (kind, NPC, age, FRESH or STALE), the giver the quest data names against the NPC dialog used, the current stamp against the dialog's stamp, the location source, the data layers (with what `verified=yes` means for the observed pack), prerequisites in the data, and why an UNKNOWN pickup is allowed.
* Location wording: a position that came from the observed pack is reported as the recorder's PLAYER position at a checkpoint, never as an NPC coordinate; a giver coordinate is reported with its source layer.
* HELD BACK lines and the per-opportunity lines now say how the giver's dialog was matched and whether it is fresh or stale; the old header line "not used by the planner" was corrected (the planner reads this evidence for the 0.6.8 hold).
* Not changed: UNKNOWN policy, holds, scoring, candidate generation, NPC matching (including the by-name fallback), evidence weighting, the meaning of `verified`, the data packs, progression stamps.
