# M8.14: Provenance and Cross-Version Knowledge Model

**Status: design draft.** Source facts below come from the project's own recorded research (M0, M7.x, M8.2
reports as captured in project history) and from direct measurement of `Data.lua`. Items marked **[VERIFY IN
REPO]** must be confirmed against the repository files (`LICENSING.md`, `config/sources.toml`, ATT pipeline) before
this model is finalised. No production data is changed by this document.

## 1. The principle

> "Known from Classic/SoD" does not mean "confirmed for Forever" — but it also does not mean "the player must
> rediscover it."

A value known from an earlier version of the game is a **candidate** for a Forever quest once that quest's
identity is established on Forever. It is shown to players as reference guidance, labelled by origin, and is
replaced the moment Forever evidence disagrees with it.

## 2. What the project already has

### 2.1 Forever-observed (direct evidence)

| Item | Count | Notes |
|---|---|---|
| Quests with recorder observations (M6) | 153 | ForeverRecorder / ObservationLab on the live client |
| Of those, passing M6's rule (title, level, objectives confirmed) | 96 | Exported to `Data.lua`; **this is a Forever-observed evidence layer, not the universe of guide-ready quests** |
| Fields in `Data.lua` | id, title, level, objectives, giver (name, npc_id), pos | pos = the **player's** position at a recorder checkpoint (offer vs turn-in not recorded in `Data.lua`) **[VERIFY IN REPO: M6 checkpoint kind]** |
| Missing entirely | turn-in NPC, objective locations, prerequisites, faction/race/class, start-object quests | |
| Objective text quality | 109 named, 11 blank (9 quests) | blank names are a capture-timing artefact (M8.9) |
| Coverage | 70/96 on map 2521 (Zephras Isle), 18 Durotar, 8 elsewhere; 88/96 below level 16 | |

### 2.2 Approved source data with Classic lineage

| Source | License / status | What it provides | Forever relevance |
|---|---|---|---|
| **ATT** (`ATTWoWAddon/AllTheThings`, pinned `8e25511`, cross-check `a054efd`), `forever/` database | MIT; **approved and pinned** | Quest IDs, titles, NPCs, start coordinates for most quests, `sourceQuest`/`altQuest` prerequisite hints; M7.4 candidate pool 1,102 | Mixed: real Forever content plus converted legacy/Classic data; coordinate origin unknown |
| ATT's **Classic / SoD** databases in the same repository | Same repository and MIT license — **approval scope not yet confirmed** | Classic- and SoD-era quest data | Potentially the lawful Classic/SoD reference layer this model needs **[VERIFY IN REPO: whether `LICENSING.md` approves ATT as a whole or only the `forever/` subset]** |

### 2.3 Knowledge recorded but not usable as field data

