# M7.7 Scope Reconstruction: Recorder Improvements

**Read-only scope reconstruction. No implementation code, tests, datasets, or configuration were modified.**

## 1. Scope Status

**`M7.7 SCOPE ESTABLISHED`** — but narrower than the three-part candidate scope (A/B/C) originally proposed.
Evidence supports implementing **QUEST_PROGRESS capture** and **investigating one specific alternative
quest-lookup API** as a real, bounded M7.7. Evidence does **not** currently support implementing
**QUEST_ACCEPTED** as part of this milestone — M7.6's own Finding 2 undermines the premise that acceptance
timing is the root cause, and implementing it now would be guessing at a fix for a problem whose actual
cause is still unidentified.

## 2. Confirmed Problems (From M7.6 and This Investigation)

1. **`QUEST_PROGRESS` is not captured** — confirmed directly in a real session (Jorn Skyseer): zero
   observations resulted from a real progress-check interaction. Confirmed absent from `Dispatcher.lua`'s
   8 registered events (re-verified this pass).
2. **Post-acceptance title/level lookup can fail even when the quest is confirmed accepted** — confirmed
   for quest 913 (identified with certainty via exact reward-name match), where `C_QuestLog.GetInfo`-based
   lookup failed twice, including once after the quest-log UI itself showed Abandon/Untrack controls.
3. **The failure is not explained by "the frame closes after acceptance"** — objective structure and reward
   names *did* become available/improve between the two captures for quest 913, ruling out a simple
   "everything disappears" explanation. The specific point of failure is the log-index scan itself.

## 3. Proposed Changes

### Change 1: Add `QUEST_PROGRESS` capture

- **File**: `core/Dispatcher.lua`
- **Function**: the `OnEvent` handler and the `frame:RegisterEvent(...)` block
- **Current behavior**: `QUEST_PROGRESS` is never registered; the addon's frame never receives it.
- **Proposed behavior**: add `frame:RegisterEvent("QUEST_PROGRESS")` and a new branch:
  ```
  if event == "QUEST_PROGRESS" then
      local okQ, _, vQ = ForeverRecorder.SafeCall(GetQuestID, 1)
      local ctx = { quest_id = okQ and vQ[1] or nil, npc_unit = "npc", target_unit = "target" }
      dispatchCheckpoint("quest_progress", ctx)
      return
  end
  ```
  This reuses `GetQuestID()` — the same mechanism `QUEST_DETAIL` already uses — because `QUEST_PROGRESS`
  is, like `QUEST_DETAIL`, a UI-frame-driven event where frame state should be available. **This is a
  `[?]`, not a `[V]`**: whether `GetQuestID()` actually returns a valid ID while the progress frame is open
  has not been verified on Forever and needs the minimal real-game check in Section 8.
- **File**: `observers/QuestMeta.lua`, `observers/GiverIdentity.lua`
- **Change**: add `"quest_progress"` to each module's existing `checkpoints = {...}` list. No change to
  either module's capture logic — both already accept an arbitrary `ctx` shape.
- **Why this addresses a confirmed problem**: directly closes the gap Finding 1 confirmed.
- **Evidence supporting this**: the real Jorn Skyseer session; `research/m1_5/REPORT.md`'s own citation of
  `GetProgressText()` as a progress-frame API (though this project would still capture structured data via
  `C_QuestLog.*`, consistent with `QuestMeta`'s existing, already-proven approach, not the third-party
  text-scraping approach `[2nd]`-cited there).

### Change 2 (investigate, not yet commit to implementing): try `C_QuestLog.GetLogIndexForQuestID`

- **File**: `observers/QuestMeta.lua`
- **Function**: `findQuestLogIndexByID`
- **Current behavior**: scans every quest-log index from 1 to `GetNumQuestLogEntries()`, calling
  `C_QuestLog.GetInfo(i)` and comparing `.questID` — a linear search, confirmed in code.
- **Proposed investigation**: modern Blizzard client APIs generally provide
  `C_QuestLog.GetLogIndexForQuestID(questID)` — a direct ID-to-index lookup that would replace the linear
  scan entirely. **This is `[2nd]`/`[?]`: this exact function's existence and behavior on the Forever client
  has never been checked by this project** — it does not appear anywhere in this codebase today. If it
  exists and behaves as expected elsewhere in Blizzard's API family, it could be strictly more reliable
  than the current scan (no dependency on iterating every entry, no risk of a header-row or
  collapsed-category quirk affecting the result) — but this is a hypothesis to test, not a confirmed fix.
- **Why this might address a confirmed problem**: Finding 2 shows the *current* scan-based lookup fails
  even on a confirmed-present quest — a different lookup mechanism is a direct, evidence-motivated
  candidate, not a speculative addition.
- **What's still unknown**: whether this API exists on Forever at all, and if it does, whether it would
  have found quest 913 when the current scan didn't. This cannot be resolved from the repository alone.

### Not proposed: `QUEST_ACCEPTED`

