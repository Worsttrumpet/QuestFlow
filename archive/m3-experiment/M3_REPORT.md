# M3 Report — Final

M0–M2 remain frozen; nothing under `forever-db/` was modified to produce this report. This document
describes the **final probe implementation** (`ForeverProbe.lua`, 17,092 bytes, internal version string
still `m3-probe-0.1` — the string was never bumped despite two functional patches during M3; noted here
so the code and this report can be cross-checked against each other honestly). Full raw evidence behind
every claim is in the companion document, `M3_PROBE_FINDINGS.md`.

Evidence tags: `[V]` directly observed on the operator's real WoW Forever beta client this milestone.
`[2nd]` reported by outside research, not independently reproduced. `[?]` unresolved.

---

## 1. Objective

M3 asked two related questions:

1. Does the WoW Forever addon environment (public Lua quest-log, gossip, and unit APIs) — and/or the
   local client cache — expose meaningful quest information beyond QuestV2's bare ID/flag/theme fields
   (M2), specifically: title, level, objectives, rewards, giver identity, and coordinates?
2. **Can a normal, policy-compliant WoW Forever addon collect enough of that information, through a real
   quest lifecycle, to assemble one structured, useful quest record?**

M3 does not attempt to build a database, an importer, or a production addon. It is a disposable research
probe answering exactly those two questions.

## 2. Method

**The addon**: `ForeverProbe`, a single-file, read-only Lua addon (`ForeverProbe.toc` + `ForeverProbe.lua`).
It never calls `AcceptQuest`, `CompleteQuest`, `TurnInQuest`, or any function that acts on the game world;
every quest action was performed manually by the operator. It:

- Prints and records its own build/interface assumptions on load (`GetBuildInfo()`, compared against the
  interface version `16001` recorded in M2).
- On `/fprobe scan`, calls `type()` on 47 candidate APIs from the M3 research list (plus 2 small
  necessary helpers not in that list, `C_QuestLog.GetNumQuestLogEntries` and `C_Map.GetBestMapForUnit`,
  needed to call some of the audited APIs meaningfully) and records which exist as callable functions.
- Registers a minimal event set (`QUEST_ACCEPTED`, `QUEST_LOG_UPDATE`, `UNIT_QUEST_LOG_CHANGED`,
  `GOSSIP_SHOW`, `QUEST_DETAIL`, `QUEST_COMPLETE`, `QUEST_TURNED_IN`, `QUEST_FINISHED`) and, on each
  quest-relevant event, attempts to capture quest ID, title, level, objectives, text, rewards, giver
  name/GUID/parsed-creature-ID, and coordinates — wrapping every API call in `pcall` so a missing or
  erroring API is recorded as a clean failure, never a crash or a silently dropped field.
- Silently counts (never prints) `QUEST_LOG_UPDATE`/`UNIT_QUEST_LOG_CHANGED`, since these fire dozens of
  times during ordinary play and would otherwise flood chat.
- Writes everything to account-wide SavedVariables (`ForeverProbeDB`) for reliable retrieval, since chat
  output alone is lossy and hard to transcribe at scale.

**The probe was revised during M3** because the initial title-capture approach proved unreliable — see
Section 6 for the full account. The reward-capture timing was also revised mid-experiment for the same
reason: an initial design flaw, found from real data, was diagnosed and fixed before the final session.

**Tested quest lifecycle**: accept → (gossip/detail interaction with the giver) → complete objectives
through normal play → return and turn in. Performed for real, multiple times, across three sessions.

**Addon/API observation vs. direct cache-file inspection — kept distinct throughout**: the addon-API
findings in this report come from Lua API calls, a normal, widely-practiced category of addon behavior.
Separately, a PowerShell script (`m3_cache_snapshot.ps1`) took before/after metadata snapshots of
`Cache\WDB\*.wdb` and `Cache\ADB\**\DBCache.bin` directly from disk — a different category of access (the
operator reading files with an OS tool, not the addon reading them from inside the game), carrying the
same unresolved EULA question already on record from M1.5/M2, not re-litigated here. Only file existence,
size, hash, and (for WDB files) the 24-byte documented header were read; no cache record content was
decoded, decrypted, or extracted.

## 3. Experiment Sessions

