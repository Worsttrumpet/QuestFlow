# M7.6 Follow-Up: `QUEST_ACCEPTED` Experiment Design

**Design only. No implementation, no recorder modification, no M6 change.** Every claim about existing code
is traced to the actual files; every claim about `QUEST_ACCEPTED` itself not already covered by this
project's own code is explicitly marked `[2nd]`/`[?]`, per this project's own evidence discipline.

## 1. The Exact Existing Capture Path (Traced From Code)

```
QUEST_DETAIL fires (quest-offer frame opens, always via NPC interaction)
    ↓
Dispatcher.lua's OnEvent: GetQuestID() -- a no-argument global that reads the CURRENTLY-OPEN
    quest-detail frame's state. Confirmed: QUEST_DETAIL itself carries no event arguments;
    the quest ID comes from this separate call, which depends on that frame being open.
    ↓
ctx = { quest_id = <id or nil>, npc_unit = "npc", target_unit = "target" }
    ↓
dispatchCheckpoint("quest_detail", ctx)
    ↓
Registry:ModulesForCheckpoint("quest_detail") -- returns QuestMeta and GiverIdentity
    (each registered its own "checkpoints" list at load time; Dispatcher does not know
    module names, only checkpoint names)
    ↓
QuestMeta.capture(ctx): requires ctx.quest_id to already be numeric (checked explicitly --
    returns ok=false, error="no quest_id in context" otherwise). Calls
    C_QuestLog.GetNumQuestLogEntries + C_QuestLog.GetInfo (scanning for the quest by ID in
    the log) + C_QuestLog.GetQuestObjectives(questID).
GiverIdentity.capture(ctx): uses ctx.npc_unit/target_unit (unit tokens, not IDs) with
    UnitGUID/UnitName/UnitLevel/etc. -- does not need ctx.quest_id at all.
    ↓
recordObservation() appends the raw result to ForeverObservationLabDB.observations
    ↓
/fr status reports only a count + session ID (does not inspect content)
    ↓
/fr save -> ReloadUI() only -- no transformation
```

**Critical distinction confirmed by this trace**: `GetQuestID()` (used at `QUEST_DETAIL`) depends on a
*frame being open* — it takes no arguments. `QUEST_TURNED_IN`'s handler, by contrast, reads the quest ID
directly from the *event's own arguments* (`local questID, xpReward, moneyReward = ...`) — no frame
dependency at all. These are two different mechanisms already coexisting in this codebase, not one uniform
pattern.

## 2. `QUEST_ACCEPTED` — What Is and Isn't Known

- **Confirmed by this project's own code**: `QUEST_ACCEPTED` is not registered anywhere in `Dispatcher.lua`
  (verified in M7.6 and re-confirmed here) — it is never delivered to this addon's frame at all today.
- **`[2nd]`, not verified on Forever by this project**: in modern retail/Classic-era WoW client APIs
  generally, `QUEST_ACCEPTED` fires with the quest ID as a direct event argument (`QUEST_ACCEPTED(questID)`)
  — the same *style* as `QUEST_TURNED_IN`, not the same style as `QUEST_DETAIL`/`GetQuestID()`. This is a
  real, load-bearing distinction: if true, the existing `QuestMeta.capture()` function could be reused
  as-is (it only needs `ctx.quest_id` populated, however that happens) — but `GetQuestID()` itself likely
  would **not** work at `QUEST_ACCEPTED` time, since the quest-offer frame has just closed. **Whether this
  holds on the actual Forever client is unverified — this is exactly the kind of claim the experiment below
  needs to test, not assume.**
- **`[?]`, genuinely unknown**: whether `C_QuestLog.GetInfo`/`GetQuestObjectives` — which scan the quest log
  by ID — succeed *immediately* at `QUEST_ACCEPTED` time, or whether the log entry needs a brief moment to
  populate (the same kind of timing concern that already justified `quest_complete_delayed`'s 1.5-second
  follow-up capture in this exact codebase).

## 3. The Smallest Possible Experiment

