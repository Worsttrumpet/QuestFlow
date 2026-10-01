# M8.6-A Completion Report: Route & Quest QoL/UI Pass

**Status: COMPLETE, pending real-client confirmation.** All eleven requested features are implemented, pass
a 184-check Lua self-test with zero failures, and preserve every existing M8.1/M8.3/M8.5 behavior. Nothing
in this milestone has been run on the real client yet — see "Real-client test procedure" for what to check,
and "Unverified behavior" for exactly what the automated checks cannot prove (most importantly, the guessed
vertical spacing for the substantially taller ROUTE tab).

## Files created

```
forever-db/docs/
  M8_6_A_COMPLETION_REPORT.md   -- this document
```

No other new files. This milestone extended existing files rather than adding new modules.

## Files modified

| File | Change |
|---|---|
| `m8-guide-addon/routes/route_schema.py` | Added two new optional, route-authored step fields: `why` (non-empty string or absent) and `required` (boolean or absent). Both validated; both still absent means "no claim," never defaulted. |
| `m8-guide-addon/routes/generate_route_data.py` | Emits `why`/`required` into the generated Lua exactly as authored (`nil` when omitted, never guessed). |
| `m8-guide-addon/routes/thunder_lizards_test_route.json` | Updated the existing hand-authored test route to actually use both new fields: all 5 steps now carry `required` (4 `true`, 1 `false` — step 5, the route-author's optional second-quest addition), and 2 steps carry a `why` (step 4's matches the request's own example almost verbatim; step 5 explains the optional transition). |
| `m8-guide-addon/routes/test_generate_route_data.py` | Added 5 new tests for the two fields (empty-`why` rejection, missing-`why`/`required` acceptance, non-boolean-`required` rejection, exact round-tripping into the generated Lua). One existing test (`test_generated_lua_contains_no_quest_content_duplication`) was corrected — not loosened — because the new `why` text legitimately mentions a quest by name in prose; see "A test that needed fixing" below. |
| `m8-guide-addon/addon/ForeverQuestGuide/Preferences.lua` | Added a third preference, `uiMode` (`"detailed"`/`"compact"`, defaults to `"detailed"` so a fresh install's layout is unchanged from M8.5), with the same per-key-default/get/set pattern as `theme`. |
| `m8-guide-addon/addon/ForeverQuestGuide/Core.lua` | Added `/fguide mode compact\|detailed` as a second control path, mirroring `/fguide theme` exactly (an unrecognized mode name reports an error via chat and changes nothing, same as an unrecognized theme name). Login message now also reports the view mode. |
| `m8-guide-addon/addon/ForeverQuestGuide/UI.lua` | The bulk of this milestone — see "What was built" below. Grew from roughly 22 KB to 42 KB. |
| `m8-guide-addon/addon_selftest/stub_ui_env.lua` | Added `SetText`/`GetText` tracking to the generic stub object (previously write-only/absent), needed to test the search box's real `OnTextChanged` handler, which calls `self:GetText()`. |
| `m8-guide-addon/addon_selftest/run_ui_selftest.lua` | Extended with 5 new sections (search, route progress/badge/why, preview, compact/detailed mode, theme-on-new-controls) — every existing M8.1/M8.3/M8.5 check preserved verbatim and still passing. |

**Confirmed unchanged, not just unedited** (checked by content, not file-modification time — see M8.3's own
completion report for why the latter isn't trustworthy in this environment): `Data.lua` is still
byte-identical to a fresh run of its own generator (untouched by this milestone). `RouteData.lua` is
byte-identical to a fresh run of the now-updated route generator — i.e. the new fields flow through
correctly and nothing else about it drifted. `m6-dataset-baseline/`, the recorder, and ATT ingestion were not
opened this session.

## What was built

### 1. Quest search/filter
A labeled `EditBox` above the quest list, filtering `ns.QuestOrder` locally by substring match against
title OR giver name, case-insensitive, using `string.find(..., 1, true)` (plain-text mode, never a Lua
pattern) so a quest title or giver name containing a pattern-magic character can never break the match. No
new data source; reads only the existing `Data.lua`. Clearing the field restores the complete 96-quest list.
Fuzzy matching and ranking were deliberately not implemented, per the request.

### 2. Route progress
`"STEP 3 OF 5"` (reworded from M8.3's `"STEP 3 / 5"`) plus a new visual progress bar: a row of small
textures, one per step in the CURRENT route's own `step_order`, filled up through the current step index.
The bar's segment count comes only from `#order` (the authored chain's own length) — never from a quest ID,
a coordinate, or anything else.

### 3. Next-step preview
Shows up to **3** upcoming steps (see "A judgment call: 3, not 3–5" below), each rendering its kind glyph,
kind name, and the same `formatStepBody()` summary the current step itself uses. Follows the `next_step_id`
chain exclusively (via the route's precomputed `step_order`, itself only ever built by walking that chain —
see `route_schema.py`). Never shows a past step. Truncates correctly to fewer entries — down to *zero* —
when fewer than 3 future steps remain; verified at the most extreme case (0 remaining, at the final step).

### 4. "Back to current step"
**Not implemented, per the request's own permission**: the preview is non-clickable (display-only), which
the request explicitly said removes the need for this control. Clicking a preview entry does nothing; it
cannot select, jump to, or alter the current step or the authored route order in any way.

### 5. Sticky current step
Implemented via a genuinely dynamic layout, not fixed anchors with hidden gaps: `chainBelow()`, a new small
helper, re-anchors each line below whichever line above it actually ended up visible, every render. This is
what lets compact mode actually close up the space a hidden line would otherwise leave — WoW does not reflow
layouts on its own. The fixed, always-visible header block (title, step counter, progress bar, kind+badge,
quest title) stays pinned above everything else regardless of mode or content.

### 6. "Why this step?"
A new, optional, `route-authored` step field (see `route_schema.py`'s own docstring for exactly how it's
categorized). Shown only when authored; the section is omitted entirely — not shown blank — otherwise. Never
auto-generated from `quest_id`, a coordinate, proximity, or an ATT relationship; the schema has no mechanism
to derive it, so this isn't a policy this milestone merely followed but one the data shape itself enforces.

### 7. Required/optional
A new, optional, boolean `route-authored` step field. Displayed as a plain "REQUIRED"/"OPTIONAL" badge next
to the step-kind line, or left blank if the author never set it — omission is never treated as "required,"
which would be asserting a judgment the author didn't make.

### 8. Compact/detailed mode
A third preference (`Preferences.lua`), switched via a small in-window button (mirroring the M8.5 theme
toggle exactly) and `/fguide mode compact|detailed`. Detailed mode is visually identical to M8.3/M8.5's
existing layout plus the new progress bar/badge (both always shown, both modes). Compact mode hides the NPC
line, the step's own `display_text`, the entire "why" section, and the entire preview — while still showing
the priority items the request named: step number, step type, main instruction, quest title, objective (via
the main instruction for `OBJECTIVE` steps), and destination.

### 9. Route preview collapse
A small `[-]`/`[+]` toggle button labeled "UP NEXT" (see "ASCII substitution" below for why not `▼`/`▲`).
Collapsing hides all preview lines without affecting `currentStepIndex` or anything else; expanding restores
them. Independent of compact mode, which hides the preview section outright regardless of this toggle's
state.

### 10. Theme system
Every new visual element — the search box (background **and** its own text color, via a new
`themedEditBoxes` registry), the progress bar segments (colored via the theme's existing
`primaryButtonBG`/`tabInactiveBG` entries, no new palette values needed), and the two new toggle buttons —
goes through the same `applyTheme()` pass every existing element already used. No new hardcoded colors were
introduced anywhere in this milestone.

### 11. ASCII glyphs only
Unchanged — `[*]`/`[X]`/`[>]` are the only step-kind glyphs used anywhere, including in the new preview
entries (which reuse the same `kindGlyph()` function the current-step display already used).

## Judgment calls made, stated explicitly

- **Preview count: 3, not 3–5.** The request's own text allowed a range; its own illustrative example
  showed only 2 future steps (UP NEXT, THEN). 3 was chosen as a middle ground that stays on the compact
  side, consistent with the milestone's overall "minimal clutter" framing. This is a design choice, not a
  requirement violated.
- **ASCII substitution for the collapse indicator.** The request's own example used `▼`/`▲`, but Rule 11
  says "ASCII step glyphs only... do not reintroduce emoji glyphs," and M8.3 already found Forever's font
  renders non-ASCII Unicode symbols as blank boxes. `▼`/`▲` are not technically emoji, but nothing
  establishes they'd render any better, and Rule 11's own instruction is treated here as authoritative over
  the illustrative example's specific characters. `[-]`/`[+]` are used instead — plain ASCII, consistent
  with the already-proven-safe vocabulary.
- **A test that needed fixing, not loosening.** `test_generated_lua_contains_no_quest_content_duplication`
  originally banned a quest's M6 title from appearing anywhere in the generated route file. The new `why`
  text for step 4 legitimately contains "Enraged Thunder Lizards" in prose — an author referencing a quest
  by name is not the same failure mode the test was written to catch (a *structural* field silently carrying
  a stale copy of observed data). The test's own docstring had already anticipated this distinction
  ("outside of what the author explicitly wrote in a step's own npc/display_text fields") without actually
  implementing it; this milestone's fix makes the check precise — scanning only structural fields (`id`,
  `kind`, `quest_id`, `npc`, `destination`, `next_step_id`), explicitly excluding `display_text` and `why` —
  rather than removing the check.
- **Window grows substantially taller for the ROUTE tab.** `ROUTE_PANEL_HEIGHT` (480px, up from the
  204px this route panel used in M8.3) is a generous, best-effort estimate based on counting the new lines
  of content, not a measured real-client value. The QUESTS tab does not grow to match (it keeps its M8.1
  size), so there is empty space below the quest list/detail panel now that the shared window frame is
  taller — a disclosed trade-off, not a bug, chosen over building a per-tab dynamic resize.
- **Two real bugs caught and fixed during this milestone's own development**, both by the Lua self-test
  before this report was written: (1) the new preview-line construction code referenced a `build()`-local
  variable (`routePanel`) from a different top-level function, which would have thrown a Lua error the very
  first time a route with fewer than 3 remaining steps needed to create additional preview-line widgets —
  fixed to use `frame.routePanel`, the same pattern `renderDetail()` already established for exactly this
  situation; (2) the self-test's own stub had no `SetText`/`GetText` tracking at all, which is why the first
  self-test run against the real search-box handler failed loudly rather than silently passing a weaker
  check — fixed in `stub_ui_env.lua` before any test was allowed to rely on it.

## Automated verification

**Lua self-test (`addon_selftest/run_ui_selftest.lua`): 184 checks, 0 failures**, up from M8.5's 125. Beyond
every existing check (all still passing, confirming M8.1/M8.3/M8.5 behavior is intact), the new sections
cover: search matching (title and giver name, case-sensitivity, empty-search restore, zero-match case),
exercised through the widget's own real `OnTextChanged` handler, not just the underlying filter function;
route progress segment count staying constant across navigation; the required/optional badge and why-section
visibility tracking the actual authored values on specific real steps (not synthetic fixtures); preview
truncation at the most extreme case (zero future steps, at the final step) and the cap case (3 shown when 4
are available); the preview collapse toggle's real click handler; compact-mode hiding exactly the lines the
request named as secondary while keeping every priority item visible, exercised via the real toggle button
and the slash-command path with an unrecognized-mode rejection case; and that `ForeverQuestGuideDB` stays
SavedVariables-safe after all of the above.

**Python route-schema suite: 36/36 passing** (31 from M8.3 + 5 new for `why`/`required`).
**Python M8.1 generator/contract suite: 117/117 passing, unmodified.**
**M6 regression: 62/62 passing, unmodified.**
**`luac5.1 -p`: passes on all nine addon/self-test Lua files.**

**Protected-file verification:** a pre-implementation snapshot of 122 protected files (M6
datasets/registry/scripts, the recorder, M4/ATT code, schemas, config, and every M7.x/M8.0–M8.5 document) was
taken before this milestone began. Diffed against the same snapshot afterward: **0 changed, 0 removed, 0
added** (this report itself is created after that diff, same as every prior milestone's own report).
`CollectionRun` registry: still 11 runs. `Data.lua`: confirmed byte-identical to a fresh generator run.
`RouteData.lua`: confirmed byte-identical to a fresh run of the (now-updated) route generator, meaning the
schema addition changed exactly what it should and nothing else. No M6/M7/ATT/licensing file was opened this
session.

## Real-client test procedure

1. Copy the full, updated `ForeverQuestGuide` folder into WoW Forever's `Interface/AddOns/`, replacing the
   M8.5 version.
2. Log in; confirm the load message now also reports the view mode ("detailed").
3. Open the guide. On the QUESTS tab, confirm the new "Search:" box appears without visually colliding with
   anything above or below it.
4. Type a partial quest name (e.g. "thunder"); confirm the list filters live, case-insensitively. Try a
   giver name (e.g. "skyseer"). Clear the box; confirm the full 96-quest list returns.
5. Confirm quest selection/detail still works exactly as before.
6. Switch to the ROUTE tab. **This is the one thing most likely to need adjustment**: confirm the window is
   tall enough that nothing overlaps — specifically, check that the Previous/Next buttons at the bottom
   don't overlap the preview section above them, and that no line of text overlaps the one below it.
7. Confirm "STEP 1 OF 5" and the progress bar render, and that the bar visibly fills as you click NEXT.
8. On step 1, confirm no "Why this step?" section appears (none was authored). Advance to step 4; confirm
   the why-section appears with the authored text.
9. Confirm the REQUIRED/OPTIONAL badge shows correctly (steps 1–4 should read REQUIRED, step 5 OPTIONAL).
10. Confirm "UP NEXT" shows up to 3 future steps at step 1, and that clicking a preview entry does nothing
    (by design). Click the `[-]`/`[+]` toggle; confirm the preview collapses and expands.
11. Click the new "View: Detailed" button (or run `/fguide mode compact`); confirm the layout visibly
    tightens — NPC line, explanation text, why-section, and preview should all disappear, while quest title,
    main instruction, and destination remain. Switch back to Detailed.
12. Switch to Dark theme; confirm the search box and progress bar both pick up the dark palette correctly,
    and re-check compact mode in Dark too.
13. Confirm the minimap button and welcome-popup behavior from M8.5 are both unaffected.
14. Confirm `/fguide` still works.
15. Report any Lua error, and separately, report any visual overlap or cramped spacing on the ROUTE tab even
    if no error occurred — the 480px height is an estimate, not a measurement.

## Unverified behavior

- **The ROUTE tab's new vertical spacing.** This is the single largest unknown from this milestone — a
  guessed height, not a measured one, for a tab with roughly double the content of M8.3's original layout.
- **Whether the search box (`EditBox`) behaves as expected at all.** This addon has never used an `EditBox`
  widget before this milestone; every prior widget was a `Frame` or `Button`. The self-test proves the Lua
  around it runs without error and that `SetText`/`GetText` round-trip correctly *in the stub* — it cannot
  prove the real widget accepts keyboard focus, displays typed characters, or behaves as a text field at all
  on Forever.
- **Whether the progress-bar segments render as a legible bar** rather than, say, invisible slivers at very
  small step counts or widths — never visually inspected outside the stub.
- **Whether compact mode's tighter spacing looks intentional or cramped** in practice.

## Client/API limitations discovered

None new. Every design decision in this milestone works within capabilities already established (or already
found absent) in M8.0 through M8.5 — no new WoW API was introduced, and this milestone's own scope
explicitly excluded anything that would have required one.

```text
M8.6-A STATUS: COMPLETE (pending real-client confirmation of the items above)
```
