# M6.3: Collection Run Report

**Scope: M6.3 only.** This is an organizational-metadata layer for planning and tracking future
collection sessions — it performs no data collection itself, classifies no conflicts (M6.4), and prepares
no guide data (M6.6). M6.4–M6.6 are not started.

## 1. What M6.3 Implemented

A small, JSON-file-backed registry of **collection runs** — deliberate research/data-collection
activities that can span multiple recorder sessions, reloads, and logout/login cycles, as distinct from a
single WoW client session. Each run carries a fixed four-state lifecycle (`planned` → `active` →
`completed`, or → `abandoned` from either of the first two), a target (specific quest IDs, specific
coverage fields, and/or a free-form scope description), associated session IDs, and optional before/after
coverage snapshot references for measuring what a completed run actually changed.

## 2. Storage Format

**A single JSON registry**, `out/m6_collection_runs.json`, keyed by `run_id` — matching the exact
convention M6.1 (`inventory.json`) and M6.2 (`m6_coverage.json`) already established. A SQLite table was
considered and rejected: it would mean either extending the frozen M4 schema (no concrete blocker exists
that would justify this) or standing up an entirely separate database file and connection lifecycle for no
benefit a JSON file doesn't already provide, given the project's own stated priority of "simple,
inspectable, reproducible, version-controllable."

**Coverage snapshots are stored separately**, one small file per snapshot under
`out/coverage_snapshots/<run_id>_<before|after>.json`, with the main registry holding only a path and a
SHA-256 content hash. The full coverage output is ~1.4MB; embedding two copies per run directly in the
registry would make the registry itself unreadable, defeating the "inspectable" requirement it's meant to
satisfy.

## 3. Run Lifecycle

```
planned -----> active -----> completed
   |              |
   +--> abandoned <+
```

No other transition is permitted — `completed` and `abandoned` are terminal. This is a deliberately small,
fixed lifecycle, not a general workflow engine, per the instruction to keep the implementation practical
rather than build a large framework.

## 4. Session Association

A run holds a plain list of session IDs — nothing more. **The M5 observation contract was not touched to
add a run identifier to it.** Association is purely a mapping this registry maintains on its own side:

```
collection run
    |
    +-- session_id A
    +-- session_id B
    +-- session_id C
```

Adding the same session ID twice is a no-op (idempotent); adding a new session never removes or reorders
ones already present. This lets one run span an arbitrary number of real sessions without any change to
how the recorder itself works.

## 5. Targeting Approach

A run can specify any combination of:
- **`target_quest_ids`** — a plain list of real quest IDs. Targeting a quest with *no* current evidence at
  all is legitimate and expected — that is the entire point of a `planned` run — and creates no fabricated
  coverage or assertion data for that ID; it is purely a note of intent on the run itself.
- **`target_fields`** — validated against the exact field set M6.2's coverage already defines
  (`coverage.QUEST_FIELD_MAP`), so a run can't silently target a field the coverage system doesn't know how
  to evaluate.
- **`target_scope`** — a free-form dict for broader, human-readable targeting (e.g. `{"zone": "...",
  "level_range": "1-10"}`) where specific IDs aren't yet known.

## 6. Before/After Coverage Approach

A snapshot is a **fresh call to M6.2's own, unmodified `build_coverage()`**, saved to its own file, with a
path and content hash recorded on the run. Comparing two snapshots (`compute_coverage_delta`) walks every
targeted quest and field and checks the **`evidence_state`** specifically — a field moving from
`unresolved` to anything else is a real coverage change; a field's `observation_count` rising with its
`evidence_state` unchanged is **explicitly not** counted as a coverage change, per the project's standing
rule that observation count must never be treated as proof that coverage improved. If either snapshot is
missing, the delta is reported as `"unknown"`, never estimated.

A field regressing *to* `unresolved` (which should not normally happen, since this project's evidence
model never deletes prior evidence) is detected and surfaced as `fields_regressed`, not silently dropped —
an anomaly worth seeing, not hiding.

## 7. Current Registered Runs

**One real, honestly-registered run exists.** No new real-client data collection happened as part of M6.3
itself (per the explicit project rule) — this run is registered as **`planned`**, with a real `before`
snapshot already taken, awaiting an actual future session:

| Field | Value |
|---|---|
| `run_id` | `run-001-resolve-unresolved-titles` |
| `status` | `planned` |
| `target_quest_ids` | `92516, 92517, 92553, 93318, 93319, 93951, 94411, 95350, 97970, 99196` — the real 10 quests M6.2's coverage report identified as viewed but never resolved to a title |
| `target_fields` | `title, quest_level, objectives` |
| `before_coverage_ref` | real snapshot, `quest_count=95, npc_count=63`, matching the current M6.2 output exactly |
| `after_coverage_ref` | none yet — no new data has been collected |

This is a genuine example of the system in use, not a placeholder — every quest ID above is real and
currently unresolved, drawn directly from the actual M6.2 coverage output.

## 8. Tests Performed and Results

**20 of 20 tests pass** (`test_collection_runs.py`), covering exactly the required list: run creation,
the full status lifecycle including a rejected invalid transition, target quest IDs/fields/scope
(including rejection of an unknown field), single and multiple session association, idempotent duplicate
association, non-destructive session addition, registry persistence across reload, before/after snapshot
preservation, the coverage-delta rule (a real test that an `observation_count`-only change is correctly
*not* counted as coverage), missing-coverage-stays-missing when nothing changed, independence between
multiple runs, idempotent registry re-save, legitimate no-evidence targeting, a structural check that this
module never re-implements SavedVariables parsing, and a check that snapshotting never overwrites the
shared `m6_coverage.json`.

**One real bug was found and fixed while writing these tests**: the original snapshot path was computed
relative to the wrong base directory, which a test exposed immediately. Fixed by storing every snapshot
path consistently relative to `OUT_DIR`, both when writing and when reading it back.

**Regression checks**: M6.2's own 12 tests still pass unchanged; the existing M4 suite's 141 tests still
pass unchanged. `db.py`, `assertions.py`, `importer.py`, and the v1 schema are all confirmed byte-identical
to their state before this milestone.

## 9. Known Limitations

- **`evidence_note`** still does not reach SQLite assertions (the unmodified M4 importer's known
  limitation, unchanged, not addressed here).
- **Recorder attribution** remains based on the same known-session-list approach M6.1 established — a
  collection run's session association does not create or imply any new historical attribution for data
  collected before this milestone existed.
- **No QuestV2/ATT candidate data** was added, generated, or approximated at any point in this milestone.
- **No real before/after coverage comparison has actually been exercised on real data yet** — the delta
  logic itself is tested thoroughly against synthetic snapshots, but `run-001` currently has only a
  `before` snapshot; a genuine real-world before/after result awaits an actual future collection session.
- The run lifecycle is intentionally minimal (four states, no sub-states, no automatic transitions) — it
  is not intended to grow into a general project-management system.

## 10. How M6.4/M6.5 Can Consume This

`M6.4` (evidence/conflict reporting) can read `out/m6_collection_runs.json` directly to correlate a
detected conflict with the specific run(s)/session(s) that produced the conflicting evidence, without any
change to this module. `M6.5` (production data collection) can create a `planned` run before a real session
begins, `associate_session()` as sessions occur, and call `snapshot_coverage(run, "after")` plus
`finalize_run_results()` once the session's export has actually been re-imported through M6.2 — the whole
mechanism already exists and is tested; using it for a real session requires no new code.