**The literal hypothesis — "hooking `QUEST_ACCEPTED` to trigger the existing capture logic" — cannot be
tested as a real automatic capture without adding an event registration.** `Dispatcher.lua`'s frame never
receives `QUEST_ACCEPTED` today; there is no existing code path that would run at that moment no matter
what the player does in-game. This is confirmed by the trace above, not assumed.

However, a **narrower, existing-code-only precursor experiment** can still probe the underlying premise —
*does the information genuinely become unavailable immediately upon acceptance, or only after some delay/
session change?* — using only the already-hooked events, one quest, and no code change:

```
1. Find one quest not yet accepted.
2. Talk to the giver -> QUEST_DETAIL fires (existing path, already captures title/level/objectives/giver).
3. Accept the quest.
4. WITHOUT leaving or delaying, immediately re-open dialogue with the SAME NPC.
5. Observe empirically: does this immediate re-interaction produce a second QUEST_DETAIL, or GOSSIP_SHOW?
6. /fr status, /fr save.
```

This does not test `QUEST_ACCEPTED` hooking itself, but it directly tests whether the loss of
`QUEST_DETAIL` access is **instantaneous upon acceptance** (already true even with zero delay) or
**session/distance/time-dependent** (the already-documented M6.5 finding involved a real gap in time and
likely a different session). If step 5 shows `GOSSIP_SHOW` even with zero delay, that's strong evidence the
information genuinely can only be caught at the exact acceptance instant — strengthening the case for the
`QUEST_ACCEPTED` hook. If step 5 still shows `QUEST_DETAIL`, the original M6.5 problem may be about
elapsed time or session boundaries rather than the acceptance moment itself, and a different fix (not
`QUEST_ACCEPTED`) might be more relevant.

## 4. The Comparison (As Specified)

| Field | Capture A (`QUEST_ACCEPTED`-triggered) | Capture B (existing path, later revisit) |
|---|---|---|
| Quest ID | Would need the event's own argument (unverified) or `GetQuestID()` (likely fails, no frame open) | `GetQuestID()`, confirmed working (existing path) |
| Quest title | Untested — depends on Question 2 above | Confirmed working when quest already in log |
| Quest level | Untested | Confirmed working |
| Giver / giver ID | `GiverIdentity` doesn't need `quest_id` — would work regardless | Confirmed working |
| Coordinates (player only) | Would work regardless (same as giver) | Confirmed working |
| Objectives | Untested — depends on log-population timing | Confirmed working |
| Rewards | Not applicable at acceptance (no reward data exists pre-completion) | Confirmed working at turn-in only |

**Capture A cannot currently exist to run this comparison** — Section 3's literal ask requires the event
hook. The precursor experiment in Section 3 is offered as the closest thing performable today, but it is
not a substitute for the literal comparison this section specifies.

## 5. Are Code Changes Necessary?

**Yes, for the literal experiment as specified.** The existing recorder cannot deliver a `QUEST_ACCEPTED`
event to any capture logic at all — not "discards it," genuinely never receives it (confirmed: no
`RegisterEvent("QUEST_ACCEPTED")` call exists anywhere).

**Minimum change identified, NOT implemented:**

- **File**: `core/Dispatcher.lua`
- **Change 1**: add `frame:RegisterEvent("QUEST_ACCEPTED")` alongside the other seven registrations.
- **Change 2**: add a new branch in the `OnEvent` handler, patterned after `QUEST_TURNED_IN`'s
  argument-based style (not `QUEST_DETAIL`'s `GetQuestID()` style, per Section 2's reasoning):
  ```
  if event == "QUEST_ACCEPTED" then
      local questID = ...
      local ctx = { quest_id = questID, npc_unit = "npc", target_unit = "target" }
      dispatchCheckpoint("quest_accepted", ctx)
      return
  end
  ```
- **File**: `observers/QuestMeta.lua` and `observers/GiverIdentity.lua`
- **Change 3**: add `"quest_accepted"` to each module's existing `checkpoints = {...}` list (no other
  change to either module's capture logic — both already accept an arbitrary `ctx` shape).
