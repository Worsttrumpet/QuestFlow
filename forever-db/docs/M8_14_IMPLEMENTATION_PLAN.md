# M8.14 Implementation Plan: Guide Knowledge Foundation + Player-Facing Guide UI

One milestone, two workstreams. The provenance model (`M8_14_PROVENANCE_MODEL.md`) supplies the data *underneath*
the UI; it changes what the counts and instructions say, not whether the UI is built. Goal: opening the addon
should feel like a guide, not a database viewer.

## Workstream A — Knowledge layer

| # | Item | Depends on |
|---|---|---|
| A1 | Evidence layers (FOREVER_OBSERVED / CLASSIC_ESTABLISHED / SOD_ESTABLISHED) and computed statuses | Model: done (draft) |
| A2 | Knowledge summary: one function computing KNOWN / RESEARCHED / ACTIONABLE / ROUTED, split by evidence layer | Current `Data.lua` now; ATT layer after the repository check |
| A3 | Start-object support (quests begun by clicking objects, e.g. the Cozy Sleeping Bag chain) in the knowledge schema | Design only this milestone |
| A4 | Route validator (missing / later / unresolved prerequisites, missing destination/provenance) | Pure logic; runs read-only on the test route |
| A5 | Source inventory and licensing-scope answer (ATT whole vs `forever/` subset) | **Repository files** |

## Workstream B — Player-facing UI

| # | Item | What it does | Depends on |
|---|---|---|---|
| B1 | **Guide Home** as the opening screen | Current route and step with a Continue button; what the guide can help with; coverage counts from A2, split by evidence; sections with no data are omitted, never faked | A2 |
| B2 | **Coverage wording** | Replaces "96 guide-ready" with evidence-based counts, e.g. "96 quests observed on Forever; 87 with full instructions" | A2 |
| B3 | **Compact guide view** | Default route view shows: what to do, where, what to look for, what's next. No "Destination: not captured" or other data-quality text; missing data simply isn't shown. The detailed view remains available | none |
| B4 | **Useful step instructions** | Each step reads as an instruction built from knowledge, e.g. "Talk to Jorn Skyseer — The Barrens, 44.9, 59.1", "Collect 3 Thunder Lizard Blood", with a small origin marker when a value is inherited rather than Forever-observed | A2 (origin marker) |
| B5 | **Options menu** | One button opening a small menu: Skip, Reset Step, Undo, Pause, Show on Map, Route Details, reset positions. Previous and Next/Confirm stay visible. Built from plain buttons (no Blizzard dropdown templates, which are unverified on Forever) | none |
| B6 | **Draggable minimap button** | Left click unchanged; right-click drag moves it freely near the minimap; position saved and restored across `/reload`; reset in the Options menu | Window dragging confirmed on Forever in M8.1; the probe re-checks right-button drag and read-back |
| B7 | **Guide Arrow** | Separate from progression. Shows direction, destination name and addon-computed distance; "Arrived" inside the radius; hidden when the current step has no destination; draggable like B6 | **Probe**: facing, texture, rotation, glyphs |
| B8 | **Objective-marker contract** | Data contract for current-objective markers (kill / collect / loot / interact) with evidence per location; renders nothing when no evidence exists — no invented locations | A1 |
| B9 | **Quest detail contract** | QUESTS view shows researched knowledge (start, objectives, turn-in, prerequisites, route status, completeness) where it exists | A2 |

## Guide Arrow design, by probe outcome

| Probe result | Arrow behaviour |
|---|---|
| Facing works + a texture rotates | True relative arrow: rotation = bearing to destination − player facing |
| Facing works, no usable texture | Relative direction as text (e.g. "ahead", "turn right") or ASCII glyphs that render |
| Facing absent | Compass bearing only (N / NE / E …), labelled as compass, not relative |
| Arrow glyphs render | Used for the text fallback and the arrival check mark |

Distance always comes from the addon's own calculation (M8.10); the game's navigation, waypoint and super-track
state are never used for the arrow's distance or for progression.

## Order of work

1. **Now:** B3, B4, B5, B6 (no unknowns), A4 validator, A2 on current data, B1/B2 on current data.
2. **After the probe:** B7 Guide Arrow.
3. **After the repository check:** A5, then A2's ATT layer — the Home screen and instructions pick it up automatically.
4. Stub tests throughout; the 82 M8.13 tests must stay green.
5. One short real-client check of the finished UI.

## Not in M8.14

Bulk route data, bulk ATT import into production, per-objective matching, automatic advancement.
