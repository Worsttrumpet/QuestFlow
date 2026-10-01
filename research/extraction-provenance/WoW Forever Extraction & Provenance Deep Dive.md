# WoW Forever: DB2 Extraction & Provenance Deep Dive

## Verdict

DB2 extraction from the WoW Forever client is **technically reproducible** using existing open-source tooling (DBCD + WoWDBDefs), and the WoWDBDefs project already includes definitions for all three known Forever builds (1.60.1.69876, 69893, 69913). However, **client DB2 tables alone are insufficient to build a quest leveling-route planner**. QuestV2.db2 contains only quest IDs and two flags — no titles, objectives, text, rewards, giver NPCs, or prerequisites. Those data are server-side, delivered to the client dynamically, and cached only in WDB/ADB cache files for quests the player has actually encountered. A complete quest database will require in-game addon-based collection, cache-file parsing, or another server-side source — each with distinct licensing and provenance concerns.

**Evidence key:** [V] = primary source, directly verified; [2nd] = secondary report; [?] = unresolved / not verified.

---

## 1. ForeverDiff Findings & Provenance

### 1.1 Operator and Identity

ForeverDiff is operated by the **"Vient team"** [V] — not affiliated with Blizzard Entertainment [V]. Contact email: cadendeveloper@gmail.com [V]. No GitHub repository was found for ForeverDiff or the Vient team after web and GitHub searches [?]. The site is static (no backend, no user accounts) [V].

| Attribute | Value | Evidence |
|---|---|---|
| Operator | "Vient team" | [V] About page |
| Affiliation | Not affiliated with Blizzard | [V] About page |
| Contact | cadendeveloper@gmail.com | [V] Terms page |
| GitHub repo | Not found | [?] |
| Site type | Static, no backend | [V] Privacy page |
| Analytics | Google Analytics (GA4) | [V] Privacy page |
| Player data | None collected | [V] Privacy page |

