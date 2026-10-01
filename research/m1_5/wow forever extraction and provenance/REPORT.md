# M1.5 research spike: can we get a trustworthy first-party QuestV2?

Date of research: 2026-09-21. M1 is frozen; nothing under `src/`, `registry/`, `config/`, `manifests/`, `docs/` or `tests/` was changed.
This is research, not legal advice.

**Evidence tags:** **[V]** I read/ran it myself. **[2nd]** documented or reported by another project/site, not reproduced.
**[?]** unresolved. A **[V]** on "the archive contains X" is not a **[V]** on "Blizzard said X"; where those differ the text says so.

Companion files in this folder: `build_identity.json`, `dbd_vs_csv_check.json`, `EXTRACTION_RUNBOOK.md`.

---

## 1. Executive summary

**The central question: can we take a real WoW Forever client, identify its build, extract QuestV2, reproduce the extraction, and record provenance another person could verify?**

**Answer: partially. Everything I could examine says yes; nothing was executed against a real client.**

| Stage | Status | Where it stops |
|---|---|---|
| Identify the build | Plan is sound. Three builds have distinct BuildConfig hashes seen in two independent third-party sources. | I could not query Blizzard or the CDN, so no hash is Blizzard-confirmed by this pipeline. `.build.info` is an agent-written cache, not proof. |
| Extract QuestV2 | Tools exist and read the right format. Definitions exist for the three builds. QuestV2 is reported (by two sources) to be a real client table with 6,600 rows. | No .NET/Go runtime, no client, no CDN access in this environment. Never ran a tool on a Forever file. |
| Reproduce | Defined: raw `.db2` SHA-256 must match between two people with the same client. | Needs a second person with beta access, and the beta ends Oct 21. |
| Record provenance | Attestation template written (`EXTRACTION_RUNBOOK.md` step 6). | Untested. |

Headline findings:

1. **QuestV2 very likely ships as a real client DB2 table** in all three builds: ForeverDiff and lodestar's docs both give 6,600 rows, and the pinned WoWDBDefs commit maps it to exactly the three columns M0 saw. All **[2nd]** for presence.
2. **The Forever client is the modern engine.** QuestV2's layout hash (`1854BDB9`) is shared with retail 12.x builds **[V]**. Existing tools that read WDC5 can plausibly read it. **[?]** until run.
3. **A definition existing does not mean a table ships.** WoWDBDefs' build mappings are dumped from the *executable's* metadata **[V, UPDATING.md]**. 1,161 definitions are mapped to Forever builds **[V]**; ForeverDiff pulled only 83 tables. So the `QuestObjective`/`QuestV2CliTask` conflict from M0 is **unresolved**, not resolved.
4. **Quest text, NPC names, objective target IDs and loot are server-side.** Stated by ForeverDiff and by a second independent write-up **[2nd]**. In-game observation is therefore the only route to most quest facts.
5. **The M1 "label without content" hypothesis is weakened.** ForeverDiff says the three builds are identical at entity level **[2nd]**, and ATT's updater re-downloads when the build label changes **[V]**. Identical bytes are consistent with genuinely unchanged data. Neither is proven.
6. **Licensing is unresolved and the EULA has a specific clause to weigh:** §1.C.vi "Data Mining" **[V, read on blizzard.com]**. See section 8.

**Recommendation before M2:** do not start M2. Have someone with beta access run `EXTRACTION_RUNBOOK.md` before **October 21**, and decide your risk posture on EULA §1.C.vi first. Details in sections 9 and 10.

---

## 2. What a Forever client contains (per table)

Columns: is there a definition for the Forever builds (WoWDBDefs commit `02b1fa9a4714` **[V]**), is there independent evidence the DB2 file ships, and my conclusion.

