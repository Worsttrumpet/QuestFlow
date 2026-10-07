# 0.7.8: UI pass (partial) and the relevance gate

**Status: PARTIAL.** This build contains the first part of the UI/UX pass. Items marked NOT DONE are still open; nothing here was validated on the real Forever client.

## Done
* **Semantic visual system** (`UI/Theme.lua`). Cards ask for a ROLE (primary, optional, later, urgent, ready, discovery, training, profession, dungeon, world, progression); the active theme decides how it looks.
  Colour is never the only signal: every role has a one-character marker (`>`, `+`, `!`, `?`, `*`, `T`, `P`, `D`, `o`, `^`), a label, an accent edge and a weight (primary and urgent are heaviest).
  Themes: `codex` (the classic look) and `contrast` (brighter, heavier). The choice is stored account-wide (`ui.theme`). A theme missing a role falls back to the default theme's.
  The TIMED QUEST card is the `urgent` role and gets louder only as the deadline nears (`Theme.Urgency`); DUNGEON QUESTS no longer shares its colour (now plum, marker `D`).
* **NOW is clearer**: a bigger title and label, a heavier accent, and ONE short "Why:" line in player words (`Presenter.WhyPlayer`: a timed quest running out, what a hand-in opens, already in the area, keeps your quests moving, on your way ...). Idle wording is honest ("Nothing urgent right now", "Gathering information...").
* **Startup**: `UI.Init` runs at login (Boot). The cause of "I had to click the minimap button" was that the UI was built lazily on the first click and a first-time character was only told to type `/codex`. A first-time character now gets the setup panel by itself; a returning one gets the tracker unless it was closed.
* **Resizable Codex window**: drag the bottom right corner. WIDTH only (300 to 520): the height always fits the content so nothing is clipped. Saved with the window position (the existing `w` field), clamped when restored. `Reset window size and place` on the Themes tab.
* **Codex Options rewritten** (sections, check rows with a one-line explanation, DROPDOWNS for zone, style, party news). **Themes tab**: theme, direction arrow (show, style, colour, preview), game interface (the game's quest tracker, the world-map button), reset window.
* **What Codex knows** (Appendices) rewritten against the code. **Commands and card guide** added.
* **Relevance gate** (`Relevance.lua`) and **PetTraining** (`PetTraining.lua`): a feature is shown only when it applies to the character. Pet Training applies to Hunter and Warlock and shows a card only when a pet SOURCE has something to say. Codex reads NO pet information on Forever today, so no class sees a Pet Training card. No pet data is invented and no Era table is shipped.

## NOT DONE
* World and Journey polish (the pages are unchanged).
* The arrow staying useful while "in the objective area".
* "Next Area" (deliberately left to a planner task).
* Making list rows clickable.

## Limitations
* The window height is not user-resizable (it fits the content).
* The dropdown is Codex's own (no Blizzard template); its open list closes on selection, on opening another dropdown or when the page hides, not on a click elsewhere.
* A narrow window truncates long unwrapped lines with an ellipsis; wrapped text reflows.
* The purchase hook, resize drag and startup behaviour need a real-client check.
