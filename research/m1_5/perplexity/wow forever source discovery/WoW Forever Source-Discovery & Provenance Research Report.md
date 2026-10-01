# WoW Forever Source-Discovery & Provenance Research Report

**Date:** September 21, 2026
**Scope:** Independent source-discovery investigation for World of Warcraft: Forever (Classic Anniversary / Anniversary realms), patch 1.60.x

---

## Executive Summary

### Potentially New Sources Found: 17

After extensive web searching across GitHub, GitLab, community sites, addon directories, database viewers, and data-extraction tool repositories, I identified **17 potentially new sources** not in the user's known list (AllTheThings, Questie, ForeverGuide, lodestar, forever-quest-markers, wow-classic-beta-spells, 60.tools, ForeverTome, Warcraft Tavern, Blizzard announcements).

### Most Interesting Sources

1. **ForeverDiff** (foreverdiff.com) — The single most interesting new source. Contains a WoW Forever database of every player spell, equippable item, talent, and recipe that changed against Classic Era, with exact numerical comparisons. Claims data is "read from Blizzard's own game client." Includes 14,208 spell changes, 9,055 item changes, 467 talent changes, 3,707 recipe changes, 175 zone changes, and 88 item-set changes. Synced Sep 19, 2026. However, the "How we read this" and "Build history" pages could not be fetched (JavaScript-rendered), so the extraction methodology is unverified. No license or redistribution terms stated.

2. **ForeverTalents** (github.com/dan-in-it/ForeverTalents) — WoW Forever talent calculator with 470 talents across 27 trees and 40 racial abilities. Self-contained HTML files with embedded data. Data provenance unstated; no repository license; artwork attributed to Blizzard. GitHub Pages hosted.

3. **Travelcraft / WoW Forever Atlas** (benjamh681.github.io/wow-forever-atlas) — Interactive map and route planner for WoW Forever with zones, level ranges, dungeons, ship routes, and travel times. GitHub-hosted. No license stated.

4. **ForeverWisp** (foreverwisp.com) — Free leveling addon in development for WoW Forever with route data including quest names, NPC names, coordinates, quest IDs, prerequisites, and profession stops. Currently uses Classic reference steps, not yet beta-ready. No license stated.

5. **WoW Forever News** (wowforevernews.com) — Documents an entity-tree architecture with JSON datasets and a Supabase database, including foreign-key relationships (Item.source → NPC.id, Quest.reward → Item.id). Plans a census pipeline with an in-game /who scanner addon. No license stated; data provenance unstated.

6. **WoW Forever Builds** (wowforeverbuilds.com + foreverbuilds.gg) — Two separate talent calculator and guide sites. wowforeverbuilds.com includes a Character Export Addon (/wfb command) and Legacy planner. No data license stated.

7. **wow-forever.top** — Quest and item directory with 16 indexed quest routes, 1,203 unique item names, and dungeon quest rewards. Links item/quest IDs to Wowhead Forever. Described as "sourced beta records." No API or machine-readable export.

### Sources That Appear Genuinely Independent

- **ForeverDiff** — Claims to read data directly from Blizzard's game client. If accurate, this is independent of Wowhead, Questie, and ATT. However, the extraction method is unverified.
- **ForeverTome quest database** (already known) — Quest data from player observations, explicitly recording build 1.60.1.69893. This is player-observed data, not derived from DB2 extraction.
- **ForeverWisp** — Route data appears to be independently authored, though currently based on Classic reference steps.
- **Travelcraft** — Map and travel-time data appears independently compiled, though provenance is unstated.

### Sources with Useful Machine-Readable Data

| Source | Machine-readable? | Format |
|---|---|---|
| ForeverDiff | Not stated (no API/export found) | Web display only |
| ForeverTalents | Partially — data embedded in HTML/JS files | HTML/JS |
| Travelcraft | GitHub-hosted but format unstated | JS app |
| WoW Forever News | Yes — JSON datasets, Supabase DB, URL endpoints | JSON, SQL |
| ForeverTalents (GitHub) | Partially — embedded in HTML | HTML/JS |
| wow-forever.top | No | Web display |
| WoWDBDefs (tool) | Yes — DBD to JSON/XML conversion | JSON, XML |
| WDBx (tool) | Yes — exports CSV, JSON, SQL | CSV, JSON, SQL |
| nexus-devs/wow-classic-items (tool) | Yes — JSON data | JSON (npm package) |
| QuestieTDB DESIGN.md | Yes — Lua tables, CBOR encoding | Lua, CBOR |

### Major Licensing Concerns

1. **None of the WoW Forever-specific community sites state a data license or redistribution terms.** ForeverDiff, ForeverTalents, Travelcraft, ForeverWisp, WoW Forever Builds, wow-forever.top, WoW Forever News, and ForeverBuilds.gg all lack explicit licenses for their data. Redistribution rights are unclear.
2. **Game data licensing ≠ code licensing.** An MIT/GPL repository license covers the code, not the underlying game data extracted from Blizzard's client. This applies to Questie, ClassicCodex, pfQuest, and all addon-embedded databases.
3. **Wowhead Forever** data is populated from beta datamining and the Wowhead Looter addon. Wowhead's terms of service and scraping policies are not stated on the database page. Wowhead is owned by Fanbyte (© 2026).
4. **DB2/DBC extraction tools** (WDBx, WoWDBDefs, DBCD, erorus/db2, wow.export) can read game client data but do not themselves contain WoW Forever datasets. Their use to extract data from the WoW Forever client would produce data derived from Blizzard's proprietary files.
5. **Server emulator databases** (VMaNGOS, CMaNGOS, TrinityCore) contain Vanilla/TBC-era data reconstructed from private server development, not from WoW Forever. Their data lineage traces to Elysium/LightsHope, not to Blizzard's Forever client.