| Table | Definition (Forever builds) | Evidence the file ships | Conclusion |
|---|---|---|---|
| QuestV2 | yes, layout `1854BDB9`, 3 cols | ForeverDiff 6,600 rows / 0 unidentified cols **[2nd]**; lodestar docs 6,600 **[2nd]**; M0 carried claim 6,600 **[2nd]** | **Client DB2, existence only** (no name/level/reward) |
| QuestInfo | yes, `E505C927` | ForeverDiff 7 rows **[2nd]** | Client DB2 (tiny) |
| QuestXP | yes | ForeverDiff 100 rows **[2nd]** | Client DB2 |
| QuestPOIBlob / QuestPOIPoint | yes, `FDC814CF` / `5CBBEFE7` | M0 carried: 54 / 99 rows **[2nd]**; not in ForeverDiff's list | Probably client DB2, tiny; **[?]** |
| QuestLabel | yes, `357F8064` | none | **[?]** |
| QuestObjective | yes, `50E2491F` | lodestar says absent; ForeverGuide README says present; not in ForeverDiff's list | **Unresolved conflict** |
| QuestV2CliTask | yes, `D6D31C39` | same conflict | **Unresolved conflict** |
| Map | yes, `D43AFAC3` | ForeverDiff 73 rows **[2nd]** | Client DB2 |
| AreaTable | yes, `9995B797` | M1 ATT mirror 1,372 rows **[V of mirror]**; ForeverDiff 1,372 **[2nd]** | Client DB2 |
| UiMap / UiMapAssignment | yes, `DB51D55F` / `C9CC8DFB` | M1 mirror 60 / 61 **[V of mirror]**; ForeverDiff 60 / 61 **[2nd]** | Client DB2 |
| TaxiNodes | yes, `E7B597F0` | M1 mirror 100 **[V of mirror]**; ForeverDiff 100 **[2nd]** | Client DB2 |
| TaxiPath | yes, `A303DE51` | ForeverDiff 328 rows **[2nd]** | Client DB2 |
| TaxiPathNode | yes, `FE362E70` | none | **[?]** |
| Creature | yes, `6E14C900` | none; ForeverDiff says NPC names are not in client tables **[2nd]** | **[?]** |
| Item | yes, `9A2A4834` | 31,675 rows in both M1 mirror **[V of mirror]** and ForeverDiff **[2nd]** | Client DB2 |
| ItemSparse | yes, `6FCC3191`, 69 cols | ForeverDiff 19,171 rows; 10,169 Era item IDs listed in `Item` have no ItemSparse row **[2nd]** | Client DB2, partial |

Categories, as far as the evidence goes:

- **Client DB2 (structure/lookup):** QuestV2, QuestInfo, QuestXP, Map, AreaTable, UiMap, UiMapAssignment, TaxiNodes, TaxiPath, Item.
- **Server-side or cached, not in client tables:** quest names/text/objectives, NPC names, vendor lists, loot, quest rewards, creature spawns **[2nd]**. The client writes some to `Cache/WDB/*.wdb` after asking the server (lodestar **[2nd]**).
- **Encrypted / withheld:** ForeverDiff records 99 withheld blocks and 5,391 rows in encrypted sections across its 83 tables **[2nd]**; a second write-up counts ~3,300 fully sealed files **[2nd]**. Keys are not shipped.

**Cross-check I could do and did [V]:** the column names and order of 23 CSVs that M1 read from the ATT mirror equal the Forever-mapped definition blocks at the pinned commit, 23/23 (`dbd_vs_csv_check.json`). That shows the mirrored CSVs were parsed with a Forever-compatible layout. It does not show which client produced them.

---

## 3. DB2 format and extraction

