# M0 report: what Forever data actually exists (as of 2026-09-21)

**Evidence tags used throughout**
- **[V]** verified first-hand: I read the file / ran the computation.
- **[2nd]** reported by another project's file or docs; I did not reproduce it.
- **[?]** unverified: no access or no evidence. Not filled in from general WoW knowledge.

## 0. Access limits

`wago.tools` and `us.version.battle.net` were blocked by the sandbox allowlist (re-tested at the end of the session, still blocked). `wago.tools` also disallows automated fetch via robots.txt. Consequently:

- Table row counts and headers are first-hand only for CSVs that other repos vendor (ATT, ForeverGuide).
- The current build number could not be checked against Blizzard's version service.
- Nothing in this report comes from Wowhead. It was not accessed or scraped.

## 1. Sources inspected

| Source | Commit (shallow clone, 2026-09-21) | License |
|---|---|---|
| ATTWoWAddon/AllTheThings | `8e25511677df4ea5c3d0322009eafc18f203ffd3` | MIT [V] |
| RevoltLive85/ForeverGuide | `561023695a0364024e290f2d39b385d24d6cfad3` | none found [V] |
| danielcosta42/lodestar | `8964d0ca325919ce33e9c40693ad204ee9203e0c` | MIT [V] |
| Questie/QuestieDB | `baa0998d49695c70a1fb8fec559fa9169e9adf33` | GPL-3.0 [V] |
| Questie/Questie | `e99fc5fc4ef93e32f1c1c8097eaa13cbb71066b9` | no root license file seen [V] |
| TylerAkins/forever-quest-markers | `5177a8f0ea2fbb7525d2921007202fb4d01a1680` | GPLv3 [V] |
| omegahelixwow/wow-classic-beta-spells | `e34134d36a8cdb549dff8e643e7241b39f29166e` | none found [V] |

Key paths read:
- ATT: `.contrib/.db/forever/**` (excluding `zzOLD`, `.config`), `.contrib/.db/forever/.config/.wago/*.1.60.1.69913.csv`, `.config/forever.config`, `.config/constants/maps.lua`, `.contrib/Harvesters/Database Harvester/Builds.txt`
- ForeverGuide: `data-src/db2/*.1.60.1.69913.csv`, `data-src/forever.json`, `Data/README.md`, `tools/PHASE1_NOTES.md`
- lodestar: `docs/forever.md`, `ForeverData.lua`
- QuestieDB: `data/{Classic,Forever}/*`, `support/Forever/provenance.json`, `docs/forever-data.md`

## 2. Build number

Latest found: **1.60.1.69913**. It is the first client update, a day after the beta opened on 2026-09-17. It is referenced by ATT's vendored CSVs, ForeverGuide, lodestar and a third-party issue dated 2026-09-20. **[2nd]** Not checked against Blizzard.

