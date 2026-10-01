# M8.0: Addon Architecture & Prototype Reconnaissance

**Status: reconnaissance only. No implementation performed.** Nothing in the repository was modified. Every API claim
below is labeled by its actual source; nothing is asserted about the Forever client that this project has not itself
observed.

**Reconnaissance date:** 2026-09-28.

## 1. Repository / addon structure findings

**No player-facing UI addon exists anywhere in the project.** Six addon directories exist, and all six are read-only
research/recording tools with no windows, buttons, or map integration of any kind:

| Directory | Addon | Role | Status |
|---|---|---|---|
| `m3-experiment/addon/ForeverProbe` | ForeverProbe | disposable M3 probe | frozen |
| `m4-pre-experiment/addon/ForeverProbeM4` | ForeverProbeM4 | disposable M4 pre-check | frozen |
| `m4-reputation-followup/addon/ForeverProbeM4Rep` | ForeverProbeM4Rep | disposable follow-up | frozen |
| `m4-item-retry-followup/addon/ForeverProbeM4Retry` | ForeverProbeM4Retry | disposable follow-up | frozen |
| `m4-observation-lab/addon/ForeverObservationLab` | Forever Observation Lab | modular observation lab | frozen |
| `m5-production-recorder/addon/ForeverRecorder` | Forever Recorder | production passive recorder | **current, locked (M7.7 manifest)** |

Every `.toc` in the project (8 total, plus 2 inside the vendored, gitignored ATT snapshot under `forever-db/data/raw/`)
declares `## Interface: 16001`, consistently across M3 through M5. No build or export script anywhere in the project
writes Lua or TOC files; the only existing "export" is the recorder's own SavedVariables dump
(`m6-dataset-baseline/out/latest_export_ForeverRecorder.lua`), which is research evidence, not addon data.

**Test/stub infrastructure:** two stub environments exist (`m4-observation-lab/tests/stub_env.lua`,
`m5-production-recorder/tests/stub_env.lua`), both hand-built fakes of a narrow slice of the WoW API used to unit-test
the recorder's own observers under plain Lua 5.1 (no real client). Neither stub defines any map-pin, POI, MapCanvas,
minimap, or tooltip API — those names do not appear anywhere in the stub files. The project's Lua *interpreter* choice
for tests (`lua5.1`) is stated directly in `m4-pre-experiment/M4_PRE_EXPERIMENT_NOTES.md` and the test runner headers;
this is the test harness's own choice, consistent with WoW's known Lua runtime, and is not itself a real-client
confirmation of the Forever client's Lua version.

**How M6 could be consumed by an addon:** there is no existing bridge. `m6_guide_dataset.json` (959,359 bytes, 153
quests) is a JSON research artifact with no accompanying JSON Schema (only the raw harvest-observation format has one,
`forever-db/schemas/harvest_observation.v{0,1}.schema.json`) and no Lua-table converter anywhere in the repository.
Nothing currently turns M6 output into a form an addon's `.toc` could load.

## 2. Actual Forever client / API findings

Every line below is labeled by where it comes from.

### Confirmed from the actual Forever client (via the recorder's real-client validation runs, M5–M7.7)
- Interface version **16001** (`GetBuildInfo()`'s 4th return, `tocversion`, checked against this literal in
  `Bootstrap.lua` and matched on every real run since M5).
- Build **70009**, client version **1.60.1** (per-observation `GetBuildInfo()` stamps, most recently confirmed in the
  M7.9-ingested export).
- **Quest APIs confirmed working:** `C_QuestLog.GetNumQuestLogEntries`, `C_QuestLog.GetInfo` (returns a table with
  `.questID`, `.title`, `.level`), `C_QuestLog.GetQuestObjectives`, `GetQuestID()` (only after M7.7's
  `QUEST_PROGRESS` hook), `GetNumQuestRewards`, `GetNumQuestChoices`, `GetQuestItemInfo`, `GetQuestLogRewardMoney`,
  `GetNumQuestLogRewardFactions`, `GetQuestLogRewardFactionInfo`, `GetFactionInfoByID`.
