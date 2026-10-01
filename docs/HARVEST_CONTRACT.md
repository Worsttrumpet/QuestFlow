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

## Unverified items this contract depends on

- Whether Forever exposes the quest-data request API reliably. Third parties report server throttling and
  a client cache directory (`Cache/WDB/*.wdb`). Not tested here.
- Whether values become unreadable ("secret") in some client states. Reported by a third party, not tested here.
- WDB record layouts. `parser_version` exists because we expect to get them wrong at first.
