# M7.6: In-Game Data Harvesting Feasibility — Technical Research

Read-only investigation. No code, M6 data, or licensing file was modified. Every finding below is traced
to actual source code in `m5-production-recorder/addon/ForeverRecorder/` or to already-existing research in
`forever-db/research/m1_5/REPORT.md` and `forever-db/docs/M5_PRODUCTION_RECORDER_DESIGN.md` — nothing is
assumed or inferred without a cited source.

## 1. The Actual Current Pipeline (Traced From Code, Not Documentation)

```
human action (talk to NPC / view quest / turn in quest)
    ↓
WoW client fires an event (QUEST_DETAIL / QUEST_COMPLETE / QUEST_TURNED_IN / GOSSIP_SHOW / GET_ITEM_INFO_RECEIVED)
    ↓
Dispatcher.lua's frame:OnEvent handler (the ONLY entry point -- confirmed, only 8 events registered)
    ↓
dispatchCheckpoint()/dispatchEvent() calls each registered observer module's capture()/on_event()
    ↓
recordObservation() appends a raw table to ForeverObservationLabDB.observations (SavedVariables, in memory)
    ↓
/fr save → Export.lua calls ReloadUI() only (confirmed: no data transformation, no network call anywhere in this file)
    ↓
WoW's own client writes SavedVariables to disk on the reload
    ↓
human exports the .lua file, sends it
    ↓
M4's savedvars.py parses it; M4's importer.py turns raw observations into assertions
    ↓
M6.2 coverage / M6.4 classification / M6.6 guide dataset
```

Every step above is confirmed directly from source, not assumed.

## 2. Exactly Which Events Are Hooked (Dispatcher.lua, Confirmed)

```
ADDON_LOADED, PLAYER_LOGIN, QUEST_DETAIL, QUEST_COMPLETE, QUEST_TURNED_IN, QUEST_FINISHED, GOSSIP_SHOW, GET_ITEM_INFO_RECEIVED
```

**`QUEST_FINISHED` is registered but intentionally never dispatched to any module** — the code comment
states it "fires multiple times per turn-in ... and carries no data," confirmed repeatedly per M3/M4.

**Not hooked, confirmed by their absence from this exact list**: `QUEST_ACCEPTED`, `QUEST_LOG_UPDATE`,
`QUEST_WATCH_UPDATE`, `PLAYER_TARGET_CHANGED`/`UNIT_TARGET`, `UPDATE_FACTION`, `TAXIMAP_OPENED`.

## 3. `/fr status` and `/fr save` — Exact Implementation

`SlashCommands.lua` (full file read): `/fr status` prints `#ForeverObservationLabDB.observations`,
`CurrentSessionID`, and `CurrentBuildInfo.observed_build` — nothing else; it does not inspect or summarize
observation content. `/fr save` calls `ForeverRecorder.Export.Save()`, which (per `Export.lua`, full file
read) does exactly one thing: `ReloadUI()`. **No data transformation, filtering, or network activity exists
in this file** — the TOC file's own note confirms this: *"Records locally; export is manual and
local-only... No networking of any kind."* The confirmation of a successful save is not printed by this
code at all — it comes from `Bootstrap.lua`'s next-load banner (`ObservationCountAtLoad`), a real fact
rather than an unverifiable in-the-moment message.

## 4. Per-Observer API Surface (Every Field Currently Captured, Traced From Code)

