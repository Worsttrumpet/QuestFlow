# M8.1 Real-Client Validation Addendum

**M8.1 REAL-CLIENT VALIDATION: PASS**

This addendum documents the operator's manual test of the ForeverQuestGuide addon on a real WoW Forever
client, following the exact procedure in `docs/M8_1_COMPLETION_REPORT.md`'s "Manual WoW test instructions."
Everything in that report up to this point had been verified only through the Python generator/contract
suite and the Lua execute-level self-test under a hand-built stub environment — neither of which is the real
game. This document records what the real client actually did. It is a short validation record, not a
replacement for the completion report.

## 1. Load validation

The addon loaded successfully at login, with no manual setup step. The login chat message read:

> `[ForeverQuestGuide] vm8-guide-addon-0.1 loaded. Read-only quest browser, 96 guide-ready quest(s)
> available. Never accepts/completes/turns in quests, never calls GetQuestReward().`
> `[ForeverQuestGuide] type /fguide to open or close the guide.`

- Version reported: `vm8-guide-addon-0.1`, matching the `.toc`.
- Quest count reported: **96**, matching the current `m6_guide_dataset.json`'s `guide_ready_count`.
- **No Lua error appeared during login or load.**
- **No interface-mismatch warning appeared.** Per `Core.lua`, that warning only fires when
  `GetBuildInfo()`'s reported TOC version differs from the addon's `EXPECTED_INTERFACE` (16001). Its absence
  means the client reported interface 16001 on this login. This confirms the addon's declared interface
  matched this one real login on this one client build — it does not establish that every future Forever
  build, patch, or client will report the same interface, and no such claim is made here.

## 2. `/fguide` validation

All of the following were exercised directly and produced no Lua error:

- `/fguide` opened the addon window.
- `/fguide` closed it; running it again reopened it.
- The quest list displayed all visible rows correctly, with readable text.
- Mouse-wheel scrolling over the list moved through the 96-quest list (confirmed by quest IDs outside the
  first 16 becoming visible, e.g. quests in the 92600–93165 range).
- Clicking a quest row selected it and updated the detail panel (confirmed independently on at least two
  different quests, e.g. quest 92684 and quest 907 — see Section 3).
- The detail panel rendered title, level, giver, position, and objective text correctly for every quest
  selected.
- The window could be dragged to a new screen position by clicking and holding its body.

## 3. Quest 907 validation

**Quest 907 — Enraged Thunder Lizards.** The addon's displayed values were compared field-by-field against
the values recorded in `docs/M8_1_COMPLETION_REPORT.md`'s "Selected real-client test quest" table:

| Field | Expected (completion report) | Displayed by the addon | Match |
|---|---|---|---|
| Title | `Enraged Thunder Lizards` | `Enraged Thunder Lizards` | Yes |
| Level | `18` | `18` | Yes |
| Objective | `0/3 Thunder Lizard Blood` | `0/3 Thunder Lizard Blood` | Yes |
| Giver | `Jorn Skyseer` | `Jorn Skyseer` | Yes |
| Position | map `1413`, approx. `(0.449, 0.591)` | map `1413` `(0.449, 0.591)` | Yes |

All five fields matched exactly. This is a **static addon-data display validation**: it confirms the addon
correctly loads and displays the values `Data.lua` was generated with from M6. It does not use, query, or
compare against the operator's own live quest log, and no claim is made about the operator's actual
in-game quest state — the addon has no code path that reads `C_QuestLog` or any other live quest API at all.

## 4. Map button

The "Show on Map" button was clicked multiple times, on multiple different selected quests, and each time
printed the expected placeholder message:

> `[ForeverQuestGuide] Show on Map: not implemented -- no map-pin API has been confirmed on Forever yet
> (see docs/M8_0_SCOPE.md).`

This confirms only that the **current, intentionally inert M8.1 placeholder** behaves as designed (prints a
notice, takes no action, throws no error). It does **not** mean any map-pin, POI, or MapCanvas API has been
implemented, tested, or confirmed to exist on Forever — that remains exactly as unresolved as
`docs/M8_0_SCOPE.md` §2 and §9 described it before this test.

## 5. Reload validation

- `/reload` completed with no Lua error.
- The addon loaded again afterward, printing the same login message with the same **96**-quest count.
- `/fguide` opened successfully after reload.
- The quest list populated immediately, with no visible delay or loading state.
- The window reopened instantly, with no re-selection needed and no stale or missing data.

This validates that the addon's **static generated data** loads correctly and immediately on every login —
the only kind of "persistence" this addon needs, since it has no SavedVariables. It does **not** test or
establish anything about the unresolved SavedVariables logout/character-select persistence issue documented
in `docs/M8_0_SCOPE.md` §2, because this addon does not depend on SavedVariables and therefore cannot
encounter that issue.

## 6. What this validates

The real client confirmed the following, previously listed only as "untested" or "unverified" in
`docs/M8_1_COMPLETION_REPORT.md`'s "Known limitations" section, each exercised at least once during this
test:

- `CreateFrame` (plain frames, buttons, all without XML templates)
- `CreateTexture`
- `CreateFontString`
- `GameFontNormal` (text rendered correctly; no fallback font was needed)
- The addon's namespace/data-loading pattern (`local _, ns = ...` across `Data.lua`, `Core.lua`, `UI.lua`)
- Slash-command registration (`/fguide`)
- Mouse-wheel event handling
- Click event handling
- Drag event handling (`SetMovable`, `RegisterForDrag`, `StartMoving`/`StopMovingOrSizing`)
- Static generated Lua data loading (`Data.lua`'s `ns.QuestData` / `ns.QuestOrder`)
- Quest list rendering
- Quest detail rendering

Only APIs and behaviors actually exercised during this specific test session are listed above. Nothing
listed here should be read as validated for any other client build, any other WoW Forever session, or any
API this addon does not itself call.

## 7. What remains intentionally unimplemented

Unchanged by this validation and still out of scope, exactly as `docs/M8_0_SCOPE.md` and
`docs/M8_1_COMPLETION_REPORT.md` describe:

- Directional arrow
- Route ordering
- Automatic route progression
- NPC world-position tracking
- Mob/objective area markers
- Minimap/map pins
- Custom quest/NPC route markers (⭐ or otherwise)
- Quest acceptance automation
- Quest turn-in automation
- New data collection
- Route optimization

None of the above is a failure of M8.1 — all were explicitly deferred by M8.0's reconnaissance and M8.1's
own scope, and none was attempted here.

## 8. Conclusion

M8.1 successfully established the first functional player-facing ForeverQuestGuide addon: it loads without
error on the real WoW Forever client, its generated data displays correctly and matches M6 exactly on the
quest checked, and its UI (list, selection, detail view, scrolling, dragging, and the inert map placeholder)
all function as designed. The next milestone can focus on route/navigation architecture rather than on
basic addon loading or UI feasibility, both of which this validation now closes out.

**M8.1 STATUS: COMPLETE AND REAL-CLIENT VALIDATED**