### Major Gaps That Still Remain

1. **No publicly available, licensed, machine-readable WoW Forever quest database exists.** ForeverTome has 29 entries; ForeverDiff has change-comparisons but not full quest records; Wowhead Forever has the most complete data but no public API and unclear redistribution rights.
2. **NPC spawn locations and coordinates for WoW Forever are not publicly available in a structured dataset.** Questie-X's QuestieLearner could theoretically collect this, but no WoW Forever plugin exists yet.
3. **Object locations** (herbs, mining nodes, chests, quest objects) for WoW Forever new zones (Zephras Isle, Riverglades, etc.) are not available in any structured format.
4. **Flight path / taxi route data** for WoW Forever is not available as a dataset. Travelcraft shows travel times visually but does not expose structured data. The Warcraft Wiki documents the `C_TaxiMap.GetAllTaxiNodes` API function, which could be used in-game to collect this data.
5. **Build-specific data** is a concern. ForeverTome records build 69893; ForeverDiff references "the compared build" and a "Build history" page that could not be fetched. No source explicitly identifies builds 69876 or 69913. Data from one build may not be identical to another.
6. **Quest prerequisites, quest chains, and quest completion data** for WoW Forever are almost entirely absent from structured datasets. ForeverWisp plans route data but is not yet beta-ready.
7. **No source provides a complete, redistributable WoW Forever DB2 dump.** The tools to create one exist (WDBx, WoWDBDefs, DBCD), but no one has published the extracted data with a clear license.

---

## Complete Source Table

### Category A: Potential Data Sources