| Observer | Checkpoints | Exact APIs called | Notes |
|---|---|---|---|
| `QuestMeta` | `quest_detail`, `quest_complete_immediate`, `quest_complete_delayed` | `C_QuestLog.GetNumQuestLogEntries`, `C_QuestLog.GetInfo` (title, level, questID), `C_QuestLog.GetQuestObjectives` | Requires the quest to already be in the log — confirmed by `findQuestLogIndexByID`'s linear scan; fails silently (`quest_log_index_error`) if not found |
| `GiverIdentity` | `quest_detail`, `quest_complete_immediate`, `quest_complete_delayed`, `GOSSIP_SHOW` | `UnitGUID` (via `GuidUtil.CreatureIDFromUnit`), `UnitName`, `UnitLevel`, `UnitClassification`, `UnitCreatureType`, `UnitCreatureFamily`, `PositionUtil.Capture()` | Captures **both** `npc` and `target` units separately |
| `PositionUtil` (used by `GiverIdentity`, not its own observer) | n/a | `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(mapID, "player")`, `pos:GetXY()` | **The unit token is hardcoded to `"player"` — confirmed directly in code.** Never queries any other unit's position. No API for NPC world position is called or referenced anywhere in this addon. |
| `Gossip` | `GOSSIP_SHOW` | `C_GossipInfo.GetAvailableQuests`, `C_GossipInfo.GetActiveQuests` | **Real, confirmed data-discarding behavior**: `extractQuestList` reports `total_count` for the full list but only samples the **first 5** entries in full detail (`if shown >= 5 then break`). An NPC with more than 5 gossip quests has some silently under-sampled — count is preserved, detail is not. |
| `RewardsXPMoney` | `QUEST_TURNED_IN` | Event arguments only (`args[2]`, `args[3]`) | Code comment confirms `GetQuestLogRewardMoney/XP` were tested and found unreliable on 15 of 16 real quests — deliberately not used |
| `RewardsItems` | (checkpoints not re-read this pass; established in M4/M5) | `GetQuestItemInfo` | Returns 6 positional values (`r1`...`r6`); this project's code does not label which numbered return is itemID vs. icon vs. quality — captured, not semantically decoded |
| `RewardsReputation` | (established) | `GetQuestLogRewardFactionInfo` | `GetFactionInfoByID` explicitly confirmed **absent** on Forever (code comment: exact error message recorded) |

## 5. Client-Side API Research Already On File (Not Newly Discovered, But Currently Unused)

`research/m1_5/REPORT.md` §7 already investigated a broader API surface than the recorder currently uses,
each tagged with this project's own evidence rigor (`[V]` = verified by inspecting real collector code,
`[2nd]` = another project's claim, cited not verified, `[?]` = genuinely unknown on Forever):

- **Quest frame text APIs** (`GetTitleText`, `GetQuestText`, `GetObjectiveText`, `GetProgressText`,
  `GetRewardText`) — `[V]` in a third-party collector's code, `[2nd]` that it actually worked on Forever.
  Not used by `ForeverRecorder` (which uses `C_QuestLog.GetInfo` instead — a different, already-proven API).
- **Client-side WDB cache files** — `Cache/WDB/questcache.wdb`, `creaturecache.wdb`, `gameobjectcache.wdb`,
  written by the client itself; `RequestLoadQuestByID` reportedly triggers a server record; documented
  24-byte-header-then-records format — `[2nd]`, **entirely unverified on Forever, never attempted by this
  project.** This is client-written data outside the addon API surface entirely — reading it would require
  file access this addon has never used, and its legitimacy/accessibility from a normal addon is unknown.
- **Taxi node APIs** — `NumTaxiNodes`, `TaxiNodeName`, `C_TaxiMap.GetAllTaxiNodes(uiMapID)`, available while
  the taxi map UI is open (`TAXIMAP_OPENED`/`TAXIMAP_CLOSED`) — `[2nd]` (Warcraft Wiki), Forever behavior
  `[?]`. **Entirely unused by the current recorder.** If real, this would let one taxi-map opening enumerate
  every flight point for that map in a single call — a genuinely different shape of data (bulk, not
  per-interaction) from anything the recorder currently captures.
- **Objective target IDs** (the actual creature/item/object ID an objective refers to, not just its text) —
  `[2nd]`: "no API exposes them; the WDB cache record has them." This matches this project's own real
  experience: `objective.att`'s data (ATT candidate, Section 10) includes structured `targets` with
  `kind`/`id`, something the *live client* apparently cannot give the addon directly.
