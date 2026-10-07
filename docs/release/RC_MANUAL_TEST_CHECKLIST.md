# Quest Flow release candidate: manual test checklist (real WoW Forever client)

Only things the real client can prove are here. Logic, planner rules, advisor rules, slot handling, packaging contents and report wording are covered by the automated suite and are not repeated.

**Rules for this pass**
- Test the **release ZIP**, installed fresh (Part A), never the working tree.
- Do not change anything if a result surprises you. Record exactly what you saw (the **Capture** column), then decide.
- `/qflow` is the command. `/codex` is kept as an alias; F4 checks it still works.
- Evidence: a screenshot only where marked **SHOT**; `REPORT` means run `/qflow report`, press Ctrl+C and paste it into your notes.

Legend: PASS / FAIL / N/A. Anything FAIL goes in the table at the end.

---

## Part A. Install the actual ZIP (do this first)

| # | State | Do | Expect | PASS if | FAIL if | Capture |
|---|---|---|---|---|---|---|
| A1 | Quit WoW. A clean `Interface/AddOns/` copy (or delete any `ForeverCodex` and `QuestFlow` folders first). | Unzip `QuestFlow-<version>.zip` into `AddOns/`. | `AddOns/QuestFlow/QuestFlow.toc` exists, one folder deep. Folder holds only `.lua`, `.toc`, `.tga`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, `Data/`, `Media/`, `UI/`, `Providers/`. | Layout matches. | Extra folder level, other file types, or missing LICENSE. | Note the ZIP file name and size. |
| A2 | Character select. | Open the AddOns list. | **Quest Flow**, right version, the "questing companion" note, author Worsttrumpet, enabled, no "out of date" flag. | All correct. | Wrong name/version or out of date. | **SHOT** of the AddOns list (once). |
| A3 | Log in with `/console scriptErrors 1`. | Watch chat. | A load line naming Quest Flow and `/qflow` (a new character also gets a short welcome line). No Lua error popup. | Welcome shown, zero errors. | Any Lua error, or the words "Forever Codex" / "Codex" anywhere in the welcome line. | Copy the welcome line. |
| A4 | Fresh character data (no earlier settings). | `/qflow`. | Setup page "Welcome to Quest Flow"; Start works; the tracker fills in. | Works, no errors. | Blank page, cut-off text, errors. | **SHOT** of the setup page. |

| A5 | Logged in. | Look at the minimap button, the button on the world map (open the map), and the Quest Flow entry in the AddOns list. | All three show the **Quest Flow logo** (the compass-and-map badge), not the old "C on a book". The minimap and map buttons are round, with no square corners showing. | Right logo in all three, clean round edge. | The old logo anywhere, a square background, a blank or white box. | **SHOT** of the minimap button (zoomed) and the AddOns list. |

## Part B. Reload, relog, state

| # | State | Do | Expect | PASS if | FAIL if | Capture |
|---|---|---|---|---|---|---|
| B1 | Tracker open, a skip made, window moved. | `/reload`. | Same window place, same skip, same settings, no errors. | All kept. | Anything lost or an error. | Note which setting you checked. |
| B2 | Same. | Log out, log in. | Same as B1, and NOW matches your quest log now (not the state from before logout). | Fresh, correct NOW, settings kept. | Stale NOW, lost settings, errors. | **SHOT** of NOW after relog. |
| B3 | An earlier test build's saved settings exist (only if you have them). | With the game closed copy `SavedVariables/ForeverCodex.lua` to `QuestFlow.lua` in the same folder; log in. | Settings carry over (see CHANGELOG). | They carry over. | Errors or empty settings. | N/A if you start fresh. |

## Part C. Reward window (the most important part)

Use **real quest rewards**. Open the reward window by talking to the quest NPC with a finished quest and **do not click Complete Quest** until the checks are done (you can close and reopen).

