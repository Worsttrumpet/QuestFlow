# WoW Forever M3 Research Report: Client-Side Quest Data Collection

**Date:** September 21, 2026
**Scope:** Determine what quest information can actually be collected from the real WoW Forever beta client (build 1.60.1.69913, product `wow_classic_beta`) and propose the smallest technically useful M3 experiment.
**Frozen prior milestones:** M1 and M2 are frozen and must not be modified.

---

## Evidence Legend

| Label | Meaning |
|---|---|
| **[V]** | Directly verified for the Forever/current client — either user-provided M2 facts, primary source text quoted verbatim, or reproducible output from source code we inspected at a cited commit. |
| **[2nd]** | Reported by a secondary source or documented externally (Warcraft Wiki, wowdev.wiki, another project, ForeverDiff). Not independently confirmed against build 1.60.1.69913. |
| **[?]** | Unresolved — definition exists, presence/behavior not verified for the Forever client. |

A DBD definition existing is **not** proof that a table exists in the Forever client. "API documented" is **not** "API works in WoW Forever." "File format documented" is **not** "this exact Forever cache uses that format."

---

## Executive Summary

The client DB2 tables alone cannot build a quest database: QuestV2 contains only quest IDs and flags, and the rich quest text, objectives, rewards, giver NPCs, and prerequisites are server-side data delivered to the client dynamically. Two realistic collection channels remain, each with distinct provenance:

1. **WDB cache files** (QuestCache.wdb, CreatureCache.wdb, GameObjectCache.wdb) — documented to contain quest titles, descriptions, objective text, completion text, rewards, NPC names, and object names, but **only for entities the player has actually encountered**, and **only if the Forever client persists them to disk** (unverified [?]).
2. **In-game addon API observation** — the documented API surface (C_QuestLog, C_GossipInfo, UnitGUID, UnitPosition, reward functions) is sufficient in principle to assemble a complete quest row (ID/title/objectives/rewards/giver creature ID/name/coordinate) during normal gameplay, as demonstrated by QuestieLearner and Grail's source code. **Whether every listed API exists and returns useful data in build 1.60.1.69913 is unverified [?].**

The recommended M3 is a single minimal probe addon plus a before/after cache snapshot, run in the real beta client, to convert the [?] labels into [V] for the smallest useful set of fields. No Blizzard-derived data should enter the repository.

---

## 1. QuestCache.wdb / questcache.wdb

### 1.1 What it contains (documented structure)

