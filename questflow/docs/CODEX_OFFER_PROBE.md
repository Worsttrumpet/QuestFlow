# Offered-quests probe (0.6.4): read-only

Purpose: find out what the Forever client itself says an NPC is offering when its dialog opens, because "the quest exists in Codex data" is not "this character is offered it" (Yorana Windyreed offered nothing while Codex recommended Q:92642 / Q:92645). No planner, scoring, candidate, skip, filter or actionability behaviour changes; nothing is marked dirty or recomputed.

## What it does (FACT: code; the Forever payloads are UNPROVEN until the real-client test)
`OfferProbe.lua` listens to GOSSIP_SHOW, QUEST_GREETING and QUEST_DETAIL and, only if each function exists (pcall, tallied PROVEN / UNPROVEN / FAILED / ABSENT), reads:
* GOSSIP_SHOW: `C_GossipInfo.GetAvailableQuests / GetActiveQuests / GetOptions` and the older `GetNumGossipAvailableQuests / GetGossipAvailableQuests / GetNumGossipActiveQuests / GetGossipActiveQuests / GetNumGossipOptions`
* QUEST_GREETING: `GetNumAvailableQuests / GetAvailableTitle` (and `GetAvailableQuestID` only if the client has it), `GetNumActiveQuests / GetActiveTitle`
* QUEST_DETAIL: `GetQuestID`, `GetTitleText` (the quest whose offer dialog is open)
* the NPC: `UnitName("npc")` and the creature id parsed from `UnitGUID("npc")` (the raw GUID is never stored)

