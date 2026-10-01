# M1 architecture: the data / evidence foundation

M1 answers one question: **"Exactly what do we know about a Forever entity, which build did we
observe it in, where did each field come from, and how confident are we?"**

Out of scope for M1: frontend, map, route engine, public API, PostgreSQL. Storage is SQLite.

## 1. Directory structure

```
forever-db/
  pyproject.toml            tooling config only (no runtime dependencies; stdlib only)
  .gitignore                data/ and *.sqlite are never tracked
  README.md
  registry/
    builds.toml             COMMITTED  build registry: three builds, evidence, verification status
    verification_log.jsonl  COMMITTED  append-only log of attempts to verify against Blizzard
  config/
    tables.toml             COMMITTED  DB2 tables we care about, and why
    sources.toml            COMMITTED  pinned source snapshots (repo, commit, license notes)
  manifests/                COMMITTED  generated metadata only: names, row counts, columns, sha256
    db2_manifest.<snapshot>.json       (no row data)
    db2_manifest_diff.json
    coord_validation.json
    carried_from_m0.json               second-hand claims from M0, labelled as such
  schemas/
    harvest_observation.v0.schema.json COMMITTED  harvest contract (design only)
  docs/                     COMMITTED
  src/foreverdb/
    registry.py             build registry + Blizzard version-feed check (never guesses)
    provenance.py           DatasetRecord, sha256, license/redistribution status
    acquire.py              pinned git snapshots; Wago fetcher (disabled by default); local files
    manifest.py             DB2 table probe + cross-build diff
    db.py                   SQLite schema (generated at build time)
    quests.py               quest shell + evidence flags
    assertions.py           assertion model, status log, resolution
    policy.py               evidence ranking (which assertion wins; nothing is deleted)
    coords.py               UiMapAssignment transform, derived coordinates, validation
    att/dsl.py              tolerant parser for ATT's Lua DSL
    att/importer.py         ATT -> assertions
    cli.py                  `python -m foreverdb ...`
  tests/unit/               synthetic fixtures only; always run
  tests/integration/        need acquired snapshots (auto-skip otherwise)
  data/                     NEVER COMMITTED
    raw/                    pinned git snapshots, downloaded CSVs
    build/forever.sqlite    generated database
```

## 2. Data flow

```
 pinned sources ──acquire──► data/raw/ ──probe──► manifests/*.json        (metadata, committed)
 (git@sha, wago,                │
  user-supplied CSV)            ├─ parse ATT DSL ──► assertions ─┐
                                ├─ QuestV2 CSV ────► quest shell ┤
                                └─ UiMapAssignment / TaxiNodes ──┤► data/build/forever.sqlite
                                                                 │        │
                   registry/builds.toml ───────────────────────► ┘        ├─ resolve() (strongest tier)
                                                                          └─ derived_coordinate (rebuildable)
```

Every step that reads a file records a `dataset` row: source, ref (commit/build), retrieval
time, SHA-256, license id, license status, and whether redistribution is established.

## 3. Schema changes from M0

M0 proposed `game.*`, `comm.*`, `derived.*` layers. M1 narrows that to what the evidence supports:

| M0 proposal | M1 |
|---|---|
| `quest` with attributes | `quest` is a bare shell (`quest_id` only). Flags are **derived by view** from evidence rows, so they cannot go stale. |
| game-layer quest fields | The only client-derived quest structure is `quest_client_row` (what QuestV2 holds). Everything else is an assertion. |
| `placement` table | `assertion` with a location value, plus `derived_coordinate` (rebuildable, never authoritative) |
| single confidence number | categorical `confidence` plus an explicit ranking policy in code |
| assumed build labels | `build` registry with `verification`, plus per-dataset `claimed_build_id` and `build_claim_verified` |

Tri-state flags: `1` observed, `0` checked and absent, `NULL` **not checked** (no source of that kind loaded).

## 4. Provenance / evidence model

See `PROVENANCE_MODEL.md`. In short: an assertion is `(entity, field, value)` plus
`source_dataset_id`, `source_locator` (file:line), `observed_build_id` or `claimed_build_id`,
`source_kind`, `status`, `confidence`. Competing values coexist; `resolve()` returns the strongest
tier and never deletes the rest. Status changes are appended to a log.

## 5. Safe to commit

Code, tests with synthetic fixtures, docs, schemas, `registry/`, `config/`, and `manifests/`
(table names, row counts, column names, file hashes only). The hash of a Blizzard-derived file
is a fingerprint, not content.

## 6. Generated / downloaded at build time (never committed)

- `data/raw/**`: pinned ATT snapshots (they contain mirrored Blizzard CSVs), any Wago download, user-supplied CSVs.
- `data/build/forever.sqlite`: contains Blizzard-derived rows (taxi nodes, map regions, QuestV2 ids).
  A publishable evidence-only export is deferred until redistribution rights are resolved.

Enforced by `tests/unit/test_repo_safety.py`.

## Open licensing items (unchanged from M0)

Blizzard redistribution: unresolved. wago.tools terms: not retrieved; the Wago fetcher stays
disabled until you explicitly enable it. ATT: MIT for the repo, upstream provenance of its
coordinates unknown. Code license for this project: **your decision** (no LICENSE file added).