M7.6's Finding 2 shows the log-index lookup fails on a quest already confirmed accepted by other means —
meaning the failure is not simply about *when* the recorder looks, it's about *how* it looks. Hooking
`QUEST_ACCEPTED` alone, using the same `GetQuestID()`/scan-based mechanism, would not obviously fix
anything, and could just add a third failure point. If Change 2's investigation establishes that a better
lookup mechanism exists and works reliably, `QUEST_ACCEPTED` could become worth revisiting *using that
mechanism* — but that is future work, not part of this scope.

## 4. Quest Event Flow

| Event | Current | Proposed |
|---|---|---|
| `QUEST_DETAIL` | Hooked. `GetQuestID()` (frame-dependent) → `dispatchCheckpoint("quest_detail", ctx)` | Unchanged |
| `QUEST_PROGRESS` | **Not hooked at all** | Hooked, same `GetQuestID()` pattern → `dispatchCheckpoint("quest_progress", ctx)` |
| `QUEST_ACCEPTED` | Not hooked | **Not proposed this milestone** |
| `QUEST_TURNED_IN` | Hooked. Quest ID from event's own arguments (frame-independent) → `dispatchCheckpoint("QUEST_TURNED_IN", ctx)` | Unchanged |

## 5. Quest ID Strategy

**Current**: two different mechanisms coexist already — `GetQuestID()` (frame-state-dependent, used at
`QUEST_DETAIL`/`QUEST_COMPLETE`) and direct event arguments (used at `QUEST_TURNED_IN`). **Proposed for
M7.7**: `QUEST_PROGRESS` uses the `GetQuestID()` pattern (Section 3, Change 1) since it is architecturally
the same kind of event as `QUEST_DETAIL` (a UI frame opening) — consistent with existing precedent, not a
new pattern. No change to how `QUEST_DETAIL` or `QUEST_TURNED_IN` obtain their IDs.

## 6. Title/Level Resolution

**Current path**: `QuestMeta.capture()` → `findQuestLogIndexByID()` (linear scan, `GetNumQuestLogEntries` +
loop + `GetInfo` comparing `.questID`) → if found, `C_QuestLog.GetInfo(index).title`/`.level`. **Identified
failure point**: the linear scan itself, confirmed failing on quest 913 even after acceptance was
independently confirmed. **Proposed for M7.7**: investigate (not yet implement) replacing the scan with
`C_QuestLog.GetLogIndexForQuestID(questID)` if real-client testing confirms it exists and resolves reliably
where the scan didn't.

## 7. Evidence/Provenance Impact

Neither proposed change touches ATT, `sources.toml`, or any M6 evidence-state vocabulary. Both operate
entirely within the existing recorder → raw observation → M4 importer pipeline, which already treats any
new checkpoint name as pass-through metadata (confirmed: the importer's field emission for `title`/`level`/
`objectives` depends only on key presence in the captured data, not on which checkpoint produced it — no
importer change is needed for `quest_progress` observations to flow through exactly like `quest_detail`
ones already do). No ATT value is read, referenced, or could be conflated with anything these changes
produce. No CollectionRun, M7.3, or M7.4 artifact is touched by either change.

## 8. Testing Plan

### Unit tests (all performable in the existing `stub_env.lua` framework — confirmed, no new test
infrastructure needed: `stub_env.lua`'s `CreateFrame` stub already fires arbitrary events generically via
`f._fire(event, ...)`)

- `QUEST_PROGRESS` registration: assert `frame:RegisterEvent("QUEST_PROGRESS")` was called.
- Dispatcher routing: firing a simulated `QUEST_PROGRESS` event produces a `quest_progress`-checkpoint
  observation via the existing `dispatchCheckpoint` mechanism.
- Quest ID extraction at `QUEST_PROGRESS`: test both the case where `GetQuestID()` succeeds and where it
  fails (the stub's `GetQuestID()` currently always returns `111` unconditionally — extending the stub to
  model a "no frame open" `nil` case is a small, necessary addition to test this properly).
- Malformed/missing quest data: existing `QuestMeta`/`GiverIdentity` error-handling paths already cover
  this generically (both already handle a missing/invalid `ctx.quest_id`) — a `quest_progress` checkpoint
  test should confirm the same paths apply without any special-casing.
- Backward compatibility: existing `quest_detail`/`quest_complete_*`/`QUEST_TURNED_IN` tests must continue
  passing unmodified.
- (If Change 2 is pursued) Log-index lookup: unit test both the current scan and a stubbed
  `GetLogIndexForQuestID`, comparing results on a synthetic quest-log fixture.

### Integration tests

The existing recorder integration framework (`stub_env.lua` + `run_recorder_tests.lua`) can simulate
`QUEST_PROGRESS` the same way it already simulates every other event — no new simulation capability is
needed. `QUEST_ACCEPTED` is out of scope this milestone, so no integration test for it is proposed here.

### Real-game validation

