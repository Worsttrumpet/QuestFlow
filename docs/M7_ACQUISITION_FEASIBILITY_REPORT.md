# M7.2-A: Acquisition Feasibility & Source Pinning

**Read-only feasibility investigation. No repository was cloned. No dataset was downloaded. No file was
modified. Only metadata (HTTP status codes for specific commit/file URLs) was checked remotely — never
content.**

## Executive Summary

**Every exact historical source M0 used is still technically reachable right now** — verified directly,
not assumed: all 4 repositories exist, all 5 pinned commits resolve, and every specific file M0 actually
consumed still exists at its pinned commit. **The real blocker is not availability — it's licensing, and
it was already decided before this task began.** The project's own current, authoritative source config
(`config/sources.toml`) already excludes ForeverGuide and Questie/QuestieDB **on purpose**, per
`docs/LICENSING.md`. Since QuestV2's only historical source was a ForeverGuide-vendored CSV, and Questie
Era's only source is QuestieDB itself, **neither QuestV2 nor Questie Era can be reproduced through this
project's own already-approved pipeline** — not because the commits are gone, but because reproducing them
exactly as M0 did means re-introducing two sources this project has already decided not to use. ATT is the
one source that is both currently pinned in the live config and fully reproducible.

## Historical Acquisition Map

| Source | Repository | Revision | File | M0 usage | Current availability |
|---|---|---|---|---|---|
| ATT (head) | `ATTWoWAddon/AllTheThings` | `8e25511677df4ea5c3d0322009eafc18f203ffd3` | `.contrib/.db/forever/**` | Full Forever quest/NPC/coord/flight-path import | **Repo, commit, and path all confirmed reachable now** |
| ATT (a054efd, cross-check only) | `ATTWoWAddon/AllTheThings` | `a054efd473f0b9b13c0695dc1e81a16af4918f9d` | Same tree, labeled build `69893` | DB2-manifest diff cross-check only, not a quest import | **Repo, commit confirmed reachable now** |
| QuestV2 CSV | `RevoltLive85/ForeverGuide` | `561023695a0364024e290f2d39b385d24d6cfad3` | `data-src/db2/QuestV2.1.60.1.69913.csv` | Source of the 6,600 existence-only count | **Commit and exact file path confirmed reachable now — but the source itself is already excluded per `LICENSING.md`** |
| ForeverGuide overlay | `RevoltLive85/ForeverGuide` | same commit | `data-src/forever.json` | Cross-check set (`FG` in `quest_sets.py`) | Same as above |
| Questie Era | `Questie/QuestieDB` | `baa0998d49695c70a1fb8fec559fa9169e9adf33` | `data/Classic/classicQuestDB.lua` | Source of the 4,244 Era-quest count | **Commit and exact file path confirmed reachable now — but the source itself is already excluded per `LICENSING.md`** |
| lodestar | `danielcosta42/lodestar` | `8964d0ca325919ce33e9c40693ad204ee9203e0c` | (documentation/claims only — no extraction) | Cited as a claims source for the 2,824/1,795 baseline figures, explicitly **not reproduced** by M0 itself | **Repo and commit confirmed reachable now** |

## QuestV2 Trace

The **6,600** figure traces to exactly one place: `m0/scripts/questie_cov.py` and `quest_sets.py` both read
`ForeverGuide/data-src/db2/QuestV2.1.60.1.69913.csv` directly via `csv.DictReader`, counting `{int(r['ID'])
for r in ...}`. There is no other QuestV2 source anywhere in this project's history. `carried_from_m0.json`
independently confirms this exact figure and explicitly labels it `"carried_from_m0_not_reprobed"`,
sourced from "a third-party repository's vendored CSVs (ForeverGuide)." **No separate, first-party QuestV2
extraction has ever been performed** — `research/m1_5/REPORT.md` scoped out exactly such a path (extracting
QuestV2 directly from a real client's own `.db2` file via `wowdev/WoWDBDefs` + an MIT-licensed extractor)
but its own executive summary states plainly: **"nothing was executed against a real client."** That
alternative path's own pinned dependencies (`WoWDBDefs` commit `02b1fa9a4714fa41adbbd600304f0449d0b58146`,
`wow.tools.local` commit `06d1bf9`) are both confirmed reachable now, but this remains a fully-scoped,
never-executed plan, not a reproducible historical result.

## ATT Trace

The **1,537** figure traces to a real, executed import: `manifests/att_import_report.att-head.json`,
`"parsed_quest_ids": 1537`, from `src/foreverdb/att/importer.py` run against the pinned `att-head` commit —
the same commit still pinned in `config/sources.toml` today. This is the one figure in this whole
investigation that comes from the project's **own real importer code**, not a third-party claim. The same
report also shows `"quest_ids_only_parser_found": 21` and `"regex_quest_ids": 1516` — a real, documented
cross-check discrepancy between two parsing approaches, already noted in the M7.1 report, not resolved
here. This import covers ATT's *entire* Forever quest tree (`.contrib/.db/forever`), not a subset.

