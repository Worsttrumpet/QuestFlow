# M6.5 Pre-Collection Quest Investigation

**Investigation only — no real-client collection performed.** `run-001-resolve-unresolved-titles` was not
activated by this task (it was already `active` from the prior turn — see the note at the top of that
response; not reverted here since no `active→planned` transition exists in the current lifecycle, and
building one would be a code change outside this task's scope). No M4/M5/M6.1–M6.4 file was modified.

## 1. Executive Summary

Investigated all 10 target quests against every legitimate existing project artifact. **The real title is
already recoverable, from this project's own data, for 8 of the 10 quests** — not through the field M6.2
currently checks (`title.harvest_observed`, populated only by the `QuestMeta` module), but through the
`Gossip` module's own captured title text for the same quest ID, which M6.2's coverage view doesn't
currently cross-reference. This is a real, useful finding, not a fix applied here — no coverage code was
changed. Two quests (`92517`, `93318`) and one partial case (`95350`) have no title anywhere in existing
data and genuinely need a real-client view. Quest `99196` remains gossip-fan-out-only exactly as
previously established — its title is recoverable, but nothing else about it is, since it has never been
directly observed.

## 2. Per-Quest Summary Table

| Quest ID | Title (source) | Level | Giver | Map | Rewards known | Classification |
|---|---|---|---|---|---|---|
| 92516 | **Hippogryph Harrassment** (gossip) | 7 (gossip, see caveat) | Teeri Wellwind (251906) | 2521 | Reputation only (2 factions, 50 ea) | Objectives partial, name blank |
| 92517 | Name not currently recoverable from project data. | unknown | Constable Aonda (251523) | 2521 | 3 choice items, reputation | Fully unresolved except giver/rewards |
| 92553 | **Restocking the Larders** (gossip) | unknown | Zerril Softbreeze (251905) | 2521 | 2 guaranteed items (names unresolved), reputation | Item names blank at this checkpoint |
| 93318 | Name not currently recoverable from project data. | unknown | *(bounty board, no creature ID)* | 2521 | 2 choice items, reputation | Fully unresolved except rewards |
| 93319 | **Pilfered Windstones** (gossip) | 7 (gossip, see caveat) | Teeri Wellwind (251906) | 2521 | Reputation only | Objectives blank item name |
| 93951 | **A Little Beauty** (gossip) | unknown | Taleen Shimmerthread (251991) | 2521 | Reputation only | Objectives blank item name |
| 94411 | **Meddlesome Mages** (gossip) | unknown | Illaya Amberwind (251902) | 2521 | 2 choice items, 1 faction (100 rep) | Objectives has real mob name |
| 95350 | Name not currently recoverable from project data. | unknown | Alaana Stormwalker (259119) | **1412** (different zone) | 1 faction (25 rep) | Fully unresolved, different map, older build |
| 97970 | **Camping 101: Mining** (gossip) | unknown | Raan Wildwind (263664) | 2521 | none observed | Matches known "Camping 101" profession-quest pattern |
| 99196 | **A Donation of Wool** (gossip) | unknown | *(none — never directly observed)* | unknown | none | **Gossip-fan-out only**, no direct evidence of any kind |

## 3. Detailed Evidence Per Quest

Every entry below cites the exact source: `direct` (a `QuestMeta`/`GiverIdentity`/`RewardsItems`/
`RewardsReputation` observation with this quest's own `quest_id`) or `gossip fan-out` (this quest ID
appearing inside a *different* interaction's `Gossip` sample list — never treated as a direct observation
of this quest itself, per instruction).

### 92516
- **Title**: `title.harvest_observed` (QuestMeta, direct) = `None` — genuinely unresolved via the field
  M6.2 checks. **However**, `Gossip` observations (session `e91d734523ba1a`, obs[1606]/[1608]/[1614], and
  session `9a2307cc62589b`, obs[1657]/[1659]) all show `title: "Hippogryph Harrassment"` for this exact
  quest ID. Source: this project's own real gossip capture — not an external source.
- **Level**: gossip shows `level: 0` in the earliest two sightings, then `level: 7` in the three later
  ones. **Caveat, not overclaimed**: this is the same gossip `kind`-transition pattern M6.4 already
  classifies as `state_change` (available→active) — `0` looks like an unpopulated placeholder before
  acceptance, `7` the real value once tracked, but this report does not assert that with certainty; it's a
  pattern match, not a confirmed rule.
- **Objectives** (direct, `quest_detail`): three monster-kill objectives, `8`, `6`, `1` required — but the
  monster **names are blank** in the captured text (`"0/8   slain"`) — a real, honest gap in the raw
  capture, not fabricated.
- **Giver**: Teeri Wellwind, creature `251906`, map `2521`, real coordinates in the raw export.
- **Rewards**: 0 choice/guaranteed items; 2 reputation factions (`2778`, `2779`, `raw_amount=5000` each —
  the same faction pair seen throughout this project's real data).

### 92517
- **Title**: no `QuestMeta` observation ever resolved a title, and **zero gossip mentions exist anywhere
  in the export** for this ID. `Name not currently recoverable from project data.`
- **Objectives**: none — the one `QuestMeta` observation has `title/level/objectives` all `None`
  (`"not found among 5 entries"`).
- **Giver**: Constable Aonda, creature `251523`, map `2521` — the same NPC already documented (M5
  completion report) as a real turn-in-stage giver for a different quest, `92528`, from an earlier
  session not present in this dataset's lineage.
- **Rewards**: 3 real choice items — "Bandit's Jerkin", "Patchwork Leggings", "Highlands Mail Legguards";
  reputation, same faction pair as above.

### 92553
- **Title**: no `QuestMeta` title. One gossip mention (session `e91d734523ba1a`, obs[1634]):
  **"Restocking the Larders"**.
- **Objectives**: two item-collection objectives (`3` and `8` required), item names blank in the captured
  text.
- **Giver**: Zerril Softbreeze, creature `251905`, map `2521` — the same NPC who gave the real,
  previously-documented "Camping 101: Cooking" quest during M5 real-client testing.
- **Rewards**: 2 *guaranteed* (non-choice) items — but both item names came back **blank** at this
  `quest_detail` checkpoint (`r1: ''`), the same "unresolved-at-first-read" pattern documented since M4;
  no later checkpoint observation exists to confirm whether they resolved naturally, since this quest was
  never progressed past `quest_detail`.

### 93318
- **Title**: no `QuestMeta` title, and **zero gossip mentions** anywhere. `Name not currently recoverable
  from project data.`
- **Giver**: recorded name is **`"Bounty Available: Vulgara the Insatiable!"`**, with `parsed_creature_id:
  None` — the GUID parse did not resolve to a `Creature`/`Vehicle` type. This is a real, distinctive clue:
  this "giver" is very likely a **bounty board or similar interactive object**, not a named NPC, since a
  real NPC name would not itself read as a UI banner string. Worth using this exact string as a search
  target in-game rather than looking for an NPC by that name.
- **Rewards**: 2 choice items — "Hunter's Simple Cloak", "Highlands Defender's Shield"; reputation, same
  faction pair.

### 93319
- **Title**: no `QuestMeta` title. Five gossip mentions (two sessions) all agree: **"Pilfered
  Windstones"**, matching the same 0→7 level-transition pattern as `92516` (same giver too — Teeri
  Wellwind — strongly suggesting both quests are offered at the same physical location).
- **Objectives**: one item-collection objective (`10` required), item name blank.
- **Rewards**: reputation only, same faction pair.

### 93951
- **Title**: no `QuestMeta` title. One gossip mention: **"A Little Beauty"**.
- **Objectives**: one item-collection objective (`8` required), item name blank.
- **Giver**: Taleen Shimmerthread, creature `251991`, map `2521`.
- **Rewards**: reputation only, same faction pair.

### 94411
- **Title**: no `QuestMeta` title. One gossip mention: **"Meddlesome Mages"**.
- **Objectives**: a real, fully-populated objective — **"0/6 High Order Apprentice defeated"** — the only
  one of these 10 quests where the monster name actually came through.
- **Giver**: Illaya Amberwind, creature `251902`, map `2521`.
- **Rewards**: 2 choice items — "Windcharged Leaf", "Windcarved Effigy"; a single reputation faction
  (`2778`, `raw_amount=10000` — double the usual amount seen elsewhere in this project's data).

### 95350
- **Title**: no `QuestMeta` title, and **zero gossip mentions**. `Name not currently recoverable from
  project data.`
- **A genuinely different case from the other 9**: this quest's evidence comes from session
  `2e787541803171`, **build `69977`** — the older, pre-existing/Lab-attributed session lineage (M6.1's own
  attribution), not the newer `70009`-build recorder testing the other 9 all come from. It is also the only
  one of the 10 on a **different map** (`1412`, not `2521`) — meaning it's very likely in a different zone
  entirely from the other 9.
- **Objectives**: the one `QuestMeta` observation shows an **empty objectives array** — not blank text
  within an objective, but zero objectives captured at all.
- **Giver**: Alaana Stormwalker, creature `259119`.
- **Rewards**: a single reputation faction (`2778`, `raw_amount=2500` — a smaller amount than any other
  quest in this set).

### 97970
- **Title**: no `QuestMeta` title. One gossip mention: **"Camping 101: Mining"** — matching the exact
  naming pattern of two other real, already-documented quests from this project ("Camping 101: Cooking,"
  "Camping 101: Blacksmithing"), strongly suggesting a short, simple profession-tutorial quest.
- **Objectives**: a single blank/empty objective entry (`type: ''`, `text: ''`) — consistent with a
  minimal-UI tutorial-style quest rather than a missing-data problem.
- **Giver**: Raan Wildwind, creature `263664`, map `2521` — a name already directly documented (M5
  completion report) as a real profession-quest giver.
- **Rewards**: none observed of any kind.

### 99196
- **Title**: **never directly observed at all** — zero `QuestMeta`/`GiverIdentity`/`RewardsItems`/
  `RewardsReputation` rows exist for this quest_id anywhere in the export. The *only* evidence is one
  gossip fan-out mention (session `2e787541803171`, build `69977`, obs[1157]):
  `title: "A Donation of Wool"`, `level: 0`.
- **Everything else — objectives, giver, position, rewards — is completely absent.** This is the case M6.2
  originally surfaced as gossip-fan-out-only, and it remains exactly that here: a real name, and nothing
  else.

## 4. Sources/Files Inspected

`out/m6_coverage.json`, `out/m6_collection_runs.json`, `out/m6_evidence_report.json`, `out/inventory.json`,
the raw export itself (`out/latest_export_ForeverRecorder.lua`, parsed directly via the existing,
unmodified `savedvars.py`), and every file under `forever-db/manifests/` (checked individually — none
contain a raw QuestV2/ATT/Era ID list, and a direct text search confirmed none of the 10 target quest IDs
appear in any manifest file). **No SQLite build exists in the repository to query.** No web source, no
Wowhead, no RestedXP, no external data of any kind was used.

## 5. Quests Probably Locatable Using Existing Evidence Alone

**8 of 10** already have a real title and a real, named giver NPC (or, for `93318`, a distinctive
bounty-board string) plus a map ID — enough to plan exactly where to go and who/what to interact with:
`92516`, `92517`, `92553`, `93318`, `93319`, `93951`, `94411`, `97970`.

## 6. Quests Genuinely Requiring Live-Client Collection for Title

All 10 still need a real `QuestMeta` observation to move `title.harvest_observed` itself from `unresolved`
— the gossip-sourced names above are a strong practical aid for *finding* the quest in-game, not a
substitute for the direct field M6.2 tracks. Two (`92517`, `93318`) and effectively `95350` have **no name
at all** yet from any source and will need to be identified purely by their giver/location clues once
reached.

## 7. Especially Difficult Cases

- **`99196`**: no direct evidence of any kind exists — only a name. Locating the actual giver/location will
  require exploring near wherever `2e787541803171`'s session activity occurred, or simply encountering it
  incidentally.
- **`95350`**: different map (`1412`) from every other target, older build lineage — likely requires
  travelling to a different zone than the other 9, which are clearly clustered together (same map, several
  sharing the same giver).
- **`93318`**: the giver isn't a normal NPC (no creature ID resolved) — likely a bounty board, which may
  require a different interaction method than talking to an NPC.

## 8. Recommended Collection Order

1. **`92516`, `93319`** together — same giver (Teeri Wellwind), same map; visiting once likely resolves
   both.
2. **`92517`, `92553`, `93951`, `94411`, `97970`** — five different named NPCs, all on map `2521`,
   presumably in the same general area as the above.
3. **`93318`** — same map, but look for the bounty board specifically, not an NPC.
4. **`95350`** — different map/zone; worth planning as a separate trip.
5. **`99196`** — no location clue at all yet; lowest priority for a dedicated trip, best picked up
   incidentally while pursuing the others, or investigated further only if it remains the sole gap after
   the rest are attempted.

---

**Tests and preservation, confirmed this task**: 52 M6 tests (`test_coverage.py`, `test_collection_runs.py`,
`test_evidence_report.py`) and 141 M4 tests all pass, run fresh. `db.py`, `assertions.py`,
`importer.py`, `inventory.json`, `m6_coverage.json`, and `m6_evidence_report.json` all confirmed
byte-identical to before this investigation — nothing was modified to produce it.
