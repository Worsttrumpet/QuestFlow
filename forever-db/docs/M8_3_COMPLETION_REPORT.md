# M8.3 Completion Report: First Hand-Authored Route Prototype

**Status: COMPLETE.** ForeverQuestGuide now has a second, static route-view tab built on one hand-authored
test route, layered on top of M8.1's quest browser without changing its data contract or behavior. All
route-authored information is explicitly tagged as such; no ATT data, no invented coordinate, and no
inferred ordering was introduced anywhere.

## Files created

```
m8-guide-addon/routes/
  route_schema.py                  -- Route/RouteStep/Destination shapes + validator (docs/M8_2_SCOPE.md SS2-4,12)
  thunder_lizards_test_route.json  -- the one hand-authored test route (source of truth, human-edited)
  generate_route_data.py           -- route JSON(s) -> RouteData.lua, validated against M6 guide-ready quests
  test_generate_route_data.py      -- 31 pytest cases (schema, data integrity, determinism, content)
m8-guide-addon/addon/ForeverQuestGuide/
  RouteData.lua                    -- GENERATED, not hand-written
forever-db/docs/
  M8_3_COMPLETION_REPORT.md        -- this document
```

## Files modified

| File | Change |
|---|---|
| `m8-guide-addon/addon/ForeverQuestGuide/ForeverQuestGuide.toc` | Added `RouteData.lua` to the file list (loaded after `Data.lua`, before `Core.lua`/`UI.lua`); bumped `## Version` to `m8-guide-addon-0.2`; updated `## Notes` to describe the new static route view and restate that no auto-progression, arrow, or map pins exist. |
| `m8-guide-addon/addon/ForeverQuestGuide/Core.lua` | `VERSION` bumped to match the `.toc`; the login chat message now also reports the hand-authored route count and restates "no auto-progression, no directional arrow, no map pins." No other logic changed. |
| `m8-guide-addon/addon/ForeverQuestGuide/UI.lua` | Rewritten (269 → 569 lines) to add: a QUESTS/ROUTE tab bar, a route-view panel, step-type glyph lookup, and Previous/Next navigation. **Every M8.1 function, variable, and code path for the quest browser is preserved unchanged** — the diff is additive (new tab-switching, new route-rendering functions, and the two new panel-visibility calls at the end of `build()`); nothing inside `renderDetail`, `refreshList`, `selectQuest`, or the quest-list construction was altered. |
| `m8-guide-addon/addon_selftest/run_ui_selftest.lua` | Extended (not replaced) with new checks for route-data export, tab switching, forward/backward navigation through all 5 steps, and both boundary no-ops. Every original M8.1 check still runs and still passes. |

**Confirmed unchanged, not just unedited:** `Data.lua` on disk is still byte-identical to a fresh run of
`generate_addon_data.generate()` (checked directly, not inferred from file timestamps — this environment's
file-modification times are not reliable evidence of change, see "A methodology note" below).
`addon_selftest/stub_ui_env.lua` was never opened this session.

## Route schema

Implements `docs/M8_2_SCOPE.md` §2–4 and §12 directly (see `route_schema.py`'s own docstring for the
full reasoning). Summary:

- **`Route`**: `id`, `title`, `provenance` (must be `"route-authored"`), `first_step`, `steps` (a dict keyed
  by step ID — never an array, so ordering can never be "whatever position it sits at").