## Questie Trace

The **4,244** figure traces to `m0/M0_REPORT.md` §6's prose, describing a direct read of
`QuestieDB/data/Classic/classicQuestDB.lua` (the exact file `questie_cov.py` also references) at commit
`baa0998d49695c70a1fb8fec559fa9169e9adf33`. `M0_REPORT.md` states this data is "Era data with converted
coordinates," explicitly not Forever-native. No separate Questie import code exists in this repository at
all (unlike ATT) — this figure has only ever existed as a one-time, manual count from that single M0
session.

## Reproducibility

| Source | Status | Reason |
|---|---|---|
| ATT (`att-head`) | `reproducible_exact` | Repo, exact pinned commit, and exact consumed path all confirmed reachable right now; a real importer already exists and already reproduces the 1,537 figure from this exact commit |
| ATT (`att-a054efd`) | `reproducible_exact` | Same — confirmed reachable; used only for the existing DB2-manifest diff, already pinned in `sources.toml` |
| QuestV2 (via ForeverGuide CSV) | `license_or_provenance_unresolved` | The exact commit and file are technically reachable, but the source itself (ForeverGuide) is already flagged **"Not read"** in `docs/LICENSING.md` — reproducing it exactly as M0 did would mean overriding an already-made project decision, not a technical limitation |
| QuestV2 (via direct client `.db2` extraction) | `not_assessed` | A distinct, MIT-tooling-based path exists and its dependencies are confirmed reachable, but it has never been executed against any real client — cannot be assessed for reproducibility until actually attempted |
| Questie Era | `license_or_provenance_unresolved` | Same situation as ForeverGuide: the exact commit and file are reachable, but QuestieDB is already flagged **"Not read"** (GPL-3.0, unclear upstream provenance) in `docs/LICENSING.md` |
| lodestar | `reproducible_with_known_difference` | The repo/commit are reachable, but M0 itself never reproduced lodestar's cited baseline figures (2,824/1,795) — they were always documentation-only claims requiring additional data M0 explicitly did not have (`"baseline not reproduced [?]"`) |

## Licensing / Provenance

**Known** (directly documented in `docs/LICENSING.md`, confirmed still accurate — this file was not
modified by this task, only read):
- ATT: MIT, license status "verified" (a LICENSE file was actually read at the pinned commit); the
  **coordinate data's own upstream provenance is separately unresolved**, distinct from the repo's MIT
  license itself.
- ATT-vendored wago CSVs specifically: Blizzard-derived, redistribution unresolved, build labels are only
  claims — this is a narrower, separate concern from ATT's own repo license.
- Questie/QuestieDB: GPL-3.0, explicitly "Not read" by this project already.
- ForeverGuide: no license file found (all rights reserved by default), explicitly "Not read," and its
  overlay embeds RestedXP CC BY-NC-SA 4.0 material.
- Wago.tools: terms not retrieved; a fetcher exists in code but is disabled by default.
- Blizzard DB2/map art: no explicit redistribution grant found for any path (vendored-CSV or
  direct-extraction alike).

**Unknown**: whether the pinned ATT commit's coordinate data has since been independently attributed
upstream; whether wago.tools' current terms (never retrieved) would change the wago-CSV assessment.

**Previously flagged concern, reconfirmed unchanged**: Wowhead and RestedXP-derived data remain
categorically excluded; nothing in this task's findings changes either of those.

## Proposed Raw Snapshot Layout (Not Created)

```
data/
  raw/
    att-head/            <- exact git snapshot at 8e25511677df4ea5c3d0322009eafc18f203ffd3
    att-a054efd/          <- exact git snapshot at a054efd473f0b9b13c0695dc1e81a16af4918f9d
    manifest.json          <- per-snapshot: source URL, commit SHA, acquisition timestamp,
                              file hashes, license_id/license_status (mirroring sources.toml's
                              own existing field names, not inventing new ones)
```

Deliberately **no `questv2/` or `questie/` subdirectory proposed** — per the Reproducibility table above,
neither has an approved acquisition path today. If the direct-client-extraction alternative for QuestV2 is
ever actually executed, its output would be a first-party attestation (matching the shape
`research/m1_5/EXTRACTION_RUNBOOK.md` already scoped), not a vendored third-party CSV, and would warrant
its own separate proposal once real.

## M7.2-B Acquisition Checklist (Proposed, Not Implemented)

1. Fetch the exact pinned `att-head` and `att-a054efd` commits (already the only two entries in
   `config/sources.toml`) into the proposed `data/raw/` layout above.
2. Verify each fetched commit's SHA matches the pinned value exactly (`git rev-parse HEAD`).
3. Preserve the raw snapshot — no clone-and-discard; the snapshot persists after acquisition, unlike M0's
   original workflow.