**One tiny, natural interaction, not a campaign**: the next time the player naturally revisits any
in-progress quest's giver during normal play (something that happens routinely, not a deliberate detour),
check `/fr status` before and after to confirm a `quest_progress` observation was recorded. This requires no
new quest, no collection campaign, and can piggyback on whatever the player is already doing. If Change 2
is pursued, the same natural interaction (on a quest where the current scan is already known to fail, like
retrying with a similarly-structured quest) would validate whether the alternative API resolves it.

## 9. Explicit Out-of-Scope Items

| Item | Status |
|---|---|
| `QUEST_ACCEPTED` capture | Deferred — premise undermined by Finding 2; revisit only after Change 2's investigation concludes |
| Gossip quest-list expansion beyond 5 entries | Out of scope — not established as relevant to either confirmed problem |
| Target/NPC capture integration into M6 | Out of scope — not established as relevant to either confirmed problem |
| WDB cache file investigation | Out of scope — unrelated to the two confirmed problems; a separate, much larger unknown |
| Taxi node API investigation | Out of scope — unrelated to the two confirmed problems |
| Automatic CollectionRun creation | Out of scope — unrelated to recorder capture; M7.5 already established this is a separate, explicit-approval step |
| ATT candidate promotion | Out of scope — categorically excluded by standing project rules, unaffected by this milestone |
| M6 dataset redesign | Out of scope — not needed; confirmed the existing importer already handles new checkpoints correctly |
| Map/route generation | Out of scope — unrelated |
| New external data sources | Out of scope — unrelated, and categorically excluded |

## 10. Risk Register

- **`GetQuestID()` may not return a valid value while a `QUEST_PROGRESS` frame is open** — unverified on
  Forever; this is the single largest uncertainty for Change 1, and the reason Change 1's real-game
  validation (Section 8) is needed before considering the change complete, not just before considering it
  started.
- **`C_QuestLog.GetLogIndexForQuestID` may not exist on this client, or may not fix the observed failure**
  — Change 2 is explicitly framed as an investigation, not a committed fix, for exactly this reason.
- **The root cause of Finding 2 could be something neither change addresses** (e.g., a quest-log
  category/header interaction, a caching delay longer than expected, or something else entirely) — this
  risk is real and not fully mitigated by either proposed change; Section 12 names this explicitly as a
  stop condition.

## 11. Implementation Sequence (If Approved — Not Performed Here)

1. Extend `stub_env.lua`'s `GetQuestID` stub to support a configurable success/failure case.
2. Add `QUEST_PROGRESS` registration and handler to `Dispatcher.lua`; add `"quest_progress"` to
   `QuestMeta.lua`/`GiverIdentity.lua` checkpoint lists.
3. Add and pass the unit tests in Section 8.
4. Perform the minimal real-game validation (Section 8) for Change 1 specifically.
5. Only after Change 1 is validated: research whether `C_QuestLog.GetLogIndexForQuestID` exists and
   behaves as expected (real-client check, not repository-derivable).
6. If Change 2's research is positive, implement it as a small, isolated swap inside
   `findQuestLogIndexByID`, with the old scan logic kept as a documented fallback until further real-world
   confirmation.
7. Stop. Do not begin `QUEST_ACCEPTED` or any Section 9 item without a separate, explicit scope decision.

## 12. Stop Condition

Implementation should stop, and the finding should be reported rather than worked around, if: (a) the
minimal real-game validation shows `GetQuestID()` returns nil/invalid at `QUEST_PROGRESS` time (meaning
Change 1 needs a different ID-acquisition strategy, not assumed to be solvable by retrying the same
approach); (b) `C_QuestLog.GetLogIndexForQuestID` does not exist on the Forever client at all; or (c) it
exists but still fails on a quest the current scan also fails on — in which case Finding 2's actual root
cause remains genuinely unknown and would need its own separate investigation before any further lookup-path
change is attempted.

---

## Verification

1. **No implementation files modified**: confirmed — `Dispatcher.lua` hash unchanged
   (`d7ea9d4373d9a7a40854c560c1b38b19`, re-checked this pass).
2. **No tests modified**: confirmed — no file under `m5-production-recorder/tests/` or
   `forever-db/tests/` was touched.
3. **No M6 data changed**: confirmed — `m6_collection_runs.json` unchanged
   (`60b713f2bcaf5e6ec590de382515be4efbca2c5014bd126fbee3569d7efedfaa`).
4. **M7.3 artifacts byte-identical**: confirmed (`coverage_gap_analysis.json`/`.py` untouched this pass).
5. **M7.4 artifacts byte-identical**: confirmed (`proposed_targets.json` untouched this pass).
6. **M7.5 planned CollectionRuns unchanged**: confirmed — all 10 `run-m7-5-pilot-*` entries untouched (same
   registry file, same hash as item 3).
7. **`config/sources.toml` unchanged**: confirmed, not opened this pass.
8. **`docs/LICENSING.md` unchanged**: confirmed, not opened this pass.
9. Only read operations (file reads, hash checks) were performed to produce this document.
10. **Files created this pass**: exactly one — `docs/M7_7_SCOPE.md`. **Files modified**: none.
