# M4 Completion Report — Real-Export Ingestion Milestone

**Status: this milestone is demonstrated and ready to freeze.** See "What this does NOT claim" before
reading anything else into that sentence.

## M4 objective

To determine whether a real, manually-exported `ForeverObservationLab` SavedVariables file could actually
flow through a complete pipeline — schema validation, eligibility rules, provenance, deduplication — and
land as trustworthy, traceable rows in the existing M1 assertion/SQLite system, without redesigning that
system or touching any frozen M0–M3 work.

## Implementation

```
SavedVariables .lua (real exporter output, not JSON)
  -> src/foreverdb/harvest/savedvars.py    (safe table-literal parser, no code execution)
  -> src/foreverdb/harvest/schema_validate.py + schemas/harvest_observation.v1.schema.json
  -> src/foreverdb/harvest/importer.py     (eligibility rules, entity/field mapping, provenance)
  -> src/foreverdb/assertions.py           (UNCHANGED, existing M1 append-only model)
  -> SQLite (dataset + assertion tables, UNCHANGED schema)
```

`src/foreverdb/cli.py` gained one subcommand, `harvest-import`, following the existing `build-db`
command's style.

## Real-data validation

Actual `ForeverObservationLab` export, build `1.60.1.69977`, session `788e5c5d22ea49`, ingested and
directly inspected in SQLite (not just a successful exit code):

| | Result |
|---|---|
| Observations read | 41 |
| Observations represented | 41 |
| Experimental skipped | 0 |
| `data.ok=false` skipped | 0 |
| Malformed/invalid skipped | 0 |
| NPC-scoped observations retained | 8 |
| Quest-scoped observations | 33 |
| Assertions inserted | 51 (16 `entity_type="npc"` + 35 `entity_type="quest"`) |
| Re-import of the identical file | 0 new assertions, 51 duplicates |

Every one of the 51 assertions was directly queried and confirmed to carry `observed_build_id="69977"`
and a session-traceable `source_locator` — checked across multiple observations, not one sample row.

## Real discoveries and fixes

Two gaps were found only once real data was used — synthetic fixtures never exercised either path:

1. **`GiverIdentity` without `quest_id`.** 8 of 41 real observations were NPC sightings at `GOSSIP_SHOW`
   with no quest attached, and were being silently discarded. Fixed by importing them as
   `entity_type="npc"` evidence ("this NPC was observed here"), never as a fabricated or inferred quest
   attachment. Full explanation in `docs/HARVEST_CONTRACT.md`.
2. **`session_id` not persisted per-assertion.** It was aggregated into the import report only. Fixed by
   encoding it into `source_locator` (`session:<id>|<original locator>`) — deliberately chosen over adding
   a database column, since a new column would have meant modifying frozen M1 files. Full explanation in
   `docs/HARVEST_CONTRACT.md`.

## Provenance

`observed_build_id` is set directly from each observation's own `observed_build` field — never from the
file-level `meta`, which only reflects the most recent login. `session_id` is recoverable from every
assertion's `source_locator`. Both were verified against real data, not just synthetic fixtures.

## Idempotency

Re-importing the exact same real export file: **0 new assertions, 51 duplicates** — the database's
existing `UNIQUE (entity_type, entity_id, field, value_hash, source_dataset_id, source_locator)`
constraint provides this for free, given deterministic locators; no new deduplication logic was written.

## Privacy

The resulting real database was scanned directly for GUID-shaped strings (`Creature-`, `Player-`,
`Vehicle-`, etc.) and persistent-identifier-shaped keys (`character_name`, `account_name`, `realm_name`,
etc.): **zero matches**, checked against the actual stored `value_json` content, not inferred from the
exporter's own promise.

## Test status

**141 automated tests pass** (80 original M1 tests, 15 SavedVariables parser tests, 46 harvest ingestion
tests — including 4 regression tests added specifically for the two real-data discoveries above). Lua
syntax valid across all 21 Observation Lab addon files. The Observation Lab's own real-client-validated
test suite passes. The static safety scanner (tokenizer-based, tested against a deliberately poisoned
fixture before being trusted) reports zero forbidden committing-function references and zero
networking/comms references.

## Known limitations — explicitly not solved by M4, not failures of this milestone

- **`giver.npc` does not distinguish "who offers the quest" from "who you turn it in to."** Real data
  (quest 92528) showed two different NPCs at different checkpoints, both correctly preserved as separate
  assertions under the same field name. Documented in `HARVEST_CONTRACT.md` as a future data-model
  consideration; not addressed here by deliberate scope decision.
- Faction IDs are not resolved to names — `GetFactionInfoByID` is confirmed absent on Forever; no
  replacement API is assumed.
- Currency, spell, title, and honor reward content is not imported — the modules that would produce it
  are `experimental`, and only `proven` modules are eligible for import.
- No prerequisite or quest-chain inference of any kind.
- No NPC spawn-location enumeration — only the specific NPCs/positions actually observed during real play.
- No route generation, no map, no UI.
- No automatic networking, upload, or contributor-identity tracking of any kind.
- WDB/DBCache decoding was never attempted by this or any prior milestone.

## Frozen boundary

M0, M1, M1.5, M2, and M3 remain completely unmodified. Confirmed by direct file hash for the three most
safety-critical M1 files (`db.py`, `assertions.py`, `policy.py`) and by timestamp check across every
frozen milestone folder, both before and after this milestone's work.

## What this does NOT claim

This milestone demonstrates one specific, narrow thing:

> **The M4 pipeline can ingest a real `ForeverObservationLab` SavedVariables export and preserve
> validated first-hand observations as provenance-aware SQLite assertions, including quest-scoped and
> NPC-scoped evidence, with deterministic re-import behavior.**

It does **not** claim, and nothing in this report should be read as claiming: that every Forever quest
has been captured; that the database is complete; that all NPCs or spawn locations are known; that
prerequisites are solved; that all reward types are solved; that faction names are resolved; that
automatic route generation works; that the addon can automatically discover everything; that Blizzard has
approved this project; or any legal conclusion about redistribution or compliance. Legal/licensing review
remains a separate, unresolved question this milestone does not touch.