4. Hash the snapshot's consumed files (sha256), recorded in the manifest.
5. Record a manifest: source URL, commit SHA, acquisition timestamp, file hashes, license_id/status
   (reusing `sources.toml`'s existing field vocabulary).
6. Verify the specific expected files (`.contrib/.db/forever/**`) are present as expected.
7. Re-run the existing, unmodified `src/foreverdb/att/importer.py` against the freshly-acquired snapshot.
8. Validate the resulting count against the historical `1,537` figure — record whether it matches exactly
   or differs, and by how much.
9. Record any difference explicitly (e.g., if ATT's `head` has moved on since the original pinned
   commit, or if re-running against the *same* pinned commit produces an identical result, which it should).
10. **Stop before any candidate-to-evidence integration** — no merging into M6.2/M6.4/M6.6 output.

**Safest alternative if an exact historical source cannot be used**: for QuestV2 specifically, since its
only historical path is already-excluded ForeverGuide, the safest alternative is the never-yet-executed
direct-client-extraction path (`research/m1_5/EXTRACTION_RUNBOOK.md`) — run against a **real, current**
client (build `70009`, not the historical `69913`) and labeled explicitly as a **fresh, first-party
attestation**, not a reproduction of the historical 6,600 figure, since the client has demonstrably changed
build since that number was recorded.

## Blockers

- QuestV2 and Questie Era have no currently-approved acquisition path — this is a standing project decision
  (`docs/LICENSING.md`), not something this task can or should resolve.
- The direct-client QuestV2 extraction alternative has never been executed and cannot be assessed for
  real-world reproducibility until it is.
- Whether ATT's current `head` commit still matches the *content* of the pinned `att-head` commit exactly
  (not just that the commit hash resolves) was not independently re-verified beyond the historical import
  report already on file — re-running the importer against a freshly-fetched copy (M7.2-B, step 7-8 above)
  would close this.
- GitHub's unauthenticated REST API rate limit (60 requests/hour) was exhausted partway through this
  investigation by this task's own metadata checks; subsequent checks used GitHub's web-page HTTP status
  codes instead, which worked but is a less structured signal than the JSON API would provide.

## Final Response

1. **Scripts inspected**: `m0/scripts/setup_sources.sh`, `quest_sets.py`, `questie_cov.py`, `fp_check.py`,
   `att_parse.py`, `run_m0.sh`; `forever-db/config/sources.toml`; `forever-db/docs/LICENSING.md`;
   `forever-db/registry/builds.toml`; `forever-db/research/m1_5/{REPORT.md,EXTRACTION_RUNBOOK.md}`.
2. **Repositories identified**: `ATTWoWAddon/AllTheThings`, `RevoltLive85/ForeverGuide`,
   `danielcosta42/lodestar`, `Questie/QuestieDB` (from `setup_sources.sh`); plus `wowdev/WoWDBDefs` and
   `Marlamin/wow.tools.local` (from the separate `research/m1_5` extraction path).
3. **Commits identified**: `8e25511677df4ea5c3d0322009eafc18f203ffd3` (att-head),
   `a054efd473f0b9b13c0695dc1e81a16af4918f9d` (att-a054efd), `561023695a0364024e290f2d39b385d24d6cfad3`
   (ForeverGuide), `8964d0ca325919ce33e9c40693ad204ee9203e0c` (lodestar),
   `baa0998d49695c70a1fb8fec559fa9169e9adf33` (QuestieDB), `02b1fa9a4714fa41adbbd600304f0449d0b58146`
   (WoWDBDefs), `06d1bf9` (wow.tools.local).
4. **Exact files identified**: `data-src/db2/QuestV2.1.60.1.69913.csv` and `data-src/forever.json` (both in
   ForeverGuide); `data/Classic/classicQuestDB.lua` (QuestieDB); `.contrib/.db/forever/**` (ATT).
5. **Current obtainability**: all 5 pinned commits and all specific consumed file paths returned HTTP 200
   on direct check, right now — every one is currently reachable.
6. **Remote metadata checked**: yes — `git ls-remote` for repo-level reachability, and HTTP status checks
   against GitHub's web UI for commit- and file-level existence, after the unauthenticated REST API was
   rate-limited by this task's own earlier calls.
7. **Candidate data actually downloaded**: no.
8. **Any repository cloned**: no.
9. **Files created**: one — `forever-db/docs/M7_ACQUISITION_FEASIBILITY_REPORT.md`.
10. **Files modified**: none.
11. **M4/M5/Observation Lab/M6/M7.1 confirmed untouched**: yes — `db.py`/`assertions.py`/`importer.py`
    hashes unchanged; the M7.1 report's own hash was checked before writing this one and is unchanged; no
    file under `m4-observation-lab/`, `m5-production-recorder/`, or `m6-dataset-baseline/` has a newer
    timestamp than before this task began.
12. **Recommended next action**: if the project wants to proceed, M7.2-B should acquire and persist
    **only the two already-approved ATT snapshots** (per the checklist above) — QuestV2 and Questie Era
    remain blocked by standing licensing decisions, not by availability, and should not be revisited
    without a deliberate, separate decision to override `docs/LICENSING.md`.
