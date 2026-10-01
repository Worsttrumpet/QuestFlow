# M3 Probe Findings — Technical Companion

Full raw evidence behind `M3_REPORT.md`. This describes the **final probe implementation**
(`ForeverProbe.lua`, 17,092 bytes, internal `PROBE_VERSION = "m3-probe-0.1"` throughout — the string was
never bumped across either functional patch; each session below states which fixes were actually active
at the time, since the version string alone cannot be used to tell). Build `1.60.1.69977`, interface
`16001`, across all three sessions.

Evidence tags: `[V]` directly observed this milestone. `[2nd]` reported elsewhere, not reproduced.
`[?]` unresolved. Raw Blizzard-derived payloads (full objective text strings, table dumps) are quoted
below only where needed to support a specific claim, consistent with the project's no-raw-data-committed
rule — nothing here is a bulk export of quest content.

---

## 1. API existence scan (`/fprobe scan`, session 1, 47 audited paths + 2 helpers)

**[V] 40 of 47 present as callable functions, 7 absent.** Addon's own printed tally
(`"API scan complete: 40 present as functions, 7 not."`) cross-checked by hand against the operator's
screenshots — exact match.

| API | `type()` | Note |
|---|---|---|
| C_QuestLog.GetInfo | `function` | |
| C_QuestLog.GetQuestObjectives | `function` | |
| GetQuestLogQuestText | `function` | |
| GetQuestLogCompletionText | `function` | |
| C_QuestLog.GetQuestInfo | `nil` | absent (old-style name; superseded by `GetInfo`) |
| GetQuestLogTitle | `nil` | absent (pre-modern global) |
| HaveQuestData | `function` | |
| GetNumQuestRewards | `function` | |
| GetQuestLogRewardInfo | `function` | |
| GetQuestLogRewardMoney | `function` | |
| GetQuestLogRewardXP | `function` | |
| GetQuestLogRewardTitle | `function` | |
| GetQuestLogChoiceInfo | `function` | |
| C_QuestInfoSystem.GetQuestRewardSpells | `function` | |
| GetRewardHonor | `function` | |
| C_QuestLog.GetQuestsOnMap | `function` | |
| C_QuestLog.GetMapForQuestPOIs | `function` | |
| C_QuestLog.IsQuestFlaggedCompleted | `function` | |
| QuestPOIGetIconInfo | `nil` | absent |
| C_TaskQuest.GetQuestLocation | `function` | |
| C_TaskQuest.GetQuestsOnMap | `function` | |
| IsQuestComplete | `nil` | absent |
| IsQuestCompletable | `function` | |
| GetQuestsCompleted | `nil` | absent |
| C_QuestLog.IsOnQuest | `function` | |
| C_GossipInfo.GetAvailableQuests | `function` | |
| C_GossipInfo.GetActiveQuests | `function` | |
| GetQuestPortraitGiver | `function` | |
| GetQuestLogPortraitGiver | `nil` | absent — but `GetQuestLogPortraitTurnIn` (below) IS present; asymmetric |
| GetQuestLogPortraitTurnIn | `function` | |
| UnitPosition | `function` | |
| C_Map.GetPlayerMapPosition | `function` | |
| UnitName | `function` | |
| UnitGUID | `function` | |
| UnitLevel | `function` | |
| UnitClassification | `function` | |
| UnitCreatureType | `function` | |
| UnitCreatureFamily | `function` | |
| ClosestUnitPosition | `function` | |
| ClosestGameObjectPosition | `function` | |
| C_TaxiMap.GetAllTaxiNodes | `function` | |
| C_TaxiMap.GetTaxiNodesForMap | `function` | |
| TaxiNodeName | `function` | |
| TaxiNodePosition | `function` | |
| GetTaxiNodeCost | `nil` | absent |
| *C_QuestLog.GetNumQuestLogEntries* (helper, not in the M3 list) | `function` | needed to iterate the quest log by index |
| *C_Map.GetBestMapForUnit* (helper, not in the M3 list) | `function` | needed to call `C_Map.GetPlayerMapPosition` meaningfully |