- **`RouteStep`**: `id`, `provenance` (`"route-authored"`), `kind` (one of `ACCEPT`, `TRAVEL`, `OBJECTIVE`,
  `TURN_IN`, `TALK`), `quest_id` (optional, must be a current guide-ready quest ID), `objective_index`
  (optional, 1-based, only for `OBJECTIVE` steps, range-checked against that quest's actual objectives
  count), `npc` (optional, `{name, npc_id}`), `destination` (optional, see below), `display_text` (a
  route-authored instruction), `next_step_id` (explicit link; `nil` marks the route's end).
- **`Destination`**: `nil`, or `{kind: OBSERVED_PLAYER_POSITION, ui_map_id, x, y}`, or
  `{kind: ROUTE_AUTHORED, text}`, or `{kind: SOURCE_DERIVED_ATT, ui_map_id, x, y}` — the schema permits the
  last for future use, but `generate_route_data.py` **refuses to generate a route containing one**
  (`_forbid_source_derived`, tested by `test_generator_forbids_source_derived_att_destination`).
- **Ordering** is established only by walking `next_step_id` from `first_step`; `validate_route` rejects a
  cycle, a dangling reference, or any step unreachable from `first_step`. It never sorts by `quest_id`, step
  ID, or JSON key order — proven directly by `test_route_ordering_is_explicit_not_derived_from_quest_id`,
  which reverses the JSON file's own key order and asserts the validated order is unaffected.
- **What a step never carries**: a quest's own title, giver name, or objective text. Those are looked up
  live from `Data.lua`'s `ns.QuestData` at render time (`docs/M8_2_SCOPE.md` §14's "never embedding a copy
  of quest content"), enforced by the schema simply having no field for them, and directly checked by
  `test_generated_lua_contains_no_quest_content_duplication`.

## Test route used

**`thunder-lizards-test-route`**, 5 steps, using only quests 907 and 959 (both currently guide-ready):

| Step | Kind | Quest | Destination |
|---|---|---|---|
| s1 | ACCEPT | 907 (Enraged Thunder Lizards) | none — no offer-screen position was ever captured for 907 |
| s2 | TRAVEL | 907 | none — no objective-area coordinate exists anywhere in this project |
| s3 | OBJECTIVE | 907, objective 1 | none |
| s4 | TURN_IN | 907 | **OBSERVED_PLAYER_POSITION**, map 1413 (0.4487, 0.5909) — M6's own `quest_complete_delayed` capture for this exact quest |
| s5 | ACCEPT | 959 (Trouble at the Docks) | none — same gap as 907; 959 was also only ever observed at its turn-in screen |

This exercises all four `kind`s the completion criteria and the underlying glyph vocabulary need
(`ACCEPT`/`TURN_IN` share the star glyph; `OBJECTIVE` gets crossed swords; `TRAVEL` gets the pin), and it
demonstrates a cross-quest transition (s4 → s5) that is **entirely route-authored** — nothing in M6 or ATT
suggests quest 959 follows 907; the route's own `display_text` for s5 says so explicitly, in-game, so a
player reading it is told the same thing this report tells you.

**Why the route mostly has no destinations:** both quests were only ever observed at their turn-in screen
(`docs/M7_10_SCOPE.md` §3's documented "return/turn-in only" pattern — 11 of 96 guide-ready quests share
this gap). This is not a bug in the route; it is an honest reflection of what M6 actually captured. Rather
than fabricate an offer-position or an objective-area coordinate to make the route look more complete, every
step without real position evidence simply has `destination: null`, and the UI displays "not captured" for
it. This is the direct, concrete case the "Critical Evidence Rule" in the M8.3 request was written to
prevent, encountered while authoring the very first test route.

## Route-authored fields

Both the `Route` and every `RouteStep` in the generated data carry `provenance = "route-authored"` explicitly
(present in the generated Lua file 6 times — 1 route + 5 steps — checked by
`test_generated_lua_marks_every_route_and_step_as_route_authored`). The one `Destination` that exists is
separately tagged `OBSERVED_PLAYER_POSITION`, not `route-authored`, because it is a verbatim M6 value, not an
authored guess — the destination's own `kind` is the thing that says where a value came from, independent of
the step's own provenance. No fake observation record was created; no route-authored information was written
into `m6_coverage.json`, `m6_guide_dataset.json`, or any M6/M7 artifact.

## Tests

**Python (`m8-guide-addon/routes/test_generate_route_data.py`): 31 passed, 0 failed.** Covers: schema shape
(id/title/steps/provenance), unique step IDs, valid `kind`s, every referenced quest ID is guide-ready (with a
direct negative test using a fabricated non-existent ID standing in for "ATT-only"), no duplicate step IDs,
explicit-not-derived ordering (the JSON-key-shuffle test above), cycle/orphan/dangling-reference rejection,
objective-index range checking, NPC-drift detection against M6's own giver record, the forbidden
`SOURCE_DERIVED_ATT` generator-level guard, determinism across repeated runs, `luac5.1`-parseable output, and
that the real authored route uses only quests 907/959, exercises all required marker kinds, and carries
exactly one correctly-matched observed position.

**M8.1's own suite, re-run unmodified: 117/117 still passing** — confirms the quest-browser data contract
was not touched by this milestone.

**Lua execute-level self-test (`addon_selftest/run_ui_selftest.lua`), extended: all checks pass.** Beyond
M8.1's original load/open/select/close/reopen checks (still present and still passing), it now also: loads
`RouteData.lua` and checks its shape; switches to the ROUTE tab and confirms the correct panels
show/hide; clicks Next through all 5 steps, checking the index advances each time; confirms an extra Next at
the final step is a no-op; clicks Previous back through all 5 steps; confirms an extra Previous at the first
step is a no-op; switches back to QUESTS and confirms the earlier quest selection survived the round trip
undisturbed. (Rendered *text* correctness is checked in Python against the same route data, not in this
stub, since the stub's FontString mock cannot read back what `SetText()` was called with — noted directly in
the self-test's own comments.)

**M6 regression, re-run unmodified: 62/62 still passing.**

## Determinism

Confirmed exactly as M8.1's generator was: `generate_route_data.py`'s own `__main__` block re-renders and
asserts byte-identical output before writing, and `test_generate_is_deterministic_across_runs` independently
calls `generate()` twice and compares the Lua text, the parsed route list, and both hashes. No timestamp is
embedded anywhere; the file's only provenance stamps are the M6 dataset's SHA-256
(`13999e906b802d73303bae5add24f75300602d9a0cd50f57fe80e86711173b93`) and the route JSON's own SHA-256
(`f4123e0f6067a0345e5cd14ae57bb95f88d34dcd3498ae1c4b2489e8e8f693c7`), both printed in `RouteData.lua`'s
header comment.

## Protected-file verification

A pre-implementation snapshot of 119 protected files (M6 datasets/registry/scripts, the recorder, M4/ATT
code, schemas, config, and every M7.x/M8.0/M8.1/M8.2 document) was taken before this milestone began. Diffed
against the same snapshot afterward: **0 changed, 0 removed, 0 added.** `CollectionRun` registry: still 11
runs. `sources.toml` and `LICENSING.md`: byte-identical. `docs/M8_0_SCOPE.md`, `docs/M8_1_COMPLETION_REPORT.md`,
`docs/M8_1_REAL_CLIENT_VALIDATION.md`, and `docs/M8_2_SCOPE.md`: all byte-identical (read, not modified).

**A methodology note:** this environment's file-modification timestamps do not reliably reflect edits (a
`.toc` edit made through this session's tooling did not update its own reported mtime, discovered while
preparing this section). File-level "what changed" claims in this report are therefore based on the
session's own action record and, where it mattered, direct byte-content comparison — never on timestamps
alone. The protected-file check above is unaffected, since it hashes file contents, not modification times.

## Real-client test procedure

1. Copy the full, updated `ForeverQuestGuide` folder (now four files: `.toc`, `Data.lua`, `RouteData.lua`,
   `Core.lua`, `UI.lua` — five, counting the `.toc`) into WoW Forever's `Interface/AddOns/` directory,
   replacing the M8.1 version entirely.
2. Log in. Confirm the load message now also reports "1 hand-authored route(s)" and the same
   "no auto-progression, no directional arrow, no map pins" line.
3. `/fguide`. Confirm the QUESTS tab still opens exactly as before (M8.1's already-validated behavior:
   scroll, select, detail panel, "Show on Map" placeholder) — this is the "must not break M8.1" check.
4. Click the **ROUTE** tab. Confirm "Barrens Level 18 (M8.3 test route)" appears with "STEP 1 / 5".
5. Read step 1: should show the `[*]`/star-style glyph, "ACCEPT", the quest title "Enraged Thunder Lizards"
   looked up live, and the giver "Jorn Skyseer".
6. Click **NEXT ->** four times, confirming the step counter advances 2/5, 3/5, 4/5, 5/5, and that step 3
   shows the live objective text "0/3 Thunder Lizard Blood" and step 4 shows the observed destination line
   ("map 1413 (0.449, 0.591)").
7. **Check the step-type glyphs specifically**: do the star/crossed-swords/pin characters render as
   pictures, as different-but-legible characters, or as blank boxes? This is the one piece of this milestone
   with no confirmed answer yet (see "Known limitations"). Report exactly what you see.
8. At step 5/5, confirm the Next button reads "Route Complete" and clicking it again does nothing (no error,
   no advance past 5/5).
9. Click **PREVIOUS <-** back to step 1/5, confirming each step's content matches what you saw going
   forward, and that clicking Previous again at step 1/5 does nothing.
10. Switch back to **QUESTS**, and confirm whatever quest you had selected before switching to ROUTE is
    still selected and displayed correctly.
11. `/reload`. Run `/fguide`, click ROUTE, and confirm the route reloads at step 1/5 correctly (routes are
    static data, same as quests — no state is expected to persist across reload, since the addon still has
    no SavedVariables).

No quest acceptance, travel, or combat is required anywhere in this test.

## Known limitations

- **The step-type glyphs (★/⚔/📍) have not been confirmed to render as pictures on Forever.** This is new
  since M8.1, which only validated plain ASCII text through `GameFontNormal`. `USE_EMOJI_GLYPHS` in `UI.lua`
  is a single boolean; flipping it to `false` swaps to a plain bracket-text vocabulary (`[*]`, `[X]`, `[>]`)
  with no other code change needed. This was a deliberate, disclosed choice (see `UI.lua`'s own header
  comment) rather than something resolved in advance, since this project has no way to test font glyph
  coverage without a real client.
- **No quest-state tracking, no automatic advancement.** The player controls every step transition manually;
  the addon never reads `C_QuestLog` for the route view, exactly as scoped.
- **No directional arrow, no distance, no map/minimap pin.** Unchanged from M8.0/M8.2's findings — none of
  the underlying API questions (cross-map math, a confirmed map-pin API) were investigated further here.
- **The test route only demonstrates the "no destination captured" and "one observed destination" cases**,
  because that is genuinely what M6 has for these two quests. It does not exercise a `ROUTE_AUTHORED`-kind
  text destination (the schema supports one; the JSON author chose not to invent a scenario for it rather
  than manufacture a demonstration that wasn't needed by real data — one is available in the schema for the
  next route that actually needs it).
- **Only one route exists.** `docs/M8_2_SCOPE.md` §11 already established the base schema supports several
  without a redesign (a route is just another entry in `ns.Routes`); this milestone did not need to prove
  that further by authoring a second one.

## Next recommended milestone

Per `docs/M8_2_SCOPE.md` §15, the pieces still deliberately deferred are semi-automatic progression (blocked
on `QUEST_ACCEPTED` never having been hooked), the directional arrow (blocked on cross-map distance math and
a real-world-yards conversion, neither confirmed to exist), and any map/minimap marker (blocked on the
map-pin API question, this project's single largest standing unknown). A sensible M8.4 would pick exactly one
of these three and investigate it on its own terms — most plausibly `QUEST_ACCEPTED`, since it is the
smallest, most self-contained real-client experiment (hook the event, accept one already-known quest, see
whether and how it fires) and would directly unblock the progression-model decision `docs/M8_2_SCOPE.md` §9
left open between semi-automatic and manual.

```text
M8.3 STATUS: COMPLETE
```
