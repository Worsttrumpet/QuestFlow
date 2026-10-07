# M7.7 Implementation Report: QUEST_PROGRESS Recorder Capture

**Implemented exactly the scope established in `docs/M7_7_SCOPE.md` — nothing more.**

## 1. Implementation Summary

The M5 recorder now hooks the WoW client's `QUEST_PROGRESS` event, using the same `GetQuestID()` mechanism
`QUEST_DETAIL` already uses (both are UI-frame-driven events), and routes it through the existing checkpoint
dispatch system to the existing, unmodified `QuestMeta` and `GiverIdentity` observers. No new evidence
architecture, data source, ATT interaction, or CollectionRun behavior was introduced.

## 2. Files Changed

| File | Change | Why |
|---|---|---|
| `m5-production-recorder/addon/ForeverRecorder/core/Dispatcher.lua` | Added `frame:RegisterEvent("QUEST_PROGRESS")` and one new `OnEvent` branch | Registers and routes the new event, following the exact existing convention for `QUEST_DETAIL` |
| `m5-production-recorder/addon/ForeverRecorder/observers/QuestMeta.lua` | Added `"quest_progress"` to the existing `checkpoints` list | Lets the existing, unmodified capture function run at this checkpoint |
| `m5-production-recorder/addon/ForeverRecorder/observers/GiverIdentity.lua` | Added `"quest_progress"` to the existing `checkpoints` list | Same reason — giver identity capture needs no `quest_id` and works unmodified |
| `m5-production-recorder/tests/run_recorder_tests.lua` | Added 5 new tests | Covers the required test list exactly (Section 8 below) |

**Files touched then fully reverted, confirmed byte-identical to their original content**:
`m5-production-recorder/tests/stub_env.lua` — an initial approach (a configurable global stub variable)
turned out to conflict with an *existing* test's own established pattern of directly reassigning
`GetQuestID` inline (found while debugging a real test failure, Section 5 below); reverted, and the new
tests were rewritten to reuse that existing pattern instead, per the instruction not to introduce a new
test-infrastructure mechanism unless genuinely necessary.

No other file was modified.

## 3. QUEST_PROGRESS Data Captured

**Directly event/API-derived, using existing mechanisms only:**
- Quest ID: via `GetQuestID()` — the same no-argument, frame-state-dependent global `QUEST_DETAIL` already
  uses. Not yet verified whether this function returns a valid ID while a real `QUEST_PROGRESS` frame is
  open on the actual Forever client (see Section 6, Real-Game Validation).
- Title, level, objectives: via `QuestMeta`'s existing, unmodified `C_QuestLog.GetInfo`/
  `GetQuestObjectives` calls — identical code path to `QUEST_DETAIL`, not reimplemented.
- NPC/target identity, position: via `GiverIdentity`'s existing, unmodified capture — identical code path
  to `QUEST_DETAIL`/`GOSSIP_SHOW`.

**Fields deliberately not captured at this checkpoint**: rewards (choice items, guaranteed items,
reputation, XP, money) — none of the reward-capturing observers (`RewardsItems`, `RewardsReputation`,
`RewardsXPMoney`) were added to the `quest_progress` checkpoint, since no reward information exists or is
shown at a progress check-in screen; adding them would only ever produce empty/meaningless captures.

**If the quest ID cannot be established**: `QuestMeta`'s existing, unmodified `capture()` function already
handles this exact case (`ok=false, error="no quest_id in context"`) — no new fallback logic was added,
because none was needed; verified directly by Test 3 (Section 5).

## 4. Evidence Flow

```
QUEST_PROGRESS (WoW client event)
    → Dispatcher.lua: GetQuestID() (existing mechanism) → dispatchCheckpoint("quest_progress", ctx)
    → Registry:ModulesForCheckpoint("quest_progress") → QuestMeta, GiverIdentity (existing, unmodified)
    → recordObservation() → ForeverObservationLabDB.observations (existing SavedVariables shape, unchanged)
    → /fr save → ReloadUI() (existing, unmodified)
    → M4 savedvars.py / importer.py (existing, unmodified) → title.harvest_observed / level.harvest_observed
      / objectives.harvest_observed assertions, method = "QuestMeta@quest_progress"
    → M6 coverage / evidence classification (existing, unmodified) — a quest_progress-sourced observation
      is treated exactly like any other checkpoint's observation already is
```

**ATT is not involved anywhere in this flow.** No file changed in this milestone reads, imports, or
references `src/foreverdb/att/` in any way. The new checkpoint produces the same kind of observation
`quest_detail` already produces — nothing about it resembles or touches candidate/source-derived data.

## 5. Tests