| # | State | Do | Expect | PASS if | FAIL if | Capture |
|---|---|---|---|---|---|---|
| C1 | A reward with 4 choices (2 columns, 2 rows), for example Hidden Enemies (quest 5730). | Open the reward window. | Every reward has its small icon row in its **bottom-right corner**, inside its button. | All four rows visible, each on its own reward. | Missing, on the wrong reward, or floating outside the buttons. | **SHOT** of the whole window. |
| C2 | Same window. | Look at the **second (right-hand) column**. | Icons fully visible, not cut off by the window edge, nothing overlapping the item name. | Not clipped, readable. | Clipped, or covering the name/icon. | **SHOT** (second-column reward, zoomed). |
| C3 | A dialog with 3 choices (an odd number) and one with 2, if you can find them. | Open each. | Icons sit on the right rewards in the first row and the lone reward in the second row. | Correct attachment. | Misplaced or missing. | One **SHOT** of the 3-choice dialog. |
| C4 | Any reward window. | Drag the window narrower/wider or toggle the game's UI scale if possible, reopen the reward window. | Icons stay attached to the same rewards. | Still attached. | Detached, overlapping other UI. | **SHOT** only if it fails. |
| C5 | A dialog where Quest Flow recommends one reward (find one: a clear weapon or armor upgrade next to worse choices). | Open it. | The recommended reward has a **golden border** (all four sides) and a **star** at the right end of its icon row. No other reward has a border. | One gold border on the right reward, not clipped in either column; you can tell at a glance which to take. | Border on a different reward, two borders, clipped edge, covering the item name, no star. | **SHOT** of the recommended reward (do it for a left-column and a right-column pick if you can). |
| C6 | A dialog with **no** recommendation (for example two Mixed rewards). | Open it. | No gold border, no star, no text line; only the icon rows. | None of those. | A border or star appears, or a "no clear pick" line. | **SHOT**. |
| C7 | Rewards covering the icon types (you will not get all in one window). | Over several quests find each of: Upgrade (up arrow), Not an Upgrade (down arrow), Mixed (up and down arrows), Vendor (coin), Not Usable (X), Unknown (?). | Each icon is recognisable at normal size and matches the situation. | You can tell them apart without the tooltip. | Two icons look alike, or an icon is unreadable. | **SHOT** of each icon you find (reuse screenshots from other tests). |
| C8 | A reward Quest Flow marks Vendor. | Look at its row. | The coin icon is followed by the sell value (for example `2s 15c`), gold coloured. | Value readable, belongs to that reward, does not overlap the icon, the button edge or the window edge, not cut off. | Overlap, clipped, or the value of a different reward. | **SHOT** (zoomed). Compare against Blizzard's own "Sell Price" line. |
| C9 | Any reward window. | Hover each reward for about 5 seconds, then move between rewards. | Blizzard's tooltip appears as normal **with one extra line**: `QUEST FLOW: <UPGRADE / NOT AN UPGRADE / MIXED / VENDOR / NOT USABLE / UNKNOWN>`. It does not flicker, appear twice, or disappear. | One extra line, stable, Blizzard's item text and stat comparison still there, nothing else added (no stats, percentages, prices). | Flicker, duplicated lines, Blizzard's tooltip replaced, extra stat text. | **SHOT** of one tooltip. REPORT right after hovering (it counts hook activity). |
| C10 | Same. | Move the mouse off the reward. | The tooltip disappears normally. | Gone as usual. | Lingers or flickers. | None. |
| C11 | Same. | Close the reward window, reopen it, then click **Complete Quest** on a reward. | After closing or completing, no icons, border or star remain on screen. | Nothing left behind. | Leftover icons or borders. | **SHOT** only if it fails. |

### C12. Reward situations log

Do not change the advisor because a result is surprising: record what you saw. Fill one row per case (try to cover all seven). Quest id: `/qflow report` or a tooltip addon. "Expected" is your own judgement.

| Case | Quest id | Class / level | Reward choices | Quest Flow showed (icons, star?) | You believe the right choice is | PASS / FAIL |
|---|---|---|---|---|---|---|
| 1 Clear upgrade | | | | | | |
| 2 Clear worse item | | | | | | |
| 3 Mixed | | | | | | |
| 4 Vendor fallback (no choice is equipment) | | | | | | |
| 5 Not usable item | | | | | | |
| 6 Unknown / conflicting usability | | | | | | |
| 7 One clearly recommended choice | | | | | | |

Capture: **SHOT** for each row, and one REPORT taken with the window open for cases 6 and 7.

## Part D. Normal play