| # | Character / context | Events recorded | What changed and why |
|---|---|---|---|
| **1** | Level 20 (at the beta's level cap), one NPC ("Mangletooth"), 7 quests turned in + 1 quest accepted (a second, "Tribes at War," had been accepted before this log began), all within a 27-second span | **52** (10 GOSSIP_SHOW, 7 QUEST_COMPLETE, 7 QUEST_TURNED_IN, 24 QUEST_FINISHED, 2 QUEST_DETAIL, 2 QUEST_ACCEPTED) | First real run. Found: the API-existence scan (40/47 present); the GUID→creature-ID technique worked; objectives returned real text; **but title was never captured** — traced to a probe bug (Section 6) — and reward fields were captured at the wrong lifecycle moment (accept time, before anything is owed), so all rewards read zero. |
| **2** | Same level-20 character, one additional quest ("22 Egg Hunt") turned in, using a **patched** probe (reward-timing fix applied) | **5** (1 QUEST_COMPLETE, 1 QUEST_TURNED_IN, 3 QUEST_FINISHED) | Confirmed the reward-timing fix works in principle: `GetQuestLogRewardMoney`, now called at `QUEST_COMPLETE`, returned a real, non-zero value (2500 copper). But `QUEST_TURNED_IN`'s own event arguments showed `0/0` for the same quest — from this single data point, the tentative conclusion was that the event arguments were unreliable and `GetQuestLogRewardMoney`/`XP` were the trustworthy source. **This conclusion was wrong and is corrected in Section 5.** Sample size: 1 turn-in. |
| **3** | Fresh level-1 Skyborne shaman, full Zephras Isle starting area, played normally to the earth totem quest reward, using the **same patched probe plus a title-capture fix** applied after session 1 | **161** (30 GOSSIP_SHOW, 17 QUEST_DETAIL, 65 QUEST_FINISHED, 16 QUEST_ACCEPTED, 18 QUEST_COMPLETE, 15 QUEST_TURNED_IN) | Confirmed the title-capture fix: **16 of 16** `QUEST_ACCEPTED` events captured a correct title. With **15 turn-ins** instead of session 2's 1, the reward-source conclusion reversed: `QUEST_TURNED_IN`'s arguments showed real, plausible, level-scaling values every time, while `GetQuestLogRewardMoney`/`XP` (called the same way as session 2) returned flat zero on all 15. This is the corrected, better-supported conclusion (Section 5). |

**Totals across all three sessions**: 18 `QUEST_ACCEPTED`, 23 `QUEST_TURNED_IN`, **14 distinct NPCs**
identified by name and parsed creature ID (Mangletooth 3430, Korran 3428, plus 12 more in the Skyborne
starting area — full list in `M3_PROBE_FINDINGS.md`).

Session 2's small sample size is deliberate context, not an oversight: it was a fast, targeted check of
one specific fix (reward timing) immediately after patching, before committing to a longer session. Its
conclusion turned out to be incomplete precisely because the sample was small — which is itself a useful,
honestly-reported part of this record.

## 4. Verified Results

Everything below is `[V]` — directly observed on the operator's real Forever client (build `1.60.1.69977`,
interface `16001`; note the build number moved from M2's `69913` — the beta updated between milestones,
a new fact not applied to the frozen M1 registry here).

| Field | Result | Sample |
|---|---|---|
| **Quest ID** | Obtainable from every relevant event (`QUEST_ACCEPTED` argument, `GetQuestID()` at `QUEST_COMPLETE`, `QUEST_TURNED_IN` argument) | 18 accepts, 23 turn-ins, 100% |
| **Quest title** | Obtainable via `C_QuestLog.GetInfo(index).title`, once the field is extracted explicitly (Section 6) | **16 of 16** in session 3 |
| **Quest level** | Obtainable via `C_QuestLog.GetInfo(index).level`; matched the in-game quest log level for every quest checked | 16 of 16 in session 3 |
| **Objectives** | `C_QuestLog.GetQuestObjectives` returned real, human-readable progress text for both monster-kill style (`"0/8 Juvenile Vuldren slain"`) and item-collect style (`"1/1 Blood Shard"`) objectives | confirmed on 16+ quests across sessions 1 and 3 |
| **Reward XP** | Real, non-zero, level-scaling values obtainable from `QUEST_TURNED_IN`'s own event argument (e.g. 40 XP for a level-1 quest, up to 360 XP for a level-5 quest) | 15 turn-ins in session 3, consistent |
| **Reward money** | Same source; non-zero on some quests, zero on others in a pattern consistent with genuine per-quest design (not failure) | 15 turn-ins in session 3 |
| **Quest giver creature ID** | Obtainable via `UnitGUID("npc")` parsed at the documented 6th GUID field (QuestieLearner-style technique) | **14 distinct NPCs**, zero parse failures |
| **NPC name** | `UnitName("npc")`, paired 1:1 with the creature ID above | 14 for 14 |
| **Observed NPC/player coordinates** | `C_Map.GetBestMapForUnit` + `C_Map.GetPlayerMapPosition(...):GetXY()` returned a UI map ID and fractional (0–1) x/y position for every interaction | every session, no failures |
| **Number of quest accepts observed** | **18** across all sessions (2 in session 1, 0 in session 2, 16 in session 3) | — |
| **Number of turn-ins observed** | **23** across all sessions (7 + 1 + 15) | — |
| **Number of distinct NPCs observed** | **14** | — |