- **Container format:** WDC5 is the newest DBCD reads (it lists WDBC, WDB2–6, WDC1–5) **[V, README + `DBCD.IO/Readers`]**. Whether Forever's files are WDC5 (vs a newer version) is **[?]** until a header is read. The runbook step 4 reads it.
- **Header fields useful for provenance** (wowdev.wiki/DB2 **[2nd]**): `table_hash` (hash of the table name), `layout_hash` (changes only when structure changes), `schemaString` (e.g. `WowStatic_Patch_10_2_5`, a patch string, not an exact build).
- **Definitions do not come from the DB2 file**; they come from the executable's metadata via WoWDBDefs' dumper **[V, UPDATING.md]**. This is why definitions can exist for tables that the client's data does not contain.
- **Hotfixes:** `DBCache.bin` is server-pushed and can add/replace rows **[2nd, wowdev.wiki/ADB]**. DBCD and wow.tools.local can apply them **[V]**. A first extraction should use base tables only.
- **Encryption:** encrypted sections are skipped by `wowsims/mop` db2tool ("No TACT keys are used") **[V]**. wow.tools.local defaults to loading community keys from GitHub **[V]**. See section 8 for why I recommend not using keys.

---

## 4. Tool comparison

All inspected at the commits shown; **none executed** (no .NET/Go runtime here).

| Tool | Repo / commit | License | What it does | Forever fit |
|---|---|---|---|---|
| **WoWDBDefs** | `wowdev/WoWDBDefs` @ `02b1fa9a4714` "Merge 1.60.1.69913" | code BSD-3-Clause; **definitions CC BY-SA 4.0** | `.dbd` schemas per table/build/layout | **[V]** has all three Forever builds; 1,342 definition files, 1,161 mapped to Forever, 944 to Era 1.15.9 |
| **DBCD** | `wowdev/DBCD` @ `e732093` | MIT | C# library: read/write DB2 WDBC–WDC5, hotfixes; needs DBDs | Reads WDC5 **[V]**; no CSV exporter; GitHub definition provider follows `master` (unpinned) **[V]** |
| **wow.tools.local** | `Marlamin/wow.tools.local` @ `06d1bf9` | MIT | Local web app over a local WoW install: CASC browse, DB2 viewer, **CSV export**, raw DB2 dump, hotfixes | Best fit: `GET /dbc/export/csv?name=&build=&useHotfixes=` and `/dbc/export/alltodisk` **[V]**; beta product support **[?]** |
| **db2tool** | `wowsims/mop` `tools/db2tool` @ `adbbb98` | MIT (derived from DBCD, TACTSharp, wow.tools.local; NOTICES.md) | Go: `.build.info` → CASC → WDC5 → DBD → hotfixes → SQLite | Same chain in one binary **[V]**; wowsims-specific settings; exact-build definition match, no layout-hash check **[V]** |
| erorus/db2 | `erorus/db2` | Apache-2.0 (per repo text) | PHP reader for DB2/ADB/DBCache | Not inspected beyond description |
| wowlib | `skarndev/wowlib` | not checked | C++ with Python/C# bindings; ClientDB WDBC–WDC5, TACT decryption | Not inspected |
| casc-lib, tact-parser (Rust crates) | crates.io | not checked | CASC/TACT parsing | Not inspected |
| "WDBX" | — | — | **Not investigated.** The name is ambiguous; I found no current project matching it | **[?]** |

Relevant issues/examples for Classic Era/Anniversary: I did not find issue threads; the closest evidence that community tools work on these clients is ForeverDiff and a second site both reading "local Forever beta files (build 1.60.1.69893)" against definitions "for this exact build" **[2nd]**.

Exact commands to dump a table: see `EXTRACTION_RUNBOOK.md` step 3.

---

## 5. ForeverDiff