Other builds seen: 69876 (a datamine tracker's "latest" as of Sept 17; also in ATT's `Builds.txt`) and 69893 (first build per a sim repo; Questie's Forever data was generated against it).

Inconsistency: ATT's `forever.config` declares `DataPatch = 1.60.1.69893` while its vendored CSVs are 69913.

## 3. DB2 tables

| Table | Exists? | Rows | Important fields | Useful? |
|---|---|---|---|---|
| QuestV2 | Yes [V] | 6,600 | ID, UniqueBitFlag, UiQuestDetailsThemeID | Existence list only |
| QuestPOIBlob | Yes [V] | 54 | ID, MapID, UiMapID, Flags, NumPoints, QuestID, ObjectiveIndex, ObjectiveID | 22 quests only, all absent from Questie's Era set |
| QuestPOIPoint | Yes [V] | 99 | ID, X, Y, Z (world integers), QuestPOIBlobID | Real coordinates, tiny |
| QuestInfo | Yes [V] | 7 | ID, InfoName_lang, Type, Modifiers, Profession | Minor labels |
| QuestLabel | Yes [V] | 2 | ID, LabelID, QuestID | Minor |
| QuestObjective | Reported absent [2nd] (lodestar: 404 at wago; also missing from ForeverGuide's db2 folder) | — | — | Would have been key |
| QuestV2CliTask | Reported absent [2nd] | — | — | — |
| Map | Yes [2nd] (Questie, build 69893) | 73 | ID, MapName_lang, AreaTableID (projection) | Yes |
| AreaTable | Yes [V] | 1,372 | ID, AreaName_lang, ContinentID, ParentAreaID, ContentTuningID, flags | Yes |
| UiMap | Yes [V] | 60 | ID, Name_lang, ParentUiMapID, Type, System | Yes |
| UiMapAssignment | Yes [V] | 61 | UiMapID, MapID, AreaID, UiMin_0/1, UiMax_0/1, Region_0–5, OrderIndex | Yes: transform verified (section 5) |
| TaxiNodes | Yes [V] | 100 | ID, Name_lang, Pos_0–2, ContinentID, Flags, MountCreatureID_0/1 | Yes; contains junk rows |
| TaxiPath, TaxiPathNode | [?] | ? | ? | Needed for travel times |
| Creature | [?] | ? | ? | Names only, if present |
| Item | Yes [V] | 31,675 | ID, ClassID, SubclassID, InventoryType, IconFileDataID, ContentTuningID, … (17 cols; no names) | Row count not reconciled with in-game items |
| ItemSearchName | Yes [V] | 6,621 | ID, Display_lang, RequiredLevel, AllowableClass, AllowableRaces_0/1, ItemLevel | Item names live here |
| ItemSparse | [?] (used by other projects; Questie notes a failed Item snapshot) | ? | — | — |
| ItemEffect / ItemXItemEffect | Yes [V] | 12,571 / 12,565 | ItemID, ItemEffectID, SpellID | Later |
| ItemBonus, SpellEffect | Yes [V] but ATT passes both through a cleaner | 1,124 / 42,449 | — | Counts are not raw |
| SkillLine | Yes [2nd] | 154 | Questie projection | Yes |
| SkillLineAbility | Yes [V] | 7,824 | SkillLine, Spell, ClassMask, RaceMasks_0/1 | Later |
| FactionTemplate | Yes [2nd] | 453 | ID, EnemyGroup | Minor |
| Faction (reputation) | [?] | ? | ? | — |
| ChrRaces | Yes [2nd] | 58 | ID, Name_lang, PlayableRaceBit, FactionID, Alliance | Yes |
| QuestSort | Yes [2nd] | 39 | ID, SortName_lang, UiOrderIndex | Minor |
| ContentTuning | Yes [V] | 98 | ExpansionID, level squish/offsets, XpMultQuest (all = 1) | Maybe |
| WorldMapOverlay | Yes [V] | 1,081 | UiMapArtID, texture size/offsets, hit rect, AreaID_0–3 | Map art; later |
| QuestXP | [?] | ? | — | Questie says QuestXP rows alone lack per-quest inputs |
| Spell, SpellName, Trait* | Used by other projects; not read by me [?] | ? | — | Not needed |
| Achievement, Criteria, CriteriaTree, ModifierTree, Holiday, TransmogSet(+Item), BattlePetSpecies | Yes [V] | 233 / 1,353 / 1,951 / 2,578 / 22 / 7(+63) / 112 | — | Low relevance |

Cross-build check [V/2nd]: AreaTable (1,372), UiMap (60) and UiMapAssignment (61) have identical row counts at 69893 (Questie) and 69913 (ATT).

Table notes [V]:
- **UiMap** contains the new zones: 2482 Mount Hyjal, 2521 Zephras Isle, 2524 Darkspear Islands, 2548 Riverglades, 2652 Shen'dralas. Their area IDs are 616, 16593, 16606, 16591 and 16651. UiMap and area IDs are different ID spaces.
- **UiMapAssignment** MapIDs: 0, 1, 30, 489, 529, 2991, 2997.
- **AreaTable** has rows on ContinentIDs (2832, 2853, 2940, …) with no UiMapAssignment. They look like non-Forever or prototype areas (not verified).
- **TaxiNodes** by continent: 0 → 51, 1 → 47, 30 → 2. It includes Riverglades and Hyjal nodes and junk rows (`zzOLD…`, `Quest Path …`, `Programmer Isle`).

## 4. Client vs server

**Client-side (in DB2)** [V]: quest ID list, POI for 22 quests, zone/map/taxi structure, item and spell tables.

**Server-side** (inferred from QuestV2 having three columns [V] and QuestObjective being absent [2nd]): quest title, level, objectives, givers, rewards, NPC placement. Details such as throttling of quest queries and the client cache files `Cache/WDB/*.wdb` come from lodestar and ForeverGuide notes [2nd]. I have not tested them.

## 5. Spatial data and the transform check

**Spatial sources in DB2:** TaxiNodes (world x/y/z), QuestPOIPoint (world x/y/z), UiMapAssignment (world regions per UiMap). AreaTable and UiMap have hierarchy only. No NPC, creature or object coordinates were found.

**Transform check [V]:** ATT's 14 flight-path map coordinates were compared against TaxiNodes world positions through UiMapAssignment. One of four axis orientations fit:

```
map_x% = 100 - 100 * (worldY - Region_1) / (Region_4 - Region_1)
map_y% = 100 - 100 * (worldX - Region_0) / (Region_3 - Region_0)
```

Mean absolute error is 0.09 map-% (max 0.43). Every other orientation was off by 19–33 map-%. This includes Riverglades' Farholde Keep (error 0.01 / 0.03). Caveat: 14 points on a handful of maps. Mulgore, Eastern Plaguelands, Redridge and Stormwind City (the maps QuestieDB says changed frames vs Era) are barely covered and need their own tests.

## 6. ATT's Forever database

**Extraction:** A throwaway tolerant parser handled 53 files under `.contrib/.db/forever` (excluding `.config` and `zzOLD`). It found **1,537 quest records, all unique IDs**. An independent regex count agrees exactly.

**Overlap with the client:**
- 1,372 are in QuestV2 (89.3%).
- 165 are not in QuestV2, and 156 of those are Era quests (Darkmoon Faire 41, Alterac Valley 22, Warsong Gulch 12, Barrens 11, Arathi Basin 10, Lunar Festival 10, …). ATT alone cannot prove a quest exists in Forever.
- 42 are not in Questie's Era set.
- **33 of the 3,065** QuestV2 IDs that Questie's Era set lacks (1.1%) are in ATT (30 have IDs ≥ 30000). They are mostly new Elwynn and Dun Morogh quests and Zephras Isle's five.
- Riverglades, Mount Hyjal and Shen'dralas have **no quests** in ATT. Riverglades has one flight path.

**Field coverage across all 1,537 quests:**

| Field | Count | Share |
|---|---|---|
| Name (trailing code comment, not a field; sometimes decorated with "[Zone]") | 1,513 | 98.4% |
| Coordinates (`coord`/`coords`, map %) | 1,436 | 93.4% |
| Giver NPC (`qg`) | 1,200 | 78.1% |
| Level (`lvl`, semantics unverified) | 1,123 | 73.1% |
| Prerequisite (`sourceQuest(s)`) | 819 | 53.3% |
| At least one `objective()` | 543 | 35.3% |
| At least one item child (rewards? unverified) | 412 | 26.8% |

**Objectives:** 794 `objective()` entries. 765 carry a target hint (item 423, NPC 181, object 17, provider list 139, `cr` 5). 269 have their own coordinates. 29 have neither.

**Givers:** 574 unique giver NPC IDs, of which 565 are in Questie's Era NPC set. The 9 that are not include six IDs ≥ 250,000, for example 251361, 251362 and 251368 (Zephras Isle).

**Flight paths:** 14 `fp()` entries, all present in TaxiNodes. TaxiNodes has 86 nodes without an ATT entry (10 of them junk).

**Parseability into the proposed schema:** Feasible, with caveats.
- Key syntax varies (`coord` vs `["coord"]`, `coord` vs `coords`, `sourceQuest` vs `sourceQuests`).
- Names are comment-only.
- Objective targets are untyped providers.
- Rewards are not distinguished from other item children.
- There are no spawn tables.
- Data belongs in an assertion/placement layer, not the game-data layer.

## 7. Quest coverage by source

For the 3,065 QuestV2 IDs not in Questie's Era set, ATT or ForeverGuide's overlay has some record for **791 (25.8%)**.

| Field | ATT (33 new IDs) | ForeverGuide overlay (787 new records)* |
|---|---|---|
| Name | 30 | 773 |
| Level | 4 | 705 |
| Objectives | 11 | 184 |
| Giver NPC | 28 | 40 |
| Coordinates | 29 | 116 (start positions) |
| Prerequisites | 22 | 125 (across all 823 records) |
| Rewards | 8 (item children) | none |

\*ForeverGuide's overlay mixes in-game scan data with facts from RestedXP guides (CC BY-NC-SA 4.0). Don't ingest it (section 10).

DB2 supplies coordinates for 22 quests through POIs and nothing else beyond IDs.

**Questie's Era data over the 3,535 IDs shared with QuestV2** [V] (legacy data, not Forever-verified):

| Field | Count | Share |
|---|---|---|
| Name | 3,535 | 100% |
| Started by | 3,491 | 98.8% |
| Finished by | 3,493 | 98.8% |
| Required level | 3,535 | 100% |
| Quest level | 3,533 | 99.9% |
| Objectives text | 3,280 | 92.8% |
| Structured objectives | 1,857 | 52.5% |
| Prerequisite (single) | 1,920 | 54.3% |
| Prerequisite (group) | 42 | 1.2% |
| Exclusive-to | 255 | 7.2% |
| Next in chain | 1,431 | 40.5% |
| Reputation reward | 1,959 | 55.4% |

Questie's quest schema has no item, money or XP reward fields. Its Forever tables are Era data with converted coordinates and identical entity counts: 4,244 quests, 10,119 NPCs, 6,645 objects and 14,889 items. They contain no Forever-new entities. Era quest IDs max out at 9,665.

## 8. Why the quest counts differ

| Number | What it is | Status |
|---|---|---|
| ~1,000 (ForeverGuide) | Quests confirmed by a partial in-game scan on Sept 18–19, one account. The notes give 754 Forever-only quests with titles. The server was throttling and later stopped answering. | [2nd] |
| 2,824 (lodestar) | QuestV2 (69913) IDs not in the Anniversary 2.5.6.69795 QuestV2 | All 2,824 are in QuestV2 [V]; baseline not reproduced [?] |
| 2,844 | QuestV2 IDs ≥ 30000 | Reproduced exactly [V] |
| 1,795 | QuestV2 IDs not in Era 1.15.9.69722 QuestV2 | Not reproduced [?] |
| 3,065 | QuestV2 IDs not in Questie's Era set (2,844 ≥ 30000; 221 below) | Mine [V] |
| 5,329 (Wowhead) | Total quest entries in its Forever database, not a delta | [?] not accessed |
| 6,600 / 4,244 | QuestV2 total / Questie Era total | [V] |

The counts differ in baseline (which old set is subtracted), measure (total vs delta), and test of existence (ID in a table vs quest the server answers). ForeverGuide's notes say every ID from 1 to 999 "exists" on the server, including placeholder rows titled `None` and `<UNUSED>`. They also say new quests reuse some old IDs (e.g. 490, 785). **QuestV2 membership is not proof of a real, obtainable quest**, so the schema needs per-quest evidence flags.

Also: 709 Era IDs are absent from QuestV2 [V].

## 9. Coverage summary

| Data | DB2 | ATT | Community | Unknown |
|---|---|---|---|---|
| Quest IDs | 6,600, existence only | 1,537 (1,372 valid) | — | Which are real and obtainable |
| Quest names | None | 1,513 in comments | Scan or WDB cache | — |
| Levels | None | 1,123 | Scan | Quest vs required level |
| Objective text and targets | None | 543 quests, partial | Most of it | — |
| Objective locations | POIs for 22 quests | Partial | Most of it | — |
| Rewards | None | 412 with item children | Yes | XP, money, choices |
| Quest chains | None | 819 prerequisites | Yes | Breadcrumbs, exclusives for new quests |
| Giver identity | None | 1,200 | Yes | — |
| Giver locations | None | 1,436 (map %) | Yes | Accuracy on changed-frame maps |
| NPC locations | None | Only via quests | Yes | — |
| Creature spawns | None verified | None | Yes | — |
| Flight nodes | 100 (world coordinates) | 14 | — | TaxiPath and TaxiPathNode |
| Zone hierarchy | AreaTable, UiMap | Some | — | — |
| World↔map transform | UiMapAssignment (validated on 14 points) | — | — | More points |
| Quest XP | ContentTuning XpMultQuest = 1 | — | — | QuestXP table |

## 10. Licensing and provenance flags

- **ForeverGuide:** no license file, so all rights are reserved by default. Its `Data/README.md` says its overlay includes facts from RestedXP guides (CC BY-NC-SA 4.0). It also commits a raw SavedVariables dump (`data-src/sv/…`). Do not ingest.
- **Questie / QuestieDB:** GPL-3.0. Upstream provenance of the Era data is not stated in the Questie docs I read (ForeverGuide attributes it to cmangos/vmangos). The Forever tables are converted Era data.
- **ATT:** MIT for the repo. Origin of its coordinates is unknown. Its wago CSVs are Blizzard-derived, and some tables are pre-cleaned.
- **Wowhead:** Fanbyte's EULA (last updated May 14, 2025) bars crawlers and data-mining tools and reproducing or creating derivative works. lodestar deleted its Wowhead scraper citing this. Not used here.
- **Blizzard DB2 and map art:** no explicit redistribution grant found. Other projects committing the CSVs is not evidence of permission.
- **wago.tools:** terms not retrieved.
- **Unresolved:** whether base wago CSVs match the hotfixed data the client actually uses.

## 11. Unverified register (needs network access to close)

1. Current build vs Blizzard's version service (`us.version.battle.net`).
2. Existence, row counts and columns of Map, TaxiPath, TaxiPathNode, Creature, Faction, ItemSparse, Spell, SpellName and QuestXP at 69913.
3. QuestObjective and QuestV2CliTask absence (lodestar's claim; consistent with vendored files).
4. lodestar's 2,824 and 1,795 baselines (need Anniversary and Era QuestV2).
5. Whether the Region_* transform holds on Mulgore, Eastern Plaguelands, Redridge and Stormwind City.
6. Semantics of ATT's `lvl` and of item children in quests.
7. Client cache file (`Cache/WDB/*.wdb`) contents and format.
8. Whether new-content zones are reachable during the beta (lodestar says level cap 30, no Riverglades or Shen'dralas).

## 12. Recommended M1

1. **Build registry:** Record each build with its source and date (69876, 69893, 69913). Query Blizzard's version service directly.
2. **Table probe:** A small importer that fetches a justified table list and writes a generated manifest of existence, row counts and columns. That closes items 1–2 of the register and diffs the next build.
3. **Quest shell:** One quest row per QuestV2 ID with evidence flags (client ID, Era baseline, ATT, server-confirmed). Attributes come from assertions only.
4. **ATT importer:** Into the assertion layer, filtered against QuestV2, including flight paths.
5. **Transform tests:** Extend the flight-path check to Mulgore, Eastern Plaguelands, Redridge and Stormwind City.
6. **Harvest contract (design only):** Define the schema for cache-file and in-game recorder exports, and test on a real client.
7. **Defer:** Questie ingestion, the ForeverGuide overlay, anything from Wowhead.

## 13. Reproducing this report

```
mkdir m0 && cd m0
sh /path/to/scripts/run_m0.sh
```

`setup_sources.sh` fetches the exact commits above. `att_parse.py` is a throwaway parser, not the M1 importer. The scripts read the vendored CSVs in place and copy no Blizzard-derived data.
