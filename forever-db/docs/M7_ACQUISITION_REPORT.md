# M7.2-B: ATT Source Acquisition & Verification Report

**Acquisition and verification only. No candidate integration. ATT data has not been merged into any M6
evidence, coverage, or guide-ready record — it is preserved candidate source data, nothing more.**

## Acquisition Summary

Both approved ATT snapshots were acquired using the same shallow-fetch pattern this project's own
`m0/scripts/setup_sources.sh` already established (`git init` + `remote add` + `fetch --depth 1 origin
<sha>` + `checkout FETCH_HEAD`), preserving `.git` metadata for ongoing commit verification. Preserved at:

- `data/raw/att-head/` — 979 MB (full repository checkout at the pinned commit)
- `data/raw/att-a054efd/` — 963 MB (full repository checkout at the pinned commit)
- `data/raw/manifest.json` — 46,251 bytes

**A real, honest size finding**: each full checkout is nearly 1 GB, even though only the Forever-specific
subtree is relevant — AllTheThings is a large, multi-expansion addon repository, and a full shallow clone at
one commit still includes everything else it tracks. Only the actually-consumed files (184 for att-head;
the 3 role-relevant CSVs for att-a054efd) are hashed in the manifest — the manifest does not claim relevance
for the rest of the checkout, and no attempt was made to trim it, per the instruction to preserve the exact
snapshot rather than transform it. `data/` is already covered by this project's own pre-existing
`.gitignore` entry (unchanged by this task) and by `tests/unit/test_repo_safety.py`, which still passes.

## Source Identity

| Snapshot | Repository | Pinned commit | Verified `git rev-parse HEAD` | Match |
|---|---|---|---|---|
| att-head | `ATTWoWAddon/AllTheThings` | `8e25511677df4ea5c3d0322009eafc18f203ffd3` | `8e25511677df4ea5c3d0322009eafc18f203ffd3` | **Exact** |
| att-a054efd | `ATTWoWAddon/AllTheThings` | `a054efd473f0b9b13c0695dc1e81a16af4918f9d` | `a054efd473f0b9b13c0695dc1e81a16af4918f9d` | **Exact** |

Expected path `.contrib/.db/forever/` confirmed present in att-head: 184 files (148 `.lua`), 15 MB, matching
the structure (`zones/`, `dungeons & raids/`, `pvp/`, `holidays/`, `character/`) the existing importer
already expects. The three CSVs `test_real_att.py` requires (`UiMapAssignment`, `TaxiNodes`, `UiMap`, build
label `1.60.1.69913`) are all present in att-head's `.wago` directory; the same three, labeled
`1.60.1.69893`, are present in att-a054efd's, matching `sources.toml`'s own note exactly.

## Snapshot Integrity

- **att-head**: 184 consumed files hashed (SHA-256 each, recorded individually in `manifest.json`), plus one
  aggregate `tree_sha256` for the full hashed set.
- **att-a054efd**: 3 consumed files hashed (its actual used role is the DB2-manifest cross-check only, per
  instruction not to treat it as a second quest source) — `UiMapAssignment`, `TaxiNodes`, `UiMap`, build
  `1.60.1.69893`.
- Every manifest entry records: relative path, size in bytes, SHA-256, source repository, and commit SHA —
  the manifest identifies the actual preserved source material, not a generated output.
- License/status fields reuse `config/sources.toml`'s own existing vocabulary exactly (`license_id`,
  `license_status`, `upstream_provenance`, `mirrors_blizzard_csv`) — no new vocabulary was invented.

## ATT Import Reproduction

Ran the **existing, unmodified** `src/foreverdb/att/importer.py` against the freshly-acquired att-head
snapshot, using the exact same invocation sequence `tests/integration/test_real_att.py` already establishes
(load the three wago CSVs, then `import_att_snapshot`, then `crosscheck_ids`):

| Metric | Historical | Fresh | Difference |
|---|---:|---:|---:|
| Parsed quest IDs | 1537 | **1537** | **0** |
| Parser-only IDs | 21 | **21** | **0** |
| Regex IDs | 1516 | **1516** | **0** |
| FP records | 14 | **14** | **0** |
| FP ID mismatch | 0 | **0** | **0** |
| Assertions added | 10420 | **10420** | **0** |
| Assertions duplicate | 2 | **2** | **0** |

