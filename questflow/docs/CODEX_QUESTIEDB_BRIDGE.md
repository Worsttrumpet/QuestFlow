# Forever Codex: the QuestieDB bridge (first, conservative implementation)

**Status:** implemented and proven against a *fake* of QuestieDB's documented API in the stub client. **Not yet proven on the real client** (see "Still needs real-client verification"). The existing data is still the fallback; nothing was removed.

## Architecture

```
QuestieDB addon (optional, separate, installed by the player)      QuestieTrace (separate community system; NOT read)
        |  documented public API, read-only, at runtime
        v
ForeverCodex/QuestieBridge.lua  ->  registers ONE quest pack "questiedb" (a live source: get(id) / ids())
        |
        v
Registry (merges packs field by field, by priority)
   observed Forever data   priority 100   src=observed  verified=true     (Codex's own evidence; never overwritten)
   QuestieDB               priority  50   src=questiedb verified=false    (baseline knowledge)
   existing ATT-derived    priority  10   src=att       verified=false    (TEMPORARY fallback, migration only)
        |
        v
Engine / Quest provider / Planner / Navigation / UI      (unchanged: they read the same merged records)
```

QuestieDB is the world/quest knowledge baseline. Codex is the planner, optimizer, player state, telemetry, Forever observations/evidence and UI. QuestieTrace is a separate community research system: nothing in Codex reads it, and nothing it produces is treated as Codex-verified evidence.

**Nothing is copied.** No QuestieDB code or data is in this repository; the bridge only calls the library that is installed on the player's machine. (QuestieDB's own licence could not be confirmed from its repositories or from the sources reachable during the investigation: neither repository carries a licence file. Because nothing is redistributed, Codex does not need that answer to ship the bridge, but it should still be confirmed with the maintainers.)

## Dependency behaviour

* `## OptionalDeps: QuestieDB` in `ForeverCodex.toc` (not `Dependencies`): QuestieDB loads before Codex when it is installed, and Codex loads either way. Questie itself is not required.
* **Installed and usable:** it becomes the primary world knowledge (below).
* **Missing:** Codex loads, prints one clear line at login ("The QuestieDB addon was not found. Codex uses QuestieDB for its quest knowledge ... Until then Codex uses its own small built-in data ..."), `/codex questiedb` and `/codex diag` say `NOT in use (missing)`, and the existing data is used. Nothing is pretended.
* **Installed but not usable** (unsupported contract, a non-Forever flavor, a broken interface): same, with the reason (`contract`, `flavor`, `error`). A QuestieDB serving non-Forever data is not used because Era-framed coordinates would put a few zones in the wrong place.

## Exact QuestieDB APIs used (documented in QuestieDB `docs/api.md`)

| API | Used for |
|---|---|
| `LibQuestieDB.RequireContract(1)` | version-range check (passes for any supported contract, 1 or newer) |
| `LibQuestieDB.Quest.GetAll(id, keys)`, `.Exists`, `.Get`, `.GetAllIds()` (global shorthand `QuestDB`) | quest facts, the list of known quests, the smoke check |
| `LibQuestieDB.Npc.GetAll(id, keys)`, `.Get` (global shorthand `NpcDB`) | NPC name, spawns, primary area, friendliness |
| `LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId` | AreaID to UiMapID (a Lua source string, decoded once) |
| `LibQuestieDB.readMode`, `LibQuestieDB.ModeIndicator.GetStatus()` | mode, flavor, contract, for diagnostics and the flavor check |
| addon metadata of `QuestieDB`: `Version`, `X-BUILD-COMMIT`, `X-Flavor`, `X-Mode` | version and build commit in diagnostics |

Quest fields read: `name`, `startedBy`, `finishedBy`, `requiredLevel`, `questLevel`, `requiredClasses`, `requiredRaces`, `objectivesText`, `preQuestGroup`, `preQuestSingle`, `specialFlags`, `breadcrumbForQuestId`. NPC fields: `name`, `spawns`, `zoneID`, `friendlyToFaction`.

Never used: any correction/registrar API (the bridge never writes into the shared QuestieDB, which would change what Questie itself shows), `GetRaw`, undocumented `Enum` internals. A test scans the bridge for these.

## Evidence and provenance

* **Missing from QuestieDB means unknown, never "does not exist".** The stable QuestieDB release currently lacks the 732 Forever-only quests of its source; a newer build has them. A quest QuestieDB lacks reads as unknown, falls back to the existing data if that has it, and otherwise stays a reminder (a quest in your log) or is simply not offered. No text says a quest does not exist.
* Everything read from QuestieDB is `src=questiedb`, `verified=false`, and shows as "(QuestieDB, unverified on Forever)". It is a baseline from Classic and community work, not proof of Forever behaviour.
* QuestieDB's provenance API collapses its internal layers to "QuestieDB" (raw, delta-base and trace-derived values are indistinguishable at runtime), so **Codex does not claim to know which layer a value came from**.
* Observed Forever data is never overwritten: it has priority 100, and the merge is field by field, so QuestieDB only fills fields the observed record lacks.
* **Changed giver guard:** if an observed record names a different giver NPC than QuestieDB's, QuestieDB's coordinate belongs to the other NPC and is not used; the location falls back to the observed position (labelled approximate) and the conflict is recorded (`locConflict`). This applies only to the QuestieDB pack; existing ATT behaviour is byte-for-byte as before.
* Diagnostics (`/codex diag`, `/codex report`, `/codex questiedb`) show the QuestieDB version, build commit, mode, flavor, contract, quest count, records read, records with a location, and errors.

