# Licensing and provenance matrix (M1)

| Source | Use in M1 | Status |
|---|---|---|
| ATT (AllTheThings) repo | Read at a pinned commit; ATT-authored Forever data -> assertions | MIT verified. Upstream provenance of its coordinates **unresolved** |
| ATT-vendored wago CSVs | Read at build time (UiMapAssignment, TaxiNodes, UiMap, manifest probe); never committed | Blizzard-derived; redistribution **unresolved**; build labels are **claims** |
| wago.tools | Fetcher exists but is **disabled** by default | Terms not retrieved; robots.txt refused one automated client in M0 |
| Blizzard version service | Checked by `registry verify`; failure is recorded, never guessed | Unreachable from the M1 sandbox |
| ForeverGuide | **Not read** | No license; overlay embeds RestedXP-derived facts (CC BY-NC-SA) |
| Questie / QuestieDB | **Not read by forever-db.** The Quest Flow ADDON (a separate component) may call the QuestieDB addon's public API at runtime when the player has it installed; nothing of it is copied, vendored or shipped (see `questflow/docs/CODEX_DATA_SOURCES.md`) | GPL-3.0 stated; no licence file found in its repositories; upstream provenance unclear |
| RestedXP-derived data | **Not read** | CC BY-NC-SA 4.0 |
| Wowhead | **Not read, not scraped** | Fanbyte EULA bars crawlers and derivative works |
| AGPL tooling (e.g. wowdata) | **Not used**, no code copied | Would require AGPL compliance |

## Quest Flow addon (added 2026-10-06; supersedes the "Not read" wording above for the ADDON only)
`forever-db` (this dataset pipeline) still reads none of Questie / QuestieDB / RestedXP / ForeverGuide / Wowhead. The `questflow` addon is a different component with its own, narrower rule: it may READ the separately installed
QuestieDB addon through its documented public API at runtime, and it must never copy, vendor, ship or re-export any QuestieDB (or Questie) code or data, nor treat what it reads as confirmed on Forever. Everything read is labelled
`src=questiedb, verified=false`; observed Forever data always wins field by field. The dependency is optional, and can be turned off (Quest Flow Options, or `/qflow questiedb off`). Full matrix: `questflow/docs/CODEX_DATA_SOURCES.md`.

## Rules enforced in code
- `DatasetRecord.redistributable` defaults to `None` (unresolved). Only `True` allows committing (`may_commit`).
- `.gitignore` excludes `data/`, `*.sqlite`, `*.csv`; `tests/unit/test_repo_safety.py` fails if tracked files
  include CSV/SQLite or Lua data.
- The Era baseline flag must come from a client table (an Era QuestV2), never from Questie's GPL data.

## Decisions left to the project owner
1. Code license (none added).
2. Community-data license and contributor terms.
3. Whether/when to enable the Wago fetcher (after reading its terms).
4. Whether to seek Blizzard clarification before publishing any derived client data.