Two additional helpers used only in the final probe, not covered by this scan (added after session 1):
`GetQuestID()` (used at `QUEST_COMPLETE`, confirmed present and correct — see Section 5) and `ReloadUI()`
(standard global, used only by `/fprobe save`, not part of any data-collection path).

## 2. Event methodology and lifecycle

Events registered: `ADDON_LOADED`, `PLAYER_LOGIN`, `QUEST_ACCEPTED`, `QUEST_LOG_UPDATE`,
`UNIT_QUEST_LOG_CHANGED`, `GOSSIP_SHOW`, `QUEST_DETAIL`, `QUEST_COMPLETE`, `QUEST_TURNED_IN`,
`QUEST_FINISHED`. `QUEST_LOG_UPDATE`/`UNIT_QUEST_LOG_CHANGED` are counted only (never printed, never
individually recorded) — session totals: 57 (session 1), unknown/not separately logged (session 2, small
session), 230 (session 3) — confirming these fire frequently during ordinary play and validating the
decision not to record each occurrence.

**`QUEST_ACCEPTED` fires with exactly one argument** on this build. Observed raw args: `{5052}`, `{879}`
(session 1); `{92460}`, `{92461}`, ... (session 3, 16 total, each a single-element table). Not the
two-argument `(questLogIndex, questID)` form used by some other client versions.

## 3. GUID → creature-ID methodology (QuestieLearner-style technique)

Method: on `GOSSIP_SHOW`, call `UnitGUID("npc")`, split the returned string on `"-"`, take the 6th field
as the numeric creature/NPC ID. Implemented so the **raw GUID is always stored alongside the parsed
result**, so a wrong split would be visible, not hidden.

**[V] Confirmed correct on 14 distinct NPCs, zero parse failures**:

| NPC name | Creature ID | Raw GUID (session first seen) |
|---|---|---|
| Mangletooth | 3430 | `Creature-0-4621-1-410-3430-000032B8EB` |
| Korran | 3428 | `Creature-0-4621-1-410-3428-000032B8EB` |
| Ailee Farheart | 251362 | (session 3) |
| Dalia the Collector | 251363 | (session 3) |
| Rorian the Dayseeker | 251361 | (session 3) |
| Elatrell Featherlight | 251368 | (session 3) |
| Windshaper Boro | 251374 | (session 3) |
| Yala Windwatcher | 249363 | (session 3) |
| Ventaari Brightwish | 251487 | (session 3) |
| Halaan Hawk-Eye | 257554 | (session 3) |
| Myriaal Mistwake | 263113 | (session 3) |
| Aetheen of the Gales | 251366 | (session 3) |
| Minor Manifestation of Earth | 251166 | (session 3) |
| Spirit Healer | 6491 | (session 3) |

Each parse was checked against its full raw GUID string at the time of capture; the technique is `[V]`
confirmed for this client, superseding the `[2nd]` status it carried in at the start of M3 (from
QuestieLearner, commit `788dad06815b`, on an unrelated codebase).

## 4. Title-capture behavior — before and after the fix

**Before the fix (session 1)**: `C_QuestLog.GetInfo(index)` was called and confirmed to return a real
table — `[V] 25 keys observed` (sample: `isAbandonOnDisable`, `sortAsNormalQuest`, `difficultyLevel`
[21 for quest 5052, 25 for quest 879], `questClassification`, `isHeader`). The probe's generic
`describe()` summarizer capped its output sample at 6 arbitrary keys (by `pairs()` iteration order, which
is unordered), and `title` was not among the 6 sampled for either quest. **Result: title unknown, not
absent** — the underlying data almost certainly included it; the probe's own summarization discarded it.

