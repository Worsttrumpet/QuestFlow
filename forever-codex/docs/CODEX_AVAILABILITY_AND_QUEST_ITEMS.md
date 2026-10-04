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