Each observation (`ForeverCodexDB.offers.obs`, last 100, `src = CODEX_OBSERVED`, separate from QuestieDB / ATT / the observed quest pack / the quest log) holds the event, time, build, NPC and an answer per API: LISTED (with the quest id when the client gave one, else the title only, plus the payload's field names), EMPTY (the API answered and listed none: the only thing that counts as "nothing offered"), NO_DATA (the call returned nothing: not the same), ABSENT, ERROR. An identical refreshed dialog raises a counter.

A negative observation means only: this character opened this NPC's dialog at this time and the client did not list the quest. It is never turned into a class / race / prerequisite / availability rule.

`/codex report` has an OFFERED QUESTS PROBE section: event registration and counts, each function's status, totals, and the last 6 observations.

## Real-client test (short)
1. `/reload`, then open Yorana Windyreed (gossip text, no quests). `/codex report` -> OFFERED QUESTS PROBE: expect a GOSSIP_SHOW row with NPC "Yorana Windyreed". What matters: does `C_GossipInfo.GetAvailableQuests` say "answered, none listed" (EMPTY) or "returned nothing" (NO_DATA) or is it ABSENT, and which functions show PROVEN.
2. Open an NPC that offers you a quest and look at the report without accepting: expect that quest listed with its id (or "(no id)" plus a title, and the field names in `fields:`).
3. Click the quest (QUEST_DETAIL) to see the offer: expect a QUEST_DETAIL row with the id and title. Accepting is optional.
4. Check for Lua errors (`/codex report` shows "caught errors") and that NOW / ALSO DO are unchanged.
Worth trying once each, in this order of value: an NPC with no quests (done in 1); one quest; several quests; an NPC where you already have a quest in the log (does it appear under "active"?); an NPC with a quest ready to turn in. Anything else is optional.

## 0.6.5: the evidence layer (no planner change)
Real-client facts (user-tested on build 70205): `GOSSIP_SHOW` fires and `C_GossipInfo.GetAvailableQuests()` / `GetActiveQuests()` answer with empty tables at Valennia Stormfist and Talaanis Shadowsong; `QUEST_DETAIL` fired at Fendaal Windstone with `GetQuestID()` = 98512 and `GetTitleText()` = "Al'Aketh Assassins".

The probe now normalises its observations into two bounded indexes (still `CODEX_OBSERVED`, still no raw GUIDs):
* `quests[id]`: OBSERVED via `QUEST_DETAIL` (the offer dialog opened; the stronger source, kept when both were seen) or via `AVAILABLE_LIST` (a client available list carried the id), with the NPC, count, first / last time (cap 300).
* `npcs[key]`: the latest answer that NPC's dialog gave, AVAILABLE and ACTIVE each `EMPTY` / `LISTED` (with the ids when every entry had one) / `NO_DATA`; keyed by creature id when the client gave one, else by name (cap 100). A `QUEST_DETAIL` never rewrites a listing, and is associated only with the NPC the client reported at that moment.

`OfferProbe.OfferEvidence(quest, giverNpcId, giverName)` and `Planner.OfferEvidence(action)` return:
* `OBSERVED` (via QUEST_DETAIL or AVAILABLE_LIST), which also makes `Planner.Actionability` = OBSERVED;
* `EMPTY_AT_NPC`: the quest's giver (matched by creature id, else by exact name) was observed listing nothing, at that time;
* `NOT_LISTED_AT_NPC`: the giver's list was complete (every entry had an id) and did not include the quest;
* nil: no client evidence (UNKNOWN, the default).
The two negatives are contextual and leave the actionability UNKNOWN. A positive observation always outranks them and is never erased by a later list. They are not rules, not about class / race / prerequisites, and not about the quest in general.

Hierarchy kept: QUEST_DETAIL > client list with id > client EMPTY at the NPC > quest log > QuestieDB / ATT / observed pack > UNKNOWN.

**Planner: unchanged.** Considered and deliberately not done: dropping a pickup whose giver just returned EMPTY. The evidence can be stale (a later level or quest step may change what the NPC offers) and an association by name is weaker than by creature id, so the evidence is exposed first: `plan.onTheWay[i].offer`, the OPPORTUNITIES provenance lines and the report. A narrow, time-bounded gate can be reviewed later with real data.

Report: the section is now ACTIONABILITY / OFFER EVIDENCE (event and function status, totals, OBSERVED quests, per-NPC latest answers with what they do and do not prove, and the last 3 raw observations).

### Real-client checks (not yet performed)
A. Open an NPC that offers a known quest without accepting: GOSSIP_SHOW fires, the quest id appears in AVAILABLE (if the list carries ids), then open the quest: a QUEST_DETAIL row with the same id.
B. Open Valennia Stormfist again: AVAILABLE EMPTY, and no quest is marked unavailable anywhere (her quests show `offer evidence: EMPTY_AT_NPC`, actionability UNKNOWN).
C. Another NPC offering a different quest: separate NPC rows, no mixing.
D. A QuestieDB-known quest never opened stays `actionability UNKNOWN (never seen offered...)`.

## 0.6.6: refinement from the v0.6.4 real-client report
Proven by that report (build 70205): `GOSSIP_SHOW` x16, `QUEST_DETAIL` x5, `QUEST_GREETING` never; `C_GossipInfo.GetAvailableQuests` / `GetActiveQuests` answered 16/16 with entries that carry quest ids and the fields `questID`, `title`, `questLevel`, `questInfoID`, `repeatable`, `isComplete`, `isImportant`; 15 dialogs, 8 listed entries (all with ids), 8 empty answers. Example: Strange Hermit available Q93160 and Q93172, active Q93172.

Changes (the code already had the 0.6.5 evidence layer; the v0.6.4 report predates it):
* The proven-absent functions (`GetNumGossip*`, `GetGossip*`, `GetAvailableQuestID`) are no longer called; the report lists the functions that are still asked.
* Only `C_GossipInfo.*` answers count as listing evidence (NPC context, OBSERVED via the available list, EMPTY / NOT_LISTED). QUEST_GREETING counts are recorded as observations and never become evidence (unproven payload).
* The ACTIVE list is stored per NPC (ids and titles) and is never offer evidence. A quest in both lists (Q93172) is OBSERVED only because it appeared in the available list or its QUEST_DETAIL opened.
* Per quest: observations are counted by source (QUEST_DETAIL x n, AVAILABLE_LIST x n); QUEST_DETAIL stays the stronger `via`.
* Hierarchy: positive evidence is never erased. When the giver's NEWER dialog is EMPTY or omits the quest from a complete list, the quest stays OBSERVED and the report/diagnostics show "NEWER dialog ... (kept, not erased)". Ordering uses a sequence number, not wall time (one-second resolution).
* NOT_LISTED_AT_NPC requires an answered table where every entry is a table with a numeric `questID` and the count matches; anything else (title-only entry, string id, non-table entry, number instead of a table, missing API, raised error) makes no claim.
* Entries keep `repeatable` / `isComplete` when the client gives them (the ACTIVE `isComplete` flag shows a quest ready to hand in).
* Report: per quest "NPC | OBSERVED | sources | observations | age"; per NPC "available LISTED: Q93160 ..., Q93172 ... | active LISTED: Q93172 ...", or EMPTY.

Meaning is unchanged: OBSERVED means the client offered the quest to this character at that time (history, not a promise it is offered now); EMPTY / NOT_LISTED describe one NPC dialog at one moment. Nothing here is a rule about class, race, prerequisites or permanent availability. The planner does not read any of it.
