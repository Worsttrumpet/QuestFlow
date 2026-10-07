# 0.8.0: a skipped quest never comes back as NOW

**Real-client bug (0.7.9):** the player skipped `Q:98298` (Arugal's Folly). The report listed it under the skipped keys and counted "skipped by you", yet the planner still produced `NOW Q:98298:ACCEPT [BEST_SEQUENCE,PLAYER_ADDED]` and a route that travelled to the giver.

## Cause (traced through the whole lifecycle)
1. **Generation, `Providers/Quest.lua` `Q.Generate`:** the quest had been ADDED by the player (so it is "pinned"). The `pinned` branch was tested BEFORE `skipped["Q:" .. id]`, so an added quest never reached the skip check and was emitted as a pinned ACCEPT.
2. **Why the skip did not remove the add:** `Preferences.Skip` only set the skip flag. (`Preferences.Add` clears a skip, so adding after skipping worked, but skipping after adding did not undo the add.) The Skip button on NOW calls exactly this, so skipping a NOW that was PLAYER_ADDED did nothing.
3. **Two more layers also exempted pinned actions from skipping:** `Engine.Candidates` (`... and not a.pinned`) and `Planner.usable` (`... and not a.pinned`). So even with a skip flag, a pinned action passed the funnel and the sequencer.
4. **Downstream:** the planner's stop building gives pinned stops priority (`pinnedFirst`, the `pinned` value, the PLAYER_ADDED reason), so once the action existed it won NOW and pulled a TRAVEL step in front of it. Nothing downstream was wrong; the action should never have existed.

## Fix (filtering path only; no planner redesign)
* `Q.Generate` checks the skip BEFORE the pinned branch.
* `Engine.Candidates` and `Planner.usable` no longer exempt pinned actions from a skip (three independent layers now agree: a skipped action is never generated, never a candidate, never sequenced).
* `Preferences.Skip` removes the quest from "added": the player's latest explicit choice wins, the mirror of `Preferences.Add` clearing a skip.
* `Preferences.NormalizeOverrides` (run at login) resolves a save that already holds both flags (written by 0.7.9): the skip wins and the quest leaves "added".
* The explicit ways back are unchanged: `/codex unskip`, or `/codex add <quest>` (which clears the skip).

## Tests (`tests/skip_tests.lua`)
Skip (via the Skip button path `State.SkipCurrent`) a quest that is PLAYER_ADDED and NOW, recompute, and assert it is nowhere in `plan.now / alsoDo / thenAction / next / sequence / upcoming / nearby / inProgress / reminders / turnIns / objectives / stops` or in the window's card (including TRAVEL legs); a save holding both flags; unskip and add as the ways back; strategies do not let it in; an in-log quest with a QT skip. Verified to FAIL on the 0.7.9 code (NOW stays `Q:98298:ACCEPT`) and pass after the fix.

**Needs the real client:** skip the added NOW quest and confirm it leaves the tracker and the route.
