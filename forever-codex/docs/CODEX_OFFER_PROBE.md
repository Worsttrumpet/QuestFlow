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
