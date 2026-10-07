# Harvest contract v0 (design only)

M1 defines *what an in-game recorder or cache exporter must provide*. Nothing here is implemented
and no recorder was built or run. The machine-readable form is
`schemas/harvest_observation.v0.schema.json`; an obviously synthetic example is in
`docs/examples_harvest_v0.json` (fake IDs, not observations).

## Principles

1. **Observed, not interpreted.** Record raw API returns with the API name and arguments
   (`values: [{api, args, returns}]`). The pipeline, not the recorder, decides what a return means.
   This keeps field semantics attributable when they turn out to be misunderstood (compare ATT's `lvl`).
2. **Every export carries the client build and how it was learned.** `build_source = client_api`
   lets the pipeline set `observed_build_id`; `toc_only` / `user_declared` are recorded as *claims*.
3. **Observed vs imported are different source kinds.** Harvest data becomes assertions with
   `source_kind = harvest_observation`, `confidence = observed_first_hand`, `status = observed`.
   ATT and any other third-party data stays `third_party_import`.
4. **No personal data.** No character names, realms, account or player GUIDs. Session IDs are
   random per export. Entity IDs (NPC, object) are derived by the recorder from unit GUIDs; the GUIDs
   themselves are not exported. (Third-party recorders have committed raw SavedVariables dumps to public repos;
   the contract exists to prevent that.)
5. **Positions are exported as the client returned them** (UI map id plus 0-1 fractions, and world
   coordinates where an API provides them). The pipeline converts to percent and derives world/map
   values; it never trusts a derived value from the recorder.

## Observation kinds

| kind | required `data` | becomes assertion fields (proposed) |
|---|---|---|
| `quest_record` | `quest_id`, `values[]` | `observed.<api>` per return; sets `server_confirmed` evidence |
| `quest_giver_seen` / `quest_turnin_seen` | `npc_id`, `position` | `giver.npc`, `location.observed_player_position` |
| `objective_progress` | `quest_id`, `objective_index`, `values[]` | `objective.observed` |
| `npc_seen` / `object_seen` | `entity_id`, `position` | `location.observed_sighting` |
| `taxi_node_seen` | `node_id` | `taxi_node.observed` |
| `wdb_record` | `cache_file`, `record_type`, `record_id`, `payload_sha256`, `parser_version` | parsed later; keeps hash of raw payload |

`server_confirmed` is set only by a `quest_record` whose values are non-placeholder. The
placeholder rule (titles like `None`, `<UNUSED>` were reported for IDs 1-999 by a third party) is **not
defined yet**: it needs real observations to write correctly.

## Position caveat

A player position when meeting an NPC is not the NPC's position. The field is named
`location.observed_player_position` on purpose; an NPC placement needs several sightings and a
distance model. That model is out of scope for M1.

## Unverified items this contract depends on (as of v0)

- Whether Forever exposes the quest-data request API reliably. Third parties report server throttling and
  a client cache directory (`Cache/WDB/*.wdb`). Not tested here.
- Whether values become unreadable ("secret") in some client states. Reported by a third party, not tested here.
- WDB record layouts. `parser_version` exists because we expect to get them wrong at first.

---

# Harvest contract v1 -- implemented, matches the real Observation Lab exporter

v0 above was written before any recorder existed; it assumed a JSON export and an `{api, args, returns}`
raw-call log shape. M3/M4's real-client testing built and ran an actual addon (`ForeverObservationLab`),
and its real export shape differs from v0's assumptions in several concrete ways documented below. v1
(`schemas/harvest_observation.v1.schema.json`, importer in `src/foreverdb/harvest/`) matches what the
addon actually produces, not what was originally imagined. v0's history is kept above, unedited.

## The exporter produces Lua SavedVariables text, not JSON

The single biggest discrepancy from v0: `ForeverObservationLab` writes a WoW SavedVariables `.lua` file
(`ForeverObservationLabDB = { ["meta"] = {...}, ["observations"] = {...} }`), never JSON. v1's importer
includes `src/foreverdb/harvest/savedvars.py`, a small, safe parser for the narrow table-literal grammar
SavedVariables actually uses -- not a general Lua interpreter, no function calls, no expressions, nothing
executed. A malformed or adversarial input can produce a parse error; it cannot run anything. The v1 JSON
Schema describes the *parsed* (post-Lua) logical structure, since JSON Schema has no way to describe Lua
syntax directly.

## `module_status`

Every observation is tagged `"proven"` or `"experimental"` by the addon itself -- this describes the
maturity of the *collection code*, not the evidence strength of any one observation. **Only
`module_status="proven"` observations are ever imported.** `"experimental"` observations are skipped and
counted, never silently promoted. See `EXPORT_CONTRACT_SEMANTICS.md` (in the Observation Lab's own repo)
for the full reasoning; this is the smallest decision consistent with the existing ranking system --
no new confidence tier or source_kind was added for this.

## Nested `ok`: outer vs. `data.ok`

An observation's outer `ok` means the module's Lua code ran without an error -- a code-health signal.
`data.ok` (inside the module-specific payload) means the observation itself actually succeeded. **Only
`data.ok=true` observations become content assertions**, regardless of the outer `ok`. A concrete real
case: `RewardsReputation`'s missing-quest-ID guard produces `ok=true, data.ok=false` -- the module ran
perfectly correctly and *correctly refused* to record unattributable data. That refusal must never be
read as observed game content, and the importer enforces this directly (`_import_one` in
`src/foreverdb/harvest/importer.py`).

## Per-observation build and session metadata

`meta.session_id`/`meta.observed_build` reflect only the *current* login -- they are overwritten every
session and are not authoritative for older observations sitting in the same accumulated file. Real-client
testing found and fixed this exact gap twice, independently, for session identity and then for build
identity. Each observation therefore carries its own `session_id` and `observed_build`/
`observed_toc_version`/`observed_version`/`observed_build_date`, stamped at the moment it was created. The
importer uses these per-observation fields for `AssertionInput.observed_build_id` -- never the file-level
`meta` -- so two builds' worth of observations accumulated in one file remain distinguishable after import.

## Reward checkpoint context is preserved, not ranked

Real-client testing (quest 92514) found that item-choice data could read `0` at `quest_detail` and
`quest_complete_immediate`, and only the correct `3` at `quest_complete_delayed`, for the *same* quest.
v1 does not invent a checkpoint-superiority ranking. Every reward-type assertion's value carries its
`checkpoint` explicitly; multiple checkpoint-tagged observations of the same quest's same reward field
coexist as separate assertions via the existing append-only architecture, and any future weighting
decision is left to a later, explicit choice, not baked in silently here.

## Field mapping (entity_type is always `"quest"`)

| Module | Field(s) | Notes |
|---|---|---|
| `QuestMeta` | `title.harvest_observed`, `level.harvest_observed`, `objectives.harvest_observed` | Objectives are stored as the full array the client returned, never re-normalized into v0's old per-index `objective_progress` shape |
| `RewardsXPMoney` | `reward_xp.harvest_observed`, `reward_money.harvest_observed` | Only imported from the `QUEST_TURNED_IN` checkpoint -- M3 found the no-argument reward-query APIs unreliable; the turn-in event's own arguments were the reliable source |
| `RewardsItems` | `reward_items.harvest_observed`, `reward_choice_items.harvest_observed` | Value includes `checkpoint`; raw per-item fields (`r1`..`r6`) pass through unmodified, no field renamed as if its meaning were confirmed |
| `RewardsReputation` | `reward_reputation.harvest_observed` | `faction_id`/`raw_amount`/`normalized_amount` only -- no faction name is ever invented; `GetFactionInfoByID` is confirmed absent on Forever |
| `GiverIdentity` | Quest-scoped: `giver.npc`, `location.observed_player_position`. NPC-scoped (no `quest_id`, e.g. at `GOSSIP_SHOW`): `sighting.harvest_observed`, `location.observed_player_position`, both under `entity_type="npc"` | `giver.npc` deliberately reuses the **same field name the ATT importer already uses** for the same real-world claim, so the existing ranking naturally arbitrates between a harvest observation and an ATT guess for the same quest's giver. `location.observed_player_position` reuses v0's own already-documented name and caveat: this is the *player's* position, not the NPC's, and is never converted into an NPC-location claim. See "Real-data discoveries" below for the NPC-scoped case and the `giver.npc` role-ambiguity limitation |
| `Gossip` | `availability.harvest_gossip_seen` | One Gossip observation can name several quests; each becomes its own assertion against its own quest ID. The field name itself states the limited claim -- one player, one session, one sighting -- never "this quest is universally obtainable" |

## Reject-vs-skip policy (documented, not left implicit)

A whole **file** that fails to parse as SavedVariables, or fails schema validation, is rejected loudly and
immediately -- nothing from it is imported. An individual **observation** that's ineligible (experimental,
`data.ok=false`, missing a required quest ID, an unrecognized module, a raw GUID, a disallowed key) is
skipped with a counted, reported reason, and the rest of the file continues -- matching the ATT importer's
existing practice of never crashing on one bad record.

## Privacy enforcement in the importer (defense in depth)

The addon should never export a raw GUID or a persistent identifier, and real-client testing across many
sessions found none. The importer does not merely trust that promise: every observation's `data` is
recursively scanned for GUID-shaped strings (`Creature-`, `Player-`, `Vehicle-`, etc.) and for a blocklist
of disallowed key names (`character_name`, `account_name`, `realm_name`, and similar) before anything is
imported. A hit rejects that one observation, counted and reported, not silently dropped.

## Duplicate and conflict behavior

No new logic was needed here -- the existing append-only assertion architecture already provides it.
Deterministic `source_locator`s (`observations[N].<field>`) mean re-importing the identical file produces
zero new assertions (the database's own `UNIQUE` constraint recognizes the exact duplicate). Genuinely
conflicting observations of the same field -- different sessions, different builds, different checkpoints,
or just plain disagreement -- coexist as separate rows; `resolve()` returns tied or ranked winners without
ever deleting or overwriting a losing observation.

## Real-data discoveries (found only once an actual export was ingested)

Two real gaps existed in the field-mapping design above that synthetic fixtures never exercised. Both
were found by running an actual `ForeverObservationLab` SavedVariables export (build `69977`) through the
importer, not by additional synthetic testing.

### `GiverIdentity` observations without a `quest_id` are legitimate -- not malformed

`GiverIdentity` fires at `GOSSIP_SHOW` as well as at quest checkpoints, and `Dispatcher.lua` never sets a
`quest_id` in context for `GOSSIP_SHOW` by design -- gossip is a general NPC interaction, not necessarily
about one specific quest at that moment. The importer originally required `quest_id` for every
`GiverIdentity` observation, which meant every such sighting was silently discarded. In the one real
export tested, this was 8 of 41 observations -- not a rare edge case.

**Such an observation means "this NPC was observed here," not "this NPC offers a particular quest."** It
is now imported as its own entity:

```
entity_type = "npc"
entity_id   = the NPC's parsed creature ID
fields      = sighting.harvest_observed (name), location.observed_player_position (unchanged meaning)
```

Never a fabricated quest ID, never attached to "the nearest quest," never treated as proof the NPC gives
any quest. When a `GiverIdentity` observation *does* have a real `quest_id` (the quest-checkpoint case),
behavior is exactly as it was before this discovery -- `entity_type="quest"`, field `giver.npc`.

### Session provenance is encoded in `source_locator`, not a new column

Every observation carries its own `session_id` (see "Per-observation build and session metadata" above),
but this was only ever aggregated into the *import report*, never persisted on the assertion itself --
meaning an imported assertion could not be traced back to the session that produced it. The M1 assertion
schema (`db.py`) has no `session_id` column, and adding one would mean modifying a frozen M1 file.

Instead, `source_locator` -- already a free-text column, already used for exactly this kind of
traceability -- now takes the form:

```
session:<session_id>|<original per-observation locator>
```

e.g. `session:788e5c5d22ea49|observations[14].title`. This is a **deliberate, minimal choice** made
specifically to avoid touching frozen M0-M3 work. It is now part of M4's deterministic
provenance/deduplication behavior: re-importing the identical export produces the identical locator for
each assertion, which is exactly what lets the database's existing `UNIQUE` constraint recognize true
duplicates and add zero new rows. **This format should not be changed casually** -- any change to it
would break deduplication for previously-imported data.

## Known modeling limitation: `giver.npc` does not yet distinguish roles

Real data surfaced this directly: quest 92528 ("Among the Faithful") produced **two different NPCs** --
"Missionary Jasaan" observed at `quest_detail` (the offer) and "Constable Aonda" observed at the turn-in.
Both are correctly preserved as separate, non-overwritten assertions under the same field, `giver.npc`.
**The field name does not currently distinguish "who offered the quest" from "who you turned it in to."**
Do not read a `giver.npc` assertion as definitively "the quest's offerer" without checking which
checkpoint produced it. This is a documented future data-model consideration, not resolved by M4 --
resolving it was explicitly out of scope when this gap was found.

## What v1 does not do

No route generation, no map/UI, no WDB/cache decoding, no prerequisite or quest-chain inference, no
automatic networking, no contributor-identity tracking, and no new confidence-ranking system. Item,
currency, spell, title, and honor rewards beyond what `RewardsItems`/`RewardsXPMoney`/`RewardsReputation`
actually established are not imported, because `module_status="experimental"` excludes them by
construction -- not because the importer has separate logic naming them.