| # | State | Do | Expect | PASS if | FAIL if | Capture |
|---|---|---|---|---|---|---|
| D1 | Any character with open quests. | Accept a quest, finish an objective, turn in a quest, accept the follow-up. After each, wait a few seconds. | NOW / ALSO COMPLETE / READY TO TURN IN update by themselves within a couple of seconds. | Updates every time, no stale item. | Stale NOW, a finished quest still shown, needs `/reload`. | **SHOT** of a normal NOW + ALSO COMPLETE screen (once). |
| D2 | A quest you can abandon safely. | Abandon it. | It disappears from the tracker and NOW. | Gone. | Still listed. | None. |
| D3 | Any. | Walk to a different zone or area; if you can, go somewhere with no known quest position. | NOW and nearby information change with you. A quest with no known location is listed **without** an arrow or invented spot, and the old zone's items do not hang around. | Updates, nothing fabricated, nothing stale. | Wrong location shown for a quest that has none, or stale NOW after leaving. | Note the zones. |
| D4 | A character close to a full quest log (39 or 40 of 40) with a pickup nearby, if practical. | Look at NOW and the pickups. | Quest Flow does not tell you to accept a quest the game cannot take. | No impossible accept offered. | It recommends an accept with a full log. | **SHOT** if it fails. |
| D5 | A quest-starting item in your bags (a drop that begins a quest). | Look at the tracker. | It appears as a new quest item; using the item and accepting the quest behaves normally afterward. | Listed correctly, then gone after you accept. | Missing, or still listed after accepting. | None. |
| D6 | Party with another Quest Flow user (only if easy). | Turn on party cards. | Progress shows, no chat spam. | Works quietly. | Spam or errors. | N/A is fine. |

## Part E. Dungeon smoke test (quick; do not investigate further)

| # | State | Do | Expect | PASS if | FAIL if | Capture |
|---|---|---|---|---|---|---|
| E1 | A dungeon quest in your log. | Look at DUNGEON QUESTS and NOW outside the dungeon. | The dungeon quest is listed under DUNGEON QUESTS and is not NOW; other quests still work normally. | As described. | The planner breaks or the dungeon quest takes NOW from outside. | **SHOT** of the list. |
| E2 | Same quest done (or any dungeon quest ready to hand in). | Turn it in. | The tracker updates, no errors. | Updates cleanly. | Errors or a stuck entry. | None. |

## Part F. Diagnostics

| # | State | Do | Expect | PASS if | FAIL if | Capture |
|---|---|---|---|---|---|---|
| F1 | A reward window open (use the Hidden Enemies reward if possible). | `/qflow report`, Ctrl+C, paste. | A window opens with the text selected. First line: `=== QUEST FLOW DIAGNOSTIC REPORT v<version> ===`. | Correct title and version, no "PLAYTEST", no "Forever Codex". | Wrong title, empty window. | REPORT. |
| F2 | Same report. | Find the REWARD OVERLAY section. | It lists the reward buttons found, how many choices are annotated, tooltip hook counters and the build-hook line. | Enough to tell whether icons attached and the tooltip hook ran. | Section missing. | Same REPORT. |
| F3 | Same report. | Read it for private data. | It includes class, level, race, position and quest log, **and your character name and realm** (first line, the `Character:` line and the `live stores belong to:` line). It has no account, password or machine paths. | Only the above. | Anything else personal. | Note what you see. |
| F4 | Any. | `/codex report` and `/codex dev`. | Both still work (the old command is an alias; `/codex dev` opens the advanced window titled "Quest Flow - advanced view"). | Work. | Not recognised. | None. |
| F5 | Any. | Click the **Feedback** button in the tracker, write one sentence, create the report. | A short report is created and shown for copying; it does not include your character name and says it was saved locally, not sent. | As described. | Says it was sent, or includes the name. | **SHOT**. |

## Part G. Options and external data

| # | State | Do | Expect | PASS if | FAIL if | Capture |
|---|---|---|---|---|---|---|
| G1 | Options tab. | Toggle the arrow, replacing the game's tracker (then back), the world-map button; `/reload`. | Each takes effect and survives the reload. | All do. | Any does not. | None. |
| G2 | With QuestieDB installed, then disabled/not installed. | Log in each way; `/qflow questiedb`. | Loads either way; `/qflow questiedb off` turns it off. | Works both ways. | Errors without QuestieDB. | None. |
| G3 | Any. | Open each tab (Options, Themes, World, Journey, Appendices). | Titles read "Quest Flow"/no "Codex"; no text cut off by the longer name. | Clean. | Clipped titles or buttons (Quest Flow is longer than the old name). | **SHOT** of any clipped title. |

---

## Part H. World and travel (0.11.0)

Do these in the real client with the ZIP. After each, run `/qflow report` and look at the section **WORLD AND TRAVEL KNOWLEDGE**: each line is PASS, FAIL or PENDING. PENDING means "not tried yet", not a failure. A FAIL on an API line means that API does not exist on Forever: paste the report.