| # | Name | URL | Type | Data Contents | WoW Forever? | Build/Version | Machine-Readable? | Independent? | License | Redistribution | Ingestion Suitability | Category |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | ForeverDiff | [foreverdiff.com](https://foreverdiff.com/) | Web database | 14,208 spell changes, 9,055 item changes, 467 talent changes, 3,707 recipe changes, 175 zone changes, 88 item-set changes, 58 faction changes, 118 enchant changes vs Classic Era | Yes | Synced Sep 19, 2026; build not stated on main page | Not stated (no API found) | Claims "read from Blizzard's own game client" — unverified | None stated | Unclear | Potentially useful as corroboration; extraction method unverified | A/D |
| 2 | ForeverTalents | [github.com/dan-in-it/ForeverTalents](https://github.com/dan-in-it/ForeverTalents) | GitHub repo / web app | 470 talents across 27 trees, 40 racial abilities, build-code formats (WFD1, WFS1, WFS2) | Yes | Not stated | Partially (embedded in HTML/JS) | Unstated; no upstream source identified | No repo license; Cinzel font under SIL OFL; artwork © Blizzard | Unclear | Data could be extracted from HTML/JS; provenance unknown | A/D |
| 3 | Travelcraft (WoW Forever Atlas) | [benjamh681.github.io/wow-forever-atlas](https://benjamh681.github.io/wow-forever-atlas/) | GitHub Pages web app | Interactive map, zone level ranges, dungeons, ship routes, travel times | Yes | Not stated | Partially (JS app source on GitHub) | Unstated | No license stated | Unclear | Travel-time and zone-range data could be useful; provenance unknown | A/D |
| 4 | ForeverWisp | [foreverwisp.com](https://www.foreverwisp.com/) | Web site + addon | Route data: quest names, NPC names, coordinates, quest IDs, min levels, prerequisites, profession stops, trainer visits | Yes (in development) | Beta target; no build number | Not stated | Appears independently authored; currently uses Classic reference steps | No license stated | Unclear | Route/quest data could be useful once beta-ready; not yet available | A/D |
| 5 | WoW Forever News | [wowforevernews.com](https://wowforevernews.com/) | Web site | Entity tree with JSON datasets, Supabase DB, foreign-key relationships; planned census pipeline with in-game /who scanner | Yes | "July 2026" reference; no build number | Yes (JSON datasets, Supabase, URL endpoints) | Unstated | No license stated | Unclear | Architecture suggests structured data exists; actual datasets not publicly accessible | A/D |
| 6 | WoW Forever Builds | [wowforeverbuilds.com](https://wowforeverbuilds.com/) | Web site | Talent calculator data (51-point trees), Legacy planner (3 trees, 16 points), community guides, Character Export Addon (/wfb) | Yes | Pre-release; no build number | Shareable build links; Character Export Addon | Data "labeled by source"; may change during beta | No data license stated | Unclear | Talent and Legacy data could be useful; source labeling is a positive signal | A/D |
| 7 | ForeverBuilds.gg | [foreverbuilds.gg](https://foreverbuilds.gg/) | Web site | Talent calculator for 9 classes, 27 specs | Yes | Not stated | Not stated | Unstated | No license stated | Unclear | Overlaps with wowforeverbuilds.com; less detailed | A/D |
| 8 | wow-forever.top | [wow-forever.top](https://wow-forever.top/) | Web site | 16 indexed quest routes, 1,203 unique item names, dungeon quest rewards, boss loot | Yes | "Sourced beta records"; no build number | Not stated | Links to Wowhead Forever; not a mirror | No license stated | Unclear | Quest reward and dungeon loot data could be useful as corroboration | A/D |
| 9 | QuestieTDB | [github.com/Questie/QuestieTDB](https://github.com/Questie/QuestieTDB) | GitHub repo | Questie's data model for quests, NPCs, items, objects; 9 non-English locales; SoD and Classic+ corrections | Questie covers Classic Anniversary (uses QuestieDB_TBC.toc) | Mentions build 69109 for validation | Yes (Lua tables, CBOR encoding, public API) | Derived from Questie's existing data; explicitly not from VibeQuest | Not stated on DESIGN.md page | Unclear | Direct ingestion would duplicate Questie data; QuestieTDB is a reorganization, not new data | A/E |
| 10 | Grail | [github.com/smaitch/Grail](https://github.com/smaitch/Grail) | GitHub addon | Quest database: completion status, prerequisites, level/race/class/reputation requirements, quest locations, reputation rewards, achievement tracking | Not stated | Not stated | Saved variables (Grail.lua) | Player-observed via in-game quest acceptance/turn-in | Not stated | Unclear | Player-observed quest data model is interesting; WoW Forever coverage unverified | A/D |

### Category B: Evidence / Corroboration Sources

| # | Name | URL | Type | Data Contents | WoW Forever? | Notes | Category |
|---|---|---|---|---|---|---|---|
| 11 | Wowhead Forever | [wowhead.com/forever/database](https://www.wowhead.com/forever/database) | Web database | Items, NPCs, quests, spells, achievements, mounts, battle pets, factions, toys, recipes | Yes (Patch 1.60.1) | Populated from beta datamining + Wowhead Looter addon. No public API. © 2026 Wowhead/Fanbyte. Scraping not recommended without ToS review. | B/D |
| 12 | WoW Forever Wiki | [wowforeverwiki.org](https://wowforeverwiki.org/) | Wiki | Races, classes, talents (470), zones, dungeons, raids, Forever vs Classic differences, Legacy, Camping, itemization | Yes | Evidence-ranked wiki; separates Blizzard-confirmed facts from research-derived details. No API or machine-readable export. No license stated. | B |
| 13 | WoW Forever Game Wiki | [wowforevergame.wiki](https://wowforevergame.wiki/) | Wiki/tools directory | Tools directory, community site listings, zone/system explainers | Yes | Aggregates information about other sources; useful for discovery but not a data source itself | C |
| 14 | WoW Forever Guides | [wowforeverguides.com](https://wowforeverguides.com/) | Web site | Leveling guide checkpoints, zone descriptions, dungeon info | Yes | Guide content, not structured data | B |

### Category C: Discovery-Only / Tooling Sources

| # | Name | URL | Type | Data Contents | WoW Forever? | Notes | Category |
|---|---|---|---|---|---|---|---|
| 15 | WDBx | [github.com/Frostshake/WDBx](https://github.com/Frostshake/WDBx) | DB2/DBC viewer tool | Opens DBC and DB2 files; exports CSV, JSON, SQL | No (tool, not data) | GPL-3.0. Could read WoW Forever client DB2 files if you have the client. Does not contain WoW Forever data itself. | C |
| 16 | WoWDBDefs | [github.com/wowdev/WoWDBDefs](https://github.com/wowdev/WoWDBDefs) | DB2 field definitions | Column/field definitions for DBC/DB2 files, builds 7.3.5.26654 to current | No (definitions only) | Machine-readable (C#, Python, JSON/XML export). License present but not stated on page. Could define structures for WoW Forever DB2 files. | C |
| 17 | DBCD | [github.com/wowdev](https://github.com/wowdev) (org) | C# DB2 reader library | Reads DBC/DB2 database files | No (library) | Part of wowdev org. Could be used to programmatically read WoW Forever DB2 files. | C |
| 18 | erorus/db2 | [github.com/erorus/db2](https://github.com/erorus/db2) | PHP DB2 reader | Reads DB2, ADB/DBCache files; used by The Undermine Journal | No (library) | Apache 2.0. Supports versions 3.x through 8.1.0+. Could read WoW Forever client data. | C |
| 19 | wow.export | [github.com/Kruithne/wow.export](https://github.com/Kruithne/wow.export) | Model/texture export toolkit | Extracts M2, WMO, BLP, sound, video files from WoW client or CDN | No (tool) | MIT. Supports Retail and Classic. Could extract Forever client assets. | C |
| 20 | wow.tools.local | [github.com/Marlamin/wow.tools.local](https://github.com/Marlamin/wow.tools.local) | Local database viewer | Views DB2 files, TACT keys, CDNs, BLP, cinematics | No (tool) | Local version of wow.tools. Could be used to inspect WoW Forever client data. | C |
| 21 | SimulationCraft dbc_extract | [github.com/simulationcraft/simc](https://github.com/simulationcraft/simc/wiki/GameClientData) | DBC extraction script | Extracts item, spell, enchant, gem data from DBC files | No (tool/docs) | Documents the DBC extraction process used by SimulationCraft. Useful methodology reference. | C |
| 22 | nexus-devs/wow-classic-items | [github.com/nexus-devs/wow-classic-items](https://github.com/nexus-devs/wow-classic-items) | JSON item database | Items, professions, zones, classes for Vanilla/TBC/WotLK Classic | No | MIT. Data from Wowhead scraping + Blizzard API. Not WoW Forever. Could be a template for data structure. | C/E |
| 23 | Warcraft Wiki API docs | [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API) | API documentation | Documents WoW API functions including C_TaxiMap.GetAllTaxiNodes | No (docs) | Useful reference for in-game data collection addon development. Documents taxi node data structure. | C |
| 24 | WoWDBDefs manifest.json | (part of WoWDBDefs) | DB2 manifest | Lists known DB2/DBC files with tableHash, db2FileDataID, dbcFileDataID | No (metadata) | Could help identify which DB2 tables exist in the WoW Forever client. | C |

### Category D: Restricted / Unclear

| # | Name | URL | Type | Data Contents | WoW Forever? | Notes | Category |
|---|---|---|---|---|---|---|---|
| 25 | VMaNGOS | [github.com/World0fWarcraft/vmangos](https://github.com/World0fWarcraft/vmangos) | Server emulator + world database | Items, creatures, quests, scripts for Vanilla 1.2–1.12 | No | GPL-2.0. Data lineage: Elysium/LightsHope. Not WoW Forever. Could overlap with pfQuest data. | D |
| 26 | pfQuest/ShaguDB | [github.com/shagu/pfQuest](https://github.com/shagu/pfQuest) | Addon + database | Quests, NPCs, objects, items, spawns, vendors, flight masters, etc. | No | MIT. Vanilla data from VMaNGOS; TBC from CMaNGOS. Not WoW Forever. | D/E |
| 27 | ClassicCodex | [github.com/SwimmingTiger/ClassicCodex](https://github.com/SwimmingTiger/ClassicCodex) | Addon + database | Quests, NPCs, objects, items, spawns, vendors | No | MIT. Partial rewrite of pfQuest/ShaguDB. Not WoW Forever. | D/E |
| 28 | Questie-X | [github.com/Xurkon/Questie-X](https://github.com/Xurkon/Questie-X) | Addon framework | Plugin architecture for private servers; QuestieLearner crowdsources data | No | MIT (code). Fork of Questie. Does not mention WoW Forever. QuestieLearner could be adapted for Forever data collection. | D |
| 29 | Guidelime | [github.com/max-ri/Guidelime](https://github.com/max-ri/Guidelime) | Leveling guide addon | Guide steps with quest progress tracking, coordinates | No | No license stated. For WoW Classic (Era through MoP). Not WoW Forever. World revamp makes old 1-60 guides obsolete. | D |
| 30 | RestedXP Guides | [github.com/RestedXP/RXPGuides](https://github.com/RestedXP/RXPGuides) | Leveling guide platform | In-game leveling guide framework | No | License present but not stated on page. For WoW Classic. Not WoW Forever (though wow4ever.quest lists RestedXP 4.11.5 as having a Forever build). | D |
| 31 | WoW Eternity | [woweternity.com](https://woweternity.com/) | Addon hub | Addon directory for "Forever v1.2.0 (3.3.5a Core)" | Appears to be private server, not official WoW Forever | Supports "Forever v1.2.0 (3.3.5a Core)" — this is a WotLK private server, not Blizzard's WoW Forever (1.60.1). Misleading naming. | D |
| 32 | Aeternium WoW API | [aeterniumclan.de/wow/api](https://www.aeterniumclan.de/wow/api) | Private server API | JSON endpoints for online roster, PvP leaderboards, character profiles | No (private server) | CORS-open API with character and realm data. Private server, not official WoW Forever. | D |
| 33 | WoW Classic DB | [wowclassicdb.com](https://wowclassicdb.com/) | Web database | Items, quests for Classic Era, TBC, WotLK | No | Does not mention WoW Forever. Provenance unstated. | D |

### Category E: Already Known / Substantial Overlap

| # | Name | URL | Overlap | Notes | Category |
|---|---|---|---|---|---|
| 34 | ForeverTome (quest database) | [forevertome.com/database/quests](https://forevertome.com/database/quests) | Already known | 29 quest entries from player observations, build 1.60.1.69893. Important build-specific data but already in known list. | E |
| 35 | 60.tools | [60.tools](https://www.60.tools/) | Already known | Database snapshot 1.60.1.69913. Already in known list. | E |
| 36 | Questie | [github.com/Questie](https://github.com/Questie) | Already known | Already in known list. QuestieTDB is a reorganization. | E |
| 37 | AllTheThings | [github.com/ATTWoWAddon/AllTheThings](https://github.com/ATTWoWAddon/AllTheThings) | Already known | Already in known list. | E |
| 38 | Wowhead Looter | [wowhead.com/client](https://www.wowhead.com/client) | Overlaps with Wowhead Forever | The Wowhead Looter addon collects in-game data (NPCs, items, etc.) and uploads to Wowhead. This is the data-collection mechanism behind Wowhead Forever's database. | E/B |

---

## Detailed Analysis of Most Promising Sources

### 1. ForeverDiff (foreverdiff.com)

**What it contains:** A comprehensive WoW Forever database comparing every player spell and equippable item against Classic Era, plus every talent and recipe that is new, changed, or removed. The scale is significant: 14,208 spell changes, 9,055 item changes, 467 talent changes, 3,707 recipe changes, 175 zone changes, 88 item-set changes, 58 faction changes, and 118 enchant changes. It also notes 10,169 items from the compared build that are listed in the client's item table without name, stats, or tooltip — described as "neither changed nor removed."

**WoW Forever coverage:** Explicitly yes. The site describes itself as "the WoW Forever database."

**Build/version:** Data synced September 19, 2026. The site references "the compared build" and links to a "Build history" page, but the specific build number could not be verified (the page is JavaScript-rendered and could not be fetched).

**Independence:** The site claims data is "read from Blizzard's own game client" and that tooltips are compared "straight from Blizzard's own game client." This suggests direct client data extraction rather than derivation from Wowhead, Questie, or ATT. However, the extraction methodology page ("How we read this") could not be accessed, so this claim is **unverified**.

**License:** None stated. No terms of use, copyright notice, or redistribution policy found.

**Redistribution:** Unclear. No permission granted or denied.

**Ingestion recommendation:** Treat as Category D (restricted/unclear) until the extraction methodology and licensing can be verified. The scale of change data is impressive, but without confirming the extraction method and redistribution rights, this should be used as an evidence/corroboration source rather than a direct ingestion source.

**Key concern:** If the data was extracted from Blizzard's DB2/client files, the underlying game data is Blizzard's proprietary content. A comparison database derived from that extraction may carry the same provenance concerns as a direct DB2 dump.

---

### 2. ForeverTalents (github.com/dan-in-it/ForeverTalents)

**What it contains:** WoW Forever talent calculators for all 9 classes, 470 talents across 27 trees, and 40 racial abilities across 10 faction/race entries (including High Order and Windshaper Skyborne). Includes build-code formats (WFD1, WFS1, WFS2), prerequisite allocation, point budgets, and verification tests. The calculators are self-contained HTML files with embedded artwork and fonts.

**WoW Forever coverage:** Explicitly yes. The repository is titled "ForeverTalents" and describes itself as "WoW Forever talent calculators."

**Build/version:** Not stated. No specific game build number, patch, or client version mentioned.

**Independence:** Unstated. No upstream source, attribution, or collection methodology is identified. The data could be from gameplay observation, datamining, transcription from official sources, or derived from another project. The presence of build-code formats (WFD1, WFS1, WFS2) suggests some independent development work.

**License:** No repository license. The Cinzel font is under SIL Open Font License. Warcraft artwork is attributed to Blizzard Entertainment. The talent and racial data itself has no stated license.

**Redistribution:** Unclear.

**Ingestion recommendation:** The talent data (470 entries with ranks, prerequisites, and effects) could be valuable, but without provenance or licensing, this should be treated as Category D. The data is embedded in HTML/JS files and would need to be extracted programmatically.

---

### 3. Travelcraft / WoW Forever Atlas (benjamh681.github.io/wow-forever-atlas)

**What it contains:** An interactive map and route planner for World of Warcraft: Forever. Includes every zone, level ranges, dungeons, ship routes, and travel times. A text version is available as a "WoW Forever guide."

**WoW Forever coverage:** Explicitly yes.

**Build/version:** Not stated.

**Independence:** Unstated. The GitHub repository (benjamh681/wow-forever-atlas) contains the source code, but no data provenance is described.

**License:** No license stated on the GitHub repository.

**Redistribution:** Unclear.

**Ingestion recommendation:** Zone level ranges, dungeon level ranges, and travel-time data could be useful for a leveling route planner. However, without provenance or licensing, treat as Category D. The data is embedded in a JavaScript application and would need extraction from the source.

---

### 4. ForeverWisp (foreverwisp.com)

**What it contains:** A free leveling addon in development for WoW Forever. Route data includes quest names, NPC names, coordinates, quest IDs, minimum levels, prerequisites (when recorded), next route steps, profession stops, trainer visits, gathering reminders, and milestone levels. The web demo includes Classic reference steps for Elwynn Forest (levels 1-10) with specific coordinates (e.g., 43.8, 65.8 for Innkeeper Farley, quest 2158).

**WoW Forever coverage:** Yes, but currently in development. The site states "Wisp and its routes are not ready for beta use" and the web previews use "Classic reference steps" that are "not verified Forever routes." The site gives the launch date as November 4, 2026.

**Build/version:** Beta target; no specific build number stated.

**Independence:** Appears independently authored. Route data appears to be manually created rather than derived from Questie or ATT. However, the Classic reference steps may derive from known Classic quest data.

**License:** No license stated.

**Redistribution:** Unclear.

**Ingestion recommendation:** Once beta-ready, the route data structure (quest IDs, coordinates, prerequisites, profession stops) could be a valuable template. Currently, the Classic reference steps should not be treated as WoW Forever data. Treat as Category A/D — promising but not yet usable.

---

### 5. WoW Forever News (wowforevernews.com)

**What it contains:** A "WoW Forever Core Data Store" with JSON datasets and a Supabase database. The documented entity schema includes items with fields: id, name, quality, icon, itemLevel, reqLevel, slot, stats, source. Foreign-key relationships: Item.source → NPC.id, Quest.reward → Item.id, Recipe.reagent → Item.id. A census pipeline is planned with an in-game /who scanner addon to track active player demographics, faction balance, class trends, and guild speedruns.

**WoW Forever coverage:** Yes. The page identifies the system as "WoW Forever Core Data Store" and references "Warcraft Forever."

**Build/version:** References "Blizzard:Warcraft ForeverRealm Time: July 2026." No specific build number.

**Machine-readable:** Yes. The page explicitly references JSON datasets, static JSON, a JSON schema payload, a Supabase database, and URL endpoints using the pattern `/items/:id`.

**Independence:** Unstated. No data collection methodology described.

**License:** None stated.

**Redistribution:** Unclear.

**Ingestion recommendation:** The documented architecture suggests structured data exists, but the actual datasets are not publicly accessible via the documented endpoints. The census pipeline plan is interesting but not yet operational. Treat as Category A/D — potentially valuable if data becomes accessible, but currently unverifiable.

---

### 6. WoW Forever Builds (wowforeverbuilds.com)

**What it contains:** Talent calculator data for all 9 classes with 51-point talent builds, shareable build links, level-by-level talent orders, race and profession associations. Community guides (PvE/PvP) with voting and comments. Legacy planner with 3 trees and 16 points. Character Export Addon using `/wfb` in-game command. Class quiz producing spec/race recommendations. Featured level-20 beta builds for all 9 classes.

**WoW Forever coverage:** Yes. Independent fan site, not affiliated with Blizzard.

**Build/version:** "Pre-release talent data that can change during beta." Each guide records the data version used. Beta starts September 17, 2026; launch November 4, 2026.

**Independence:** Data is "labeled by source." Values not confirmed in-game are marked as unconfirmed. Specific external sources are not identified.

**License:** No data license stated.

**Redistribution:** Build links can be shared (Discord, etc.), but bulk data redistribution is not addressed.

**Ingestion recommendation:** Talent data and Legacy system data could be useful as corroboration. The source-labeling practice is a positive signal. The Character Export Addon (/wfb) suggests data can be exported from the game client. Treat as Category A/D.

---

### 7. wow-forever.top

**What it contains:** A quest directory with 16 indexed quest routes covering Hall of Thanes and Ruins of Lordaeron dungeons. Each quest entry includes dungeon, level, faction/route, quest name, objective description, and reward choices. An item directory with 1,203 unique indexed names and 1,543 boss/source associations. The site explicitly states it is "not a mirror of Wowhead's complete quest database" and links item/quest IDs to Wowhead Forever when known.

**WoW Forever coverage:** Yes. Described as "sourced beta records."

**Build/version:** No specific build number stated.

**Independence:** The site links to Wowhead Forever for verified item/quest identities. It does not import Wowhead's database. The quest records appear to be independently documented from dungeon guide coverage.

**License:** None stated.

**Redistribution:** Unclear.

**Ingestion recommendation:** The 16 quest routes with rewards are useful as corroboration for dungeon quest data. The item directory is limited and explicitly notes that "ID and icon availability do not by themselves verify that an item drops from the same boss or has unchanged stats in Forever." Treat as Category A/D — useful for corroboration of dungeon quest rewards.

---

### 8. Wowhead Forever (wowhead.com/forever/database)

**What it contains:** A full database covering items, NPCs, quests, spells, achievements, mounts, battle pets, factions, toys, and recipes. Includes "New in Patch 1.60.1" sections for items, achievements, recipes, NPCs, mounts, and battle pets. User comments include coordinates (e.g., "/way 48.5 68.2", "/way 55.39; 55.54") and gameplay observations. Screenshots of items, quests, and NPCs.

**WoW Forever coverage:** Yes. Dedicated Forever section separate from Retail and Classic.

**Build/version:** Patch 1.60.1 referenced in section headings.

**Data collection method:** The Wowhead Looter addon ([wowhead.com/client](https://www.wowhead.com/client)) maintains an in-game addon that "collects data as you play the game" and uploads it to Wowhead. The database is described as "populated from beta datamining" by the wowforevergame.wiki tools directory. Wowhead's FAQ states that "user submitted data goes through an internal process which results in legitimate data appearing on the site once approved."

**License:** © 2026 Wowhead / Fanbyte. No data license, API access, or scraping policy stated on the database page.

**Redistribution:** Not permitted without explicit authorization. Wowhead's content is copyrighted by Fanbyte.

**Ingestion recommendation:** Treat as Category B/D — excellent corroboration source, but do not scrape or bulk-copy without reviewing Wowhead's terms of service. Individual facts (coordinates, quest IDs) can be verified against Wowhead pages, but the database as a whole should not be ingested.

---

### 9. QuestieTDB (github.com/Questie/QuestieTDB)

**What it contains:** A reorganized version of Questie's existing data model for quests, NPCs, items, and objects. Includes entity schemas (questKeys, npcKeys, itemKeys, objectKeys), static and dynamic corrections, faction corrections, Season of Discovery corrections, and 9 non-English locales. Uses CBOR encoding for baked data and provides a public API (LibQuestieDB).

**WoW Forever coverage:** The DESIGN.md documents a TOC mapping that includes "Classic Anniversary" using `QuestieDB_TBC.toc`. This means Questie treats Classic Anniversary as using the TBC database, which may or may not be accurate for WoW Forever.

**Build/version:** Mentions build 69109 for in-client validation. This is not one of the builds listed by the user (69876, 69893, 69913).

**Independence:** Explicitly derived from Questie's existing data. The document states: "Questie's existing data" is the locked data-source decision. It explicitly does not use VibeQuest data.

**License:** Not stated on the DESIGN.md page.

**Ingestion recommendation:** Treat as Category A/E — this is a reorganization of Questie's data, not a new source. Direct ingestion would duplicate Questie data. However, the documented schema (questKeys, npcKeys, itemKeys, objectKeys) and the CBOR encoding approach could serve as a useful reference for data architecture.

---

### 10. Grail (github.com/smaitch/Grail)

**What it contains:** A WoW addon providing a library of quest information: completion status, obtainability (level/race/class/reputation requirements), prerequisite quests, quest locations, reputation rewards, and achievement tracking. Starting with version 029, achievement and reputation data are in loadable addons. Version 049+ records quest completion history including repeat counts.

**WoW Forever coverage:** Not stated. The page refers generally to World of Warcraft.

**Independence:** Player-observed. As players accept and turn in quests, Grail checks its internal database and records discrepancies in saved variables (Grail.lua). Users can submit these for future releases. This is a crowdsourced, player-observation model.

**License:** Not stated.

**Ingestion recommendation:** The player-observation model is interesting — it records actual quest behavior seen in-game, not extracted from client files. If Grail were run on the WoW Forever client, it could collect build-specific quest data. However, no WoW Forever coverage is confirmed. Treat as Category A/D — the methodology is valuable but the current dataset is for older WoW versions.

---

## Independence Analysis

### Data Lineage Summary

| Source | Ultimate Data Origin | Independent? |
|---|---|---|
| ForeverDiff | Claims "Blizzard's own game client" — unverified | Potentially independent if claim is accurate |
| ForeverTome | Player observations in beta | Yes — independent player observations |
| ForeverTalents | Unstated | Unverified |
| Travelcraft | Unstated | Unverified |
| ForeverWisp | Independently authored route data (Classic reference) | Partially — Classic steps may derive from known data |
| WoW Forever News | Unstated | Unverified |
| WoW Forever Builds | "Labeled by source" but sources not identified | Unverified |
| wow-forever.top | Dungeon guide coverage; links to Wowhead | Partially — quest records appear independent, item IDs from Wowhead |
| Wowhead Forever | Beta datamining + Wowhead Looter addon | Independent collection (crowdsourced + datamining) |
| QuestieTDB | Questie's existing data | No — reorganization of Questie |
| Grail | Player observations via in-game addon | Yes — player-observed, but not WoW Forever |
| pfQuest/ShaguDB | VMaNGOS / CMaNGOS databases | No — derived from server emulator data |
| ClassicCodex | pfQuest/ShaguDB | No — partial rewrite of pfQuest |
| Questie-X | Questie fork + QuestieLearner crowdsourcing | Partially — base data from Questie, new data from players |
| VMaNGOS | Elysium/LightsHope codebases | No — private server reconstruction |
| nexus-devs/wow-classic-items | Wowhead scraping + Blizzard API | No — derived from Wowhead and Blizzard API |
| WDBx/WoWDBDefs/DBCD | Tools — no data | N/A (tools that could read client files) |

### Key Independence Finding

The most genuinely independent sources of WoW Forever data are:

1. **ForeverTome** — player observations recorded with explicit build numbers (already known)
2. **ForeverDiff** — if the claim of reading from Blizzard's client is accurate (unverified)
3. **Grail's methodology** — player-observed quest data (but not yet WoW Forever)
4. **Wowhead Looter** — crowdsourced in-game data collection (but data is Wowhead's, not redistributable)
5. **QuestieLearner** — in-game crowdsourcing model (but no WoW Forever plugin exists)

Most other "databases" ultimately trace back to one of: Blizzard's DB2/client files, Wowhead, Questie, or server emulator reconstructions (VMaNGOS/CMaNGOS).

---

## Build/Version Investigation

| Source | Build(s) Identified | Notes |
|---|---|---|
| ForeverTome | 1.60.1.69893 (enUS) | Explicitly recorded for all 29 quest entries |
| 60.tools (known) | 1.60.1.69913 | Database snapshot |
| ForeverDiff | Not stated on accessible pages | "Build history" page exists but could not be fetched |
| QuestieTDB | 69109 (validation) | Not a WoW Forever build |
| Wowhead Forever | Patch 1.60.1 | No specific build number |
| User-provided builds | 69876, 69893, 69913 | Not all represented in sources |

**Important:** No source found in this investigation explicitly identifies build 69876. ForeverTome covers 69893, and 60.tools covers 69913. ForeverDiff may cover one of these but the build history page was inaccessible. Data from one build should not be assumed identical to another.

---

## Special Focus: Gaps in Hard-to-Obtain Data

### Quest Objectives
- **Best available:** ForeverTome (29 entries with objectives, build 69893)
- **Gap:** No comprehensive WoW Forever quest objective database exists. Questie/QuestieTDB cover Classic Anniversary but may use TBC data, not Forever-specific data.

### Quest Rewards
- **Best available:** wow-forever.top (16 dungeon quest routes with reward choices), ForeverTome (observed rewards for 29 quests)
- **Gap:** No complete reward database. Wowhead Forever has the most data but is not redistributable.

### Quest Givers
- **Best available:** None for WoW Forever specifically. ForeverWisp plans route data with NPC names but is not beta-ready.
- **Gap:** No WoW Forever quest-giver database. Grail's methodology could collect this but has no Forever coverage.

### NPC Locations/Spawns
- **Best available:** None for WoW Forever. pfQuest/ClassicCodex have Vanilla/TBC data from VMaNGOS.
- **Gap:** QuestieLearner (Questie-X) could collect this in-game but no WoW Forever plugin exists.

### Object Locations
- **Best available:** None for WoW Forever.
- **Gap:** No source provides WoW Forever object (herb, mining, chest, quest object) location data.

### Creature Data
- **Best available:** ForeverDiff (spell/creature ability changes vs Classic Era)
- **Gap:** No complete creature database for WoW Forever new zones.

### Quest Completion Data
- **Best available:** Grail (methodology only, not WoW Forever), Questie (Classic, not Forever)
- **Gap:** No WoW Forever quest completion tracking database.

### Quest Prerequisites
- **Best available:** ForeverWisp (plans to record prerequisites, not yet available), Grail (methodology, not Forever)
- **Gap:** No WoW Forever quest prerequisite/chain database.

### Taxi Paths and Travel Times
- **Best available:** Travelcraft (visual travel times, not structured data), Warcraft Wiki API docs (C_TaxiMap.GetAllTaxiNodes function)
- **Gap:** No WoW Forever flight-path dataset. The API function exists but no one has published collected data.

### Map Coordinates
- **Best available:** Wowhead Forever comments (individual coordinates), ForeverWisp (Classic reference coordinates), Travelcraft (zone map)
- **Gap:** No structured coordinate dataset for WoW Forever NPCs, objects, or quest targets.

### Player-Observed Quest Data
- **Best available:** ForeverTome (29 entries, build 69893), Grail (methodology, not Forever)
- **Gap:** Scale is very small. No large-scale player-observation database exists.

### Client Cache/WDB Data
- **Best available:** WDBx (tool to read DB2/DBC files), erorus/db2 (PHP reader), WoWDBDefs (field definitions)
- **Gap:** No one has published extracted WoW Forever DB2 data. The tools exist but no public dataset has been produced with clear licensing.

### In-Game Recording/Export Tools
- **Best available:** Wowhead Looter (collects and uploads to Wowhead), QuestieLearner (crowdsources for Questie-X), Grail (records quest discrepancies), GuideCreator (generates Guidelime text from quest events), WoW Forever Builds Character Export Addon (/wfb)
- **Gap:** No tool specifically designed to export WoW Forever quest/NPC/item data for open-source use. The WoW API (C_TaxiMap, quest functions, etc.) could be used to build such a tool.

---

## Conclusions

### What publicly accessible sources of WoW Forever information exist that have not been considered?

The investigation found 17 potentially new sources, with **ForeverDiff**, **ForeverTalents**, **Travelcraft**, **ForeverWisp**, **WoW Forever News**, **WoW Forever Builds**, and **wow-forever.top** being the most relevant WoW Forever-specific sites. Additionally, several tooling projects (WDBx, WoWDBDefs, DBCD, wow.export, wow.tools.local) were identified that could enable independent data extraction from the WoW Forever client, though none currently contain published WoW Forever datasets.

### How independently sourced is the information?

Most WoW Forever community sites do not clearly document their data provenance. ForeverDiff claims to read from Blizzard's game client (unverified). ForeverTome uses player observations (genuinely independent, but already known). ForeverWisp appears independently authored. Most other sites either don't state their sources or likely derive from Wowhead datamining or Blizzard DB2 extraction. The tools (WDBx, WoWDBDefs, etc.) are independent projects that could produce independent data, but haven't been used to publish WoW Forever datasets yet.

### Can it be responsibly used in an open-source project?

**No source found in this investigation can be directly ingested into an open-source project without significant licensing and provenance review.** Every WoW Forever-specific community site lacks a stated data license. The most promising approach for the project would be:

1. **Use ForeverDiff, ForeverTome, and wow-forever.top as corroboration sources** to verify facts obtained through other means.
2. **Use the DB2 extraction tools** (WDBx, WoWDBDefs, DBCD) to independently extract data from a legitimately obtained WoW Forever client, producing a first-party dataset.
3. **Build an in-game data-collection addon** (inspired by Grail's player-observation model or QuestieLearner's crowdsourcing) to record quest objectives, NPC locations, coordinates, and other data directly from gameplay.
4. **Use the Warcraft Wiki API documentation** to identify which in-game API functions can provide structured data (taxi nodes, map info, quest data).
5. **Use ForeverTalents and WoW Forever Builds as references** for talent data structure, but verify all values independently.

The tools and methodologies exist for independent data collection. What is missing is a coordinated effort to apply them to the WoW Forever client and publish the results under an appropriate license.

---

*This report was produced through web searches and page fetches conducted on September 21, 2026. All claims are based on publicly accessible web content as of that date. Where pages could not be fetched (JavaScript-rendered SPAs, paywalled content, or crawler errors), claims are explicitly marked as "unverified."*
