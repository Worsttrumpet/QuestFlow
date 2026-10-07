# 0.7.6: fixes from the fresh level 1-5 Hunter playtest (build 70205)

Evidence legend: **CLIENT** = confirmed on the Forever client; **PROJECT DATA** = existing ATT / QuestieDB / observed pack (not Forever behaviour unless observed); **UNPROVEN** = no Forever evidence in the repository.

## 1. Timed quests (QuestTimers.lua, Planner.TimerUrgency, TIMED QUEST card)
* **Source of the time:** the live client only, never quest data. **UNPROVEN on Forever:** which API answers. The reader tries `C_QuestLog.GetTimeAllowed(questID)` (total, elapsed) then `GetQuestTimers` + `GetQuestIndexForTimer`; `/codex report` (QUEST TIMERS) says which functions exist and which answered. With none, nothing is timed.
* **Display:** a TIMED QUEST card shows `Time remaining: m:ss` (soonest first; gold under 5:00, red under 2:00, "Time is up" at zero). The tracker updates the text about once a second from the end time (no recompute); a quest that leaves the log, completes or expires is removed.
* **Planner:** only the SLACK matters (time left minus the planner's own walk and work estimates): flat above 600 s, rising smoothly, and at or below 90 s the quest is a must-do-first stop (like a quest the player added). A quest in the same stop as the previous NOW no longer loses to stickiness when it is urgent. Unplaced timed quests get guidance first. The numbers are design values, not game facts.
* While the window is closed and a timed quest is counting down the plan is refreshed every 10 s (the only polling added; it stops with the timer).

## 2. Spell Training lifecycle (SpellTraining.lua)
* **CLIENT (0.7.x reports):** trainer functions exist; rank text and level requirement are in the rows; no spell ids; no spellbook API; a learned row reports level 0.
* **Cause of "learned spells did not leave":** a learned row has level 0 and the old match was by key only (fixed in 0.7.4 by name+rank/cost), and a trainer whose "known" filter is off simply stops listing a learned spell, which nothing handled. Now a spell the character can already learn that a recognised class-trainer window no longer lists is learned (only when the window shares a spell with the class list, so a pet-training window learns nothing, and shows "available" rows or the client's `GetTrainerServiceTypeFilter` says that filter is on).
* **Catalog (account-wide, per class):** every class-trainer window a character opens is recorded (name, rank text, level requirement, cost, build, `src = "trainer window"`). **No Era / Classic spell data is shipped:** there is no Forever spell dataset in the repository and importing another game's tables would present them as Forever's. A later character of the class hears about level-gated spells without a trainer visit, but only for spells whose level is above the level Codex first saw that character at (a spell at or below it may have been learned before Codex ran, and there is no spellbook API to check). The catalog is only as complete as the windows opened; `/codex spells catalog` prints it as copyable text so observed rows can later be turned into shipped data.
* **Ranks:** compared only with ranks of the same kind (rank text with rank text, level with level); only the lowest unlearned rank of a spell is listed; a learned higher rank retires lower ones. Don't Want to Learn, reload and per-character isolation are as before (a re-created character resets via the identity check; the catalog stays).
* **Limit:** a first-ever level 1 character of a class on an account with no recorded trainer window knows nothing until its first visit.

## 3. Area objectives (AreaEvidence.lua, Navigation.Assess)
* An area objective is ONE representative point (ATT objective coordinate or the game's quest-map point). **No source carries an area radius or shape** (PROJECT DATA has none; nothing observed), so none is invented. Two honest signals: objective progress made where the player stands (the client's own objective counts rising; the position is remembered for the session, "still in the area" within 80 yd of it) and arrival within 40 yd of the marker. Inside: no pin, no arrow, the card says "In the objective area". Outside, or with no evidence: Codex keeps steering and shows the distance as approximate. A target that carries a real `radius` (none today) is honoured. Exact destinations (NPCs, hand-ins) are never treated as areas. The 80 / 40 yd values are design values.
* Related fix: objective progress rows are read as the client gives them (`numFulfilled` / `numRequired`); the feedback report's quest log now carries progress.

## 4. Quest sources: NPC, world object, item (QuestieBridge, Registry, Providers/Quest, Presenter)
* QuestieDB's `startedBy` has slots for creatures, objects and items; the bridge ignored the last two. It now records `startKind` (NPC | OBJECT | ITEM), the object id, the item id and the item's name (documented `Item.Get`). A quest with no creature starter has **no giver set**: the card says "Starts from an item: <name>. Not from an NPC." and no nearby NPC is named. A creature starter still wins when the data lists one.
* **PROJECT DATA / reference only:** QuestieDB is GPL-3.0 Era-derived and unverified on Forever; its `startedBy` is not observed Forever behaviour. ATT and the observed pack carry no source kind (unknown stays unknown). **Gaps:** object names and coordinates (no documented object API is used), where the item is obtained (object drops), and the full chain object -> item -> use -> quest. The existing NEW QUEST ITEM card (client container quest info) still covers an item in the bags. No Questie code or data was copied.

## 5. Planner: available is not the same as best now
* New rule (`Planner.DEFER_PICKUPS`): a new pickup that is not close (over 150 yd) and not on the way (detour over 100 yd) waits while objective work of quests already in the log is waiting on the player's map within 900 yd. It stays a candidate and can still be an ALSO DO. A quest the player added or a chosen route zone is never deferred. General: no quest is named.
* **Golden baseline changed:** one sweep row only (C: a pickup 200 yd off the path to a 300 yd destination: NOW=Accept: Pickup became NOW=Continue: Destination, THEN=Accept: Pickup). All 22 scenarios and every other row are unchanged.

## 6. READY -> TURN IN -> UNLOCK -> THEN
* A hand-in that opens a quest right beside it (the chain credit the planner already prices) is no longer deferred behind work elsewhere, and the NOW card for a hand-in now says what it opens ("It opens X and Y."; READY TO TURN IN already shows "opens N more quests"). **Not done:** forcing such a hand-in ahead of nearer work: the existing reviewed chain tests make it THEN, and no evidence says to override them.

## 7. Questie as a reference
Used as a reference for the shape of `startedBy` only. Not copied; not treated as Forever behaviour; its object / area concepts were not adopted because their APIs are not documented for the bridge and area radii are not in the data.

## 8. Character state isolation
Already shipped in 0.7.5 (identity check, unstamped dialogs never current): see `CODEX_CHARACTER_IDENTITY.md`. The Spell Training catalog is account-wide class data by design and is not reset with a character.

## Real-client validation checklist (nothing below is validated yet)
1. `/codex report`: QUEST TIMERS shows which timer function exists. On a timed quest (for example Grace of An'she and Musha): the TIMED QUEST card matches the game's timer and counts down; it turns gold then red; at the deadline it says "Time is up".
2. Level-up with no trainer visit: on a Hunter whose trainer was opened once (by any Hunter on the account), the new level's spells appear; learn one: it disappears; a second new Hunter hears of Track Beasts at level 1 with no visit. `/codex spells` shows the catalog row count and whether `GetTrainerServiceTypeFilter` exists; `/codex spells catalog` prints it.
3. Kill the correct mobs 100+ yd from the quest marker: the arrow stops, the card says "In the objective area"; walk far away: the arrow returns.
4. Quest sources: `/codex report` and the card for a quest whose QuestieDB starter is an item or object (the Dirt-Stained Map quest, if QuestieDB lists it that way): "Starts from an item: ...", no NPC named.
5. At a hub with a pickup and in-log objectives in the cluster: the cluster comes first; the pickup follows.
6. Fresh character with a reused name: no inherited skips or journey.