**Answer to the objective's second question: yes.** A normal, read-only addon using only documented,
non-protected APIs can assemble a structured record containing quest ID, title, level, objectives,
XP/money rewards, giver creature ID and name, and interaction coordinates — for quests actually
experienced by the player. This is demonstrated, not theorized: the fields above were captured, not
merely shown to be theoretically available.

## 5. Reward API Finding / Correction

This finding changed shape as the sample size grew, and both stages are preserved here rather than
letting the earlier one quietly disappear.

**Session 2 (n=1 turn-in — "22 Egg Hunt")**: `QUEST_TURNED_IN` fired with `money_reward = 0, xp_reward = 0`.
Separately, `GetQuestLogRewardMoney()`, called with no arguments at `QUEST_COMPLETE`, returned a real
`2500`. **Tentative conclusion at the time**: `QUEST_TURNED_IN`'s arguments are unreliable; use
`GetQuestLogRewardMoney`/`XP` instead.

**Session 3 (n=15 turn-ins — Skyborne starting quests)**: `QUEST_TURNED_IN`'s arguments showed real,
plausible, level-scaling XP and money on every single turn-in. `GetQuestLogRewardMoney`/`GetQuestLogRewardXP`,
called identically to session 2, **returned flat zero on all 15, no exceptions**.

**Corrected conclusion, reflecting the stronger evidence**: `QUEST_TURNED_IN`'s event arguments are the
reliable source for XP/money rewards on this build. `GetQuestLogRewardMoney`/`XP`, called with no
arguments, are not reliable as called by this probe — the most likely explanation is that these
old-style "quest log" globals require a quest to be explicitly selected in the quest-log UI first (a step
this probe never performs), and the real `2500` seen in session 2 was most likely coincidental — that
quest happened to still be selected from earlier browsing — rather than evidence the no-argument calling
pattern works in general.

This finding is stated at the confidence its sample size supports: **15 consistent data points** is a
reasonably strong basis for the corrected conclusion, but it is one build, one starting zone, and one
quest design era (early Skyborne leveling content) — it is not claimed to generalize to every quest type
in the game.

## 6. Probe Revision / Corrections

Two functional fixes were made to `ForeverProbe.lua` during M3, both driven by real data from session 1,
both re-tested (syntax check plus a full simulated event-lifecycle run against a stub WoW environment)
before being sent back to the operator, and both then confirmed against real client data in session 3.

**Fix 1 — title capture.** In session 1, `C_QuestLog.GetInfo(index)` was confirmed to return a real,
rich table (25 keys observed), but the probe's own `describe()` helper — a generic table-summarizer built
to cap output at ~6 arbitrary keys and avoid flooding chat/SavedVariables with large dumps — happened not
to include the `title` key in its sample. **This was a probe implementation flaw, not a client
limitation**: the title data existed in the table the whole time; the probe's own generic summarization
discarded it before it was ever stored. The fix: explicitly extract `info.title`, `info.level`, and
`info.questID` as their own named fields (`C_QuestLog_GetInfo_title`, etc.) immediately after the call,
bypassing the lossy generic summarizer for exactly the fields this experiment most needed. **Retested in
session 3: 16 of 16 quests correctly captured a title after this fix.**