| Source | What the project retains | Why it can't feed fields |
|---|---|---|
| Questie Era (`classicQuestDB.lua`) | Aggregate count (4,244 quests) from M0 | Excluded by `LICENSING.md` (GPL-3.0 decision); raw data never persisted |
| QuestV2 CSV (via ForeverGuide) | Aggregate count (6,600 IDs) | ForeverGuide excluded; also: QuestV2 membership is not proof a quest is real (placeholder rows, reused IDs — M0 §8) |
| Wowhead | Nothing | Excluded (EULA) |
| Wikis and fan guides | Ad-hoc research references (e.g. M8.13's 907 chain lookup) | Not an approved source. Usable as a **pointer for what to verify**, never as route data |

### 2.4 SoD

**No SoD knowledge is established in the project.** The Cozy Sleeping Bag chain is operator-encountered on
Forever and publicly reported as SoD content, but no approved source for it is in the pipeline yet. Whether ATT's
pinned data carries it is unknown **[VERIFY IN REPO]**.

## 3. Evidence layers and derived statuses

The six labels mix two different things, so they are split:

**Evidence layers** — where a value came from. A field can have several.

| Layer | Meaning |
|---|---|
| `FOREVER_OBSERVED` | Captured on the live Forever client (recorder, probe, or operator report with evidence) |
| `CLASSIC_ESTABLISHED` | From an approved source's Classic-era data |
| `SOD_ESTABLISHED` | From an approved source's Season of Discovery data |

**Field status** — computed from the layers, never stored by hand.

| Status | Rule |
|---|---|
| `CROSS_VERSION_CONFIRMED` | A `FOREVER_OBSERVED` value agrees with a Classic/SoD value |
| `FOREVER_SPECIFIC` | `FOREVER_OBSERVED` value with no Classic/SoD counterpart (new content, or Forever changed it) |
| `NEEDS_VERIFICATION` | Only Classic/SoD evidence, or layers disagree |

Resolution: a `FOREVER_OBSERVED` value always wins. A disagreement is kept as data (both values, both sources),
never silently overwritten — the same rule M6 already applies to its own conflicts.

## 4. What may be inherited

A quest must first have **Forever identity**: its ID exists on Forever *and* its title matches the earlier
version (ID alone is not enough — Forever reuses some old IDs, M0 §8). Then:

| Field | Inherit as candidate? | Why |
|---|---|---|
| Title, description | Yes | Used to establish identity; low change risk |
| Quest chain / prerequisites | Yes, `NEEDS_VERIFICATION` | Strong prior (e.g. 907's chain); Forever may restructure chains |
| Giver / turn-in (NPC **or object**) IDs and names | Yes | Low change risk; cheaply confirmed by the recorder when encountered |
| Objective targets (creature/item/object IDs) | Yes | Low change risk |
| Objective counts | Yes, `NEEDS_VERIFICATION` | Tuning changes are plausible |
| Faction / race / class restrictions | Yes, `NEEDS_VERIFICATION` | Forever may open or change races (e.g. new races) |
| **Coordinates** | **Only through a documented conversion** | Forever changed the map frame: Questie's Forever work had to convert Era data across it. Classic coordinates are not Forever coordinates |
| Required / suggested level | Candidate only | Forever may rebalance; M6 already observes levels directly |
| XP, money, item rewards | **No — must be Forever-verified** | Most likely to change; players rely on them |
| Anything in Forever-only zones (e.g. map 2521) | N/A | No earlier-version data exists: `FOREVER_SPECIFIC` by definition |

## 5. Quest classification

| Class | Rule |
|---|---|
| **Classic + Forever** | Forever identity established; ID + title match Classic-layer data |
| **SoD + Forever** | Forever identity established; ID + title match SoD-layer data (e.g. the Cozy Sleeping Bag chain, once sourced) |
| **Forever-specific** | Forever identity established; no Classic/SoD counterpart (all of Zephras Isle; most IDs in the 90000+ range seen by the recorder) |
| **Classic/SoD-only** | Known from an earlier version, Forever identity **not** established — never shown as a Forever quest |

Forever identity can come from: a recorder observation (strongest), membership in ATT's `forever/` data
(approved), or the client's own quest table (existence only — weak, because of placeholder and reused IDs).

## 6. Evidence record (minimum)

Each value carries a list of evidence entries:

```
{ value, layer, source, source_rev, record_ref, method, recorded_at }
```

- `layer`: `FOREVER_OBSERVED` | `CLASSIC_ESTABLISHED` | `SOD_ESTABLISHED`
- `source` / `source_rev` / `record_ref`: e.g. `att`, `8e25511`, the ATT record key; or `recorder`, export SHA,
  observation ID
- `method`: `direct` | `inherited` | `converted` (coordinates) | `inferred`

Status (§3) is computed from this list. Nothing collapses the layers into one "truth" value.

## 7. Guide readiness, recomputed

"Guide-ready" becomes a computed result over merged evidence, not membership in a table:

| Level | Requires | Current count |
|---|---|---|
| **KNOWN** | Forever identity (ID + title) | 96 Forever-observed; ATT `forever/` identity would add many more **[VERIFY IN REPO]** |
| **RESEARCHED** | Giver/start known + objectives named, from any layer | 87 from Forever evidence alone |
| **ACTIONABLE** | RESEARCHED + where to go (a Forever or converted coordinate) + turn-in known | Unknown until M6 checkpoint semantics and ATT coordinates are checked |
| **ROUTED** | ACTIONABLE + prerequisites resolved in a validated route | 0 |

Each level shows how much rests on `NEEDS_VERIFICATION` values, so "actionable from inherited data" and
"actionable from Forever evidence" stay visibly different.

## 8. Open questions for the repository check

1. Does `LICENSING.md` / `config/sources.toml` approve ATT as a whole (including its Classic and SoD data), or
   only the `forever/` subset?
2. What does M6 record for each observation's checkpoint (offer vs turn-in), so `pos` can be interpreted?
3. How many of ATT's 1,102 qualified candidates carry giver, objective, coordinate and prerequisite data, and do
   ATT's `forever/` coordinates already use the Forever map frame?
4. Does ATT's pinned data include the Cozy Sleeping Bag chain or any other SoD content?