**The fix**: added explicit extraction immediately after the `C_QuestLog.GetInfo` call:
```lua
if ok and type(info) == "table" then
    rec.C_QuestLog_GetInfo_title = info.title
    rec.C_QuestLog_GetInfo_level = info.level
    rec.C_QuestLog_GetInfo_questID = info.questID
end
```
Tested against a stub WoW environment (synthetic `C_QuestLog.GetInfo` returning
`{questID=111, title="Fake Quest One", level=12}`) before being sent to the operator; confirmed the three
fields extracted correctly in isolation.

**After the fix (session 3), 16 of 16 quests captured a correct title**, with level and questID
cross-checked against each other for internal consistency on every one:

| Quest ID | Title | Level |
|---|---|---|
| 92460 | Coming of Age | 1 |
| 92461 | Harmony in Balance | 1 |
| 92462 | Infestation Investigation | 2 |
| 92463 | The Cirrusfly Queen | 3 |
| 92465 | Agitators | 3 |
| 92466 | Call of Earth | 4 |
| 92467 | Call of Earth | 4 |
| 92468 | Call of Earth | 4 |
| 92469 | Return to Rorian | 4 |
| 92470 | Foul Matriarch | 5 |
| 92471 | Aetheen of the Gales | 4 |
| 92474 | Falling With Style | 2 |
| 92484 | Embracing the Elements | 2 |
| 92598 | The Gift of Skysight | 4 |
| 93552 | Harvesting Windstones | 4 |
| 94414 | The Anchors of Zephras | 2 |

**Note on quest 92461, "Harmony in Balance":** this exact quest ID and title were used as a synthetic
example in M1's ATT-importer test fixtures, written before this session existed. Almost certainly not
coincidental — those fixtures were most likely modeled on real values seen in the legitimately-mirrored
ATT data parsed during M0/M1, rather than independently invented. Recorded for the project history; does
not affect the validity of either milestone.

`GetQuestLogTitle` and `C_QuestLog.GetQuestInfo` remained `nil`/absent throughout, consistent with the
Section 1 scan.

## 5. Reward-source observations — full detail

### Session 1 (accept-time capture, pre-fix)

Reward fields were captured inside the `QUEST_ACCEPTED` handler. Example (`quest_id=5052`):
```
GetRewardHonor: ok=true, values={0}
GetNumQuestRewards: ok=true, value=0
GetQuestLogRewardXP: ok=true, values={0,0}
GetQuestLogChoiceInfo: ok=false, values={"Usage: GetQuestLogRewardInfo(index)"}
GetQuestLogRewardMoney: ok=true, values={0}
reward_items: {} (empty)
```
All zero/empty — expected, since nothing is owed to the player at accept time. This is a probe-timing
artifact, not evidence about the client.

### Session 2 (complete-time capture via new `GetQuestID()` helper, n=1)

Quest 868 ("22 Egg Hunt"). At `QUEST_COMPLETE`:
```
GetQuestID(): ok=true, value=868
GetQuestLogRewardMoney(): ok=true, values={2500}
GetQuestLogRewardXP(): ok=true, values={0,0}
GetNumQuestRewards(): ok=true, value=0
```
At `QUEST_TURNED_IN` (fired ~6 seconds later): `quest_id=868, money_reward=0, xp_reward=0`.

**Two readings of the same quest, at nearly the same moment, disagreeing**: `GetQuestLogRewardMoney`
said 2500; `QUEST_TURNED_IN`'s own argument said 0. **At n=1, this could not distinguish "the event
argument is wrong" from "the event argument is right and this specific quest gives 0 money, while
`GetQuestLogRewardMoney` is wrong."** The tentative conclusion drawn at the time (event args unreliable)
turned out to be the less-supported reading.

XP reward showing `0` for this quest was later explained by the operator: the character was at the
beta's level-20 cap for the entire session, and a capped character receives no XP from any quest. This
is consistent with money (uncapped) reading nonzero while XP (capped) read zero — an operator-reported
explanation, not independently verified by re-testing on an uncapped character with this exact quest, but
specific and plausible.