- **Expected behavior**: a new `quest_accepted` checkpoint observation would appear in
  `ForeverObservationLabDB.observations`, structurally identical in shape to an existing `quest_detail`
  observation.
- **Reversion**: remove the one registration line and the one new branch in `Dispatcher.lua`; remove
  `"quest_accepted"` from the two checkpoint lists. No schema, no M4 importer change would be needed to
  revert (a `quest_accepted` checkpoint value simply wouldn't appear in the data anymore).

This is a small, precisely-scoped, fully reversible change — but it is still a change, and this document
does not make it.

## 6. Expected Outcomes and Interpretation

If the (not-yet-implemented) `QUEST_ACCEPTED` hook were added and tested:

- **If `GetQuestID()`-style lookup fails but the event's own argument works**: confirms Section 2's `[2nd]`
  claim; the minimal change above (argument-based, not `GetQuestID()`-based) is the right shape.
- **If `C_QuestLog.GetInfo`/`GetQuestObjectives` return nothing immediately**: would mirror the existing
  `quest_complete_delayed` pattern — a short `C_Timer.After` follow-up capture (already proven code in this
  exact codebase) would likely be needed, not a fundamentally new mechanism.
- **If everything resolves immediately and cleanly**: the hypothesis is confirmed cheaply and directly.

For the **precursor experiment** (Section 3, performable today):
- **`GOSSIP_SHOW` fires even on immediate re-interaction**: strengthens the case that only an
  acceptance-moment hook (not merely "revisit sooner") can catch this data — supports pursuing the real
  `QUEST_ACCEPTED` change.
- **`QUEST_DETAIL` still fires on immediate re-interaction**: suggests the original M6.5 problem is
  time/session-dependent rather than instantaneous — the `QUEST_ACCEPTED` hook might help less than
  expected; simply revisiting sooner (no code change at all) might be sufficient.

## 7. Manual Steps for the User (Precursor Experiment Only — Section 3)

1. Find any quest not yet accepted, with `ForeverRecorder` enabled.
2. Talk to the giver, note that the quest-offer screen appears (this is `QUEST_DETAIL`).
3. Accept it.
4. Immediately (no delay, no walking away) reopen dialogue with the same NPC.
5. `/fr status`, then `/fr save`.
6. Report the export — checking which checkpoint (`quest_detail` or `GOSSIP_SHOW`) appears for that second
   interaction will directly answer the question in Section 6.

This requires exactly one quest and one extra NPC interaction — no code change, no new milestone, no
CollectionRun.

## 8. Final Decision

**IMPLEMENTATION REQUIRED**

The literal experiment specified (Capture A = a real `QUEST_ACCEPTED`-triggered capture, compared against
Capture B) cannot be performed with the existing recorder as it stands today — `QUEST_ACCEPTED` is never
delivered to the addon's frame at all, confirmed directly from `Dispatcher.lua`, not assumed. A precise,
minimal, fully reversible code change (Section 5) would be required to run that literal comparison. A
narrower, existing-code-only precursor experiment (Section 3) can still be run today, requires no
implementation, and would meaningfully inform whether pursuing that code change is worthwhile — offered
here as a genuinely useful next step, not as a substitute for the literal ask.

## 9. M7.6 Real-World Recorder Findings

A real attempt at the Section 3 precursor experiment was performed in-game. The actual sequence turned out
messier than the clean two-step design (three gossip interactions and an unrelated quest turn-in happened
in between the two relevant captures), so the findings below are split precisely into what the real,
captured data confirms, one important additional finding, and what remains genuinely ambiguous. The
player's own recollection of quest content (specifically an unrelated memory about "Thunderlizard Blood")
was explicitly not used as evidence anywhere in this analysis, per instruction — only captured observation
data and a player-provided screenshot used to *identify* a quest ID were treated as evidence.

### 1. `QUEST_PROGRESS` blind spot — confirmed

The player returned to an NPC (Jorn Skyseer) on an already-accepted quest and was shown a screen with
"Required Items," narrative progress text, and **Continue/Cancel** buttons (a screenshot confirms
this exact UI — no Accept/Decline pair, consistent with a quest-progress check-in screen, not the original
offer). **This interaction produced zero matching observations of any kind** in the exported data — no
`quest_detail`, no `GOSSIP_SHOW`, nothing. This is a real, confirmed blind spot: `QUEST_PROGRESS` (the
likely underlying WoW event for this screen) is not among the 8 events `Dispatcher.lua` registers, and this
real session demonstrates the practical consequence directly, not just the code-level absence already noted
in Section 2.

### 2. Quest 913 = "Cry of the Thunderhawk" — confirmed by exact reward match

A second screenshot of the quest's own log entry ("Cry of the Thunderhawk," objective `0/1 Thunderhawk
Wings") was compared against the real captured data for quest ID `913`:

- Captured objective structure: `{"type": "item", "numRequired": 1, ...}` — one item required, matching
  "0/1 Thunderhawk Wings" exactly.
- Captured choice items: `["Cobalt Buckler", "Wind Rider Staff"]` — an **exact** match to the screenshot's
  shown choice rewards.
- Captured guaranteed item (second capture only): `"Gloves of the Moon"` — an **exact** match to the
  screenshot's shown guaranteed reward.

Three independent matching data points make this identification certain, not merely plausible.

### 3. Post-acceptance title/level lookup failure — an important additional finding

Quest 913 was captured via `quest_detail` **twice**. The player's quest-log screenshot for this same quest
shows **Abandon/Untrack** controls, not Accept/Decline — confirming the quest was genuinely accepted and
sitting in the log by the time of at least the later parts of this session. Despite that:

| | Capture #1 | Capture #2 |
|---|---|---|
| Title | Not found in log | **Still** not found in log |
| Level | Not found in log | **Still** not found in log |
| Objective structure | None captured at all | Present: `0/1` item objective |
| Guaranteed item name | Blank (`""`) | Resolved: `"Gloves of the Moon"` |

**This rules out the simplest version of the original hypothesis.** The problem is not simply "the
quest-detail frame's information disappears the moment a quest is accepted" — objective and reward data
*did* become available/improve between the two captures. But title and level specifically failed to resolve
via the existing log-index scanning method (`C_QuestLog.GetNumQuestLogEntries` + loop + `C_QuestLog.GetInfo`
in `QuestMeta.lua`) even once the quest was confirmed present in the log by other means. This points to a
**separate reliability issue in the log-index scan itself**, distinct from the timing question this
experiment set out to test.

### 4. Fields that improved between captures

Objective structure (none → present) and the guaranteed item's name (blank → resolved) both improved
between the two `quest_detail` captures — consistent with the same "unresolved-at-first-read" pattern this
project has documented since M4, now observed specifically in a post-acceptance context.

### 5. What remains unresolved

**The original `QUEST_ACCEPTED` timing hypothesis is not resolved by this session.** Three separate
`GOSSIP_SHOW` interactions with the same NPC occurred between the two `quest_detail` captures for quest
913, so it cannot be established whether capture #2 represents an *immediate* re-interaction after
acceptance or a later one. This session's real value is the two findings above (§1 and §3), not a clean
answer to the original timing question.

### 6. Implications for a Future Recorder Improvement (Not a Recommendation)

These findings would matter to any future recorder change: an eventual `QUEST_ACCEPTED` hook would still
need to account for the title/level lookup failure documented here, since simply hooking the event would
not by itself guarantee `C_QuestLog.GetInfo` succeeds — the same log-index scan that already fails on a
*confirmed*-accepted quest in this real session. Separately, a `QUEST_PROGRESS` hook is now a distinct,
evidence-backed candidate improvement in its own right, not previously considered in Section 2's analysis.
Neither is recommended for implementation here — both are documented as findings only.

**Conclusion**: M7.6 established that passive harvesting can capture more information during normal
gameplay, but it does not eliminate the need for deliberate interaction. The session also identified two
concrete recorder blind spots: `QUEST_PROGRESS` is not captured, and post-acceptance quest lookup can fail
to resolve title/level even when the quest is confirmed in the quest log. The `QUEST_ACCEPTED` timing
hypothesis remains unresolved and should not be treated as proven.
