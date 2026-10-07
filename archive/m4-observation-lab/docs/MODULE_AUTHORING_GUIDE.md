# Module Authoring Guide

How to add a new observation capability to the lab without creating another addon, and without
touching `core/`.

## The one rule that matters most

**Never call, or design toward calling, a committing quest function** — `GetQuestReward`, `AcceptQuest`,
`CompleteQuest`, `TurnInQuest`, or anything equivalent. This is enforced two ways: by convention (every
module in this lab follows it), and mechanically (`tests/safety_scan.py` scans every `.lua` file for
executable references to these names and fails — not warns — if one is found). Run it before you
consider a new module finished:

```
python3 tests/safety_scan.py addon/ForeverObservationLab
```

Mentioning these names in a comment or a chat string (to explain *why* something is forbidden) is fine
— the scanner properly strips comments and string literals before scanning, so documentation doesn't
trip it. An actual reference — a call, or assigning the function to a variable — will.

## Steps to add a module

1. **Decide proven or experimental.** If real Forever data has already confirmed the field works
   (matching a "Verified" line in `M4_PLAN.md` or a follow-up's findings), it's `proven`. Otherwise —
   including "the API exists and I can call it, but no real reward data has confirmed it does anything
   useful yet" — it's `experimental`. This decision is about the module's own maturity, not about
   whether any single call happens to succeed.

2. **Create the file** under `modules/proven/` or `modules/experimental/` as appropriate.

3. **Register it**, once, at file load time:

```lua
ForeverLab = ForeverLab or {}

ForeverLab.Registry:Register({
    name = "YourModuleName",              -- must be unique
    status = "proven",                     -- or "experimental"
    checkpoints = {"quest_complete_immediate", "quest_complete_delayed"},
    -- events = {"SOME_RAW_EVENT"},        -- optional, only if you need a raw game event too
    capture = function(ctx)
        -- ctx.quest_id, ctx.npc_unit, ctx.target_unit, ctx.raw_event_args
        -- are available depending on which checkpoint fired. Return a
        -- plain table -- the Dispatcher wraps it with the shared envelope
        -- (module_name, module_status, checkpoint, ok, recorded_at)
        -- automatically. You do not need to add those fields yourself.
        return { ok = true, api_source = "SomeRealAPIName", value = 42 }
    end,
})
```

4. **Always call real APIs through `ForeverLab.SafeCall`, never `pcall` directly, and never the old
   `{pcall(...)} + unpack(...)` pattern.**

```lua
local ok, err, values = ForeverLab.SafeCall(SomeAPI, 6, arg1, arg2)
-- values[1] .. values[6] are always correct, even if SomeAPI returns
-- nils in the middle of a longer list followed by real values -- the
-- exact bug class found during the M4 reputation follow-up.
```

Never write `local ok, v1, v2 = pcall(...)` or build a results table and `unpack()` it yourself. That
is precisely what silently dropped real return values (`isHeader`/`hasRep`) behind a run of `nil`s when
testing `GetFactionInfoByID`. `SafeCall` is the one place that fix lives; every module should lean on it,
not reimplement it.

5. **Record raw positional values, not assumed field names**, for any API whose exact Forever signature
   hasn't been independently confirmed — following the pattern in `RewardsReputation.lua` (`r1`, `r2`, ...)
   rather than guessing `factionId`/`amount` are really at those positions until real data confirms it.

6. **Never store a raw GUID.** If your module needs a creature ID, call
   `ForeverLab.GuidUtil.CreatureIDFromUnit(unit)` — it returns the parsed ID only, never the GUID string
   itself. Do not call `UnitGUID` directly and keep the result.

7. **Don't invent an API name.** If you're testing a reward type with no verified candidate function yet
   (the situation `RewardsCurrency` is in), register the module as a documented placeholder that returns
   `ok = false` with a clear reason, the same way `RewardsCurrency.lua` and `FactionNameResolution.lua`
   do. Do not guess a plausible-sounding function name and call it — that's exactly what this whole
   project has consistently avoided, from the original harvest contract's evidence tags onward.

8. **Add the file to `ForeverObservationLab.toc`**, in the same relative section (`modules/proven/` or
   `modules/experimental/`) as the other files there.

9. **Experimental modules never run by default.** A player has to explicitly type
   `/flab enable YourModuleName` (case-insensitive) for a session. This is enforced by `Registry:IsActive`,
   not by convention — you don't need to add any enable/disable logic yourself, just register with
   `status = "experimental"` and it's automatically gated.

## What NOT to do

- Don't add a new SavedVariables global, a new slash command prefix, or a new addon folder for a new
  reward type. That's exactly the pattern this lab exists to replace — every prior M4 probe required a
  full fork and a rename exercise for one new capability.
- Don't call `Describe()` (the bounded chat/status stringifier) to build stored data. It caps table
  summaries at a handful of arbitrary keys, which is exactly what silently dropped the `title` field
  during the very first M4 pre-experiment. `Describe()` is for `/flab`-command chat output only.
- Don't assume a successful, error-free call makes a field `[V]`. Only real, verified data — a quest
  independently known to have the reward type, checked against what actually happened in-game — earns
  that. A module running without a Lua error just means the module ran; it says nothing about whether
  the underlying game data was meaningful.

## Updating the test suite

After adding a module, add it to the `EXPECTED_PROVEN`/`EXPECTED_EXPERIMENTAL` lists in
`ForeverObservationLab.lua` (the load-time self-check) and to `tests/run_lab_tests.lua`'s registration
count assertion, so a missing or mis-registered module fails loudly rather than being silently absent.