- **Prerequisites/quest chains** — `[2nd]`: another project ("Grail") only *infers* these via
  `IsQuestFlaggedCompleted`/`GetQuestsCompleted`/accept-turn-in event history plus its own database, never
  reads them directly. Consistent with this project's own standing finding: `prerequisites` has had zero
  data source through M6.6.
- **A secondhand claim about quest level being "unreliable while the frame is open"** conflicts with this
  project's own verified, repeated real-world success capturing level via `C_QuestLog.GetInfo` (confirmed
  across dozens of real M6.5 observations) — noted as a discrepancy, not resolved; this project's own
  first-hand `[V]` evidence is more directly applicable to Forever than the secondhand claim.

## 6. What Is Captured But Discarded (Confirmed, Not Assumed)

- **Gossip quest lists beyond the first 5** — `total_count` is kept, full detail for entries 6+ is not
  captured at all (not merely discarded after capture — never read from the game in the first place beyond
  the count).
- **`UnitClassification`/`UnitCreatureType`/`UnitCreatureFamily`** for both `npc` and `target` units are
  fully captured by `GiverIdentity` but not currently consumed by the M4 importer's field mapping (verified:
  the importer only emits `giver.npc` from `name`/`parsed_creature_id`, nothing from these three fields) —
  present in every raw observation, unused downstream.
- **The `target` unit's full capture** (name, level, classification, position) is recorded by every
  `GiverIdentity` call but the M4 importer only ever reads the `npc` unit for `giver.npc` — the `target`
  capture exists in every raw export and is not imported into any M6 field at all.

## 7. Scenario-by-Scenario (Section 12 of the Task)

| Scenario | Currently automatic? | Evidence |
|---|---|---|
| A: Accept a quest | **No** | `QUEST_ACCEPTED` is not registered in `Dispatcher.lua` at all |
| B: Talk to a quest giver | **Partially** | `GOSSIP_SHOW` fires on essentially any NPC talk and does trigger `GiverIdentity`/`Gossip` capture without the player needing to "think about" data collection — this is the one scenario already effectively passive today, confirmed by this project's own M6.5 sessions (gossip captures happened incidentally) |
| C: Progress through objectives | **No** | No event exists in the hooked list that fires on objective progress; objectives are only read as a snapshot at the three `QuestMeta` checkpoints |
| D: Turn in a quest | **Yes, for the checkpoint itself** | `QUEST_COMPLETE`+`QUEST_TURNED_IN` together are the most reliable capture in the whole system, proven repeatedly (M6.5's 8/10 real resolutions all came through here) — but still requires the player to manually initiate the turn-in dialog, same as always |
| E: Move around the world | **No** | `PositionUtil.Capture()` is only ever invoked as a sub-step inside `GiverIdentity`'s capture — there is no periodic timer or movement event hook anywhere in this addon |

## 8. The One Concrete, Evidence-Grounded Re-Examination Worth Naming

`docs/M5_PRODUCTION_RECORDER_DESIGN.md` explicitly excluded `QUEST_ACCEPTED`, but for a narrower reason than
M7.6 is asking about: *"the first carries no additional information beyond what `QUEST_DETAIL` already
captured... fires with a single argument, the quest ID, nothing else."* That reasoning addresses whether
`QUEST_ACCEPTED`'s own event *payload* is useful — it does not address whether *hooking* the event (to
trigger a `QuestMeta`-style capture attempt at that moment, the same way `QUEST_DETAIL` does) would help.
This matters because of a real, already-documented finding from M6.5: **talking to an NPC whose quest is
already accepted opens `GOSSIP_SHOW`, not `QUEST_DETAIL`** — meaning the current recorder has no reliable
way to capture an already-accepted-but-not-yet-turned-in quest's title/level/objectives except by turning
it in. Hooking `QUEST_ACCEPTED` to trigger the same `QuestMeta`/`GiverIdentity` capture logic already used
elsewhere would capture that data at the one moment it's freshest — right as the quest enters the log,
exactly when `findQuestLogIndexByID`'s scan is most likely to succeed. This is a genuine, code-grounded
observation, not a general "we should collect more" preference — but it is **not implemented here**, per
the milestone's explicit scope.