| Question | Answer | Level |
|---|---|---|
| Operator | "the Vient team"; no individual named | **[V]** (about/terms pages) |
| Source code | No repository linked from the site. A related MIT collector addon exists (`anombyte93/ForeverDiffCollector`) that points to `foreverdiff.gg`, a different domain; same operator unconfirmed | **[?]** |
| Build history | Lists 69876, 69893, 69913 (Forever) and 1.15.9.69722 (Era); one Era build "pulled, not published" | **[V]** page |
| Method (its claims) | Pulls tables from Blizzard's public CDN, parses with a pinned WoWDBDefs commit, records BuildConfig/CDNConfig and per-table counts and hashes | **[2nd]** |
| Direct read of client files? | Says yes ("read from Blizzard's own game client"), by CDN/CASC, not by scraping other sites | **[2nd]** |
| Build identification | "config from patch-server"; BuildConfig/CDNConfig 16-hex prefixes shown | **[2nd]**; prefixes match the archived Blizzard responses **[V]** for all three builds |
| Pinned definitions | WoWDBDefs `02b1fa9a4714` | **[V]** the commit exists and is "Merge 1.60.1.69913" |
| Row counts | Agree with what M1 read for 8+ tables (e.g. Item 31,675; AreaTable 1,372; SpellEffect 42,449) | **[V]** for ATT side, **[2nd]** for theirs |
| Hashes/manifests exposed | Row counts and config prefixes; I found no per-table file hashes | **[V]** absence on pages read |
| Cross-check with wago | Says it samples rows against wago.tools; build pages say "cross-check not run" | **[2nd]** |
| Independent reproducibility | Method is reproducible in principle (all inputs are public tools plus Blizzard's CDN). Their output is not independently verifiable without doing the extraction | **[?]** |
| Terms / reuse | Terms page grants no license for the data; "as is"; game content is Blizzard's | **[V]** |

Conclusion: ForeverDiff is a useful **corroborating** source for existence, counts and build identity. It is not something to ingest. The lesson to copy is its provenance page design (version, BuildConfig, CDNConfig, definitions commit, per-table counts, withheld counts).

---

## 6. Build identification

Full details and hashes: `build_identity.json`.

**What is recorded where**

| Place | What it holds | Trust |
|---|---|---|
| `.build.info` (WoW root) | Branch, Build Key, CDN Key, Version, Product, etc. | Written by the Battle.net agent; client trusts it as a cache **[2nd]**. One claim, not proof. |
| `.flavor.info` (product folder) | TACT product name | Same |
| Executable (`WowB.exe` for the beta per a third-party report) | Version resource | Independent of `.build.info` **[?]** for this client |
| In-game `GetBuildInfo()` | version, build, date, interface | Client's own answer; used by ForeverDiffCollector **[V]** |
| Build config file (hash = Build Key) | root/encoding hashes, build name | Content-addressed: MD5 of the file should equal the key **[2nd]** |
| DB2 header | `table_hash`, `layout_hash`, `schemaString` | Ties file to a *layout*, not to an exact build |

**Build hashes seen** (`[V]` that the archive contains them; `[2nd]` that Blizzard's service produced them; two sources agree):

| Build | BuildConfig (full) | CDNConfig(s) seen |
|---|---|---|
| 1.60.1.69876 | `e7fab7248766e9e7daddb3b6083c9c3c` | `272d201d…` then `c39a363b…` |
| 1.60.1.69893 | `70dc75547c16ac2a381fde65945a0e85` | `504e831a…` then `ae86d19f…` |
| 1.60.1.69913 | `6c0df97e8e481a9a41600e373367c200` | `1f946798…` then `5525ea1c…` |

CDNConfig changed twice per build while BuildConfig stayed fixed, so **BuildConfig is the stable identity**.

**Chain that could tie a DB2 to a build cryptographically (design, untested):** Build Key (MD5 of build config) → encoding/root hashes named in that config → FileDataID → content key (MD5 of file content) → the raw `.db2` bytes → SHA-256 recorded by us. Every link is a hash, so another person can recompute it, but only if they have the same client or CDN access.

**Do 69893 and 69913 use the same DB2 schema/format?** The pinned definitions list all three builds under the same layout block for every table checked, so same layouts **[V, definitions]**. Table content identical at entity level **[2nd]**. The M1 byte-identity observation is consistent with that **[V]**.

**How to reach "Blizzard-confirmed" (not done):** query the version service for `wow_classic_beta` (reports only the *current* build; cannot confirm historical ones), and/or fetch the build config file from Blizzard's CDN by hash and check its MD5. Neither was possible here. Until done, all build claims stay unverified.

**Do not promote:** the M1 registry stays as is. Suggested addendum (not applied): add the three BuildConfig hashes as `[2nd]` evidence.

---

## 7. In-game observation

Methodology references only; no databases ingested.

| Fact | Observable from a running client? | Source / caveat |
|---|---|---|
| Quest title, description, objective text, progress/completion text | Yes, in the quest frame (`GetTitleText`, `GetQuestText`, `GetObjectiveText`, `GetProgressText`, `GetRewardText`) | **[V]** code of ForeverDiffCollector running on beta build 69893 per its README (**[2nd]** that it worked) |
| Quest giver / turn-in NPC ID | Yes, from `UnitGUID("npc")` | **[V]** in collector code; lodestar says identity is not secret for quest NPCs **[2nd]** |
| NPC/object **position** | **Not directly.** Collector records the player's position when the frame opens | **[V]**. Needs multiple sightings + a distance model |
| Rewards (items, choices, XP, money) | Yes in the frame (`GetNumQuestChoices/Rewards`, `GetRewardMoney/XP`) | **[V]** |
| Quest **level** | Unreliable while the frame is open; collector deliberately records none | **[V]** collector comment |
| Objective target IDs | **No API** exposes them (only text/type); the WDB cache record has them | lodestar **[2nd]** |
| Prerequisites / chains | Not directly. Grail infers via `IsQuestFlaggedCompleted`, `GetQuestsCompleted`, `QUEST_ACCEPTED/TURNED_IN` and its own DB | Grail code **[V]** (APIs used); prerequisites are inferred, not read |
| Quest status/completion | Yes (`C_QuestLog.*`, `IsQuestFlaggedCompleted`) | Grail **[V]** (calls exist; presence on Forever **[?]**) |
| Class/race restrictions | Not exposed on the quest; observed indirectly by who is offered a quest | **[?]** |
| Taxi nodes / routes | Only while the taxi map is open (`TAXIMAP_OPENED`…`TAXIMAP_CLOSED`, `NumTaxiNodes`, `TaxiNodeName`, `C_TaxiMap.GetAllTaxiNodes(uiMapID)`) | Warcraft Wiki **[2nd]**; Forever behaviour **[?]** |
| Build | `GetBuildInfo()` | **[V]** in collector |
| Client cache files | `Cache/WDB/questcache.wdb`, `creaturecache.wdb`, `gameobjectcache.wdb`, written by the client; `RequestLoadQuestByID` triggers the server record; 24-byte header then `id`+`size`+payload | lodestar **[2nd]**; unverified here |

Runtime facts about the Forever client (lodestar **[2nd]**, MIT, `8964d0c`): interface range 16000–16999, `WOW_PROJECT_ID = 1` (retail-like); "secret values" apply to combat state, not quest/gossip/map data; **SavedVariables are not loaded at login, so each logout overwrites the previous session's file**. A collector must therefore export additively (one file per session, merge offline). I recommend adding this to the harvest contract as v0.1 (a proposal only; the M1 contract is frozen).

Privacy contrast worth keeping: ForeverDiffCollector records `GetRealmName()`; our contract forbids realm/character identifiers.

QuestieLearner: only a private-server fork description was found (passive recording of what the base DB lacks on accept/kill/loot; optional broadcast over an addon channel). I did not inspect code. Avoid the broadcast pattern.

Licensing of the references: ForeverDiffCollector MIT (README states the license "does not grant rights to Blizzard game assets"); Grail **no license file**; lodestar MIT.

---

## 8. Licensing and provenance

*Not legal advice. This separates documented terms from everything else.*

### Documented Blizzard terms **[V, read on blizzard.com]**
Blizzard EULA, last revised March 21, 2024:

- **§1.B.ii** licensed "for your personal and non-commercial entertainment purposes only."
- **§1.C.i Derivative Works:** no "reverse engineer… decompile… or create derivative works based on or related to the Platform."
- **§1.C.vi Data Mining:** no "unauthorized process or software that intercepts, collects, reads, or 'mines' information generated or stored by the Platform," except Blizzard may allow "certain third-party user interfaces."
- **§2.A:** Blizzard owns all virtual content and "all data and communications generated by, or occurring through, the Platform," and the right to create derivative works, "except… Blizzard's Fan Policies, or addenda." I could not locate a document by that name. The closest, an undated Legal FAQ, grants a personal, non-commercial, non-transferable, revocable license over content downloaded from Blizzard's site and says nothing about game data.
- **§1.D.ii.3 (beta):** confidentiality applies only if Blizzard *announces* the beta confidential (the launch post I read contains no such statement; invitation emails unseen **[?]**); on termination of the test you "must delete the pre-release version… and all documents and materials you received."
- Blizzard's UI Add-On Development Policy (forum post; not fetched in full **[2nd]**): add-ons must be free, code visible, must not harm realms, and Blizzard may disable functionality.

### Project licenses **[V]**
WoWDBDefs: code BSD-3-Clause, **definitions CC BY-SA 4.0**. DBCD, wow.tools.local, wowsims/mop: MIT. ForeverDiffCollector: MIT. Grail, wow-listfile, TACTKeys: **no license file at repo root**. ForeverDiff: no data license; "as is."

### Community assumptions **[2nd]**, not rights
Many sites and repositories publish extracted client data (ATT's repository vendors mirrored CSVs; ForeverDiff and others publish datamined tables). That is common practice. It is not a grant. Blizzard's enforcement posture toward datamining sites is **[?]**. A repository's license does not license Blizzard-derived data inside it (M1 principle, unchanged).

### The five cases

| Case | Documented terms bearing on it | Status |
|---|---|---|
| A. Extract from your own legitimately obtained client | §1.C.vi (data mining), §1.C.i (derivative works), §1.B.ii (personal use) | **Unresolved.** Whether reading local files with a tool is "unauthorized… software that… reads information… stored by the Platform" is a legal question I cannot answer |
| B. Store extracted data locally | Personal-use license; beta deletion duty (§1.D.ii.3, "Termination" paragraph) | Personal storage is the least-exposed case; the deletion duty applies to beta materials after the test ends (Oct 21) |
| C. Commit extracted data to GitHub | §2.A ownership; no documented grant | **No documented right.** Community practice only |
| D. Distribute generated CSV/SQLite | Same as C, plus CC BY-SA obligations if our files embed adapted definitions | **No documented right** |
| E. Distribute only software, schemas, manifests, hashes, attestations; users supply their own client | Extractors are MIT/BSD; definitions CC BY-SA (attribution + ShareAlike if adapted); hashes/counts/columns are metadata | **Best supported.** Still subject to A for the people who run the tools |

### Additional cautions
- **Encryption keys.** Blizzard encrypts unreleased content and withholds keys (ForeverDiff **[2nd]**). Using community keys to read those sections is a different posture from reading shipped tables, and `TACTKeys` has no license. Recommendation: do not load keys.
- **Wago.** Not enabled. `wago.tools` refused my fetch tool again (`ROBOTS_DISALLOWED`), so its terms remain unread. What ATT downloads from it **[V]**: one CSV per table per build label via `https://wago.tools/db2/<Table>/csv?build=<label>`. That output would be *second-hand* for provenance (Wago's parse, Wago's build labelling) and carries the same Blizzard-derived-data questions.
- **Provenance rule:** a hash of a file proves which bytes we hold, not that we may redistribute them, and a build label proves nothing about the client.

---

## 9. Recommended extraction path

**Path A (recommended): user-side extraction from the beta client, with pinned tooling and an attestation record.**

1. Someone with beta access runs `EXTRACTION_RUNBOOK.md` on their machine: record identity evidence, pin WoWDBDefs at `02b1fa9a4714`, dump raw DB2 and CSV for QuestV2 (base tables only, no keys), check `layout_hash == 0x1854BDB9`, hash everything.
2. A second person repeats it; raw `QuestV2.db2` SHA-256 must match.
3. Only the attestation JSON and hashes come back to the repository. Extracted data stays local until the sharing question (case C/D) is decided.
4. M1's importer already accepts a QuestV2 CSV via `--questv2 --questv2-build` and records it as `user_file` with an unverified build claim, so nothing in M1 needs redesign.

**Path B (not recommended yet): Wago download.** Blocked on terms I cannot read, and second-hand for provenance.

**Path C (later, complementary): in-game collector and client cache** for quest text, objective IDs, giver/turn-in NPCs and positions. This is the only route for server-side data. Harvest contract v0 applies, with the additive-export lesson above.

## 10. Exact next steps

1. **You decide** your risk posture on EULA §1.C.vi and on whether to seek clarification from Blizzard. (In the EULA text I read, `legal@blizzard.com` appears in the dispute/arbitration procedure, which is not an inquiry channel; find the right one.)
2. **You, or a trusted beta tester, run the runbook before Oct 21** and send back: the attestation JSON, `.build.info`, the step-4 header dict, and any errors. Do not send raw DB2/CSV.
3. **Record whether `QuestObjective`, `QuestV2CliTask`, `QuestPOI*`, `QuestLabel`, `TaxiPathNode`, `Creature` exist as files** (runbook step 8). This closes the biggest factual conflict.
4. **Once I have the attestation:** add an M1.5 addendum file (new file, not editing frozen ones) with the BuildConfig hashes as `[2nd]` and the attestation as the first first-hand dataset; run `build-db --questv2 …` on the result.
5. **Read Wago's terms yourself in a browser** if you want that path considered; my tools cannot.
6. **Optional:** propose harvest contract v0.1 (additive per-session export, no realm name, WDB cache channel note).

## 11. Remaining unknowns

- Whether any extractor runs correctly on a Forever client (never executed).
- Whether `wow_classic_beta` works as `-wowProduct` in wow.tools.local; whether key loading can be disabled.
- Whether Forever DB2 files are WDC5 and whether QuestV2 has encrypted sections.
- Whether `QuestObjective`, `QuestV2CliTask` and the other listed tables exist as files.
- Whether ForeverDiff and `foreverdiff.gg` are the same operator.
- Blizzard-confirmation of any build hash (version service and CDN unreachable here).
- Whether the M1 mirrored CSVs (labelled 69913) are byte-for-byte what a 69913 client contains.
- The status and scope of "Blizzard's Fan Policies"; whether the beta carries an NDA in invitations.
- Enforcement posture on data mining; whether EULA §1.C.vi covers offline reading of installed files.
- Which in-game APIs exist on Forever (only what ForeverDiffCollector and lodestar report).
- The license of `mdX7/ribbit_data` (not checked), `erorus/db2` beyond its README, `wowlib`.
- "WDBX" and QuestieLearner source code (not investigated).

---

## Question / finding / evidence / source

| Question | Finding | Evidence | Source |
|---|---|---|---|
| Does QuestV2 ship in the client? | Very likely; 6,600 rows, 3 columns | [2nd] | foreverdiff.com build pages; WoWDBDefs `QuestV2.dbd`; M0 carried |
| Is Forever the modern engine? | QuestV2 layout `1854BDB9` shared with 12.x | [V] | WoWDBDefs @ `02b1fa9a4714` |
| Does a definition prove a file ships? | No; definitions come from the executable's metadata; 1,161 mapped vs 83 pulled | [V] doc; inference mine | `UPDATING.md`; definitions count |
| QuestObjective / QuestV2CliTask in client? | Unresolved conflict | [?] | lodestar vs ForeverGuide README |
| Can tools read WDC5 with hotfixes? | Yes per source | [V] source, [?] on Forever | DBCD, wow.tools.local, db2tool |
| Extraction command | `GET /dbc/export/csv?name=QuestV2&build=…&useHotfixes=false` | [V] source | wow.tools.local `ExportController.cs` |
| Are definitions pinned by default? | No (`master`) | [V] | DBCD provider, wow.tools.local settings |
| Build hashes | Three distinct BuildConfigs, two sources agree | [2nd] | Ribbit archive; ForeverDiff |
| `.build.info` trustworthy? | Agent-written cache; one claim | [2nd] | wowdev.wiki/TACT |
| Blizzard-confirmed build? | Not achieved | [?] | version service/CDN unreachable |
| 69893 vs 69913 tables differ? | Identical at entity level | [2nd] + [V] byte-identity in ATT | ForeverDiff; M1 |
| ForeverDiff reproducible? | In principle; output not verifiable alone | [?] | methodology page |
| Server-side facts | Quest text, NPC names, objective IDs, loot | [2nd] | ForeverDiff; classicwowforever; lodestar |
| Observable in-game | Text, giver IDs, rewards, player position, build | [V] code | ForeverDiffCollector |
| SavedVariables at login | Not restored; sessions overwrite | [2nd] | lodestar |
| EULA data-mining clause | §1.C.vi | [V] | blizzard.com EULA (Mar 21, 2024) |
| Beta terms | Conditional confidentiality; delete on termination | [V] | EULA §1.D.ii.3 |
| Definition license | CC BY-SA 4.0 (data), BSD-3 (code) | [V] | WoWDBDefs `LICENSE.md` |
| Wago terms | Unread; fetch refused | [?] | `ROBOTS_DISALLOWED` |

## Source register

| Source | Version inspected | License | What I actually inspected |
|---|---|---|---|
| foreverdiff.com | fetched 2026-09-21 | none for data | home, methodology, builds index, builds/69913, 69893, 69876, terms, about |
| wowdev/WoWDBDefs | `02b1fa9a4714` (pinned checkout) | BSD-3 code / CC BY-SA 4.0 data | LICENSE.md, UPDATING.md, 1,342 `.dbd` files, 17 requested tables |
| wowdev/DBCD | `e732093` | MIT | README, `DBCD.IO/Readers`, providers |
| Marlamin/wow.tools.local | `06d1bf9` | MIT | README, `SettingsManager.cs`, `ExportController.cs` |
| wowsims/mop `tools/db2tool` | `adbbb98` | MIT + NOTICES | README, NOTICES, `tact/buildinfo.go`, `dbd/select.go` |
| mdX7/ribbit_data | `ef6f19f` | not checked | 11 `wow_classic_beta` version files |
| anombyte93/ForeverDiffCollector | `040fe29` | MIT | collector Lua, README, tests |
| smaitch/Grail | `11d8f1d` | none found | APIs/events in `Grail.lua` |
| danielcosta42/lodestar | `8964d0c` | MIT | `docs/forever.md` (Portuguese) |
| wowdev/wow-listfile, TACTKeys | `0be245d`, `8962765` | none found | trees, READMEs |
| ATT | `8e25511`, `a054efd` (M1) | MIT (repo) | `.update.bat`, mirrored CSV headers |
| Blizzard EULA | rev. 2024-03-21 | n/a | full text read |
| Blizzard news (Forever beta live) | 2026-09 | n/a | full page read |
| wowdev.wiki (DB2, ADB, TACT, CASC), Warcraft Wiki, classicwowforever.com, Blizzard forum/GitHub issue on WowB.exe | search snippets only | n/a | **not** fetched in full |
| wago.tools, Blizzard version service/CDN | — | — | **not accessible** |
