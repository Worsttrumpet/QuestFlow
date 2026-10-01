# M8.1 Completion Report: First Playable Quest-Guide Addon

**Status: COMPLETE.** The addon loads (verified by execution under a stub UI environment, not yet on a real
client), its generator produces deterministic output that reproduces M6's guide-ready values exactly, and
every existing protected project file is unchanged.

## Files created

```
m8-guide-addon/
  generator/
    generate_addon_data.py          -- the M6 -> Lua generator
    test_generate_addon_data.py     -- 117 pytest cases (generator + data-contract)
  addon/ForeverQuestGuide/
    ForeverQuestGuide.toc
    Core.lua                        -- bootstrap, chat output, /fguide
    UI.lua                          -- quest list + detail window
    Data.lua                        -- GENERATED, not hand-written
  addon_selftest/
    stub_ui_env.lua                 -- permissive fake CreateFrame/etc. for execute-level testing
    run_ui_selftest.lua             -- loads the three addon files and exercises load/open/select/close/reopen
forever-db/docs/
  M8_1_COMPLETION_REPORT.md         -- this document
```

Nothing else was created. `docs/M8_0_SCOPE.md` was read, not modified.

## Files modified

**None.** No M4, M6, M7 file, recorder file, CollectionRun, ATT snapshot, `sources.toml`, `LICENSING.md`, or
locked test was touched. Verified by a full protected-file hash diff, both mid-implementation and at the end
(Section "Protected-file hash result" below) — both show zero changes.

## Addon naming

M8.0 flagged a naming collision risk with the third-party "ForeverGuide" overlay named in `LICENSING.md` (a
CC BY-NC-SA, RestedXP-derived dataset this project has never read). The new addon is named
**ForeverQuestGuide**, and its `.toc` `Notes` field states explicitly that it is unrelated to that overlay,
shares no code or data with it, and is built only from this project's own recorder-observed M6 evidence.

## Data contract used