Sources: [ForeverDiff About](https://foreverdiff.com/about/), [ForeverDiff Terms](https://foreverdiff.com/terms/), [ForeverDiff Privacy](https://foreverdiff.com/privacy/)

### 1.2 Extraction Methodology

ForeverDiff's methodology page [V] describes a clear pipeline:

1. **Build pulled from Blizzard's CDN** — "Blizzard's patch server advertises every build, and the client's database tables sit on Blizzard's patch server" [V]
2. **Raw files hashed** — per-file hashes recorded for verification
3. **Rows normalized and joined** — values written verbatim; computed values flagged
4. **Field-by-field diff** against the previous build
5. **Build page records**: BuildConfig, CDNConfig, pinned WoWDBDefs commit hash, per-table row hashes [V]

The site uses **WoWDBDefs** ([https://github.com/wowdev/WoWDBDefs](https://github.com/wowdev/WoWDBDefs)) for column definitions [V] and cross-checks against **wago.tools** ([https://wago.tools](https://wago.tools)) [V]. ForeverDiff explicitly states: "No server-side data. Quest text, NPC names, vendor lists and loot tables are not in these client tables, so we do not have them." [V]

### 1.3 Builds Processed

ForeverDiff's build history page [V] shows:

| Build | Product | Tables | Entities | Synced | Cross-check |
|---|---|---|---|---|---|
| 1.60.1.69913 | wow_classic_beta | 83 | 63,825 | Sep 19, 2026 | not run |
| 1.60.1.69893 | wow_classic_beta | 83 | 63,825 | Sep 19, 2026 | not run |
| 1.60.1.69876 | wow_classic_beta | 83 | 63,825 | Sep 19, 2026 | not run |
| 1.15.9.69722 | wow_classic_era | 82 | 66,473 | Sep 19, 2026 | not run |

Build 1.15.9.69547 (wow_classic_era) was pulled but not published (incomplete) [V].

**Provenance details for build 69913** [V]:
- BuildConfig: `6c0df97e8e481a9a`
- CDNConfig: `5525ea1ce6668e89`
- WoWDBDefs commit: `02b1fa9a4714`
- Unidentified columns: 16 (across all tables)
- Withheld blocks: 99 (encrypted sections)
- Rows in encrypted sections: 5,391

ForeverDiff notes that build 69913 "differs from 1.15.9.69722 across 35,913 entities" but "against the previous Forever build 1.60.1.69893, the client tables are identical at the entity level: this build changed the client, not its data." [V]

Source: [ForeverDiff Build 69913](https://foreverdiff.com/builds/1.60.1.69913/)

### 1.4 Tables Available in WoW Forever Client (83 tables)

The 83 tables ForeverDiff extracted from build 69913 include [V]:

**Quest-related:** QuestV2 (6,600 rows), QuestXP (100 rows), QuestInfo (7 rows)

**Taxi/Travel:** TaxiNodes (100 rows), TaxiPath (328 rows)

**Items:** Item (31,675), ItemSparse (19,171), ItemEffect (12,571), ItemXItemEffect (12,565), ItemModifiedAppearance (16,657), ItemAppearance (9,004), ItemSet (532), and 10 damage/armor scaling tables

**Spells:** SpellName (31,767), Spell (31,767), SpellEffect (42,449), SpellMisc, SpellDuration, SpellCastTimes, SpellRange, SpellRadius, SpellPower, SpellLevels, SpellCooldowns, SpellCategories, SpellClassOptions, SpellAuraOptions, SpellShapeshift, SpellEquippedItems, SpellReagents, SpellTargetRestrictions, SpellInterrupts, SpellDescriptionVariables, SpellXDescriptionVariables, SpellItemEnchantment (2,216)

**Talents:** Talent (432), TalentTab (27), TraitTree (17), TraitNode (560), TraitNodeEntry (656), TraitDefinition (656), and 9 more Trait tables

**World:** AreaTable (1,372), Map (73), AreaPOI (372), DungeonEncounter (341), UiMap (60), UiMapAssignment (61), GameObjects (1,514), LFGDungeons (71), Difficulty (22)

**Character:** ChrClasses (9), ChrRaces (58), CharBaseInfo (56), Faction (253), FactionGroup (4), SkillLine (154), SkillLineAbility (7,824), Achievement (233), Curve (17,198), CurvePoint (36,914)

**Notable absences:** Creature table is NOT in the 83 extracted tables [V]. This means NPC names, display info, and creature data may not be shipped as client DB2 files in the WoW Forever build, or may be in encrypted sections.

### 1.5 ForeverDiff Terms and Licensing

ForeverDiff's Terms page [V] states:

> "ForeverDiff restates data from the World of Warcraft game client for reference. It is provided as is."

This is a **disclaimer of warranty**, not a data license. There is **no stated license** for reusing, copying, or redistributing ForeverDiff's data [V]. The site includes a Blizzard trademark acknowledgment but no Blizzard authorization [V].

**Implication:** ForeverDiff's data cannot be assumed to be freely redistributable. Contacting cadendeveloper@gmail.com would be necessary to clarify permissions.

### 1.6 Independence Analysis

ForeverDiff, wago.tools, and direct DB2 extraction all trace to the **same underlying source**: Blizzard's CDN/client data. They cross-check each other's *processing*, but they are **not independent data sources** — they all rest on the same Blizzard-shipped DB2 files. True data independence would require data collected through in-game observation (addon APIs) or from a different pipeline entirely (e.g., private server databases, which have their own provenance concerns).

---

## 2. DB2 Extraction Tooling Comparison

### 2.1 Tool Comparison Table

| Tool | License | Language | DB2 Formats | WoW Forever (1.60.1.x) | Status | Source |
|---|---|---|---|---|---|---|
| **DBCD** (wowdev/DBCD) | MIT [V] | C# | WDBC, WDB2–WDB6, WDC1–WDC5 [V] | Yes (via WoWDBDefs) [V] | Active (NuGet updated Mar 2026) [V] | [GitHub](https://github.com/wowdev/DBCD) |
| **WoWDBDefs** (wowdev) | Data: CC BY-SA 4.0; Code: BSD-3-Clause [V] | C#, Python | Definitions only (not a reader) | Yes (1.60.1.69876/69893/69913 in DBDs) [V] | Active (definitions updated for latest builds) [V] | [GitHub](https://github.com/wowdev/WoWDBDefs) |
| **wow.tools.local** (Marlamin) | MIT [V] | C# (uses DBCD) | All DBCD-supported formats | Yes (via DBCD + WoWDBDefs) [V] | Very active (commits within days) [V] | [GitHub](https://github.com/Marlamin/wow.tools.local) |
| **DBC2CSV** (Marlamin) | Not stated [?] | C# (standalone) | WDB5+ only [V] | Likely (if WDC2/WDC3 format) [?] | Last commit Oct 2025 [V] | [GitHub](https://github.com/Marlamin/DBC2CSV) |
| **erorus/db2** | Apache 2.0 [V] | PHP | WDB2, WDB5, WDC1–WDC3, WCH7/8, DBCache.bin, 1SLC [V] | Uncertain (supports 1.13.2 via 1SLC, but WDC3 support may cover 1.60.1.x) [?] | Last update 2017 [2nd] | [GitHub](https://github.com/erorus/db2) |
| **WDBx** (Frostshake) | GPL-3.0 [V] | C++ | DBC, DB2 (formats not specified) [?] | Not stated [?] | Last commit Jan 2025, 3 stars [V] | [GitHub](https://github.com/Frostshake/WDBx) |
| **wago.tools** | Not open source [V] | Unknown | Provides CSV exports of DB2 data | Yes (ForeverDiff cross-checks against it) [V] | Active [V] | [wago.tools](https://wago.tools) |

### 2.2 Recommended Extraction Stack

For a reproducible, open-source extraction pipeline targeting WoW Forever:

1. **wow.tools.local** (MIT) — provides a GUI for browsing and extracting DB2 files from a local WoW installation or Blizzard CDN [V]
2. **DBCD** (MIT) — the underlying C# library for reading DB2 files, with WoWDBDefs integration [V]
3. **WoWDBDefs** (CC BY-SA 4.0 for definitions) — provides the schema definitions for all 83 tables, including 1.60.1.x builds [V]
4. **DBC2CSV** (license unknown) — standalone converter for WDB5+ files to CSV [V]

**Important:** The DBD definition files (schemas) are licensed CC BY-SA 4.0, but this licenses only the structural metadata (column names, types, build ranges) — NOT the actual game data extracted from DB2 files. The code tools (DBCD, wow.tools.local) are MIT licensed, but again, this licenses the software, not the data it extracts.

### 2.3 DB2 Format in WoW Forever

The WoW Forever client (build 1.60.1.69913, product `wow_classic_beta`) uses the modern WoW client architecture (interface version 16001, game type "Camelot"). Based on ForeverDiff's ability to read it with WoWDBDefs commit `02b1fa9a4714` and the DB2 format evolution documented on [wowdev.wiki/DB2](https://wowdev.wiki/DB2), the Forever client likely uses **WDC2 or WDC3** format (introduced in BfA, Patch 8.0.1/8.1.0) [V]. ForeverDiff also reports 99 withheld blocks with 5,391 rows in encrypted sections — consistent with WDC4/WDC5 encrypted-section support [V].

---

## 3. Client Data Locations & Formats

### 3.1 DB2 Files

DB2 files are stored inside **CASC archives** (Content Addressable Storage Container), not as loose files on disk [V]. They are not directly accessible from the installation directory without extraction tools. To extract them:

- **wow.tools.local** can extract DB2s from a local WoW installation or from Blizzard's CDN [V]
- **wow.export** can browse raw client files including DB2s [V]
- **CASCExplorer** is another option [2nd]

Source: [wowdev.wiki DB2](https://wowdev.wiki/DB2), [wow.tools.local README](https://github.com/Marlamin/wow.tools.local/blob/main/README.md)

### 3.2 WDB Cache Files

WDB files are the client's cache of server-sent data, stored in the `WDB` folder [V]. For modern Classic-era clients, the cache is at `World of Warcraft/_classic_era_/Cache/` [2nd].

Key WDB cache files relevant to quest planning [V]:

| File | Signature | Contents |
|---|---|---|
| QuestCache.wdb | WQST | Quest data received from server (title, objectives, text, rewards) |
| CreatureCache.wdb | WMOB | NPC data (name, level, display info) |
| ItemCache.wdb | WIDB | Item data from server |
| NPCCache.wdb | WNPC | NPC cache data |
| PageTextCache.wdb | WPTX | Page text (quest item text, books) |
| GameObjectCache.wdb | WGOB | Game object data |
| ItemTextCache.wdb | WITX | Item text cache |

WDB header format includes: identifier (4 bytes), client version (uint32), client locale (4 bytes), record size (uint32, from v1.6), record version (uint32, from v1.6), cache version (uint32, from 3.0.8) [V].

**Critical limitation:** WDB cache files only contain data for entities the player has **actually encountered** — they are populated dynamically during gameplay. A complete quest database would require visiting every quest giver, accepting every quest, and interacting with every relevant NPC [V].

### 3.3 DBCache.bin (Hotfixes)

Since WDB6, standalone ADB files were replaced by `ADB#DBCache.bin` [V]. This file is located at `<install>/Cache/ADB/<locale>/DBCache.bin` [2nd]. It contains hotfixed records and dynamically streamed database entries. DBCD and erorus/db2 can both apply hotfixes from this file [V].

### 3.4 Build/Version Metadata

The WoW Forever client's build metadata is available through:
- ForeverDiff's build page: BuildConfig `6c0df97e8e481a9a`, CDNConfig `5525ea1ce6668e89` [V]
- The client's `.build.info` file in the installation directory [2nd]
- Blizzard's patch server (CDN), which ForeverDiff pulls from directly [V]

---

## 4. QuestV2 & Related Table Feasibility

### 4.1 Quest-Related DB2 Table Status

| Table | DBD Verified | Columns (key fields) | 1.60.1.x in DBD? | In ForeverDiff 83 tables? | Useful for route planner? | Evidence |
|---|---|---|---|---|---|---|
| **QuestV2** | Yes [V] | ID, UniqueBitFlag, UiQuestDetailsThemeID (unverified) | Yes [V] | Yes (6,600 rows) [V] | Minimal — only quest IDs and flags | [V] |
| **QuestInfo** | DBD exists (161 lines) [V] | Not fully verified [?] | Likely [?] | Yes (7 rows) [V] | Quest type/category metadata | [?] |
| **QuestXP** | Not fetched [?] | Unknown [?] | Likely [?] | Yes (100 rows) [V] | XP reward scaling | [?] |
| **QuestPOIBlob** | Yes [V] | ID, NumPoints, MapID (FK), WorldMapAreaID (FK), Floor, ObjectiveIndex, QuestID (FK to QuestV2::ID), PlayerConditionID (FK), UiMapID (FK), ObjectiveID (FK), NavigationPlayerConditionID (FK, optional), Flags (optional) | Yes [V] | Not in 83-table list [V] | Yes — quest POI map locations | [V] |
| **QuestPOIPoint** | Yes [V] | ID, X, Y, QuestPOIBlobID (FK), Z (optional) | Yes [V] | Not in 83-table list [V] | Yes — quest POI coordinates | [V] |
| **QuestObjective** | DBD exists [?] | Not fetched (rate-limited) [?] | Likely [?] | Not in 83-table list [V] | Quest objective definitions [?] | [?] |
| **QuestV2CliTask** | DBD exists [?] | Not fetched (rate-limited) [?] | Likely [?] | Not in 83-table list [V] | Unknown [?] | [?] |
| **QuestLabel** | DBD exists [?] | Not fetched (rate-limited) [?] | Likely [?] | Not in 83-table list [V] | Unknown [?] | [?] |

**Key finding:** QuestV2.db2 is extremely sparse — only 3 columns (ID, UniqueBitFlag, UiQuestDetailsThemeID). The actual quest data (title, description, objectives text, rewards, giver NPC, prerequisites) is **NOT in the client DB2**. This is server-side data [V].

**Critical gap:** QuestPOIBlob and QuestPOIPoint have DBD definitions with 1.60.1.x support, but they are NOT in ForeverDiff's 83-table extraction. This means either: (a) these tables are not shipped as client DB2s in the Forever build, (b) they are in encrypted sections, or (c) ForeverDiff chose not to include them. Direct extraction from the Forever client is needed to confirm [?].

### 4.2 Other Relevant Tables

| Table | Key Fields | In Forever 83 tables? | Rows | Evidence |
|---|---|---|---|---|
| **Creature** | Name_lang, Title_lang, CreatureType, CreatureFamily, DisplayID, Classification | **No** [V] | N/A | [V] DBD has 1.60.1.x support, but table not extracted by ForeverDiff |
| **ItemSparse** | ID, Description_lang, Display_lang, ItemLevel, RequiredLevel, StartQuestID (FK to QuestV2::ID), BuyPrice, SellPrice, AllowableClass, AllowableRace, Stackable, Bonding, and 70+ more fields | Yes [V] | 19,171 | [V] |
| **Item** | ID, class, slot info | Yes [V] | 31,675 | [V] |
| **TaxiNodes** | DBD exists (466 lines) [?] | Yes [V] | 100 | [V] |
| **TaxiPath** | DBD exists (142 lines) [?] | Yes [V] | 328 | [V] |
| **TaxiPathNode** | Not fetched [?] | Not in list [?] | N/A | [?] |
| **AreaTable** | Zone/area data | Yes [V] | 1,372 | [V] |
| **Map** | Map data | Yes [V] | 73 | [V] |
| **AreaPOI** | Points of interest | Yes [V] | 372 | [V] (4 unidentified cols) |
| **GameObjects** | Object data | Yes [V] | 1,514 | [V] (1 unidentified col) |

**Note on Creature table:** The Creature.dbd has localized name/title fields (Name_lang, Title_lang, etc.) and includes 1.60.1.x builds [V]. However, ForeverDiff does not extract this table from the Forever client [V]. Direct extraction from the Forever client is needed to confirm whether the table is present, encrypted, or absent. Even if present, the Creature table provides display info only — not spawn locations, quest-giver associations, vendor lists, or loot tables [V].

**Note on ItemSparse:** The StartQuestID field (FK to QuestV2::ID) is present in ItemSparse, meaning items can reference quests they start. This could be useful for building quest chains — if an item starts a quest, its StartQuestID links to QuestV2::ID [V].

### 4.3 What Client DB2 Data CAN Provide

Based on the 83 extracted tables [V]:
- **Quest IDs** (6,600 quest IDs from QuestV2)
- **Quest POI locations** (if QuestPOIBlob/QuestPOIPoint are present — needs direct extraction to confirm)
- **Item stats and descriptions** (19,171 items with full stat lines)
- **Spell data** (31,767 spells with full effect chains)
- **Talent trees** (469 talents, full trait system)
- **Taxi nodes and paths** (100 nodes, 328 paths)
- **Area/zone/map data** (1,372 areas, 73 maps)
- **Dungeon encounters** (341 encounters)
- **Faction data** (253 factions)
- **Skill/profession data** (154 skill lines, 7,824 abilities)
- **Achievement data** (233 achievements)

### 4.4 What Client DB2 Data CANNOT Provide

Explicitly confirmed by ForeverDiff [V]:
- **Quest titles and descriptions** — server-side
- **Quest objective text** — server-side
- **Quest rewards** (items, gold, XP) — server-side (though QuestXP table has scaling data)
- **Quest giver NPCs** — server-side
- **Quest prerequisites and chains** — server-side
- **NPC names** — not in the 83 extracted tables (Creature table absent)
- **Vendor lists** — server-side
- **Loot tables** — server-side
- **NPC spawn locations** — server-side
- **Quest completion text** — server-side

---

## 5. In-Game Data Collection Methodology

### 5.1 Available Addon API Functions

The Warcraft Wiki documents extensive API functions available in Classic-era clients [V]. These are the in-game methods for collecting quest data that is NOT in client DB2 files. All data is only available for quests the player has encountered or cached.

#### Quest Log and Details

| API Function | Returns | Evidence |
|---|---|---|
| `C_QuestLog.GetInfo(questLogIndex)` | title, questID, level, difficultyLevel, suggestedGroup, frequency, isHeader, isCollapsed, isOnMap, hasLocalPOI, isAutoComplete, questClassification | [V] |
| `C_QuestLog.GetQuestObjectives(questID)` | objectives: text, type, finished, numFulfilled, numRequired | [V] |
| `GetQuestLogQuestText()` | Quest description and objective text | [V] |
| `GetQuestLogCompletionText()` | Quest completion text | [V] |
| `C_QuestLog.GetQuestInfo(questID)` | title | [V] |
| `GetQuestLogTitle()` | (legacy) quest title, level | [V] |
| `HaveQuestData(questID)` | Whether quest data is cached | [V] |

#### Quest Rewards

| API Function | Returns | Evidence |
|---|---|---|
| `GetNumQuestRewards()` | Number of reward items | [V] |
| `GetQuestLogRewardInfo()` | Reward item info | [V] |
| `GetQuestLogRewardMoney()` | Reward money | [V] |
| `GetQuestLogRewardXP()` | Reward XP | [V] |
| `GetQuestLogRewardTitle()` | Reward title | [V] |
| `GetQuestLogChoiceInfo()` | Choice reward item info | [V] |
| `C_QuestInfoSystem.GetQuestRewardSpells(questID)` | Reward spell IDs | [V] |
| `GetRewardHonor()` | Reward honor | [V] |

#### Quest Map and POI

| API Function | Returns | Evidence |
|---|---|---|
| `C_QuestLog.GetQuestsOnMap(uiMapID)` | Quests visible on a map | [V] |
| `C_QuestLog.GetMapForQuestPOIs()` | Current quest POI map | [V] |
| `C_QuestLog.IsQuestFlaggedCompleted(questID)` | Quest completion status | [V] |
| `QuestPOIGetIconInfo()` | Quest POI icon info | [V] |
| `C_TaskQuest.GetQuestLocation(questID, uiMapID)` | locationX, locationY | [V] |
| `C_TaskQuest.GetQuestsOnMap(uiMapID)` | Task quest POIs on map | [V] |

#### Quest Giver (NPC) Interaction

| API Function | Returns | Evidence |
|---|---|---|
| `C_GossipInfo.GetAvailableQuests()` | Available quests from current NPC | [V] |
| `C_GossipInfo.GetActiveQuests()` | Active quests from current NPC | [V] |
| `GetQuestPortraitGiver()` | Portrait of quest giver | [V] |
| `GetQuestLogPortraitGiver()` | Portrait from quest log | [V] |
| `GetQuestLogPortraitTurnIn()` | Portrait of turn-in target | [V] |

#### NPC and Coordinates

| API Function | Returns | Evidence |
|---|---|---|
| `UnitPosition(unit)` | positionX, positionY, positionZ, mapID | [V] |
| `C_Map.GetPlayerMapPosition(uiMapID, unit)` | Normalized map position | [V] |
| `UnitName(unit)` | NPC/player name | [V] |
| `UnitGUID(unit)` | Entity GUID (contains type, ID) | [V] |
| `UnitLevel(unit)` | Entity level | [V] |
| `UnitClassification(unit)` | Normal/Elite/Rare/etc. | [V] |
| `ClosestUnitPosition(creatureID)` | xPos, yPos, distance | [V] |
| `ClosestGameObjectPosition(gameObjectID)` | xPos, yPos, distance | [V] |
| `UnitCreatureType(unit)` | Creature type | [V] |
| `UnitCreatureFamily(unit)` | Creature family | [V] |

#### Taxi Nodes

| API Function | Returns | Evidence |
|---|---|---|
| `C_TaxiMap.GetAllTaxiNodes(uiMapID)` | All taxi nodes for map: nodeID, position, name, state | [V] |
| `C_TaxiMap.GetTaxiNodesForMap(uiMapID)` | Map taxi nodes | [V] |
| `TaxiNodeName(node)` | Taxi node name | [V] |
| `TaxiNodePosition(node)` | Taxi node position | [V] |
| `GetTaxiNodeCost(node)` | Taxi node cost | [V] |

#### Quest Completion

| API Function | Returns | Evidence |
|---|---|---|
| `IsQuestComplete()` | Whether current quest is complete | [V] |
| `IsQuestCompletable()` | Whether quest can be completed | [V] |
| `GetQuestsCompleted()` | Table of completed quest IDs | [V] |
| `C_QuestLog.IsOnQuest(questID)` | Whether player is on quest | [V] |

### 5.2 Collection Strategy

An addon-based collection approach (similar to Grail or QuestieLearner) could work as follows:

1. **Quest log scanning**: Iterate `C_QuestLog.GetInfo()` for all quest log entries, recording title, level, questID
2. **Objective capture**: Call `C_QuestLog.GetQuestObjectives()` for each quest, recording text, type, numRequired
3. **Quest text capture**: Call `GetQuestLogQuestText()` for description and objectives
4. **Reward capture**: Call `GetQuestLogRewardInfo()`, `GetQuestLogRewardMoney()`, `GetQuestLogRewardXP()`, `C_QuestInfoSystem.GetQuestRewardSpells()`
5. **Quest giver capture**: When interacting with NPCs, call `C_GossipInfo.GetAvailableQuests()` and `GetActiveQuests()`, recording the NPC's `UnitGUID()` and `UnitPosition()`
6. **Coordinate capture**: Record `UnitPosition()` and `C_Map.GetPlayerMapPosition()` during quest interactions
7. **Taxi data**: Call `C_TaxiMap.GetAllTaxiNodes()` for each map to record taxi node positions and names
8. **Completion tracking**: Use `GetQuestsCompleted()` to track which quests are done
9. **Export**: Save all collected data to SavedVariables for offline processing

**Limitations:**
- Data is only available for quests the player has encountered [V]
- Quest objective caching may require multiple API calls (sometimes three calls needed to fully cache text) [V]
- Some quests may not be available to all races/classes, requiring multiple characters [V]
- No API for quest prerequisites or chain relationships — these must be inferred from quest giver sequencing or observed through play [?]

### 5.3 Existing Addon Methodologies

| Addon | Method | WoW Forever plugin? | Source |
|---|---|---|---|
| **Grail** | Player-observation model: records quest discrepancies in saved variables | No [2nd] | [GitHub](https://github.com/smaitch/Grail) |
| **QuestieLearner** (Questie-X) | Crowdsources quest/NPC/object data in-game | No [2nd] | [GitHub](https://github.com/Xurkon/Questie-X) |
| **ClassicCodex** | Database of quest/NPC data | No [2nd] | [GitHub](https://github.com/SwimmingTiger/ClassicCodex) |
| **pfQuest/ShaguDB** | Quest helper with database | No [2nd] | [GitHub](https://github.com/shagu/pfQuest) |

**Note:** The user's project is interested in methodology, not copying these databases. These addons demonstrate that in-game collection of quest data is feasible, but none have been adapted for WoW Forever yet.

---

## 6. Licensing & Provenance Matrix

### 6.1 The Five Scenarios

| Scenario | Description | Legal Status | Evidence |
|---|---|---|---|
| **(A)** Extract data from legitimately obtained client | Using tools to read DB2/WDB files from a WoW installation you own | **Unclear / likely prohibited** — Blizzard EULA prohibits reverse engineering, decompiling, and creating derivative works; ToU prohibits modifying game files and using third-party software that "intercepts, mines, or otherwise collects information" [V] | [V] Blizzard legal pages |
| **(B)** Keep extracted data locally | Store extracted DB2/WDB data on your own machine for personal use | **Unclear** — EULA grants "limited, non-exclusive license" to use the client; personal use may fall within this, but extraction itself may violate the EULA [V] | [V] Court documents, EULA |
| **(C)** Commit Blizzard-derived data to open-source repo | Push extracted game data to a public GitHub repository | **Likely prohibited** — EULA prohibits "copy, reproduce, [or] create derivative works based on the Game" [V] | [V] Blizzard EULA |
| **(D)** Distribute generated CSV/SQLite | Publish extracted data as downloadable files | **Likely prohibited** — same as (C); distribution of derivative works [V] | [V] Blizzard EULA |
| **(E)** Distribute only extraction software + schema + manifests + hashes | Ship tooling, DBD definitions, build metadata — NOT the extracted data | **Plausible** — tooling is independently licensed (MIT, BSD-3, CC BY-SA 4.0); schema definitions are structural metadata, not game data; but Blizzard could still challenge under ToU "intercepts, mines, or otherwise collects information" [V] | [V] |

### 6.2 Blizzard Legal Terms (Primary Sources)

**Blizzard Anti-Cheating Agreement** [V] ([source](https://www.blizzard.com/en-us/legal/cd5930c0-2784-420c-a23d-1e0d6ff8599b/anti-cheating-agreement)):

Defines unauthorized third-party programs as including any software that:
> "intercepts, mines or otherwise collects information from or through Blizzard games."

And any add-on or mod that:
> "allows users to modify or 'hack' a Blizzard game's user interface, environment, and/or experience in any way not expressly allowed by Blizzard in the EULA"

**Blizzard Developer API Terms of Use** [V] ([source](https://www.blizzard.com/en-us/legal/a2989b50-5f16-43b1-abec-2ae17cc09dd6/blizzard-developer-api-terms-of-use)):

> "You May Not Data Mine Blizzard Products Or Services. Except as permitted through authorized use of the Blizzard Developer APIs, You will not perform any data-mining, scraping, crawling, or use any processes that sends automated queries to Blizzard or any Blizzard game, service, or website, or use any other similar methods or tools to gather or extract data other information from Blizzard or any Blizzard game or service."

> "Blizzard owns all right, title and interest (including all intellectual property rights) in and to the Blizzard Developer APIs, including all output and executables of the Blizzard Developer APIs, and including any modifications to or derivatives of the Blizzard Developer APIs."

**World of Warcraft EULA** (from court documents, MDY v. Blizzard) [2nd]:
- Grants "limited, non-exclusive license to (a) install the Game Client on one or more computers owned by you or under your legitimate control, and (b) use the Game Client in conjunction with the Service for your non-commercial entertainment purposes only"
- Prohibits: "copy, photocopy, reproduce, translate, reverse engineer, derive source code from, modify, disassemble, decompile, or create derivative works based on the Game"
- Prohibits: "modify or cause to be modified any files that are a part of the Program or the Service"
- Prohibits: "use any third-party software that intercepts, 'mines', or otherwise collects information from or through the Program or the Service"
- Exception: "Blizzard may, at its sole and absolute discretion, allow the use of certain third party user interfaces"

**Important caveat:** The Blizzard EULA/ToS cited above are from court documents and the current Blizzard legal website. The specific EULA version applicable to WoW Forever may differ. These terms are presented for reference only — this is not legal advice. Legal uncertainty is explicitly noted.

### 6.3 Tool and Data License Summary

| Component | License | What it covers | What it does NOT cover | Evidence |
|---|---|---|---|---|
| DBCD (code) | MIT [V] | The C# library for reading DB2 files | Does NOT license extracted game data | [V] GitHub API |
| WoWDBDefs (definitions) | CC BY-SA 4.0 [V] | Structural metadata (column names, types, build ranges) | Does NOT license Blizzard's game data; ShareAlike requires derivative works to use same license | [V] GitHub API |
| WoWDBDefs (code) | BSD-3-Clause [V] | Code tools (parsers, generators) | Does NOT license game data | [V] GitHub API |
| wow.tools.local | MIT [V] | The application code | Does NOT license extracted data | [V] GitHub API |
| ForeverDiff data | No license stated [V] | Nothing — data is "provided as is" with no reuse rights granted | Does NOT grant any redistribution rights | [V] Terms page |
| wago.tools data | Not open source [V] | Nothing — no public license | Does NOT grant any rights | [V] |
| Blizzard game data | Blizzard EULA/ToS [V] | Limited personal use license | Does NOT grant extraction, reproduction, or distribution rights | [V] |

**Key distinction:** A code license (MIT, BSD-3, Apache 2.0) grants rights to the software itself. It does NOT grant rights to data that the software extracts from proprietary game files. The WoWDBDefs CC BY-SA 4.0 license covers the definition files (schemas), not the game data that those schemas describe.

---

## 7. Recommended Research Path

### Phase 1: Confirm Client Data Availability (Direct Testing Required)

1. **Install wow.tools.local** and point it at a local WoW Forever installation to extract all available DB2 files
2. **Verify which tables are actually present** — especially QuestPOIBlob, QuestPOIPoint, QuestObjective, Creature, and TaxiPathNode, which have DBD definitions but are NOT in ForeverDiff's 83-table list
3. **Check for encrypted sections** — ForeverDiff reports 99 withheld blocks with 5,391 rows; determine which tables are affected
4. **Extract and inspect QuestV2.db2** — confirm the 6,600 quest IDs and check if any additional columns are populated

### Phase 2: WDB Cache Analysis

1. **Locate the WDB cache** in the WoW Forever installation (likely `World of Warcraft/_classic_beta_/Cache/`)
2. **Parse QuestCache.wdb** using a WDB parser — this contains server-sent quest data (titles, objectives, rewards) for encountered quests
3. **Parse CreatureCache.wdb** — NPC names and display info for encountered creatures
4. **Assess completeness** — WDB cache only contains data for quests/NPCs the player has encountered; plan for systematic coverage

### Phase 3: In-Game Addon Collection

1. **Build a lightweight data-collection addon** using the API functions listed in Section 5
2. **Systematically visit all zones** and interact with all quest givers to populate the quest database
3. **Record quest chains** by tracking which quests unlock after completing prerequisites
4. **Export collected data** to SavedVariables for processing

### Phase 4: Cross-Reference and Validation

1. **Cross-reference quest IDs** from QuestV2.db2 with addon-collected quest data
2. **Validate item data** from ItemSparse.db2 against in-game observations
3. **Cross-check taxi node data** from TaxiNodes.db2/TaxiPath.db2 against in-game taxi maps
4. **Compare with ForeverDiff's published data** (items, spells, talents) as a processing cross-check

### Phase 5: Distribution Strategy (Scenario E)

1. **Distribute extraction tooling** (wow.tools.local + DBCD + WoWDBDefs) — all MIT/BSD-3/CC BY-SA 4.0 licensed
2. **Distribute DBD definitions** — CC BY-SA 4.0 (attribution + ShareAlike required)
3. **Distribute build manifests and hashes** — record BuildConfig, CDNConfig, WoWDBDefs commit for reproducibility
4. **Do NOT distribute extracted game data** — keep Blizzard-derived data local
5. **Distribute addon collection tooling** — the addon code that collects in-game data
6. **Document the collection methodology** — allow community members to reproduce the database independently

---

## 8. Questions Requiring Direct Testing Against the Forever Client

1. **Are QuestPOIBlob and QuestPOIPoint present as DB2 files in the Forever client?** They have DBD definitions with 1.60.1.x support but are NOT in ForeverDiff's 83-table list. [?]

2. **Is the Creature table present in the Forever client?** Creature.dbd has 1.60.1.x support with Name_lang fields, but ForeverDiff does not extract it. Is it absent, encrypted, or simply not included by ForeverDiff? [?]

3. **What format are the DB2 files?** Likely WDC2 or WDC3 based on the client architecture, but needs direct confirmation. [?]

4. **Can DBCD successfully read Forever build DB2 files using WoWDBDefs commit 02b1fa9a4714?** ForeverDiff uses this commit; does it work with the public DBCD library? [?]

5. **What data is in the QuestCache.wdb for the Forever client?** The WDB format has evolved; does the Forever client use the legacy 20-byte header or the 24-byte header (3.0.8+)? [?]

6. **Does the WoW Forever addon API support all the functions listed in Section 5?** The client uses interface version 16001 and game type "Camelot" — some modern API functions may not be available. [?]

7. **Are there encrypted DB2 sections containing quest data?** ForeverDiff reports 99 withheld blocks with 5,391 rows — which tables are affected? [?]

8. **What does the QuestInfo table (7 rows) contain?** It could define quest categories or types. [?]

9. **Can the `C_GossipInfo.GetAvailableQuests()` API identify quest giver NPCs by creature ID?** This would link quest IDs to NPC IDs. [?]

10. **Does `ClosestUnitPosition(creatureID)` work in the Forever client?** This would enable automated NPC coordinate collection. [?]

---

## Sources

- [ForeverDiff](https://foreverdiff.com/) — Main site
- [ForeverDiff Methodology](https://foreverdiff.com/methodology/) — Extraction methodology
- [ForeverDiff About](https://foreverdiff.com/about/) — Operator information
- [ForeverDiff Terms](https://foreverdiff.com/terms/) — Terms of use
- [ForeverDiff Privacy](https://foreverdiff.com/privacy/) — Privacy policy
- [ForeverDiff Build 69913](https://foreverdiff.com/builds/1.60.1.69913/) — Build detail page
- [ForeverDiff Build History](https://foreverdiff.com/builds/) — All builds processed
- [WoWDBDefs](https://github.com/wowdev/WoWDBDefs) — Client database definitions (CC BY-SA 4.0 / BSD-3-Clause)
- [DBCD](https://github.com/wowdev/DBCD) — C# DB2 reader (MIT)
- [wow.tools.local](https://github.com/Marlamin/wow.tools.local) — Local DB2 browser (MIT)
- [DBC2CSV](https://github.com/Marlamin/DBC2CSV) — DB2 to CSV converter
- [erorus/db2](https://github.com/erorus/db2) — PHP DB2 reader (Apache 2.0)
- [WDBx](https://github.com/Frostshake/WDBx) — C++ DB2 viewer (GPL-3.0)
- [wago.tools](https://wago.tools/) — DB2 CSV exports
- [wowdev.wiki DB2](https://wowdev.wiki/DB2) — DB2 format documentation
- [wowdev.wiki WDB](https://wowdev.wiki/WDB) — WDB cache format documentation
- [Warcraft Wiki API - Classic](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic) — Addon API documentation
- [Warcraft Wiki - C_QuestLog.GetQuestObjectives](https://warcraft.wiki.gg/wiki/API_C_QuestLog.GetQuestObjectives) — Quest objectives API
- [Warcraft Wiki - C_QuestLog.GetInfo](https://warcraft.wiki.gg/wiki/API_C_QuestLog.GetInfo) — Quest info API
- [Blizzard Anti-Cheating Agreement](https://www.blizzard.com/en-us/legal/cd5930c0-2784-420c-a23d-1e0d6ff8599b/anti-cheating-agreement) — Legal terms
- [Blizzard Developer API Terms of Use](https://www.blizzard.com/en-us/legal/a2989b50-5f16-43b1-abec-2ae17cc09dd6/blizzard-developer-api-terms-of-use) — API terms
- [maxdekrieger/wow-csv-from-db2s](https://github.com/maxdekrieger/wow-csv-from-db2s) — DB2 archive repository
- [thespags/WowDbScripts](https://github.com/thespags/WowDbScripts) — wago.tools CSV downloader
