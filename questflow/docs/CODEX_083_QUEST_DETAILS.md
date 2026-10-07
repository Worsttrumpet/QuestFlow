# 0.8.3: clickable quest details (the fallback for quests Codex cannot place)

A quest in the player's log is never lost just because Codex has no usable map position for it.

## What the player sees
- **IN YOUR LOG, NOT ON THE MAP**: a quiet, low-priority card listing log quests Codex cannot place (the planner holds them as reminders, or no pack knows them). At most five rows plus "+ N more". Each row has a hover highlight, a `[+]`/`[-]` indicator and a tooltip. Finished quests are not repeated here: READY TO TURN IN carries them.
- **READY TO TURN IN** rows with no map position, and the **guidance NOW title** (when Codex has no map position for the quest), open the same card. A quest the planner can route keeps its normal guided behaviour: no click area is added.
- **QUEST DETAILS**: title (with the game's Elite / Dungeon tag when there is one), the quest log section heading, status, every objective with current counts, the QuestieDB giver / turn-in NPC NAMES labelled `(QuestieDB, unverified)` when QuestieDB has them, and `Codex has no usable map position for this quest, so there is no arrow.` when that is true. No story text (no proven API), no QuestieDB coordinates, and the game's own quest UI is never opened.
- Live: it follows objective progress, a quest becoming ready, and closes when the quest leaves the log. Clicking the same quest again (or Close) collapses it. The selection is session-only (`UI.main.detailQuest`) and is never saved.

## Where it lives
- `QuestDetail.lua`: pure `Describe(id, ctx, opts)` over the existing quest-log snapshot (no client call), and `ApiLines()` for the report.
- `Presenter.lua`: `Pr.Unplaced` (the list) and `Pr.QuestDetail` (the one function the page calls); `Overlap.Ready` rows carry `placed`.
- `QuestieBridge.lua`: `Names(id)`, names only.
- `UI/PageCodex.lua`: the two cards and the click areas. The planner is untouched.

## Report
`/codex report` lists `QuestMapFrame_OpenToQuestDetails`, `QuestLogPopupDetailFrame_Show`, `ToggleQuestLog`, `OpenQuestLog` and `C_QuestLog.SetSelectedQuest` as present or absent, always UNPROVEN and never called. There is no "open in the game's quest log" button.

## Needs the real client
How the cards look and feel (hover, indicator, tooltip, card height at different widths), QuestieDB names against a real QuestieDB, and whether any of the game's quest-UI functions work on Forever (not tested, not claimed).
