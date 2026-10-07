# 0.9.0: reward annotations on the game's own reward choices

The player sees the Reward Advisor's result directly on the quest reward choices (no Codex window, nothing to move). **Advisor decides, the overlay displays.**

## What the player sees (turn-in reward dialog with 2+ choices)
- Each choice gets a thin strip along the bottom of the game's own button: the advisor's tags (`[MIXED]`, `[NOT USABLE] [VENDOR]`, `[UPGRADE]`...), then its short stat text (`+4 stamina, -2 agility`) and `(usability unclear)` when the client's usability answers are unclear.
- One line above the first choice: `CODEX: RECOMMENDED - CHOICE n` (the advisor recommends), `CODEX: TENTATIVE PICK - CHOICE n (evidence incomplete)`, or `CODEX: NO CLEAR PICK`.
- The recommended choice also gets a gold border and its strip starts with `RECOMMENDED`. Nothing is highlighted when there is no clear pick (real Q5730: Kris MIXED, Hammer MIXED, Axe and Staff NOT USABLE + VENDOR).
- Hovering a choice adds the advisor's full reason (and caveats) to the game's own item tooltip.
- Appears when the dialog opens or its data changes, hides when the dialog closes (a light check three times a second, only while showing).

## Architecture
- `RewardAdvisor.lua`: `A.Display` / `A.DisplayRow` build the display from the classification and recommendation already made (tags, short text, unsure flag, reason). No new decision.
- `UI/RewardOverlay.lua`: draws `Advisor.Display()` on the choice buttons. Reads no item facts, compares nothing, judges nothing, has no click handler, never replaces or re-parents the game's buttons (strips are children with mouse input off; the tooltip is extended through a hook).
- `ItemProbe.DialogOpen` exposes the evidence layer's own "is a reward dialog open" check. The Presenter, planner and providers are untouched (their boundary tests still pass unchanged).
- `/codex report` has a REWARD OVERLAY section: which choice buttons were found and the reward frame's children.

## Not proven on Forever (real-client check needed)
The reward frame's structure. Choice buttons are looked up as `QuestInfoRewardsFrameQuestInfoItem<n>` then `QuestInfoItem<n>` (Classic-family names), used only when shown and (if they report GetID) the right choice. A choice whose button is not found is not annotated, nothing breaks, and the report says so. Also unverified: the strip and summary geometry (whether they cover item text), and that the tooltip hook runs after the game fills its tooltip.

## 0.9.2: first real-client report (0.9.1, Q5730)
- **Proven:** the choice buttons are `QuestInfoRewardsFrameQuestInfoItem1..4` (found by the first candidate name), `QuestFrame` and `QuestInfoRewardsFrame` exist, and the reward frame's children include the item buttons, `QuestInfoItemHighlight`, `QuestInfoMoneyFrame` and others.
- **Bug found:** with the dialog open the report said "not showing". The overlay redrew only on events, and the reward event fires before the game's reward frame is shown, so its "is a dialog open" check saw no and nothing re-checked.
- **Fix:** a light poll (about 2.5 times a second) also notices a dialog that is open and not yet annotated; it asks the advisor once per dialog (once more after a short back-off when the buttons are not there yet), and keeps hiding on close. No change to the advisor, the display content, the planner or the dungeon system.
- **Still unverified:** the strip and verdict-line geometry on the real frame (screenshot needed), and the tooltip hook.

## 0.9.3: the real cause (0.9.2 report, still "not showing")
0.9.2's poll was not the problem (it stayed as a safety net). `ItemProbe.readDialog("FACTS")`, the live refresh the advisor makes, stamped the dialog's `at` as `"FACTS"`, overwriting the QUEST_COMPLETE / QUEST_DETAIL that opened it. `Advisor.Display` only annotates the turn-in (`at == "QUEST_COMPLETE"`), so against the real client it was always nil. My fake-dialog tests supplied `at` directly and could not see it; the corrected test goes through the live path. Fix: a refresh read keeps the opening event of the same quest's dialog. Accept previews (QUEST_DETAIL) are still not annotated.