### Session 3 (complete-time capture, n=15 turn-ins, fresh level-1 character — not capped)

`QUEST_TURNED_IN` arguments (`quest_id`, `money_reward`, `xp_reward`):

| Quest ID | Money | XP |
|---|---|---|
| 92460 | 0 | 40 |
| 92461 | 15 | 80 |
| 92462 | 35 | 170 |
| 92463 | 100 | 320 |
| 92465 | 50 | 250 |
| 92466 | 0 | 270 |
| 92467 | 0 | 180 |
| 92468 | 0 | 360 |
| 92469 | 0 | 35 |
| 92471 | 0 | 35 |
| 92474 | 0 | 85 |
| 92484 | 0 | 85 |
| 92598 | 0 | 180 |
| 93552 | 75 | 360 |
| 94414 | 0 | 85 |

XP values scale plausibly with quest level (40 for a level-1 quest, up to 360 for level-4/5 quests) —
consistent with genuine reward data, not placeholder values.

`GetQuestLogRewardXP`/`GetQuestLogRewardMoney`, called identically to session 2 for every one of these
15 turn-ins: **`values={0,0}` and `values={0}` respectively, every single time, no exceptions.**

**Corrected conclusion**: `QUEST_TURNED_IN`'s arguments are the reliable reward source on this build;
`GetQuestLogRewardMoney`/`XP` called with no arguments are not, most likely because they require a quest
explicitly selected in the quest-log UI first (a step never performed by this probe). The session-2
`2500` reading was most likely a coincidental holdover from the quest log's selection state at that
moment, not evidence the no-argument calling pattern is generally reliable.

`GetQuestLogChoiceInfo` failed identically across every attempted call, in every session:
`ok=false, values={"Usage: GetQuestLogRewardInfo(index)"}` — a real, informative negative result: the
function requires an index argument the probe never supplied. **Not tested successfully; not claimed to
work.**

`GetNumQuestRewards` returned `0` on every single quest observed across all three sessions — meaning no
quest with an item reward happened to be tested this milestone. Item-reward capture is therefore
**untested**, not confirmed-absent.

## 6. Objectives — before and after, item-name quirk

Session 1, quest 5052 (already complete at accept-time capture): one objective,
`type="item", numRequired=1, finished=true, text="1/1 Blood Shard", numFulfilled=1` — real, correct text.

Session 1, quest 879 (freshly accepted, item-collect type): two objectives, both
`text="0/1  "` — **note the blank item name** where one would expect e.g. `"0/1 Rockjaw Fang"`. `[?]`
whether this is an item-name client-cache timing quirk (name not yet resolved locally, since the quest
was captured immediately on accept) or something else — not explained further.

Session 3 (16 quests, mix of monster-kill and item-collect objectives): **the blank-name quirk did not
reproduce.** Sample real text observed: `"0/8 Juvenile Vuldren slain"`, `"0/8 Pesky Cirrusfly slain"`,
`"0/7 Al'Aketh Convert slain"`, `"0/1 Cirrusfly Queen slain"`. Two quests (92460, 92469) returned `{}`
(empty objectives table) — plausibly quests with no kill/collect objective (e.g. talk-to-NPC only), not
investigated further.

`GetQuestLogQuestText`/`GetQuestLogCompletionText`, called with no arguments immediately after accept in
every session: **`ok=true` but empty `values` every time.** These globals exist and are callable but
return nothing in this calling pattern — a clean negative result, not a crash, and not claimed to be a
working text-retrieval path.

## 7. Cache-file findings (direct file access, not addon API — separate evidence category)