- **Gossip APIs confirmed:** `C_GossipInfo.GetActiveQuests`, `C_GossipInfo.GetAvailableQuests` (capped at the first 5
  entries by the recorder's own choice, not an API limit — see M7.6).
- **Coordinate/map API confirmed, but narrow:** `C_Map.GetBestMapForUnit("player")` and
  `C_Map.GetPlayerMapPosition(mapID, "player")` → a position table whose `:GetXY()` returns fractional map coordinates.
  This has been called with `"player"` as the only unit token in every run; **the NPC's own world position has never
  been queried, and no code in the project has ever tried.**
- **Unit APIs confirmed:** `UnitGUID`, `UnitName`, `UnitLevel`, `UnitClassification`, `UnitCreatureType`,
  `UnitCreatureFamily`, all called against the interacting NPC unit token the recorder derives.
- **Events confirmed hooked and firing:** `ADDON_LOADED`, `PLAYER_LOGIN`, `QUEST_DETAIL`, `QUEST_PROGRESS` (since
  M7.7), `QUEST_COMPLETE`, `QUEST_TURNED_IN`, `GOSSIP_SHOW`, `GET_ITEM_INFO_RECEIVED` (M7.6).
- **Events confirmed present but not hooked by anything in this project:** `QUEST_ACCEPTED`, `QUEST_LOG_UPDATE`,
  `QUEST_WATCH_UPDATE`, `PLAYER_TARGET_CHANGED`, `TAXIMAP_OPENED` (M7.6) — their *existence* was established enough to
  name them as candidates, but none has ever actually been hooked and observed firing.
- **SavedVariables: partially confirmed, with a known real problem.** `/reload`-triggered saves work reliably and have
  been repeatedly confirmed (`M5_PRODUCTION_RECORDER_DESIGN.md`). **A genuine logout/character-select persistence
  failure was reproduced twice on the real Forever client, and its root cause was never identified** (`[?]` in the
  design doc, `SAVEDVARIABLES_PERSISTENCE_FINDING.md`). Any addon that needs data to survive between sessions must
  account for this: `/reload` is the only confirmed-reliable save path.
- **Slash commands confirmed working:** `SLASH_x1 = "/cmd"` / `SlashCmdList["X"]` registration, exactly as used by
  every project addon to date.
- `CreateFrame`, `C_Timer.After`, `GetLocale`, `GetTime` are all confirmed callable (used by the recorder without
  incident).

### Confirmed only from project tests/stubs (not the real client)
- The stub environments' shapes for the above functions are the project's own assumptions used to unit-test observer
  logic; they were later matched against real data during M5–M7.7 validation, which is why the confirmed-from-client
  list above exists at all. Nothing in the stubs that was *not* later matched against a real run should be treated as
  confirmed (e.g., no stub or real run has ever exercised a title/UI frame beyond `CreateFrame`'s bare existence).

### Known from general WoW API knowledge, NOT verified on Forever
- Nothing is asserted in this section. Per this milestone's own instruction, no API is claimed to exist on Forever
  merely because it exists in retail or another version. Every function named above has a citation to an actual
  project run; anything not named above (world-map pins, quest POIs, tooltips, `IsQuestFlaggedCompleted`,
  `C_SuperTrack`, `C_Map.SetUserWaypoint`, `WorldMapFrame`/`MapCanvas`, `QuestPOIGetIconInfo`) is untested by this
  project and must be treated as unknown, not assumed-present.

### Unknown, requiring real-client testing
- **Whether any map-pin, POI, or MapCanvas API exists or works on Forever at all.** No code in the project's own six
  addons, its two stub environments, or a scan of the vendored ATT `.toc` interface list has ever referenced a pin,
  POI, or MapCanvas API by name. ATT itself declares support for interface 16001 among many others, which confirms
  ATT runs on Forever, but this reconnaissance did not attempt to search ATT's ~4,000 Lua files for its own map-pin
  implementation, so ATT's presence is not itself evidence that pin APIs work here — it is left explicitly unknown.
- Whether `C_QuestLog` exposes a completion-flag query (`IsQuestFlaggedCompleted` or equivalent) — never referenced
  anywhere in the project.
- Whether a tooltip API (`GameTooltip:SetHyperlink`, item/quest links) works on Forever — never referenced.
- Whether NPC world position is obtainable by any means — never attempted; only the player's own position has ever
  been queried (`core/PositionUtil.lua`, explicit in its own header comment).
- Whether addon-to-addon communication APIs exist or are needed — not applicable to a single-addon prototype and not
  investigated.
- The real client's exact Lua interpreter version — the project's test harness targets 5.1 by choice, consistent with
  WoW's known Lua runtime, but this has not been independently confirmed against the live client.

## 3. M6 → addon data contract

Inspected directly from `m6-dataset-baseline/out/m6_guide_dataset.json` (a live read, not assumed):

- Top level: `guide_ready_required_fields` (`["title", "quest_level", "objectives"]`), `guide_ready_quest_ids` (96),
  and a `quests` map keyed by quest ID.
- Each quest record's `fields` entry carries, per field: `value`, `evidence_state`, `classification`,
  `observation_count`, `sessions`, `builds`. Guide-ready quests always have `title`, `quest_level`, and `objectives` at
  `evidence_state: "confirmed"`; other fields (`giver`, `interaction_position`, `xp`, `money`, `choice_items`,
  `guaranteed_items`, `reputation`, `gossip_availability_sightings`, `completion`, `prerequisites`) may be
  `confirmed`, `observed`, or `unresolved` depending on what M6 actually captured — see M7.10 §3 for exact per-field
  coverage over the 96.
- `objectives.value` is the raw `C_QuestLog.GetQuestObjectives()` array (`text`, `numFulfilled`, `numRequired`,
  `finished`, `type`, `objectiveType`), unnormalized. `giver.value` is `{name, npc_id}`. `interaction_position.value`
  is `{checkpoint, ui_map_id, x, y}` — the **player's** position at that checkpoint, never the NPC's.
  `prerequisites` is `0/96` resolved and should not be expected in the first contract.
- **The addon should consume only the `guide_ready_quest_ids` subset**, and only the `.value` of each field, never the
  evidence bookkeeping (`evidence_state`, `classification`, `sessions`, `builds`, `observation_count`), which exists
  for the research pipeline and has no meaning to a player.
- **ATT/source-derived data never appears inside `m6_guide_dataset.json`'s guide-ready records at all** — every value
  in a guide-ready record's fields was itself observed by the recorder, not sourced from ATT. The addon therefore has
  no occasion to "decide whether ATT information is trustworthy": as long as it consumes only guide-ready records and
  never reaches into the separate M7.4 candidate-pool artifacts, ATT data structurally cannot enter its payload.

A minimal first-prototype contract, restricted to what M8.0's stated goal needs:

```
{ id, title, level, objectives: [text, ...], giver: {name, npc_id}, pos: {ui_map_id, x, y} }
```

## 4. Proposed data packaging method

**Recommended: a single generated Lua file, loaded as a normal addon file (not a SavedVariable), defining one global
data table as a plain literal.**

- Not a SavedVariable: `HARVEST_CONTRACT.md` documents that SavedVariables are parsed back by a narrow, safe
  table-literal grammar with **no function calls, no expressions**. A normal addon `.lua` file loaded via the `.toc`
  has no such restriction — it is ordinary Lua, executed once at load — so this is the more natural fit for static,
  generated data and avoids ever going through the SavedVariables path.
- Not JSON: nothing in the Forever addon environment has been shown to parse JSON (no JSON library was found
  referenced anywhere in the project's addons or the ATT `.toc`'s declared files); converting JSON to a Lua literal
  ahead of time avoids needing one.
- **Size is not a concern at this scale.** A minimal-contract dump of all 96 guide-ready quests (id, title, level,
  objectives text, giver, position — no evidence bookkeeping) serializes to about 27.5 KB as JSON, roughly 290 bytes
  per quest; a Lua literal of the same data would be comparable. The full `m6_guide_dataset.json` (959 KB, all 153
  quests with full evidence bookkeeping) is not a suitable addon payload as-is and should never be shipped directly.
- **Separation:** one new, hand-written generator script (not yet written) reads `m6_guide_dataset.json` and the
  `guide_ready_quest_ids` list and writes a single generated `.lua` file containing only the minimal contract above,
  assigned to its own namespaced global (e.g. `ForeverGuideData`), clearly marked "GENERATED — do not hand-edit" in a
  header comment. Handwritten addon code never edits this file; regenerating it is a matter of re-running the script
  against a current M6 output.
- **Reproducibility/licensing:** since every value in a guide-ready record is recorder-observed (Section 3), the
  packaged data carries the same status as the recorder's own SavedVariables export — first-party observation of the
  live client, not a third-party dataset. See Section 10 for what remains genuinely unresolved.

## 5. First UI prototype design

Minimum needed to prove "the addon loads and displays one real quest":

- **Main window:** one `CreateFrame`-built window, a title, and a scrollable list of the up-to-96 guide-ready quest
  names with their level, each with a button/click target to select it. No search, no filter, no sorting UI beyond
  whatever order the generated data ships in.
- **Quest detail:** on selecting a quest, a second panel (or the same window's content swapped) showing name, level,
  giver name, objective text lines, and the raw `{ui_map_id, x, y}` as plain text. A "Show on Map" button is included
  only as an inert placeholder (disabled, or printing "not yet implemented") **since no map-pin API has been confirmed
  to exist** (Section 2) — implementing real map interaction now would be building on an unconfirmed API.
- Nothing here requires SavedVariables: the currently-selected quest is ordinary Lua state, held only for the current
  session, and does not need to survive `/reload` or logout for this prototype's stated goal.

## 6. First real-client test

1. Install the generated addon folder (data file + minimal UI files) into the Forever AddOns directory.
2. Launch Forever, log in, and confirm the addon reports loading without a Lua error (a simple chat-frame "loaded"
   message, matching the pattern every prior project addon has used).
3. Open the addon's main window via its slash command (matching the confirmed `/fr`-style pattern).
4. Select one guide-ready quest already known from M6 (e.g. quest 907, "Enraged Thunder Lizards," level 18).
5. Verify the displayed name and level match `m6_guide_dataset.json`'s values exactly.
6. Verify at least one additional field (e.g. the objective text, or the giver name) also matches.
7. `/reload` (not a full logout, given the known unresolved logout-persistence issue in Section 2) and confirm the
   window still opens and the same quest still displays identically — this tests that the generated static data file
   itself loads correctly on every login, which is the only "persistence" a fully static data file actually needs
   (nothing here is written back to SavedVariables, so there is nothing to lose on reload).
8. Skip any map-interaction step in this first test; there is no confirmed map API to test yet.

This needs no quest grinding: any already-guide-ready quest works, and the player does not need to accept, progress,
or turn in anything.

## 7. Licensing / distribution findings

Read directly from `docs/LICENSING.md`. Its unresolved items (ATT's own coordinate provenance, the Blizzard-derived
wago CSVs' redistribution status, RestedXP/ForeverGuide/Questie/Wowhead — all "not read") are about the **research
pipeline's own upstream sources**, none of which enters a guide-ready record (Section 3). The addon's proposed minimal
contract draws only from recorder-observed evidence — the same category of data any ordinary quest-info addon
(displaying the game's own quest text, objective text, and NPC names back to the player) already relies on — and does
not implicate any of `LICENSING.md`'s open items directly.

**What remains genuinely unresolved and is not decided here:**
- `LICENSING.md` governs the *research pipeline's* sources; it says nothing about whether the project's own **derived
  guide dataset**, once packaged into a distributable addon, needs its own license or contributor terms.
  `LICENSING.md`'s own "Decisions left to the project owner" list already names this gap ("Community-data license and
  contributor terms" — undecided). This applies squarely to an addon package and was not resolved by this
  reconnaissance.
- Whether Forever's own EULA/addon policy (not inspected here — outside this repository) permits distributing an
  addon at all is not addressed by any document in this project.

**What must not happen, per Section 3 and this milestone's own constraints:** no ATT field, no wago CSV content, and
no RestedXP/ForeverGuide/Questie/Wowhead-derived text may enter the addon package. The proposed data contract
structurally cannot include any of these as long as it is generated only from `guide_ready_quest_ids` records.

## 8. Automation boundary

| Information / UI (candidate for future milestones) | Automation (explicitly deferred, unverified) |
|---|---|
| Quest name/level/objective display | Auto-accept |
| Map pins (once/if a pin API is confirmed) | Auto-turn-in |
| Quest tracker overlay | Automated dialogue selection |
| Route display (once ordering evidence exists — see M7.10 §9) | Automated movement |
| | Automated combat |
| | Automated targeting |

M8.0 makes no legal or policy determination about any automation feature. The boundary above exists only to record
that display/UI features and automation features are different categories of risk, and that nothing in the
automation column should be attempted until its API availability and rule implications are separately, explicitly
verified — which has not happened for any of them.

## 9. Proposed addon architecture

```
m6_guide_dataset.json (existing, unmodified)
        │
        ▼  (new, not yet written: a generator script, read-only w.r.t. M6)
Generated ForeverGuideData.lua  (data only, "GENERATED — do not hand-edit")
        │
        ▼  loaded by .toc, alongside handwritten files
┌───────────────────────────────────────────┐
│ New addon (name not yet chosen)            │
│  Data layer:  reads ForeverGuideData.lua   │
│  UI layer:    CreateFrame list + detail    │
│               view (Section 5)             │
│  (no Map layer yet — no confirmed API)     │
│  (no Quest-event layer yet — a static      │
│   display addon needs no event hooks)      │
└───────────────────────────────────────────┘
```

This differs from the illustrative architecture in the M8.0 request in one deliberate way: **no "Map Layer" or "Quest
Layer" (event-driven) component is proposed yet**, because (a) no map-pin API is confirmed to exist at all (Section 2)
and (b) a purely static data display, which is all M8.0's stated goal requires, needs no live quest-event hooks —
those become relevant only once the addon needs to react to the player's actual in-game quest state, which is future
scope.

## 10. Proposed M8.1 implementation scope

**Goal (unchanged from the request):** a loadable addon that displays one real M6 guide-ready quest using
generated/static addon data.

- **Files to create:**
  - `forever-db/research/m8_1/generate_addon_data.py` (or similar) — reads `m6_guide_dataset.json`, writes the
    generated Lua data file. Read-only with respect to M6.
  - A new addon directory, e.g. `m8-guide-addon/addon/ForeverGuide/` (name to be decided; must not collide with
    `ForeverGuide` the existing third-party overlay named in `LICENSING.md` — a different name should be chosen to
    avoid confusion), containing a `.toc`, the handwritten UI Lua file(s), and the generated data file.
- **Files to be generated (not hand-written):** the addon's data Lua file (e.g. `ForeverGuideData.lua`), produced by
  the new generator script, never edited by hand.
- **Files that must remain untouched:** every file this reconnaissance inspected — M4/M6 code and outputs, the
  recorder, CollectionRuns, ATT snapshots, `sources.toml`, `LICENSING.md`, and every locked M7.x artifact and test.
- **Data flow:** `m6_guide_dataset.json` → generator script (new) → generated Lua data file → new addon's UI code →
  in-game display. Nothing flows in the other direction; the addon never writes back to M6.
- **Test procedure:** Section 6 above.
- **Acceptance criteria:** the addon loads without a Lua error; its main window lists guide-ready quests; selecting
  one displays title, level, and at least one additional field that matches `m6_guide_dataset.json` exactly; the
  display survives `/reload`.

## 11. Exact files expected to change in M8.1

New only, as listed in Section 10. No existing file is expected to change. (If, during M8.1 implementation, the
generator script needs a small fixture or test file under its own new directory, that is also new, not a change to an
existing file.)

## 12. Acceptance criteria (restated for this reconnaissance)

Already satisfied by this turn: only `docs/M8_0_SCOPE.md` was created; every API claim above cites its real-client or
stub-only source; the M6 data contract was read directly from the live file, not assumed; the proposed M8.1 scope is
small enough for the test in Section 6 to be performed without any quest grinding.

## 13. Risks / unknowns

- **The map-pin/POI API question is the largest unknown for anything beyond M8.1.** Nothing in this project has ever
  tested whether Forever exposes any map-pin capability at all; the "Show on Map" button in Section 5 is deliberately
  inert until this is tested.
- **The logout-persistence failure (Section 2) is a real, twice-reproduced client issue with an unknown root cause.**
  M8.1's static-data design avoids needing to solve it, but any future feature that needs the addon to remember
  player-specific state (e.g. "quests completed so far") will run into it directly.
- Whether `title`/`level`/`objectives` lookups can fail for a *currently displayed* static quest the same way they
  failed for the *recorder's own live capture* (M7.6/M7.7/M7.10 §8: quest 913, quest 1463) is not a concern for a
  static-data addon — those failures were about capturing evidence live, not about displaying already-captured data —
  but is worth remembering once the addon needs to read the player's live quest-log state in a later milestone.
- The addon-package licensing question (Section 7) is explicitly unresolved and is an operator decision, not something
  this reconnaissance could resolve from the repository.
- Whether ATT's own ~4,000-file Lua codebase contains a usable map-pin implementation that could inform Forever's real
  capabilities was not investigated in this turn (out of proportion to M8.0's reconnaissance scope) and is a candidate
  for a future, narrowly-scoped investigation if a map layer is pursued.

## 14. Out of scope for M8.0

Full 1–60 route, route optimization, complete map, minimap integration, automatic navigation, combat automation, quest
automation, new recorder hooks, new CollectionRuns, new evidence collection, new external sources, ATT
reinterpretation, changing guide-readiness rules, resolving Quest 792 `r5`, rewriting historical tests, and publishing
to CurseForge. None of these was touched or assumed necessary by this reconnaissance.

## 15. Recommended next decision for the operator

Approve or adjust the M8.1 scope in Section 10 before any implementation begins. The one design choice most worth a
decision now, since it affects file naming, is the new addon's name (Section 10 flags a possible naming collision
with the existing third-party "ForeverGuide" overlay named in `LICENSING.md`).

**M8.0 SCOPE RECONSTRUCTION COMPLETE — addon architecture and first playable prototype defined; no implementation performed.**
