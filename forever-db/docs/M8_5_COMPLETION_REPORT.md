# M8.5 Completion Report: ForeverQuestGuide Usability & Appearance

**Status: COMPLETE, pending real-client confirmation.** All three features (minimap button, welcome popup,
dark mode) are implemented, pass a 125-check Lua self-test with zero failures, and preserve every existing
M8.1/M8.3 behavior unmodified. Nothing here has been run on the real client yet — see "Real-client test
procedure" for what to check next, and "Anything that remains unverified" for exactly what these automated
checks cannot prove.

## Files created

```
m8-guide-addon/addon/ForeverQuestGuide/
  Preferences.lua     -- SavedVariables init/defaults, theme palette, get/set helpers
  MinimapButton.lua   -- self-contained minimap-button open/close control
  WelcomePopup.lua    -- one-time welcome prompt, built from the same proven primitives as the main window
forever-db/docs/
  M8_5_COMPLETION_REPORT.md  -- this document
```

## Files modified

| File | Change |
|---|---|
| `ForeverQuestGuide.toc` | Added `Preferences.lua`, `MinimapButton.lua`, `WelcomePopup.lua` to the file list (load order: Data, RouteData, **Preferences**, Core, **MinimapButton**, **WelcomePopup**, UI); added `## SavedVariables: ForeverQuestGuideDB` (the addon's first — M8.1/M8.3 had none); bumped `## Version` to `m8-guide-addon-0.4`; updated `## Notes` to mention the new SavedVariable and its limited scope (UI preferences only). |
| `Core.lua` | `VERSION` bumped to match. `ADDON_LOADED`'s handler extracted into a named local function (`onAddonLoaded`) so a test seam can call it directly; now also builds the minimap button and shows the welcome popup (if not disabled) after the existing login message. The slash command gained one optional argument form, `/fguide theme classic|dark`; bare `/fguide` (or any other argument) falls through to the original, unchanged toggle behavior. |
| `UI.lua` | Added a theme system: every `FontString` created through `newFontString()` and every button created through `newWideButton()` self-registers into a themed-element registry; `applyTheme()` recolors all of them in one pass from `Preferences.lua`'s palette. Added a small, discoverable "Theme: Classic/Dark" toggle button next to the close button. `newWideButton()` gained an optional `role` parameter (`"primary"`/`"secondary"`) — the ROUTE tab's `NEXT ->` button is now `"primary"` (strong emphasis, per the request), `<- PREVIOUS` and `Show on Map` are `"secondary"`. **No change to any M8.1/M8.3 data flow, rendering logic, navigation logic, or layout beyond color.** |
| `addon_selftest/stub_ui_env.lua` | Added two permissive stub globals, `Minimap` and `GameTooltip`, so the self-test can execute the minimap button's construction and tooltip code without erroring. Explicitly documented as *not* a claim that either exists on Forever. |
| `addon_selftest/run_ui_selftest.lua` | Extended (every existing M8.1/M8.3 check preserved verbatim) with new sections: `Preferences` defaults, actually firing `ADDON_LOADED` (previously the self-test could only inspect side effects, never trigger the event itself — see "Change control" below), minimap-button creation and click behavior, the welcome popup's both buttons, in-window and slash-command theme switching, and "Don't Show Again" persistence across a simulated reload. |

**Confirmed unchanged, not just unedited** (checked by content, given this environment's file-modification
times are not reliable — see M8.3's own completion report for why): `Data.lua` and `RouteData.lua` are still
byte-identical to fresh runs of their respective generators. `m6-dataset-baseline/`, the recorder, ATT
ingestion, the route schema (`route_schema.py`), and the route generator (`generate_route_data.py`) were not
opened this session.

## Feature 1: minimap button

**API investigation performed first, per the request.** Searched the project's own six addons, both stub
environments, and the vendored ATT `.toc` for any minimap-button precedent. Found none in this project's own
code. ATT's `.toc` wires its own minimap button through `AddonCompartmentFunc` — a modern, retail-only
Blizzard feature (Addon Compartment) with no evidence of existing on Forever's interface (16001, which
resembles nothing in the range where that feature exists) — so it was **not** used as a model here, per the
request's own caution against assuming modern retail minimap-button APIs.

**Design used instead:** a plain `Button` widget built from the exact same `CreateFrame`/`CreateTexture`/
`CreateFontString` primitives every other part of this addon already uses — no library, no data-broker icon
convention, no draggable-minimap-ring positioning. It is parented to the global `Minimap` frame if one
exists. `Minimap`'s existence on Forever is **not independently confirmed** by this milestone; the design
degrades safely either way, for two reasons already true of this codebase, not new assumptions:
- `CreateFrame(type, name, parent)` with a `nil` parent already defaults to `UIParent` — proven by this very
  codebase's own `CreateFrame("Frame")` (no parent at all) in `Core.lua`'s `ADDON_LOADED` listener.
- `Frame:SetPoint(point, relativeTo, ...)` with a `nil` `relativeTo` is ordinary, version-independent
  `UIObject` behavior (defaults to the frame's own parent), not something specific to or requiring
  confirmation on Forever.
- Net effect: if `Minimap` doesn't exist, the button still appears (near the screen's top-right, since its
  parent silently becomes `UIParent`) rather than erroring or vanishing. **Which outcome actually happens
  has not been observed yet.**

The icon is a plain colored square with a "Q" on it (same texture+FontString pattern as every other button
in this addon), not a game icon texture path, since no icon path has been confirmed to exist on Forever. The
tooltip ("Forever Quest Guide" / "Click to open/close") is shown through the global `GameTooltip`, gated
behind `if GameTooltip then` and `ns.Safe()` calls, mirroring the same defensive pattern `Core.lua`'s own
`say()` already uses for `DEFAULT_CHAT_FRAME`.

Self-contained in one small file with one exported function (`ns.MinimapButton.Build`), so it can be
replaced with a more sophisticated icon/dragging implementation later without touching anything else, per
the request.

## Feature 2: welcome popup

Built the same way as the main window (bare primitives, no `StaticPopupDialogs` framework — that is another
unconfirmed XML-template system, avoided for the same reason every other template has been avoided since
M8.1). Behavior matches the request's exact wording:

- **"Open Guide"** hides the popup and opens the guide (`ns.UI.Toggle()`), but does **not** persist a
  do-not-show flag — the popup can still appear on a future login unless "Don't Show Again" is used
  separately. Verified directly (`ForeverQuestGuideDB.welcomePopupDisabled` stays `false` after clicking it).
- **"Don't Show Again"** hides the popup and sets `ForeverQuestGuideDB.welcomePopupDisabled = true`,
  permanently (until a future milestone adds a reset — none exists in M8.5).
- The popup auto-shows on `ADDON_LOADED` only if `welcomePopupDisabled` is not `true`.
- `/fguide` and the minimap button are entirely independent of this preference and were confirmed to keep
  working regardless (Section "Automated verification" below).

**Persistence, stated honestly per the request's own instruction to investigate rather than assume:**
`ForeverQuestGuideDB` uses the same SavedVariables mechanism the recorder already found a real,
twice-reproduced logout/character-select persistence failure in (`docs/M8_0_SCOPE.md` §2, root cause
unknown). This module cannot work around that; it is the same mechanism, with the same limitation. The
self-test can only prove the *logic* is correct (the flag is read and honored correctly when
`ADDON_LOADED`-equivalent code runs again with the flag already set) — it runs inside one continuous Lua
process and cannot exercise the real client's disk-write/restore path at all, so it says nothing about
whether the value actually survives a real `/reload` or a real logout, only that the code reacts correctly
to the value being present. That distinction is the entire reason "Real-client test procedure" item 8 below
exists.

## Feature 3: dark mode

Two complete palettes are defined in `Preferences.lua`, not a partial override: `classic` reproduces
M8.1/M8.3's exact existing colors (so choosing Classic, or never switching at all, changes nothing already
shipped), and `dark` is a new palette with the specific properties the request asked for:

| Requirement | How it's met |
|---|---|
| Dark background for the main window | `windowBG = (0.04, 0.04, 0.05, 0.97)`, near-black |
| Clearly contrasting panels / readable text | `panelText = (0.92, 0.92, 0.95, 1)`, near-white, applied to every registered `FontString` |
| QUESTS/ROUTE tabs easy to distinguish, clear active state | `tabActiveBG` (a saturated blue) vs. `tabInactiveBG` (near-black); the active tab is recomputed on every theme change and every tab switch through one shared function (`setActiveTabTheme`), so the two triggers can never disagree with each other |
| Buttons substantially easier to see | All button backgrounds move from the low-opacity grays M8.1/M8.3 shipped to fully-opaque, higher-contrast colors in dark mode |
| `NEXT ->` strong emphasis | `primaryButtonBG` is a saturated green in dark mode, applied only to buttons registered with `role = "primary"` (currently only `NEXT ->`) |
| `<- PREVIOUS` visually distinct, still visible | `secondaryButtonBG` is a muted blue-gray, applied to `PREVIOUS` and `Show on Map` |
| Applies consistently to QUESTS and ROUTE | Both tabs' `FontString`s and buttons register into the same shared theming registries; there is no per-tab theming code to fall out of sync |
| No emoji/unsupported glyphs | Unchanged from M8.3's already-fixed `[*]`/`[X]`/`[>]` fallback vocabulary — dark mode does not touch glyph selection at all |
| Route-step semantics unchanged | `route_schema.py`, `generate_route_data.py`, and every `*_route.json` file were not opened this session |