Primary source: [wowdev.wiki QuestCache.wdb](https://wowdev.wiki/QuestCache.wdb) [2nd — documentation]

The wowdev wiki documents four record layouts: `0.5.3.3368`, `3.3.5?`, `8.0.1.27075`, and `9.0.1.33978`. The modern variable-length structure (8.0.1 / 9.0.1) contains the following. **The exact layout used by the Forever client (interface 16001) is not documented on the page [?].**

| Field group | Specific fields | Present? |
|---|---|---|
| Quest title | `LogTitle` (char[]) | Yes [2nd] |
| Quest description | `QuestDescription` (char[]) | Yes [2nd] |
| Quest log description / objective summary | `LogDescription` (char[]) | Yes [2nd] |
| Area description | `AreaDescription` (char[]) | Yes [2nd] |
| Quest giver portrait text/name | `PortraitGiverText`, `PortraitGiverName` (char[]) | Yes [2nd] — these are **display strings, not a creature ID** |
| Turn-in portrait text/name | `PortraitTurnInText`, `PortraitTurnInName` (char[]) | Yes [2nd] |
| Completion log text | `QuestCompletionLog` (char[]) | Yes [2nd] — note this is the completion-log string, distinct from the in-game completion-dialog text returned by the API; do not conflate the two [?] |
| Structured objectives | `Objectives[NumObjectives]` with `ID`, `Type`, `ObjectID`, `Amount`, `Flags`, `Description` | Yes [2nd] |
| Fixed item rewards | `RewardFixedItems[4].ItemID/Quantity` | Yes [2nd] |
| Choice item rewards | `RewardChoiceItems[6].ItemID/Quantity/DisplayID` | Yes [2nd] |
| Money reward | `RewardMoney` (precomputed at cache time), `RewardMoneyDifficulty`, `RewardMoneyMultiplier`, `RewardBonusMoney` | Yes [2nd] |
| XP reward | `RewardXPDifficulty`, `RewardXPMultiplier` (column into QuestXp, not a flat XP value) | Yes [2nd] |
| Spell rewards | `RewardDisplaySpell[3]`, `RewardSpell` | Yes [2nd] |
| Faction/reputation rewards | `RewardFaction[5].FactionID/FactionValue/FactionOverride/FactionGainMaxRank` | Yes [2nd] |
| Currency rewards | `RewardCurrency[4].CurrencyID/Quantity` | Yes [2nd] |
| Title reward | `RewardTitle` | Yes [2nd] |
| Skill rewards | `RewardSkillLineID`, `RewardNumSkillUps` | Yes [2nd] |
| Quest level / required level | `QuestLevel`, `QuestMinLevel`, `QuestMaxScalingLevel` — present in 8.0.1 layout, **removed in 9.0.1.33978** [2nd] | Layout-dependent [?] |
| Next quest in chain | `RewardNextQuest` (forward link only) | Yes [2nd] |
| Quest sort / info | `QuestSortID`, `QuestInfoID`, `QuestPackageID` | Yes [2nd] |
| POI data | `POIContinent`, `POIx`, `POIy`, `POIPriority` (rarely used) | Yes [2nd] |
| Flags | `Flags`, `Flags2`, `Flags3` | Yes [2nd] |

### 1.2 What QuestCache.wdb does NOT contain

- **Quest giver creature ID.** The cache stores `PortraitGiverDisplayID` (a display-info reference) and `PortraitGiverName` (a text string), but **not** the creature ID of the quest giver NPC. [2nd]
- **Explicit prerequisite quest IDs.** Only `RewardNextQuest` (forward chain link) is present. There is no "requires quest X" field. [2nd]
- **NPC spawn position.** No coordinates. [2nd]
- **Authoritative quest level / required level** for the Forever client — the level fields were removed in the 9.0.1 layout, and the Forever layout is unverified [?].

### 1.3 WDB header format

Primary source: [wowdev.wiki WDB](https://wowdev.wiki/WDB) [2nd — documentation]

| Offset | Type | Field | Availability |
|---|---|---|---|
| 0x00 | char[4] | Identifier (e.g. `WQST`, stored reversed) | All versions |
| 0x04 | uint32 | Client Version (low-to-high encoding) | All versions |
| 0x08 | char[4] | Client Locale (stored reversed) | WDB ≥ 1.6.0 |
| 0x0C | uint32 | Record Size (internal structure size) | WDB ≥ 1.6.0 |
| 0x10 | uint32 | Record Version (manually updated) | WDB ≥ 1.6.0 |
| 0x14 | uint32 | Cache Version (set via `SMSG_CLIENTCACHE_VERSION`) | WDB ≥ 3.0.8 |

Header lengths: 16 bytes (<1.6), 20 bytes (1.6–1.9.4), **24 bytes (≥3.0.8)** [2nd]. The Forever client is a modern codebase (interface 16001) and would use the 24-byte header if it produces these files at all, but this is not documented for 1.60.1.x [?].

### 1.4 Does the Forever client produce QuestCache.wdb?

**[?]** The wowdev WDB page states: "not all WDB caches are saved to disk; this is defined in the client by the `DBCache` constructor's `persistent` parameter" [2nd]. Modern WoW clients (since ~Legion/BfA) increasingly route streamed records through `Cache/ADB/<locale>/DBCache.bin` rather than separate `.wdb` files [2nd]. Whether the Forever client writes `QuestCache.wdb` to its `Cache/WDB/` directory, or routes quest records through `DBCache.bin`, is **not documented and must be tested directly** [?]. The only clean proof is a before/after snapshot of the Cache directory during gameplay in build 1.60.1.69913.

### 1.5 Open-source WDB parsers

| Parser | Repo | License | WDB (cache) support? | Notes |
|---|---|---|---|---|
| DBCD | [wowdev/DBCD](https://github.com/wowdev/DBCD) | MIT | **No** — DB2/DBC focused (WDBC, WDB2–WDB6, WDC1–WDC5) | Does not parse `.wdb` cache files [2nd] |
| erorus/db2 | [erorus/db2](https://github.com/erorus/db2) | Apache 2.0 | Partial — supports `DBCache.bin`/`1SLC`/`WCH7`/`WCH8` | PHP; last update 2017 [2nd] |
| WDBx | [Frostshake/WDBx](https://github.com/Frostshake/WDBx) | GPL-3.0 | Unspecified; 3 stars, last commit Jan 2025 | Not confirmed to parse modern QuestCache.wdb [?] |
| WoWDBDefs | [wowdev/WoWDBDefs](https://github.com/wowdev/WoWDBDefs) | CC BY-SA 4.0 (data) / BSD-3 (code) | Definitions only — no reader | Schema metadata, not a parser |

**Finding:** No widely-used, actively-maintained open-source parser was found that is confirmed to parse the modern (8.0.1/9.0.1) QuestCache.wdb record layout. WDB cache parsing is a gap; most tooling targets DB2/DBC table files, not the `.wdb` cache format [?].

---

## 2. Other Client-Side Quest DB2 Tables

All 15 tables the project asked about have `.dbd` definition files in the WoWDBDefs repository (verified via the [GitHub contents API](https://github.com/wowdev/WoWDBDefs/tree/master/definitions) at commit `83057bdc0cbe`, 2026-09-18) [2nd]. A definition existing means the table is a known WoW table type with a documented schema — it does **not** prove the table is shipped as a data file in the Forever client.

| Table | DBD exists? | 1.60.1.69913 in DBD build list? | Forever presence | Evidence |
|---|---|---|---|---|
| **QuestV2** | Yes | No (1.15.9.x only tagged) | **[V] present** | Quest IDs/flags only; not rich quest info. M2 directly verified (6,600 unencrypted records, layout hash 1854BDB9) |
| QuestInfo | Yes | **Yes** | [2nd] schema coverage; data-file presence [?] | Quest type/category metadata |
| QuestXP | Yes | No (1.15.9.x only) | [?] | XP scaling/lookup table; useful with QuestCache/API data |
| QuestObjective | Yes | No (1.15.9.x only) | [?] | Structured objective metadata if present; not necessarily localized objective text (text is server-side / in QuestCache.wdb) |
| QuestV2CliTask | Yes | No (1.15.9.x only) | [?] | Usefulness unresolved |
| QuestLabel | Yes | **Yes** | [2nd] schema coverage; data-file presence [?] | Category/label metadata |
| QuestLine | Yes | No (1.15.9.x only) | [?] | Quest-line grouping, not full prerequisites |
| QuestLineXQuest | Yes | No (1.15.9.x only) | [?] | Quest-line grouping, not full prerequisites |
| QuestHub | Yes | **Yes** | [2nd] schema coverage; data-file presence [?] | Usefulness unresolved |
| QuestPackageItem | Yes | **Yes** | [2nd] schema coverage; data-file presence [?] | Reward package lookup |
| QuestFactionReward | Yes | **Yes** | [2nd] schema coverage; data-file presence [?] | Reputation scaling/lookup table; useful with QuestCache/API data |
| QuestMoneyReward | Yes | **Yes** | [2nd] schema coverage; data-file presence [?] | Money scaling/lookup table; useful with QuestCache/API data |
| QuestSort | Yes | No (1.15.9.x only) | [?] | Quest category/sort metadata |
| QuestPOIBlob | Yes | **Yes** | [2nd] schema coverage; data-file presence [?] | Map POI data if present |
| QuestPOIPoint | Yes | **Yes** | [2nd] schema coverage; data-file presence [?] | Map POI coordinates if present |

**Key caveat on the "1.60.1.69913 in DBD build list" rows:** Among the 15 requested quest-related tables, **8 have 1.60.1.69913 explicitly in their DBD build list** (QuestInfo, QuestLabel, QuestHub, QuestPackageItem, QuestFactionReward, QuestMoneyReward, QuestPOIBlob, QuestPOIPoint); Creature (covered in §3) also has 1.60.1.69913 schema coverage. This means WoWDBDefs explicitly has schema coverage for build 1.60.1.69913 — actual data-file presence and usefulness in the Forever client remain **[?] until direct extraction confirms it**. The user's research rules forbid treating a definition as proof of table presence, so these remain [2nd] (schema-coverage) at best. Conversely, the **absence** of 1.60.1.x from a DBD build list is **inconclusive**: QuestV2 itself is not tagged for 1.60.1.x in its DBD, yet M2 proved it exists in Forever — the definition is simply untagged/incomplete. **No requested table is confirmed absent from the Forever client by this report.**

**ForeverDiff evidence:** ForeverDiff reports extracting 83 tables from build 69913 ([ForeverDiff build page](https://foreverdiff.com/builds/1.60.1.69913/)) [2nd]. However, the build page does **not** enumerate the 83 table names, and the ForeverDiff homepage only displays change-categories (spells, items, talents, recipes, factions, zones, enchants, item sets) — no quest, NPC, or gameobject categories. The prior session's specific claim that "QuestPOIBlob/QuestPOIPoint/Creature are NOT in the 83-table list" **could not be reproduced** from ForeverDiff's public pages and is therefore downgraded to [?]. ForeverDiff's build page does confirm: 83 tables, BuildConfig `6c0df97e8e481a9a`, CDNConfig `5525ea1ce6668e89`, WoWDBDefs commit `02b1fa9a4714`, 99 withheld blocks, 5,391 rows in encrypted sections [2nd].

**Implication:** QuestObjective, QuestLine, QuestLineXQuest, and the POI tables — if present — would contain structured objective and chain data. But even QuestLine/QuestLineXQuest only define quest-line grouping, not the full prerequisite graph; and QuestObjective defines objective IDs/types, not the human-readable text (which is server-side / in QuestCache.wdb). These tables cannot substitute for the addon/cache collection path [?].

---

## 3. NPC / GameObject Information

### 3.1 Creature DB2

[Creature.dbd](https://github.com/wowdev/WoWDBDefs/blob/master/definitions/Creature.dbd) has a 1.60.1.69913 layout and localized `Name_lang` / `Title_lang` fields [2nd — definition]. **Whether the Creature DB2 is actually shipped as a data file in the Forever client is unverified [?].** Even if present, the Creature table provides display info and name only — **not** spawn locations, quest-giver associations, vendor lists, or loot tables [2nd].

### 3.2 GameObjects DB2

[GameObjects.dbd](https://github.com/wowdev/WoWDBDefs/blob/master/definitions/GameObjects.dbd) exists with 1.15.9.x builds but 1.60.1.x is not tagged in its build list [2nd]. Forever presence unverified [?]. Contains object display/name metadata, not spawn positions or quest relationships [2nd].

### 3.3 CreatureCache.wdb

Primary source: [wowdev.wiki CreatureCache.wdb](https://wowdev.wiki/CreatureCache.wdb) [2nd — documentation]

Signature `WMOB`. Documented for build `1.13.2.31882` (Classic). Contains: creature ID, name(s) (Name0–Name3 + alt names), title, flags, `CreatureType`, `CreatureFamily`, `Classification`, `ProxyCreatureID`, display info. **Does NOT contain:** position, level, or quest-giver relationship. Whether the Forever client persists this cache to disk is [?].

### 3.4 GameObjectCache.wdb

Primary source: [wowdev.wiki GameObjectCache.wdb](https://wowdev.wiki/GameObjectCache.wdb) [2nd — documentation]

Signature `WGOB`. Contains: `objectID`, object type, `displayID`, `ObjectName`, icon, scale. **Does NOT contain:** position or quest-related object relationships. Forever persistence [?].

### 3.5 In-game addon APIs

The addon API is the only channel that can associate an NPC/object with a quest giver relationship and an **observed interaction coordinate** (not an authoritative spawn location). See §4–§5.

**Summary of what is realistically obtainable:**

| Need | Source | Obtainable? |
|---|---|---|
| NPC ID | UnitGUID("target"/"npc") — 5th hyphen-delimited field | [2nd] documented; Forever [?] |
| NPC name | UnitName("target"/"npc") | [2nd] documented; Forever [?] |
| NPC position | UnitPosition / C_Map.GetPlayerMapPosition during interaction | Observed interaction coordinate only — not spawn location [2nd] |
| NPC quest-giver relationship | GOSSIP_SHOW + UnitGUID + QUEST_ACCEPTED/TURNED_IN timing | [2nd] methodology (QuestieLearner); Forever [?] |
| GameObject ID | UnitGUID (when targeting/interacting) | [?] |
| GameObject name | GameObjectCache.wdb (if persisted) | [?] |
| GameObject position | UnitPosition during GAMEOBJECT_USED interaction | Observed coordinate only [?] |
| Quest-related object relationships | Inferred from observation only | [?] |

---

## 4. In-Game Addon APIs

All API behavior below is **documented** ([2nd] — Warcraft Wiki) unless marked [V]. **No API has been verified to exist or return useful data in build 1.60.1.69913.** "API documented" ≠ "API works in WoW Forever." The M3 probe must convert each [?] to [V].

### 4.1 Quest log and details

| API | Documented return | Classic/Era version | Forever [?] |
|---|---|---|---|
| `C_QuestLog.GetInfo(questLogIndex)` | `title`, `questID`, `level`, `difficultyLevel`, `suggestedGroup`, `frequency`, `isHeader`, `isCollapsed`, `isOnMap`, `hasLocalPOI`, `isAutoComplete` (many fields retail-gated: `questClassification` 11.0.2, `headerSortKey` 11.0.0, etc.) | Added 8.0.1/1.13.2 era | Exists/works [?] |
| `C_QuestLog.GetQuestObjectives(questID)` | objectives: `text`, `type`, `finished`, `numFulfilled`, `numRequired`, `objectiveType` | Added 8.0.1/1.13.2 | Exists/works [?]. Note: "Sometimes three calls are needed to fully cache everything, such as text" [2nd]; requires quest in log |
| `GetQuestLogQuestText([questLogIndex])` | `questDescription`, `questObjectives` | Version not stated | Exists/works [?] |
| `GetQuestLogCompletionText()` | Completion text | Listed for M3 probe; return details not independently sourced in this report [?] |
| `C_QuestLog.GetQuestInfo(questID)` | `title` | Listed for M3 probe; return details not independently sourced in this report [?] |
| `HaveQuestData(questID)` | Whether quest data is cached | Listed for M3 probe; return details not independently sourced in this report [?] |

### 4.2 Quest rewards

| API | Documented return | Forever [?] |
|---|---|---|
| `GetNumQuestRewards()` | Number of reward items | Listed for M3 probe; return details not independently sourced in this report [?] |
| `GetQuestLogRewardInfo(itemNum)` | name, texture, numItems, quality, isUsable | Listed for M3 probe; return details not independently sourced in this report [?] |
| `GetQuestLogRewardMoney()` | Reward money (copper) | Listed for M3 probe; return details not independently sourced in this report [?] |
| `GetQuestLogRewardXP()` | Reward XP | Listed for M3 probe; return details not independently sourced in this report [?] |
| `GetQuestLogRewardTitle()` | Reward title | Listed for M3 probe; return details not independently sourced in this report [?] |
| `GetQuestLogChoiceInfo()` | Choice reward item info | Listed for M3 probe; return details not independently sourced in this report [?] |
| `C_QuestInfoSystem.GetQuestRewardSpells(questID)` | Reward spell IDs | Listed for M3 probe; return details not independently sourced in this report [?] |

**Context sensitivity:** Some reward APIs return meaningful values only when the quest-detail or quest-completion frame is open (i.e., during `QUEST_DETAIL` / `QUEST_COMPLETE`), not from the quest log alone. The M3 probe must test reward APIs in **both** the quest-log context and the completion/turn-in frame context [?].

### 4.3 Quest giver (gossip) interaction

| API | Documented return | Forever [?] |
|---|---|---|
| `C_GossipInfo.GetAvailableQuests()` | `GossipQuestUIInfo[]`: `title`, `questLevel`, `isTrivial`, `frequency`, `repeatable`, `isComplete`, `isLegendary`, `isIgnored`, **`questID`** (retail-gated: `isImportant` 10.1.5, `isMeta` 11.0.0, `questInfoID` 11.2.5). Available after `GOSSIP_SHOW`. | Exists/works [?] |
| `C_GossipInfo.GetActiveQuests()` | Active quests from current NPC | Listed for M3 probe; return details not independently sourced in this report [?] |

### 4.4 NPC and coordinates

| API | Documented return | Forever [?] |
|---|---|---|
| `UnitPosition(unit)` | positionX, positionY, positionZ, mapID | Listed for M3 probe; return details not independently sourced in this report [?] |
| `C_Map.GetPlayerMapPosition(uiMapID, unit)` | Normalized map position | Listed for M3 probe; return details not independently sourced in this report [?] |
| `UnitName(unit)` | NPC/player name | Exists/works [?] |
| `UnitGUID(unit)` | GUID string, e.g. `Creature-0-1465-0-2105-448-000043F59F`; 5th hyphen field = NPC ID. Added 2.4.0/1.13.2. | Exists/works [?] |

### 4.5 Taxi / flight paths

| API | Documented return | Forever [?] |
|---|---|---|
| `C_TaxiMap.GetAllTaxiNodes(uiMapID)` | `TaxiNodeInfo[]`: `nodeID`, `position`, `name`, `state`, `slotIndex`, `textureKit` (retail-gated: `useSpecialIcon`/`specialIconCostString` 9.2.0, `isMapLayerTransition` 10.1.0). Added 7.0.3, moved to C_TaxiMap in 8.0.1. | Exists/works [?] |
| `C_TaxiMap.GetTaxiNodesForMap(uiMapID)` | Map taxi nodes | Exists/works [?] |
| `TaxiNodeName(node)` | Taxi node name | Listed for M3 probe; return details not independently sourced in this report [?] |
| `TaxiNodePosition(node)` | Taxi node position | Listed for M3 probe; return details not independently sourced in this report [?] |
| `TaxiNodeCost(node)` | Taxi node cost | Listed for M3 probe; return details not independently sourced in this report [?] |

---

## 5. Quest Giver Identification

### 5.1 Does C_GossipInfo.GetAvailableQuests() expose enough?

**Documented yes [2nd], but unverified for Forever [?].** The documented return includes `questID`, so in principle `GetAvailableQuests()` during a `GOSSIP_SHOW` event directly pairs a quest ID with the NPC being interacted with. However:

- The return's `questID` field is documented for the modern API; whether it is populated in the Forever client is [?].
- QuestieLearner (the most complete open-source observation collector) **does not rely on this** — see §5.2.

### 5.2 The proven approach: GOSSIP_SHOW + UnitGUID timing

QuestieLearner (source verified, [V] methodology; Forever applicability [?]) identifies quest givers **without** calling `C_GossipInfo.GetAvailableQuests()` at all. Its method ([Modules/QuestieLearner.lua](https://github.com/Xurkon/Questie-X/blob/main/Modules/QuestieLearner.lua), commit `788dad06815b`, 2026-07-07):

1. On `GOSSIP_SHOW`: capture `UnitGUID("npc")` + `UnitName("npc")`, parse the creature ID from the GUID, cache as `_lastGossipEntity`.
2. On `QUEST_ACCEPTED` (fires after `GOSSIP_SHOW`/`QUEST_DETAIL`): associate the accepted quest ID with `_lastGossipEntity`. Code comment: "for Objectives Board quests, `GOSSIP_CLOSED` fires before `QUEST_ACCEPTED` so 'npc' is nil" — hence the fallback cache.
3. On `QUEST_TURNED_IN`: capture turn-in NPC via `UnitGUID("npc")` with fallback to `UnitGUID("target")` ("the player almost always still targets the turn-in NPC").
4. On `QUEST_COMPLETE` / `QUEST_DETAIL`: resolve the entity via `UnitGUID("npc")`/`UnitGUID("target")`.

This means quest-giver identification does **not** depend on `GetAvailableQuests()` returning a quest ID. The `GOSSIP_SHOW` event + `UnitGUID("npc")` + `UnitName("npc")` is sufficient to know which NPC the player is interacting with, and the subsequent `QUEST_ACCEPTED`/`QUEST_TURNED_IN` events carry the quest ID. **This is the more robust approach and should be the M3 probe's primary method** [2nd methodology; Forever [?]].

### 5.3 GUID → creature ID resolution

`UnitGUID("npc")` returns a string like `Creature-0-1465-0-2105-448-000043F59F` [2nd — Warcraft Wiki]. Splitting on `-`: position 1 = unit type, 2 = server ID, 3 = instance ID, 4 = zone UID, **5 = NPC ID**, 6 = spawn UID. For `Creature`/`Vehicle` unit types, field 5 is the creature ID. For `GameObject`, the GUID type prefix differs and the same split yields the object ID [? — object GUID format not separately documented on the page]. This parsing is exactly what QuestieLearner's `ResolveNpcIdFromGuidAndName` does [V source].

---

## 6. Quest Prerequisites / Chains

| Category | What is exposed | Source |
|---|---|---|
| Explicit client table field | `RewardNextQuest` in QuestCache.wdb (forward chain link only — "next quest in the chain; sometimes blank when it shouldn't be because chains are often not linear") | [2nd] |
| Server-provided quest state | Whether a quest is available/active/complete at a given NPC (via gossip APIs) | [2nd] |
| Inferable through observation | Quest availability before/after completing other quests; quest-giver sequencing | [2nd] methodology |
| **Cannot currently be obtained client-side** | Full prerequisite graph; "requires quest X to be available" conditions; the complete chain topology | [?] |

**Conclusion:** There is no client-side table or API that exposes the full prerequisite graph. `RewardNextQuest` gives a partial forward chain only. Prerequisite/chain data must be **inferred from observation** (which quests unlock after which completions) and cannot be collected comprehensively without systematic playthrough [?]. QuestLine/QuestLineXQuest DB2 tables, if present, define quest-line grouping but not the complete prerequisite condition logic [?].

---

## 7. Quest Rewards

Via the in-game API, the following reward types are **documented** as collectible (all Forever [?]):

| Reward type | API | Context |
|---|---|---|
| XP | `GetQuestLogRewardXP()` | Quest log or completion frame [?] |
| Money | `GetQuestLogRewardMoney()` | Quest log or completion frame [?] |
| Item rewards (fixed) | `GetQuestLogRewardInfo(itemNum)` over `GetNumQuestRewards()` | Quest log or completion frame [?] |
| Choice rewards | `GetQuestLogChoiceInfo()` | Completion frame [?] |
| Reputation/faction | `GetQuestLogRewardFactionInfo` (Grail uses this) | Quest log [?] |
| Spells | `C_QuestInfoSystem.GetQuestRewardSpells(questID)` | [?] |
| Titles | `GetQuestLogRewardTitle()` | [?] |
| Other (skill-ups, currencies) | Not exposed by a single API; QuestCache.wdb has `RewardCurrency[4]`, `RewardSkillLineID` | Cache only [?] |

**Important limitation:** QuestieLearner, the most complete open-source observation collector, **does not collect reward data at all** — its source contains no calls to `GetNumQuestRewards`, `GetQuestLogRewardInfo`, `GetQuestLogRewardMoney`, `GetQuestLogRewardXP`, etc. ([V] source inspection). This means reward collection is an **unproven capability** that the M3 probe must add and test separately [?]. The M3 probe should capture rewards in both the quest-log context and the `QUEST_COMPLETE`/turn-in frame context, since some reward APIs are context-sensitive [?].

---

## 8. Player-Observation Collection Projects

### 8.1 QuestieLearner (Questie-X)

- **Repo:** [github.com/Xurkon/Questie-X](https://github.com/Xurkon/Questie-X), commit `788dad06815b` (2026-07-07), MIT license [V — repo metadata]
- **Core file:** `Modules/QuestieLearner.lua` (5,469 lines) [V — source inspection]
- **Events observed:** `UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED`, `QUEST_DETAIL`, `QUEST_COMPLETE`, `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `LOOT_OPENED`, `GOSSIP_SHOW`, `GAMEOBJECT_USED`, `COMBAT_LOG_EVENT_UNFILTERED`, `GET_ITEM_INFO_RECEIVED`, `UNIT_QUEST_LOG_CHANGED` [V source]
- **APIs used:** `UnitGUID("mouseover"/"target"/"npc"/"player"/"pet")`, `UnitName`, `C_Map.GetBestMapForUnit`, `GetPlayerMapPosition`, `GetQuestLogTitle` + `GetQuestLogLeaderBoard` (via `QuestieCompat` abstraction) [V source]
- **How it identifies NPCs:** `ResolveNpcIdFromGuidAndName(guid, name)` — parses creature ID from the GUID's 5th hyphen field [V source]
- **How it collects quest objectives:** `GetQuestLogTitle` for quest log entries + `GetQuestLogLeaderBoard(j, logIdx)` for each objective's text/type/finished state [V source]
- **How it records coordinates:** `C_Map.GetBestMapForUnit("player")` + player position; comment notes raw `GetPlayerMapPosition` can read 0,0 when the world map is open showing another zone [V source]
- **How it collects rewards:** **It does not.** No reward API calls in the source [V source]
- **How it deals with incomplete info:** caches `_lastGossipEntity` to bridge the `GOSSIP_CLOSED` → `QUEST_ACCEPTED` timing gap; falls back from `"npc"` to `"target"` for turn-in capture [V source]
- **Conflicting observations:** QuestieLearnerAutoStaticPrecedence tests exist (`Tests/QuestieLearnerAutoStaticPrecedence_spec.lua`) suggesting a precedence-resolution system for conflicting observations [V — file tree]
- **License:** MIT (covers code only; embedded game data is not licensed) [V]

### 8.2 Grail

- **Repo:** [github.com/smaitch/Grail](https://github.com/smaitch/Grail), commit `11d8f1d9e854` (2026-05-11), **no license file, no license detected via GitHub API** [V — repo metadata]
- **Version:** 127; `.toc` Interface versions: `11508, 20505, 50503, 50504, 120005, 120007` — **does not list Forever (16001)** [V — .toc]
- **Methodology (README):** "As a user of Grail plays WoW, Grail's internal database is checked as a player accepts and turns in quests. If Grail has incorrect data, it will record the actual data the player has found in the Grail saved variables file." Discrepancies are recorded in `GrailDatabase` SavedVariables and can be submitted as tickets to update future releases [V — README]
- **Events/APIs (from Grail.lua):** `QUEST_LOG_UPDATE` (preferred over `UNIT_QUEST_LOG_CHANGED`), `C_QuestLog.GetQuestInfo`/`GetTitleForQuestID`/`GetQuestsOnMap`/`IsComplete`/`IsOnQuest`/`IsQuestTask`, `GetQuestsCompleted` / `C_QuestLog.GetAllCompletedQuestIDs`, `UnitGUID`/`UnitName`/`UnitPosition`, `C_Map.GetMapInfo`/`GetPlayerMapPosition`, `GetQuestLogRewardFactionInfo`, `LOOT_CLOSED` event [V source]
- **License:** **None.** No LICENSE file, no SPDX license, no README license statement. Redistribution status unclear [V]

### 8.3 Questie / QuestieDB

- **Repo:** [github.com/Questie/Questie](https://github.com/Questie/Questie) — **no LICENSE file found; `master` branch `.toc` reads `Interface: 00000` / "game client not supported"** (placeholder/broken state as of 2026-09-21) [V — repo inspection]. The functional Questie code lives on other branches; the master branch is not a reliable citation target.
- **QuestieDB** (the embedded database within Questie) is a **static quest-helper database / data model**, not a live observation collector in the same way QuestieLearner is. It ships pre-built quest/NPC/object data tables compiled into the addon. Its data lineage traces to Classic-era sources and should **not** be copied into this project. Forever applicability [?]. QuestieDB was not deeply inspected in this report beyond confirming the repo's placeholder master-branch state.
- **License:** Not detectable [?]

### 8.4 Wowhead Looter

- **Distribution:** Closed-source addon, installed via the [Wowhead Client](https://www.wowhead.com/client); Lua is readable in the addon folder but **not openly licensed or version-controlled on GitHub** [2nd — Wowhead forums]
- **What it collects:** NPC IDs (via `/wl id`, targeting/mouseover priority), items, objects, pages, quests; data stored in the addon folder, uploaded to Wowhead after play sessions [2nd]
- **Methodology context:** Marlamin's blog confirms addons collect session data to a file for later parsing: "Thottbot initially pioneered this method of data gathering... WoWDB and later Wowhead improved upon this." Notably: "it's not always possible for these addons to reliably tie dialog text to a `CreatureID`, but only to a creature name" — a known limitation of name-based association [2nd — blog.marlam.in]
- **License:** None stated; closed-source; data uploads are Wowhead's property [2nd]

---

## 9. Legal / Provenance

**No definitive legal conclusion is given.** Relevant terms and licenses are identified for reference.

### 9.1 Blizzard UI Add-On Development Policy

Primary source: [us.forums.blizzard.com — UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534) [V — official text]

Key clauses (verbatim/characterized):
1. Add-ons must be free of charge.
2. **Add-on code must be completely visible** — "must in no way be hidden or obfuscated, and must be freely accessible to and viewable by the general public."
3. Must not negatively impact realms or other players.
4. No advertisements.
5. No in-game donation solicitation.
6. No offensive material.
7. **Add-ons must abide by the World of Warcraft ToU and EULA.**
8. Blizzard may disable add-on functionality at its discretion.

**Notable:** The addon policy itself does **not** explicitly prohibit reading game data or collecting information via the sanctioned addon API — the API surface is the mechanism Blizzard exposes for addons. The prohibition on "intercepts, mines, or otherwise collects information" lives in the EULA/Anti-Cheating Agreement (below), which applies to third-party programs. The tension: using the documented addon API to collect quest data is arguably within the sanctioned addon framework, but the EULA's broad anti-mining language could be read to cover it. This is unresolved and not a legal conclusion [?].

### 9.2 Blizzard EULA / Anti-Cheating Agreement / Developer API ToU

Primary sources (cited in prior M2 research, [V] text):
- [Blizzard Anti-Cheating Agreement](https://www.blizzard.com/en-us/legal/cd5930c0-2784-420c-a23d-1e0d6ff8599b/anti-cheating-agreement): prohibits third-party software that "intercepts, mines or otherwise collects information from or through Blizzard games."
- [Blizzard Developer API Terms of Use](https://www.blizzard.com/en-us/legal/a2989b50-5f16-43b1-abec-2ae17cc09dd6/blizzard-developer-api-terms-of-use): "You will not perform any data-mining, scraping, crawling, or use any processes that sends automated queries to Blizzard or any Blizzard game, service, or website."
- WoW EULA (via MDY v. Blizzard court documents, [2nd]): grants "limited, non-exclusive license" for non-commercial entertainment; prohibits "copy, photocopy, reproduce, translate, reverse engineer, derive source code from, modify, disassemble, decompile, or create derivative works"; prohibits "use any third-party software that intercepts, 'mines', or otherwise collects information"; exception: "Blizzard may, at its sole and absolute discretion, allow the use of certain third party user interfaces."

The specific EULA version applicable to WoW Forever may differ [?].

### 9.3 Tool and data licenses

| Component | License | Covers | Does NOT cover |
|---|---|---|---|
| DBCD (code) | MIT [V] | The C# library | Extracted game data |
| WoWDBDefs (data/definitions) | CC BY-SA 4.0 [V] | Structural metadata (column names, types, build ranges) | Blizzard's game data; ShareAlike requires derivative works to use the same license |
| WoWDBDefs (code) | BSD-3-Clause [V] | Parser/generator code | Game data |
| Questie-X (code) | MIT [V] | Addon code | Embedded game data |
| Grail | **None** [V] | — | No license granted |
| Wowhead Looter | **None / closed** [2nd] | — | Data uploads are Wowhead's property |
| ForeverDiff data | None stated — "provided as is" disclaimer only [V] | — | No redistribution rights granted |
| Blizzard game data | EULA/ToS [V] | Limited personal use | Extraction/reproduction/distribution |

**Key distinction:** A code license (MIT, BSD-3, Apache 2.0) grants rights to the software. It does **not** grant rights to data that the software extracts from proprietary game files. The WoWDBDefs CC BY-SA 4.0 license covers the definition files (schemas), not the game data those schemas describe [V].

### 9.4 Provenance implications

- Tooling, DBD definitions, build manifests, and hashes are independently licensed and may be distributed (Scenario E in prior research).
- Extracted Blizzard-derived data (DB2 rows, WDB cache payloads, quest text, reward data) should **not** be committed to the repository until provenance is established.
- Addon-collected observation data has a different provenance character (observed via sanctioned API during gameplay) but still rests on the EULA's anti-mining clause — unresolved [?].

---

## 10. M3 Recommendation: Smallest Technically Useful Experiment

The goal is **not** to build a database. It is to convert the highest-value [?] labels into [V] for the Forever client with one minimal, reproducible probe.

### 10.1 What to test

A single minimal addon ("M3 Probe") plus a before/after cache snapshot, run on a fresh character in the real Forever beta client (build 1.60.1.69913, product `wow_classic_beta`).

### 10.2 Exactly which files/APIs to test

**A. API existence probe** — for every API in §4, log `type(fn)` and, if callable, the actual return shape (or nil/error) in each relevant UI state:
- Quest log open
- `GOSSIP_SHOW` (interacting with a quest giver)
- `QUEST_DETAIL` (quest acceptance frame)
- `QUEST_COMPLETE` (turn-in frame)

**B. Cache directory snapshot** — before and after one play session:
- Record file paths, sizes, SHA-256 hashes
- For any `*.wdb` files that appear: record only metadata — first 24 header bytes, signature, client version, locale, record/cache version, record count — **not** redistributed payload
- For `DBCache.bin` if present: record existence/size/hash only

**C. End-to-end quest collection** — across one full cycle (accept → progress → complete → turn in) for one simple quest, plus one gameobject-interaction quest if available:
- Build/product/locale (from `.build.info` / `GetBuildInfo()`)
- Event order with timestamps
- `questID`, `title` (from `C_QuestLog.GetInfo` / `GetQuestInfo`)
- Quest description + objective text (`GetQuestLogQuestText`, `C_QuestLog.GetQuestObjectives`)
- Gossip tables if `C_GossipInfo.GetAvailableQuests`/`GetActiveQuests` exist
- `UnitGUID("npc"/"target")`-derived creature ID + `UnitName`
- `UnitPosition` / `C_Map.GetPlayerMapPosition` for npc/target/player at interaction time
- Reward API returns in **both** quest-log and completion-frame contexts (`GetNumQuestRewards`, `GetQuestLogRewardInfo`, `GetQuestLogRewardMoney`, `GetQuestLogRewardXP`, `GetQuestLogChoiceInfo`, `C_QuestInfoSystem.GetQuestRewardSpells`)
- Taxi node data via `C_TaxiMap.GetAllTaxiNodes` for the current map (if reachable)

### 10.3 What evidence to record

- Raw addon log file (SavedVariables + printed log) from build 1.60.1.69913
- Cache directory before/after manifest (paths, sizes, hashes, headers)
- `.build.info` / build metadata
- The probe addon source code itself

### 10.4 What constitutes success

A **single complete collectible quest row** with evidence logs from the exact build:
- questID + title
- objective text + objective structure
- reward data (XP/money/items/choice)
- giver creature ID (parsed from GUID) + giver name + observed interaction coordinate

Plus: confirmed [V] for each API that exists and returns useful data; confirmed [V] for whether QuestCache.wdb / CreatureCache.wdb are persisted to disk and their header layout.

### 10.5 What should remain [?]

- Full prerequisite/chain graph (not collectible client-side — §6)
- NPC authoritative spawn locations (only observed interaction coordinates are obtainable)
- QuestObjective / QuestLine / QuestLineXQuest / QuestPOIBlob / QuestPOIPoint data-file presence (needs direct DB2 extraction, separate from this probe)
- The exact EULA version applicable to Forever and whether addon-API collection is within sanctioned use

### 10.6 Repository hygiene — what NOT to copy in

- **Do not commit** raw quest text, reward payloads, or extracted DB2/WDB data into the repository.
- **Do not commit** the QuestCache.wdb / CreatureCache.wdb files themselves — keep them as local client-derived material outside the repo.
- **Do not commit** ForeverDiff data, wago.tools exports, or any other Blizzard-derived dataset.
- **May commit:** the probe addon source code, log schemas, redacted example rows (structure only, no quest text), build hashes/manifests, methodology documentation, and DBD definitions (CC BY-SA 4.0, with attribution).

---

## Source Ledger

| # | Source | URL | Commit / version | Evidence type |
|---|---|---|---|---|
| 1 | wowdev.wiki QuestCache.wdb | https://wowdev.wiki/QuestCache.wdb | — | [2nd] format documentation |
| 2 | wowdev.wiki WDB | https://wowdev.wiki/WDB | — | [2nd] header format |
| 3 | wowdev.wiki CreatureCache.wdb | https://wowdev.wiki/CreatureCache.wdb | — | [2nd] format documentation |
| 4 | wowdev.wiki GameObjectCache.wdb | https://wowdev.wiki/GameObjectCache.wdb | — | [2nd] format documentation |
| 5 | WoWDBDefs (definitions directory) | https://github.com/wowdev/WoWDBDefs/tree/master/definitions | `83057bdc0cbe` (2026-09-18) | [2nd] DBD schemas |
| 6 | ForeverDiff build 69913 | https://foreverdiff.com/builds/1.60.1.69913/ | synced Sep 19, 2026 | [2nd] build metadata |
| 7 | Warcraft Wiki — C_GossipInfo.GetAvailableQuests | https://warcraft.wiki.gg/wiki/API_C_GossipInfo.GetAvailableQuests | — | [2nd] API docs |
| 8 | Warcraft Wiki — UnitGUID | https://warcraft.wiki.gg/wiki/API_UnitGUID | — | [2nd] API docs |
| 9 | Warcraft Wiki — C_QuestLog.GetInfo | https://warcraft.wiki.gg/wiki/API_C_QuestLog.GetInfo | — | [2nd] API docs |
| 10 | Warcraft Wiki — C_QuestLog.GetQuestObjectives | https://warcraft.wiki.gg/wiki/API_C_QuestLog.GetQuestObjectives | — | [2nd] API docs |
| 11 | Warcraft Wiki — C_TaxiMap.GetAllTaxiNodes | https://warcraft.wiki.gg/wiki/API_C_TaxiMap.GetAllTaxiNodes | — | [2nd] API docs |
| 12 | Warcraft Wiki — GetQuestLogQuestText | https://warcraft.wiki.gg/wiki/API_GetQuestLogQuestText | — | [2nd] API docs |
| 13 | Questie-X (QuestieLearner) | https://github.com/Xurkon/Questie-X | `788dad06815b` (2026-07-07), MIT | [V] source; Forever [?] |
| 14 | Grail | https://github.com/smaitch/Grail | `11d8f1d9e854` (2026-05-11), no license | [V] source; Forever [?] |
| 15 | DBCD | https://github.com/wowdev/DBCD | MIT | [V] repo metadata |
| 16 | erorus/db2 | https://github.com/erorus/db2 | Apache 2.0 | [2nd] |
| 17 | WDBx | https://github.com/Frostshake/WDBx | GPL-3.0 | [2nd] |
| 18 | Wowhead Client / Looter | https://www.wowhead.com/client | — | [2nd] |
| 19 | Marlamin's blog (data collection context) | https://blog.marlam.in/naming-vo/ | 2024-07-05 | [2nd] |
| 20 | Blizzard UI Add-On Development Policy | https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534 | — | [V] official text |
| 21 | Blizzard Anti-Cheating Agreement | https://www.blizzard.com/en-us/legal/cd5930c0-2784-420c-a23d-1e0d6ff8599b/anti-cheating-agreement | — | [V] official text |
| 22 | Blizzard Developer API ToU | https://www.blizzard.com/en-us/legal/a2989b50-5f16-43b1-abec-2ae17cc09dd6/blizzard-developer-api-terms-of-use | — | [V] official text |
| 23 | wago.tools DBC diff (table names) | https://wowtools.work/dbc/diff | — | [2nd] |
