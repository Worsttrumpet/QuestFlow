# Provenance and evidence model

## Datasets

A `dataset` is one file or snapshot the pipeline read.

| field | meaning |
|---|---|
| source_kind | `git` \| `wago` \| `user_file` |
| source_uri, source_ref | where, and which commit or build |
| path_in_source | file inside a snapshot |
| retrieved_at | when this pipeline read it |
| sha256 | files only (snapshots use `content_id`, the git tree id) |
| first_hand | the pipeline read the bytes itself |
| origin | `direct` \| `mirror` \| `user_supplied` |
| mirror_of | e.g. `wago.tools` for a third-party copy |
| license_id, license_status | `verified` = read from a license file; `unresolved` otherwise |
| redistributable | `1` established, `0` not allowed, `NULL` unresolved (the default) |
| claimed_build_id, claim_basis, build_claim_verified | what the source says, why we believe it said so, and whether Blizzard confirms it |

**Build labels on mirrored files are claims.** M1 found that ATT's history renamed 33 tables from
`...69893.csv` to `...69913.csv` with zero content change, including Item and ItemSearchName. A label
tells us what a maintainer wrote, not which client the bytes came from.

## Assertions

| column | meaning |
|---|---|
| entity_type, entity_id | e.g. `quest`, 783 |
| field | dotted name. Fields whose meaning is not established carry an `att.` prefix or `_unverified` suffix |
| value_json | canonical JSON; `value_hash` deduplicates re-imports |
| source_kind | `client_table` \| `harvest_observation` \| `third_party_import` \| `inferred` |
| source_dataset_id, source_locator | which file, which line |
| observed_build_id | set only when the pipeline itself can tie the observation to a build |
| claimed_build_id, claim_basis | what the source says, and why we believe it |
| status | `observed` \| `imported_unverified` \| `verified` \| `disputed` \| `superseded` \| `rejected` |
| confidence | `client_authoritative` \| `observed_first_hand` \| `third_party_unverified` \| `inferred` |

**Resolution** (`policy.py`): drop `rejected` and `superseded`; rank by `source_kind`, then
confidence; return every assertion in the top tier (multi-valued fields keep all values); ties
keep the newest observed build. Nothing is deleted; `assertion_status_log` records every status change.

## Quest evidence flags (derived by view, tri-state)

`client_id_observed`, `era_baseline`, `att_observed`, `server_confirmed`.
A flag is `1` if evidence exists, `0` if a source of that kind was loaded and the ID is absent,
and `NULL` if no source of that kind has been loaded. QuestV2 membership is an observed client ID,
not proof of an obtainable quest.