- [ ] H1. Open a flight master's map. Report: taxi API status shows which family answered; "the taxi map listed nodes when opened" PASS; "discovered flight paths recorded" PASS.
- [ ] H2. At that flight master, "direct flights recorded" PASS and "matched to Quest Flow's own flight data" is not FAIL. (If the node names differ from Quest Flow's data this says so.)
- [ ] H3. Take one flight. Report: "a real flight time measured" PASS (the timer hook line must be PASS too).
- [ ] H3b. (0.12.2) After the flight lands, `/qflow report`: "Last flight: COMPLETED <from> -> <to>, N s (arrival CHECKED)", and PASS for SELECTED, STARTED, COMPLETED, "a real flight time measured" and "an observed transport edge is registered". If it says UNRESOLVED or ABORTED, paste the report: the reason is in that line.
- [ ] H3c. (0.12.2) Fly the same route again: the measured time becomes the mean of both. Open the map without flying: nothing is added.
- [ ] H11. (0.12.2) Appendices > What Quest Flow knows: the seven buttons fit inside the window, and every category scrolls (mouse wheel or the bar) so no text runs past the bottom.
- [ ] H4. With a quest far away in an area you can fly to, check the plan shows a **Fly** step first, the arrow points at the flight master, and the step after the landing walks to the objective. Skip the step and confirm Quest Flow does not nag.
- [ ] H5. A flight path you have NOT discovered must never appear in a Fly step. Compare against your game's own taxi map.
- [ ] H6. Open a vendor, a trainer and an innkeeper's window. `/qflow services vendor` (and `trainer`, `inn`) lists them with a place near where you stood.
- [ ] H7. Bind at an innkeeper. Report: "a bind point learned from binding" PASS. If the line stays PENDING, paste the report: the bind message may differ on Forever.
- [ ] H8. Enter a dungeon from outside, leave, and `/qflow services dungeon` lists it near the real entrance.
- [ ] H9. Report: "the Hearthstone state is readable" and "money is readable" PASS.
- [ ] H10. Appendices > What Quest Flow knows: the seven buttons switch categories, text is not clipped, counts match what you did.

## Part I. What comes next (0.12.0): the level 16 / Ruins of Lordaeron test

Run `/qflow report` at each step and read the section **PLANNER FUNNEL**.

- [ ] I1. Before anything else: the funnel shows `Green range N (client)` or `(default ...)`. If it says default, `GetQuestGreenRange` does not exist on Forever: note it, no action needed.
- [ ] I2. With your level 16 character and a Ruins of Lordaeron quest in your log: `Goal: dungeon ...` is listed. If it says `Goal: none known ... quest-tag API did not answer`, paste the report: the goal logic cannot work until the game tags those quests.
- [ ] I3. NOW is not a level 6 quest or a donation quest. In the funnel, every low-level quest is listed as `EXCLUDED ... GRAY` (or `PENALIZED ... LOW`), with its band.
- [ ] I4. If "A Donation of Wool" is still NOW: paste the report. The line `NOW is ...: band X (basis)` says whether the level was known. `UNKNOWN (only a required level ...)` means the data gave no quest level and the planner cannot judge it (see docs/PLANNER_FUNNEL.md, Not solved).
- [ ] I5. A hand-in for a Ruins of Lordaeron quest, if you have one finished, is NOW or next, listed `BOOSTED ... GOAL_QUEST`.
- [ ] I6. `/qflow seasonal` says seasonal quests are left out; a holiday quest is not suggested. `/qflow seasonal on` then `off` returns to that.
- [ ] I7. A quest you added with `/qflow add` appears even if it is gray (reason PINNED).
- [ ] I8. (0.12.1) With a Ruins of Lordaeron hand-in ready and you in Undercity: the hand-in is in the plan (NOW or the sequence), not left out. Walk away to about 1000 yards: the arrow and waypoint are present for a hand-in at a named NPC.
- [ ] I9. (0.12.1) `/qflow report`: the Hearthstone line reads PASS (the Hearthstone is found, even if the game has no item-count function).

## Part J. The welcome (0.13.0)

- [ ] J1. A brand-new character (or one that has never run this version): Quest Flow loads and the welcome opens by itself, with the logo and "See what's available. Choose what comes next." Check it at your normal resolution: nothing runs off the window.
- [ ] J2. Step 1 is short and readable: NOW, ALSO DO, and the line about what the game itself offers. No technical words.
- [ ] J3. Step 2: the theme dropdown changes the look of the window as you pick; the tracker, waypoint and arrow checks do what they say.
- [ ] J4. Step 3: Where to level / How to play / the extras still work. **Get Started** closes the welcome and opens the tracker (or just closes it if you turned the tracker off).
- [ ] J5. `/reload`, then log out and in, then (if practical) restart the game: the welcome does not come back. Open and close the Quest Flow windows: it does not come back.
- [ ] J6. Log in with a second character: it gets its own welcome. Log back to the first: none.
- [ ] J7. An existing character with Quest Flow data (for example Codex Runner): the welcome shows once; afterwards its style, skips, journey and theme are exactly as before.
- [ ] J8. `/qflow setup` shows the welcome again; your settings are unchanged; finishing it returns to normal.
- [ ] J9. After Get Started: the plan, tracker, arrow, a reward dialog, and `/qflow report` all still work.

## Part K. Unknown pickups (0.14.0)

- [ ] K1. Find a quest Quest Flow knows (its giver is in the report's quest data) that you have not been offered. `/qflow report`, "PLANNER FUNNEL": it is listed `OPTIONAL: unknown availability`, and it is NOT the NOW or THEN pickup. If it sits right beside your route it may show as ALSO DO, marked "not offered yet".
- [ ] K2. Walk to the giver and open the dialog so the game offers the quest. After that the report says `AVAILABLE: client offered` and the quest can be NOW or THEN like any pickup.
- [ ] K3. A quest whose giver was asked and did not offer it shows under HELD, not as optional. Level up or hand in a quest: it is released (optional again).
- [ ] K4. A quest you hold (objective or hand-in) is planned as always. A quest you added with `/qflow add` is planned as always.
- [ ] K5. Mura Runetotem-style case: a quest the game offered is still NOW, and is labelled AVAILABLE in the report.

## Part L. 0.14.1

- [ ] L1. With ready hand-ins and an untouched quest whose objective has no known place (for example The Sacred Flame 0/1): NOW is a hand-in with an arrow, not the placeless quest.
- [ ] L2. Make progress on that placeless quest (a count above zero): it can be NOW again, and the NOW row says "Place not known: see your quest log".
- [ ] L3. Fly the Orgrimmar to Thunder Bluff route: the report shows a second measured edge; the route back is priced by the measured time only for the direction you flew.

## Evidence to keep (screenshots)
1. AddOns list (A2). 2. A normal NOW / ALSO COMPLETE screen (D1). 3. Reward window with all icon rows (C1). 4. A second-column reward (C2). 5. The recommended reward with the golden border and star (C5). 6. A vendor reward with its price (C8). 7. A tooltip with the Quest Flow line (C9). 8. Each icon type (C7). 9. One `/qflow report` (F1).

## Recommended order (fastest path)
1. **A1 to A4** (install the ZIP, load, setup). If A3 fails, stop.
2. **C1, C2, C5, C8, C9** on the first reward windows you meet. These are the highest-risk items.
3. **B1, B2** (reload and relog).
4. **F1 to F2** with a reward window open, then **F5**.
5. **C6, C7, C3, C4, C10, C11** as more rewards come up; fill the **C12** table as you go.
6. **D1 to D5** during normal play.
7. **E1, E2** when you next have a dungeon quest.
8. **F3, F4, G1 to G3** last.

## Results

| ID | PASS / FAIL | What you saw (one line) | Release blocker? |
|---|---|---|---|
| | | | |

## Before publishing
- The screenshots above exist.
- The version in the AddOns list matches the ZIP name and `CHANGELOG.md`.
- The manual GitHub and CurseForge steps in `docs/release/CURSEFORGE.md` are done.

## Part M - tracker (0.14.3)

- [ ] Click the NOW quest title: its details open; click again: they close. The arrow/route does not change.
- [ ] "IN YOUR LOG, NOT ON THE MAP" is the last section. Click its header: it folds to one line with the count; /reload keeps it folded.

## Part N - Hearthstone and bind point (0.14.4)

- [ ] Report before: "bind point NOT learned"; Hearthstone state is ready/cooldown (not unknown).
- [ ] Either bind at an innkeeper (talk, "Make this inn your home", confirm) OR use your Hearthstone once and let it finish. Report: "a bind point learned" PASS, "learned (map N, from ...)".
- [ ] Walk 300+ seconds away from the inn with the Hearthstone ready: a quest far from you can show "Use your Hearthstone" as a travel step; with it on cooldown it never does.

## Part O - boats and zeppelins (0.15.0)

- [ ] Take a zeppelin or boat to another continent (for example Orgrimmar to Undercity). Do not cast anything while waiting. Stand still on the dock after you arrive for a few seconds.
- [ ] Report: "a boat or zeppelin ride recorded (1 ...)" PASS and a line "<from> -> <to>: N s shortest".
- [ ] If it says "not recorded because ...", send the report: the reason names what blocked it.