**Switching mechanism:** a small, discoverable button in the main window itself ("Theme: Classic" / "Theme:
Dark", next to the close button), not a settings framework — clicking it cycles and immediately re-applies.
`/fguide theme classic` / `/fguide theme dark` is a second, scriptable path to the same effect, added as an
optional extension of the existing slash command rather than a new one (an unrecognized argument still falls
through to the original toggle behavior, so `/fguide` "continues working exactly as it does now" in every
case, including a mistyped theme name). The current theme persists in `ForeverQuestGuideDB.theme`, subject
to the exact same SavedVariables limitation described in Feature 2.

## Automated verification

**Lua self-test (`addon_selftest/run_ui_selftest.lua`): 125 checks, 0 failures.** Beyond every existing
M8.1/M8.3 check (all still present, all still passing, confirming those features remain intact), it now
covers, each exercised through the real click handler or slash-command path rather than by calling an
internal function directly wherever a real one was reachable:

- Preferences defaults on a fresh install (`welcomePopupDisabled = false`, `theme = "classic"`) and that
  the two theme palettes are genuinely different (not the same table twice).
- **Firing `ADDON_LOADED` for real** — a capability the self-test did not have before M8.5 (see "Change
  control" below) — confirming the minimap button and welcome popup are both created as a direct effect of
  it, not merely inferred from their modules existing.
- Clicking the popup's actual "Open Guide" button: hides the popup, does not set the disable flag, and
  builds/shows the main window for the first time.
- Clicking the actual minimap-button `OnClick` handler twice: closes an open window, then reopens it.
- `/fguide` (bare) still toggles correctly afterward.
- Theme switching via the in-window button's actual `OnClick`, and separately via
  `/fguide theme classic|dark`, including an unrecognized theme name being rejected without changing the
  current theme or throwing an error.
- Every themed-element registry (`FontStrings`, primary buttons, secondary buttons, window backgrounds,
  borders) is confirmed non-empty after a real build, proving the registration wiring actually ran.
- Clicking the popup's actual "Don't Show Again" button: persists the flag, hides the popup, and — the
  reload-persistence *logic* test — firing `ADDON_LOADED` again afterward does not re-show the popup.
- `ForeverQuestGuideDB` is confirmed to contain only SavedVariables-safe value types
  (`Preferences.IsSavedVariablesSafe`) after every mutation performed during the run, guarding against ever
  accidentally storing a function or other non-persistable value in the one SavedVariable this addon has.

**M8.1 generator/contract suite: 117/117 still passing, unmodified.**
**M8.3 route schema/generator suite: 31/31 still passing, unmodified.**
**M6 regression: 62/62 still passing, unmodified.**
**`luac5.1 -p`: passes on all nine addon/self-test Lua files** (the four from M8.1/M8.3 plus the three new
M8.5 files plus the two self-test files).

**Protected-file verification:** a pre-implementation snapshot of 121 protected files (M6
datasets/registry/scripts, the recorder, M4/ATT code, schemas, config, and every M7.x/M8.0–M8.3 document) was
taken before this milestone began. Diffed against the same snapshot afterward: **0 changed, 0 removed, 0
added.** (`M8_5_COMPLETION_REPORT.md` itself is created after this diff was taken, in the same pattern as
every prior milestone's own report.) `CollectionRun` registry: still 11 runs. `sources.toml` and
`LICENSING.md`: byte-identical. `Data.lua` and `RouteData.lua`: confirmed byte-identical to fresh runs of
their own generators, so no quest or route data was altered by anything in this milestone.

## Change control (smallest additive mutation boundary)

Before editing, the existing `Core.lua`/`UI.lua` were read in full and the M8.1/M8.3 real-client validation
docs were reviewed for established, already-proven patterns to reuse rather than invent fresh ones
(`ns.Safe`, the `if <global> then` existence-guard style, the bare-primitives-only UI construction style, the
`ns._selftest` test-seam convention). One structural change was needed to support testing: `Core.lua`'s
`ADDON_LOADED` handler was extracted from an anonymous closure into a named local function
(`onAddonLoaded`) purely so a test seam could call it directly — its behavior is unchanged, only its
callability from the self-test changed. `ns._selftest` is now **merged into** by both `Core.lua` and
`UI.lua` (`ns._selftest = ns._selftest or {}`, then individual key assignments) rather than being assigned
as a single table literal by whichever file runs last — the old UI.lua pattern would have silently erased
Core.lua's new `fireAddonLoaded` entry, since `Core.lua` loads first and `UI.lua` loads last per the `.toc`.
This was caught before it could cause a silent test gap, not discovered as a failure.

## Real-client test procedure

1. Copy the full, updated `ForeverQuestGuide` folder (now 8 files, including `Preferences.lua`,
   `MinimapButton.lua`, `WelcomePopup.lua`) into WoW Forever's `Interface/AddOns/`, replacing the M8.3
   version.
2. Log in. Confirm the load message reports version `m8-guide-addon-0.4`, the same guide-ready/route counts
   as before, and now also "Theme: classic."
3. **Confirm the minimap button appears.** Report exactly where — docked next to the minimap (if `Minimap`
   exists on Forever) or floating near the top-right of the screen (if it doesn't) — since this milestone
   cannot determine which will happen.
4. Hover the minimap button and confirm the tooltip reads "Forever Quest Guide" / "Click to open/close."
5. **Confirm the welcome popup appears** (fresh install / first load) with the exact three lines of text and
   two buttons.
6. Click **Open Guide**: confirm the popup closes and the main guide window opens.
7. Close the guide, then click the minimap button: confirm it opens. Click it again: confirm it closes.
8. Confirm `/fguide` still opens/closes the guide exactly as in M8.1/M8.3.
9. `/reload`. Confirm the welcome popup does **not** reappear (since it was never dismissed via "Don't Show
   Again" in this fresh-install flow, it actually *should* reappear here, per the request's own stated
   behavior — re-test with "Don't Show Again" specifically, per step 10, to test the persistent-suppression
   path).
10. Open the guide, note the current theme label, click the "Theme: ..." button, confirm the window visibly
    changes to Dark mode: check tab distinction, button contrast (especially `NEXT ->` vs `<- PREVIOUS` on
    the ROUTE tab), and that quest titles/levels/objectives/NPC names/route instructions all stay legible.
11. `/reload`. Confirm the theme is still Dark (or whichever was last selected) after reload.
12. Trigger the welcome popup again if possible (or accept that a fresh-install-only prompt can't be
    re-triggered without clearing SavedVariables) and click **Don't Show Again** this time; `/reload`;
    confirm the popup does **not** reappear.
13. **If feasible**, fully log out to character select and back in (not just `/reload`) and report, plainly,
    whether the theme and popup-dismissal preferences survived — this is the one thing M8.0 already found
    unreliable for this client's SavedVariables in general, and this milestone has no way to know in advance
    whether the same failure applies here.
14. Confirm the QUESTS tab (list, scroll, select, detail panel) still works exactly as in M8.1, in both
    Classic and Dark.
15. Confirm the ROUTE tab (all 5 steps, Next/Previous, boundaries) still works exactly as in M8.3, in both
    Classic and Dark.
16. Report any Lua error, at which step it occurred, and its exact text.

## Anything that remains unverified

- **Whether `Minimap` exists on Forever at all**, and therefore whether the minimap button actually docks to
  a minimap or falls back to a fixed screen position. Reasoned about, not observed.
- **Whether `GameTooltip` exists and behaves as assumed** — gated defensively, but unconfirmed.
- **Whether the dark-mode color choices are actually good in practice** (contrast, readability against the
  game world behind the semi-transparent window) — chosen based on typical high-contrast UI conventions, not
  measured against anything Forever-specific.
- **Whether either preference (theme, popup dismissal) survives a real `/reload`** — the self-test proves
  the logic is correct given a value that's already present; it cannot exercise the real save/restore path.
- **Whether either preference survives a full logout/character-select cycle** — per M8.0's own standing,
  unresolved finding about this client, genuinely unknown until tested.
- **The theme toggle button's own label text and the popup's three lines of text** — never independently
  confirmed to render correctly (the stub's FontString mock cannot read back `SetText` content), though they
  use the exact same `newFontString`/`GameFontNormal` path M8.1 already validated for every other line of
  text in this addon.

## Client/API limitations discovered

- No new limitation was discovered this session beyond what M8.0 had already documented (the SavedVariables
  logout-persistence issue). Everything else in this report is a *design decision made in light of* an
  existing, already-documented limitation (no confirmed map-pin API, no confirmed minimap frame, no
  confirmed template system), not a new one found during M8.5's own work.

```text
M8.5 STATUS: COMPLETE (pending real-client confirmation of the items above)
```
