# M4 Observation Lab — SavedVariables Persistence Finding

Discovered during the post-audit real-client smoke test of the M4 Observation Lab (`ForeverObservationLab`).
Documentation only — no implementation change accompanies this finding. See "Scope boundary" at the end.

## Build

`1.60.1.69977`, interface `16001` (same build as every prior M4 session).

## `[V]` Observed

**Explicit `ReloadUI()` persistence — reliable, twice confirmed:**
`/flab save` calls Blizzard's `ReloadUI()` directly (`core/Export.lua`). Across this smoke test, an
observation count survived this path intact on every occasion it was tested: 8→8 across one save/reload
cycle during the earlier audit-fix verification, and 10→10 in the dedicated persistence test performed
here.

**Logout/character-select persistence — failed, twice reproduced:**
In two repeated tests on Forever beta build `69977`, observations persisted across `/reload`/`ReloadUI()`
but were absent from the SavedVariables file after logging out to the character-selection screen and
returning to the same character (confirmed to be the same character, same account, same file path both
times — not a character or account-switch artifact). Both times, a SavedVariables file that held 10
observations immediately before logout contained 0 immediately after logging back in.

**Repetition count: 2.** Same procedure, same character, same result both times.

## `[V]` What the addon source rules out

- Only two code paths write to `.observations` anywhere in the shipped lab: the default-initialization
  constructor in `core/Bootstrap.lua` (`ForeverObservationLabDB = ForeverObservationLabDB or {...}`,
  which only takes effect when the global is `nil`) and the explicit `/flab clear` command in
  `core/Slash.lua`. `/flab clear` was not run during either test.
- `Bootstrap.lua`'s initialization line is byte-identical regardless of how the addon was reached
  (`/reload` vs. logout/character-select) — there is no branch, condition, or code path in this addon
  that behaves differently based on which transition occurred.
- The `## SavedVariables: ForeverObservationLabDB` declaration is account-wide, not
  `SavedVariablesPerCharacter` — a character switch cannot explain this, and was independently confirmed
  not to have occurred (same character, "testing routes", both times).
- Observation records carry their own `session_id`, stamped at creation time (`core/Dispatcher.lua`), not
  read live from a shared mutable field — the disappearance is not explained by a new session ID
  overwriting or relabeling old records; the records themselves were absent from the file, not merely
  differently tagged.

## `[?]` Interpretation — a hypothesis, not confirmed

This is consistent with a Forever-client-specific difference or failure in the implicit logout
SavedVariables persistence path. The exact client-side cause was not directly instrumented and therefore
remains unconfirmed. Two save mechanisms are involved — `ReloadUI()`, an explicit, well-defined Blizzard
function this addon calls directly, versus the client's own implicit end-of-session save triggered
internally on logout, which this addon has no visibility into. The asymmetry in results (one path
reliable, twice; the other failing, twice) is real and reproduced, but its root cause sits inside the
Forever client itself, not in anything inspectable from this addon's own source.

## What remains unconfirmed

- Whether this reproduces on a different character, account, or machine.
- Whether the implicit logout save fails outright, saves a stale/incomplete snapshot, or something else
  entirely — only the *end state* (0 observations after) was observed, not the save operation itself.
- Whether a full client exit/relaunch (as opposed to logout-to-character-select) behaves the same way,
  differently, or was in fact the original, still-unconfirmed cause of the very first instance of this
  pattern (before this two-repetition test isolated logout/character-select specifically).
- Whether this is specific to this SavedVariables declaration shape, or a broader Forever-beta
  characteristic affecting other addons' account-wide SavedVariables similarly.

## Practical current mitigation

**Always run `/flab save` before logging out**, rather than relying on the client's own logout-save
behavior, for the remainder of M4 client-observation work. This has been reliable on every test to date
and fully sidesteps the issue without requiring any code change.

## Scope note

This is a testing/harvest-observation limitation encountered while collecting evidence with a disposable
research probe. It is not, at this time, a production implementation requirement — no conclusion is drawn
here about what a future real recorder addon would need to do about logout persistence; that question is
explicitly out of scope for this finding and is not addressed by it.

## Scope boundary (what this finding does NOT do)

Per explicit instruction, no implementation change accompanies this finding. Not done as part of this
documentation: no `PLAYER_LOGOUT` handling added, no automatic `ReloadUI()` call added, no autosave
behavior, no network/upload behavior, no schema change, no provenance model change, no harvest contract
change, no WDB decoding investigation, no new API experiment. The Observation Lab's addon source is
unchanged from its post-audit-fix state.