## Conservative limits (deliberate, each a later decision)

| Not done | Why |
|---|---|
| Race restrictions from `requiredRaces` | Forever's new races use bit positions that only Questie (the consumer) interprets; that is not part of QuestieDB's documented database API. The mask is kept (`raceMask`) for diagnostics. Faction is **inferred** from the giver NPC's friendliness and labelled so. Race-specific quests that only QuestieDB knows would therefore be offered to other races of the same faction. |
| Class restrictions | Done: standard class ids, bit n-1; a mask with unknown bits is left unenforced. |
| Using the turn-in NPC for routing | It is read (`turnIn`) and kept, but the quest provider still assumes the turn-in at the giver, exactly as before. Using it changes route behaviour; that is a separate decision. |
| Objective areas, object/item starters, exclusivity, Questie's own hide/blacklist policy | Not needed for equivalence; QuestieDB-only quests have no objective area (the existing pack's remain where it has them). |
| `all-of` prerequisites | Implemented in the Quest provider (`prereqAll`); the planner's chain credit still reads the any-of list. |

## How the fallback works

The existing ATT and observed packs are still loaded and still registered. The merge takes the first layer that has each field, in priority order, so: observed first, QuestieDB second, the old data only for what neither has (a quest QuestieDB lacks; objective areas; race lists; zone grouping). If QuestieDB is missing or unusable the pack is simply not registered and behaviour is the old behaviour. Removing the bridge later is deleting `QuestieBridge.lua`, its `.toc` lines and the three small Registry additions.

## Tests

* `tests/fake_questiedb.lua`: a stand-in for the documented API (documented nil/empty/packed semantics; no QuestieDB data or code).
* `tests/bridge_tests.lua`: dependency behaviour, field mapping, provenance, missing = unknown, the 98298 development check on a "stable" fake (absent) and a "newer" fake (present), layering, the changed-giver guard, failure handling, and boundary scans (no writes into QuestieDB, optional dependency, no QuestieDB names in data packs).
* `tests/planner_eval.lua`: **every one of the 22 scenarios is run three ways** (existing packs; a fake QuestieDB with the same facts layered over them; and, for the 9 scenarios the bridge fully covers, the fake as the only quest source besides observed). The Planner makes the identical decision each time. The Phase 2.5 baseline and the Phase 1 golden are untouched.
* Mutation checks (priority, `verified`, the giver guard, the absent-quest wording, the flavor check) were each caught.
* A real bug was found by these tests and fixed: the quest provider crashed (losing every quest candidate) if a live source listed an id it could not read; it now skips unreadable records.

## The development smoke check

`/codex questiedb [quest id] [npc id]` prints whether QuestieDB is in use (version, build commit, mode, flavor, contract) and asks it `Quest.Exists`, `Quest.Get(id, "name")`, `Npc.Get(id, "name")`, `Npc.spawns(id)` and the AreaID to UiMap mapping. Its defaults (98298 and 1938) exist only in the command; **no planner or product logic knows them** (a test scans every other file). On a stable QuestieDB release 98298 is expected to be absent; on a newer build it is expected to be present. Both are normal.

## Still needs real-client verification

1. `/codex questiedb` on the Forever client with the CurseForge QuestieDB: status `IN USE`, version and build commit shown, `Npc.Get(1938, "name")` = Dalar Dawnweaver, `Quest.Exists(98298)` = false on the stable build.
2. That `LibQuestieDB.ModeIndicator.GetStatus()` and `Support.Get("ZoneDB").private.areaIdToUiMapId` behave as documented on the client (the bridge copes if they do not, but the flavor check and coordinates depend on them).
3. Load cost: how long the first plan takes with about 4,250 quests merged (`/codex diag` shows records read; no timing is claimed).
4. That quest locations from QuestieDB land where the NPCs actually stand (spot-check several, not one), and that Horde/Alliance filtering by giver friendliness gives sensible lists for a Horde Skyborne.
5. With QuestieDB disabled in the addon list: Codex loads, prints the single setup line, and plans from its own data.
6. With a newer (preview) QuestieDB build: quest 98298 appears, located in The Sepulcher.

## Golden / baseline changes

None. `tests/golden/engine_plan.golden` and `tests/golden/planner_eval_baseline.txt` are unchanged (the existing scenarios pass byte-for-byte with and without the bridge). `docs/CODEX_PLANNER_EVAL_REPORT.md` was regenerated: it gains the two equivalence lines and the new pass count.