**Every single metric reproduced exactly, zero differences anywhere.** The full `by_field` breakdown
matches the historical manifest field-for-field as well (`giver.npc: 1221`, `location.att_coord: 1469`,
`name.att_comment: 1527`, `level.att_lvl_unverified: 1123`, `objective.att: 771`, and every other field —
all identical to `manifests/att_import_report.att-head.json`).

## Reproducibility Assessment

**The historical ATT import was reproduced exactly, in full, with no discrepancy of any kind.** This
confirms the pinned commit's content is byte-identical to what was originally analyzed, and that
`import_att_snapshot`/`crosscheck_ids` are fully deterministic given the same input.

## a054efd Verification

Used the existing project workflow directly (`manifest.build_manifest` + `manifest.diff_manifests`, via the
real integration test `test_cross_label_diff_finds_identical_content`) rather than writing a new comparison.
Confirmed: `att-head`'s build claim is `1.60.1.69913`, `att-a054efd`'s is `1.60.1.69893`; the diff finds
`TaxiNodes`, `UiMapAssignment`, `Item`, and `ItemSearchName` all **identical in content** despite the
different build labels, with zero tables in the `changed` list — matching the historical
`db2_manifest_diff.json` exactly. att-a054efd was not treated as an independent quest source, per
instruction.

## Licensing / Provenance

Repeating only what was already established, unchanged by this task: ATT's repository license is MIT
(license_status "verified" — a LICENSE file was read at the pinned commit); the coordinate data's own
upstream provenance remains separately "unresolved"; the vendored wago CSVs remain Blizzard-derived with
redistribution rights unresolved. No new legal conclusion is offered here. `config/sources.toml` and
`docs/LICENSING.md` were read, never modified — confirmed by hash, unchanged from before this task.

## M6 Separation

**Confirmed: no ATT data has been merged into M6 evidence, coverage, or guide data.** `m6_guide_dataset.json`
and every other M6 output file were checked for modification timestamps before and after this task — none
changed. No candidate quest records were created. No comparison against the 121 M6-observed quests was
performed. This milestone's SQLite import ran entirely in an in-memory, throwaway connection (`db.connect(
":memory:")`) that was discarded after use — nothing from it was written to any persistent M6 or M4
database file.

## Files Created

- `data/raw/att-head/` (full git checkout, 979 MB, includes `.git` metadata for commit verification)
- `data/raw/att-a054efd/` (full git checkout, 963 MB, includes `.git` metadata)
- `data/raw/manifest.json` (46,251 bytes)
- `docs/M7_ACQUISITION_REPORT.md` (this report)

## Files Modified

**None.** `config/sources.toml`, `docs/LICENSING.md`, `src/foreverdb/att/importer.py`,
`src/foreverdb/db.py`, `src/foreverdb/assertions.py`, `src/foreverdb/harvest/importer.py`, both M7
reports, and every M4/M5/Observation Lab/M6 file — all confirmed byte-identical to before this task.

## Regression Results

- **ATT real integration tests** (`tests/integration/test_real_att.py`, previously auto-skipped for lack of
  a real snapshot): **7 of 7 passed** — now genuinely exercised for the first time in this project's
  history.
- **ATT unit tests** (`test_att_dsl.py` + `test_att_importer.py`): **18 of 18 passed**.
- **Full M4 unit suite**: **141 of 141 passed** (includes the 18 ATT unit tests above).
- **Repo safety tests** (`test_repo_safety.py`): **5 of 5 passed**, including `test_gitignore_protects_data`
  — confirming the new `data/raw/` content is correctly excluded from tracked-repo status by the project's
  own pre-existing safety mechanism.
- **M6 regression suite** (M6.2 + M6.3 + M6.4 + M6.6): **62 of 62 passed**.

**Total: 233 tests passed, 0 failed.**

## Known Limitations

- The two full checkouts are much larger (≈1 GB each) than the ~15 MB actually relevant to Forever — a
  consequence of preserving the exact snapshot rather than a curated subset, as instructed.
- ATT's coordinate data's upstream provenance remains genuinely unresolved — acquiring the snapshot does
  not resolve this; it was never expected to.
- This acquisition confirms the *content* is reproducible exactly; it does not by itself establish anything
  about whether ATT's Forever-specific claims are *correct* — that remains a separate, unaddressed question,
  exactly as before this task.