**5 new M7.7 tests, all passing, in `m5-production-recorder/tests/run_recorder_tests.lua`:**

1. `QUEST_PROGRESS` event is recognized and reaches the correct Dispatcher branch.
2. A valid `QUEST_PROGRESS` capture produces exactly one `QuestMeta` and one `GiverIdentity` observation,
   with the real quest ID, and explicitly confirms no reward-observer fires.
3. An unresolvable quest ID at `QUEST_PROGRESS` is never fabricated — `QuestMeta` reports its own existing
   `"no quest_id in context"` error unchanged; `GiverIdentity` still succeeds (it needs no quest ID).
4. The `quest_progress` observation's field envelope is structurally identical to `quest_detail`'s — direct
   proof the existing M4 importer needs no new field mapping.
5. Full-lifecycle regression: `QUEST_PROGRESS` fires alongside every pre-existing checkpoint in one
   sequence, confirming no interference with existing behavior.

**A real bug was found and fixed while writing these tests, not silently worked around**: my first version
of Tests 2/3 introduced a new stub mechanism (`_G.__stubQuestIDValue`) that a pre-existing test (the
quest-scoped/NPC-scoped `GiverIdentity` test) doesn't use — that existing test directly reassigns the
global `GetQuestID` function itself and restores it with a hardcoded closure at its end, which silently
overrode my new mechanism for every test running after it. Diagnosed precisely via a debug print showing
the real accumulated state, not guessed. Fixed by removing the new mechanism entirely and rewriting my
tests to use the exact same direct-reassignment convention the existing test already established —
resulting in a smaller diff than my first attempt, and zero new test-infrastructure surface.

**A real, independent end-to-end verification was also performed**, beyond the Lua unit tests: a
schema-valid synthetic SavedVariables export containing one `quest_progress`-checkpoint observation was run
through the actual, unmodified `src/foreverdb/harvest/savedvars.py` and `importer.py`. Result: `0` fatal
errors, `3` assertions added (`title.harvest_observed`, `level.harvest_observed`,
`objectives.harvest_observed`), each with `method = "QuestMeta@quest_progress"` — confirming the M4
compatibility claim empirically, not just structurally.

**Full regression results:**

| Suite | Result |
|---|---|
| Recorder Lua test suite (`run_recorder_tests.lua`, includes the 5 new M7.7 tests) | `ALL RECORDER TESTS PASS` |
| M4 Python unit suite | 141/141 passed |
| Real ATT integration test | 7/7 passed |
| M6 regression suite | 62/62 passed |

**Zero failures. Zero existing tests weakened, deleted, or modified.**

## 6. Real-Game Validation

**Not performed as part of this implementation** — per instruction, implementation does not depend on it.
The scope document's own risk register already names this precisely: whether `GetQuestID()` returns a
valid value while a real `QUEST_PROGRESS` frame is open on the Forever client is unverified. The smallest
possible validation, reported separately rather than gating this work: the next time a player naturally
revisits an in-progress quest's giver during ordinary play, check `/fr status` before and after — if the
count increases, `GetQuestID()` worked in that real context; if not, the quest ID will have come back
`nil` and Test 3's confirmed-safe fallback (no fabrication) is what actually happened. No new quest or
detour is required for this check.

## 7. Out-of-Scope Items — Confirmed Unresolved

- Post-acceptance title/level lookup reliability (`findQuestLogIndexByID`'s scan) — untouched.
- `QUEST_ACCEPTED` — not hooked, not evaluated further.
- `C_QuestLog.GetLogIndexForQuestID` — not investigated or referenced in any code this milestone.
- Gossip quest-list expansion beyond 5 entries — untouched.
- Target/NPC integration into M6 — untouched.
- WDB cache investigation — untouched.
- Any further passive-harvesting work — not begun.

## 8. Repository Verification

| Item | Changed? |
|---|---|
| M6 outputs (`m6_collection_runs.json`, coverage, evidence, guide dataset) | **No** — hash-confirmed identical |
| M7.3 artifacts | **No** — hash-confirmed identical |
| M7.4 artifacts | **No** — hash-confirmed identical |
| M7.5 planned CollectionRuns | **No** — same registry file as above, unchanged |
| `config/sources.toml` | **No** — hash-confirmed identical |
| `docs/LICENSING.md` | **No** — hash-confirmed identical |
| ATT importer / ATT source data | **No** — not touched, not opened |

**Exact diff footprint**: 3 recorder source files (Dispatcher.lua: +12 lines; QuestMeta.lua: 1 line changed;
GiverIdentity.lua: 1 line changed) and 1 test file (+94 lines, 5 new tests). No file outside
`m5-production-recorder/` was modified.