Exactly M8.0's minimal contract (`docs/M8_0_SCOPE.md` §3), confirmed against the live `m6_guide_dataset.json`
before writing the generator (see the generator's own docstring for the field-by-field verification of types
and nullability): `id` (int), `title` (string), `level` (int), `objectives` (list of exact objective text
strings, including known blank `""` captures), `giver` (`{name, npc_id}`), `pos` (`{ui_map_id, x, y}` — the
**player's** position at interaction, never the NPC's; the `checkpoint` label M6 also stores here was
deliberately excluded as pipeline bookkeeping, matching M8.0's own minimal-contract example). No evidence
bookkeeping (`evidence_state`, `classification`, `observation_count`, `sessions`, `builds`) and no field
outside this contract (`xp`, `money`, `choice_items`, `guaranteed_items`, `reputation`,
`gossip_availability_sightings`, `completion`, `prerequisites`) is exported.

## Number of guide-ready quests exported

**96** — every quest in M6's current `guide_ready_quest_ids`, none of the 57 insufficient-evidence quests,
and nothing from the separate M7.4 ATT candidate pool (the generator never opens that file at all).

## Generated file size

`Data.lua`: **30,158 bytes** for 96 quests (about 314 bytes/quest, close to M8.0's ~290-byte/quest estimate
for the same minimal contract).

## Generator behavior

- Reads `m6-dataset-baseline/out/m6_guide_dataset.json` only; never writes to it or to any other existing
  file.
- Selects `guide_ready_quest_ids`, sorts ascending by numeric quest ID, and asserts (raises `ValueError`,
  does not silently skip) on any duplicate ID, a record whose own `guide_ready` flag disagrees with its
  presence in the ready-ID list, or a missing/mistyped contract field.
- Copies every value exactly — an empty objective-text capture round-trips as `""`, never replaced.
- Escapes Lua strings generically (backslash, double quote, `\n`, `\r`, `\t`, and any other control
  character via a decimal `\ddd` escape) — exercised against real data: the current dataset contains both
  apostrophes (`Al'Aketh Thugs`) and an embedded double quote (`1/1 "Badwind" Bennic slain`), both round-trip
  correctly (see `test_strings_are_correctly_escaped_for_lua` and
  `test_escaping_handles_every_real_guide_ready_string`).
- Embeds no timestamp anywhere; the only provenance stamp is the SHA-256 of the M6 input file's exact bytes
  (`13999e906b802d73303bae5add24f75300602d9a0cd50f57fe80e86711173b93` for the current file), which is why
  determinism holds.
- Output is a single `ns.QuestData` table keyed by quest ID plus a separate `ns.QuestOrder` array for
  guaranteed ascending display order (Lua's `pairs()` over an integer-keyed table is not order-guaranteed;
  `ns.QuestOrder` exists specifically so UI code never needs to rely on it).

## Test results

**Python (generator + data contract): 117 passed, 0 failed.**
- Generator tests: correct input file, only guide-ready quests exported, required fields preserved, no
  ATT-only fields or field names present (checked functionally — no import of or reference to the M7.4
  module or `proposed_targets.json` anywhere in the generator's actual code, not merely absent as a text
  string), no evidence-bookkeeping leakage, ascending sort, Lua-string escaping (parametrized + a real-data
  sweep), determinism across repeated runs, empty/blank field handling, no duplicate IDs, and defensive
  rejection of malformed input records.
- Data-contract tests: **all 96 guide-ready quests individually parametrized** — each generated record's id,
  title, level, objectives, giver, and position are asserted equal to M6's own value, field by field.

**Lua execute-level self-test (`addon_selftest/run_ui_selftest.lua`): 20/20 checks pass.** This loads
`Data.lua`, `Core.lua`, and `UI.lua` under a hand-built, permissive stub UI environment (not the real
client — see its own header comment) and exercises: loading all three files without a Lua error → simulating
the addon's data export → opening the window via `/fguide` → clicking a quest row → confirming the selection
state updated → closing via `/fguide` again → reopening. All steps completed without a runtime error.

## Determinism result

**Confirmed.** The generator's own `if __name__ == "__main__"` block re-renders in-memory and asserts
byte-for-byte equality before writing; a separate pytest case (`test_generator_is_deterministic_across_runs`)
independently calls `generate()` twice and asserts the Lua text, the extracted quest list, and the source
hash are all identical both times.

## Static validation result

- `loadfile()` and `luac5.1 -p` (parse-only, no execution) both succeed on all three addon files
  (`Data.lua`, `Core.lua`, `UI.lua`) and on both self-test files.
- Beyond parsing, the execute-level self-test (above) actually runs the addon's real code paths — frame
  construction, button creation, event registration, the slash-command toggle, and a simulated row click —
  under the stub environment, catching the class of error pure parsing cannot (undefined-global misuse, bad
  argument order, nil-indexing). **This is still not a real-client test**: the stub is deliberately
  permissive and makes no claim that Forever's actual `CreateFrame`, `CreateFontString`, or `SetFontObject`
  behave this way — only that this addon's own Lua is internally consistent when they do.
- No SavedVariables dependency: the `.toc` declares none, and nothing in `Core.lua` or `UI.lua` reads or
  writes any global `*DB` table.
- No external data source: `generate_addon_data.py` opens exactly one file
  (`m6-dataset-baseline/out/m6_guide_dataset.json`); no Questie, RestedXP, Wowhead, ForeverGuide, or Wago
  content appears anywhere in the new tree (checked directly; the only match for those names anywhere in the
  new files is this addon's own unrelated window title, "WoW Forever Guide (prototype)").
- No existing M4/M6/M7 file was modified (see below).

## Protected-file hash result

A pre-implementation snapshot of 116 protected files (M6 datasets/registry/scripts, the recorder, M4/ATT
code, schemas, config, and every M7.x/M8.0 artifact) was taken before any file in this milestone was
written. Diffed against the same snapshot after implementation: **0 changed, 0 removed, 0 added** among
those 116 files. `CollectionRun` registry: still 11 runs. `sources.toml` and `LICENSING.md`: byte-identical.
`docs/M8_0_SCOPE.md`: byte-identical (read, not edited).

## Selected real-client test quest

**Quest 907, "Enraged Thunder Lizards"** (confirmed present in the *current* generated `Data.lua` before
selecting it, per the instruction not to assume quest 907 is still there). Exact values to check against:

| Field | Value |
|---|---|
| Title | `Enraged Thunder Lizards` |
| Level | `18` |
| Objectives | `0/3 Thunder Lizard Blood` |
| Giver | `Jorn Skyseer` (NPC 3387) |
| Position | map 1413 (The Barrens), (0.4487, 0.5909) |

## Manual WoW test instructions

1. Copy the `ForeverQuestGuide` folder (`m8-guide-addon/addon/ForeverQuestGuide/`, all four files) into
   WoW Forever's `Interface/AddOns/` directory.
2. Start the game; at the character-select AddOns list, confirm "Forever Quest Guide (prototype)" appears
   and is enabled.
3. Enter the world on any character.
4. Confirm a chat message appears: "`[ForeverQuestGuide] vm8-guide-addon-0.1 loaded. Read-only quest
   browser, 96 guide-ready quest(s) available...`". If the interface number differs from 16001, a second
   message will say so plainly — that is expected reporting, not an error.
5. Run `/fguide`. Confirm the window opens with a quest list on the left.
6. Scroll (mouse wheel over the list) to find `[907] Enraged Thunder Lizards (Lvl 18)` and click it.
7. Compare the detail panel against the table above: title, level, objectives, giver. The position is not
   shown as readable text in the UI beyond the detail panel's plain `map 1413 (0.449, 0.591)` line — compare
   that against the table too.
8. Click "Show on Map" and confirm it prints a chat message saying map display is not implemented, rather
   than doing nothing silently or throwing a Lua error.
9. `/reload`. Confirm no Lua error appears on reload and the login chat message reappears.
10. Run `/fguide` again and confirm quest 907 still displays identically. This is the only "persistence"
    this addon needs, since it has no SavedVariables: it only tests that the static generated file loads
    correctly on every login, not the unresolved logout/character-select SavedVariables issue (M8.0 §2),
    which this addon does not depend on and therefore cannot newly encounter.
11. If a Lua error does appear at any step, note the exact error text and which step produced it — every UI
    primitive this addon uses (`CreateFrame`, `CreateFontString`, `SetFontObject`, click/drag/mouse-wheel
    scripts) is real Forever-client-untested code until this test is actually run once.

## Known limitations

- **Nothing in this addon has been run on the real Forever client yet.** Every "confirmed" claim above is
  about the generator (pure Python, environment-independent) or about the addon's Lua running correctly
  under a hand-built stub — never about the real game.
- The UI uses no XML template names (`UIPanelButtonTemplate`, `UIPanelScrollFrameTemplate`, etc.) since none
  has been confirmed to exist on Forever; scrolling is hand-rolled via `OnMouseWheel`, and buttons are bare
  `CreateFrame("Button", ...)` objects with manually created textures and font strings. This is more code
  than using stock templates would need, but avoids a second unverified-API dependency on top of the UI
  object model itself.
- `GameFontNormal` is used for text but wrapped through the project's own `Safe()` pattern with a hardcoded
  fallback font path (`Fonts\FRIZQT__.TTF`) if it's missing — neither has been confirmed on Forever; the
  manual test (step 5–7) is what actually confirms text renders at all.
- "Show on Map" is an inert placeholder, per M8.0: no map-pin API has been confirmed to exist on Forever.
- Blank-objective-text quests (the documented M6/M7.9 pattern) display the plain notice "(objective text not
  captured)" in place of the empty string — a UI-layer fallback for readability, not a change to the
  underlying data (the generated `Data.lua` still stores the exact `""` M6 captured; `renderDetail()` only
  substitutes display text at render time). This is the one place this addon shows text M6 itself didn't
  capture, and it is disclosed here rather than left implicit.
- The window has no visual polish (plain color rectangles, no borders beyond a flat outline, fixed size, no
  settings) — matches the milestone's explicit "functionality over polish" instruction.

## What remains for M8.2

- Run the manual test above on the real client and record the actual result (pass, or the exact Lua error
  and step).
- If the real client lacks `GameFontNormal` or errors on any UI primitive used here, that becomes the first
  concrete real-client UI finding for this addon family, feeding back into a future scope document the same
  way M7.6's real-client findings fed M7.7.
- Everything explicitly deferred by this milestone and by M8.0 remains deferred: map pins, route/step
  display, any ordering or sequencing of quests, and all automation. No route-step UI, fabricated ordering,
  or map interaction was implemented or hinted at anywhere in this addon — the quest list is exactly a
  browsable list in quest-ID order, nothing more.

```text
M8.1 STATUS: COMPLETE
```