**[V] Before M3 began, `Cache\WDB\enUS\` already contained 6 files**: `creaturecache.wdb` (202,591 B),
`gameobjectcache.wdb` (10,157 B), `npccache.wdb` (32 B), `pagetextcache.wdb` (7,252 B),
`petitioncache.wdb` (298 B), `questcache.wdb` (61,265 B). **1 `DBCache.bin` also present.**

**[V] `questcache.wdb`'s 24-byte header, read directly:**

| Field | Raw value | Note |
|---|---|---|
| Signature bytes | `TSQW` | Equals the documented `0x57515354` constant stored little-endian — verified by direct computation (`(0x57515354).to_bytes(4,'little') == b'TSQW'`). Confirms this is genuinely a QuestCache.wdb file per the documented format. |
| Client version | `69913` | Matches the build current at the time this snapshot was taken (before the 69977 update) — notably different from QuestV2.db2's internal schema string in M2, which read an unrelated `69800`. |
| Locale (raw / reversed) | `SUne` / `enUS` | The documented "locale stored reversed" quirk holds on a real file. |
| Record size / version / cache version | `12296` / `12` / `0` | Recorded as-is; per-record layout not decoded (a third source, AddonStudio's wiki, describes variable-length ID+length-prefixed records rather than a fixed record_size, so this field's exact role is `[?]`). |

**[V] After one multi-quest play session, `questcache.wdb` grew to 62,446 bytes (+1,181 bytes), SHA-256
changed.** Direct, measurable evidence the client actively wrote new data into this file — not merely a
timestamp touch. **No new cache files appeared or disappeared.**

**`DBCache.bin`**: only its first 4 bytes were checked (`XFTH`, matching the hotfix-container magic
constant hard-coded in `wowsims/mop`'s `tools/db2tool/wdc/hotfix.go`, MIT, commit
`adbbb9824059712ed299bc89ec1b3b08c1f28a97`). No further structure was read.

**No cache record content was decoded, decrypted, or extracted.** This satisfies the M3 scope exactly:
header/metadata only.

## 8. Tested and failed (clean negative results, not omissions)

- `GetQuestLogTitle` — absent (`nil`) on this interface, every scan.
- `C_QuestLog.GetQuestInfo` — absent (`nil`), every scan.
- `QuestPOIGetIconInfo`, `IsQuestComplete`, `GetQuestsCompleted`, `GetQuestLogPortraitGiver`,
  `GetTaxiNodeCost` — absent (`nil`), every scan.
- `GetQuestLogQuestText`, `GetQuestLogCompletionText` — present but return empty when called with no
  arguments right after accept, every time tested.
- `GetQuestLogChoiceInfo` — present but errors without an index argument, every time tested.
- `GetQuestLogRewardMoney`/`XP` — present but return zero when called with no arguments at
  `QUEST_COMPLETE`, 15 of 16 times tested (the 1 exception, session 2, is treated as likely coincidental
  per Section 5, not as evidence the method works).
- `GetQuestPortraitGiver` — present, returns `ok=true` but blank name/`0` texture, every time tested.

## 9. Remaining unknowns

- Why `ForeverProbeDB.events` did not appear to carry over between sessions 1 and 2 (52 events →
  effectively reset before session 2's 5) despite being account-wide SavedVariables. Not investigated.
- Why `QUEST_FINISHED` fires multiple times per turn-in on this build (24 times across 8 lifecycles in
  session 1; 65 times across 15-16 lifecycles in session 3). Recorded as observed, not explained.
- Whether an explicit quest-selection call (e.g. a `SetSelectedQuest`-style API) would make
  `GetQuestLogRewardMoney`/`XP` return correct values when called afterward. Not tested.
- Whether the item-name blank-text quirk (session 1 only) is a general item-objective issue or specific
  to that one quest/moment. Not reproduced or further isolated.
- Whether any quest with an item reward exists among untested quest types — `GetNumQuestRewards` read
  `0` for every single quest observed this milestone, so item-reward capture remains entirely untested.
- Full DBCache.bin structure beyond its magic bytes.
- Whether the documented `QuestCache.wdb` record layout (wowdev.wiki, `[2nd]`) matches this client's
  actual per-record content — only the file-level header was read, not individual records.