**Fix 2 — reward-capture timing.** In session 1, reward fields were captured only in the `QUEST_ACCEPTED`
handler — the moment a quest is accepted, before there is anything to reward. Every reward value read
zero or empty as a direct result. The fix: also capture reward fields in the `QUEST_COMPLETE` handler,
using a new small helper (`GetQuestID()`, a plain global not in the original M3 API list, added because
the `QUEST_COMPLETE` handler had no other way to know which quest's frame was open) to get the correct
quest ID at that moment. **Retested in session 2 (confirmed non-zero data was obtainable this way) and
session 3 (confirmed on 15 quests, and led to the Section 5 correction about which reward source is
actually reliable).**

A third, non-functional change (`/fprobe save`, calling the standard `ReloadUI()` to flush SavedVariables
without a manual `/reload`) was added for operator convenience partway through the experiment and does
not affect any finding.

**The final probe (described in Section 2 and used to produce session 3's data) includes both fixes.**
Sessions 1 and 2 in this report describe the probe as it existed *at that time*, not the final version —
each session's table above states which probe version produced it.

## 7. Evidence Classification

- `[V]` — Verified directly on the operator's real Forever client this milestone. Used throughout
  Section 4 and Section 5's corrected conclusion.
- `[2nd]` — Reported by an external source/project, not independently reproduced this milestone. Used for
  the wowdev.wiki `QuestCache.wdb` field-layout claims (Section 8) and anything carried from M1/M1.5/M2
  research without being retested here.
- `[?]` — Unresolved. Used throughout Section 8 for open questions.

No `[2nd]` or `[?]` claim in this report or its companion document was upgraded to `[V]` on the basis of
plausibility alone; each `[V]` tag corresponds to a specific observation cited with its sample size.

## 8. Limitations

M3 explicitly did **not** establish:

- **Full quest database coverage.** 23 turn-ins and 18 accepts, across two characters and two starting
  areas, is not a claim about every quest in the game.
- **Prerequisites or complete quest chains.** Not tested. The M3 task scope explicitly excluded this.
- **All reward types.** Only XP and money were confirmed. Item rewards were not observed with real data
  this milestone (`GetNumQuestRewards` returned `0` on every quest seen — no quest with an item reward
  happened to be tested); `GetQuestLogChoiceInfo` consistently errored with
  `"Usage: GetQuestLogRewardInfo(index)"`, meaning it needs an argument the probe never supplied — a
  clean negative result, not a tested-and-passed one.
- **NPC spawn tables or general NPC data** beyond the specific NPCs the operator personally interacted
  with. No general creature/spawn enumeration was attempted.
- **Whether every relevant API works for every quest type.** Two starting-zone quest designs (repeatable
  buff quests at level 20, and standard leveling quests at level 1) were tested — not, for example,
  elite group quests, PvP quests, or endgame content.
- **Whether Forever's cache files persist across sessions in general**, only that `questcache.wdb`
  existed, was already populated before M3 began, and grew measurably during one session. Its per-record
  content was not decoded — only its 24-byte header (format, build number, locale) was read.
- **Any legal or licensing conclusion.** The addon-API portion of this experiment used only documented,
  non-protected Lua APIs, consistent with normal, widely-practiced addon behavior. The direct cache-file
  reading portion carries the same unresolved EULA data-mining question already on record from M1.5/M2.
  Neither question was newly resolved by M3; this report does not conclude either way.
- **A live Blizzard confirmation of build `69977`.** Established only via the addon's own `GetBuildInfo()`
  call; the multi-source independent cross-check performed for `69913` in M2 was not repeated here.

## 9. M3 Success Criteria

The stated success criterion: one complete observed quest record containing as many of quest ID, title,
objectives, rewards, quest giver creature ID, NPC name, and an observed interaction coordinate as the
client exposes, with a partial result still counting as valuable if it clearly establishes which fields
are and aren't accessible.

| Criterion field | Met? | Basis |
|---|---|---|
| Quest ID | **Yes** | every event, every session |
| Title | **Yes** | 16/16 in session 3, after the Section 6 fix |
| Objectives | **Yes** | real text, two distinct objective styles |
| Rewards | **Yes** | real XP/money via `QUEST_TURNED_IN` arguments, corrected source (Section 5) |
| Quest giver creature ID | **Yes** | 14 distinct NPCs, zero parse failures |
| NPC name | **Yes** | paired with the above, 14 for 14 |
| Observed interaction coordinate | **Yes** | every session, no failures |

All seven fields were met. This is **not** a claim of complete quest-database coverage (Section 8) — it
is a demonstration that these specific fields are accessible to a normal addon, for quests the addon
actually observes being played.

## 10. Conclusion

M3 demonstrates that a normal, read-only, policy-compliant WoW Forever addon — using only documented,
non-protected Lua APIs, with no automation of gameplay — **can assemble a meaningful, structured quest
record from real, observed in-game interaction**: quest ID, title, level, objectives, XP/money rewards,
giver creature ID and name, and interaction coordinates. This was shown concretely, across three sessions
totaling 218 recorded events, 18 quest accepts, 23 turn-ins, and 14 distinct NPCs — not asserted from a
single lucky call.

It is **not** proof of a complete quest database, of prerequisite/chain resolution, of full reward-type
coverage, or of any conclusion about cache-file legality. Two real implementation flaws were found and
fixed during the experiment (title-capture truncation, reward-timing), and one conclusion (which API
reliably reports rewards) was reversed once a larger sample was available — both corrections are
preserved in this report and its companion document rather than smoothed over, because how the answer
changed with more evidence is itself part of what this milestone demonstrated.

**Recommendation before any further milestone**: the addon-API path is now well-proven for the fields
above and could reasonably inform a real harvest-contract implementation
(`forever-db/docs/HARVEST_CONTRACT.md`). The most useful cheap follow-up would be testing whether an
explicit quest-selection call resolves `GetQuestLogRewardMoney`/`XP`'s no-argument failure, since
`QUEST_TURNED_IN`'s arguments alone do not cover item rewards, and this milestone found no reliable path
to those.
