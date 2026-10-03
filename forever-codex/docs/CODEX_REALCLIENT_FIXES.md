# Forever Codex 0.2 alpha: fixes after the first real-client test

Evidence (character Roy, level 21 Skyborne Hunter, Silverpine Forest / The Sepulcher, map 1421): a protected-action popup at
login; a plan telling the player to travel to Thork in The Barrens; no direction arrow; no map/minimap guidance.

## 1. Combat-log taint (fixed)
The WoW taint log blamed `Telemetry.lua registerAll()`. Real-client test: registering `COMBAT_LOG_EVENT_UNFILTERED` returns
`IsEventRegistered = false` plus a "forcetaint_strong has been blocked" popup; `PLAYER_REGEN_DISABLED` registers fine.
**Forever blocks addon registration of the combat log.** Codex no longer registers it (anywhere). The MOB_KILL handler stays for a
future proven source but nothing feeds it. `MOB_KILL` is reported **UNAVAILABLE** (not "unproven") in `/codex telemetry`, `/codex diag`
and the capability table; the player-facing summary no longer lists "Creatures defeated". Proven quest telemetry (accept, objectives
complete, turn-in, movement) and the XP / level / regen code are untouched. Regression: no frame registers the combat log; capability
status; the claims scan.

## 2. Silverpine -> Barrens (diagnosed and fixed)
Reproduced with the real data: **0** candidates located on map 1421 for this character (everything level-appropriate is in
Kalimdor or elsewhere), 105 candidates in total.
| Hypothesis | Verdict |
|---|---|
| stale quest state | No. Q6541 is an ACCEPT from data; it is not in the quest log. |
| missing / unknown location | Partly: nothing in Silverpine, so every stop was reached through a cross-continent leg. |
| **planner scoring** | **Yes, the cause.** A leg whose walking time cannot be known (other continent) was priced `(t or 0)`: zero seconds. Ten ATT-only accepts across the sea looked free, net +252. Unknown legs only tied-broke on count. |
| source-trust handling | Contributing: the data is ATT (unverified); it was only discounted 10% and nothing else. |
| route-zone behaviour | No (`auto`; the zone filter was not active). |
Why distance showed nil: the plan's NEXT was the engine-made TRAVEL step; unmeasurable legs have no yards.
**Smallest correction** (no policy value changed): an unmeasurable leg is **charged** `Planner.UNKNOWN_LEG_SECONDS` (900 s, a policy
estimate for a boat/flight/long ride). A sequence that is reachable only through such a leg and does not pay for itself (net < 0) is not
recommended: `diag.reason = ONLY_DISTANT_UNMEASURED`, NOW is nil, nothing is navigated. ATT data is NOT banned: it is used whenever the
trip pays, when the player chose that route zone, or when the player added the quest. The player's own quests are always considered.
The Phase 2.5 baseline is byte-identical (no evaluation scenario had an unmeasurable leg in its chosen plan). One Phase 2 assertion
encoded the bug ("a lone far quest is NOW") and was changed deliberately.

## 3. Direction arrow (implemented, UNVERIFIED on Forever)
Evidence (M8.14 v0.1, real client): `GetPlayerFacing` exists; `Texture:SetRotation` works; `Interface\Minimap\MinimapArrow` loads.
Not measured: the facing convention (value at north, clockwise or counter-clockwise) - M8.14 v0.2 results are still outstanding. The
built-in waypoint (M8.10) exposes only a map/coordinates and super-tracking; no direction API, and `C_Navigation.GetDistance` is
unreliable. So Codex draws its **own** small frame and **learns the convention while you walk**: it compares the compass direction of
your movement (map positions, proven) with `GetPlayerFacing` and solves `facing = s * compass + offset` (needs several headings and a tight fit,
else the arrow stays hidden and says "Walk a few steps to aim the arrow"). Remembered across sessions. Assumed and unproven: the art
points up at rotation 0 and positive rotation is counter-clockwise; `/codex arrow flip` inverts it if it is mirrored.
It points at NOW's destination while navigation is on, hides on arrival / no NOW / `/codex nav off` / the player's own waypoint, never
places, moves or clears any waypoint, uses no secure frames and no hooks. `/codex arrow [on|off|flip|reset]`, draggable, position saved.

## 4. Map / minimap pins (world map implemented behind capability checks; minimap omitted)
No project evidence exists for `WorldMapFrame:GetCanvas()/GetMapID()` or for the minimap zoom/radius/rotation needed to place minimap pins.
- **World map**: Codex's own small frames on the map canvas for NOW's and ALSO DO's targets only (giver, objective area, turn-in, flight master).
  Feature-checked; absent = no pins, no error. **Unverified on Forever.** Trust: only a Forever-observed, exact, non-assumed location is drawn solid;
  ATT-derived, area, assumed-turn-in and player-position locations are dim "?" with an "Approximate location" tooltip. Codex only ever hides
  frames from its own pool; it never walks the map's children and never touches the waypoint. `/codex pins [on|off]`.
- **Minimap**: not implemented. Guessing the radius would put pins in the wrong place. Reported as "not supported".

## 5. Objective guidance (Part 5)
The kill count shown is the **quest log's own** objective progress (`GetQuestObjectives`, proven M8.9): it does not depend on the combat log.
If the log gives no counts, no number is shown (never a fake `0 / 6`). The objective's area (ATT, approximate) feeds the arrow and the dim
objective pins.

## 6. UI pass
One dropdown replaces the tab row; the Codex page has no back/forward arrows. NOW is centred in its card; NOW and NEARBY stack on the left;
NEW FOR YOU is a separate card on the right spanning both (absent unless active, and the left column then uses the full width).
NEARBY: the Planner's ALSO DO, plus a flight master within 150 yd (flight-hint system on). Inns, mailboxes, vendors and trainers are
**not** listed: no trustworthy data exists. NEW FOR YOU: checked only on reaching an even level (every even level crossed; login is a
baseline); providers return real items or nothing; shown for exactly 60 s, then gone. One provider ships: quests Forever's own data shows
(an observed record) whose required level (ATT) was just met. No spell/trainer/recipe/pet provider (those client APIs are unverified).
A new quest never changes NOW.

## 7. XP tracker
Not built or displayed. XP_GAIN / LEVEL_UP / combat events remain unproven; XP/hour and XP/kill stay hidden.

## Real-client status
Everything above except the combat-log change is **stub-tested only**. To verify on Forever: (a) login shows no protected-action popup;
(b) `/codex arrow` - walk in a few directions, check the arrow, try `flip`; (c) `/codex pins` and the world map on the right zone;
(d) an even level-up; (e) the Silverpine character now gets "Nothing to recommend" instead of a trip to the Barrens.

## 8. Raid markers (Part 10): hardened, NOT yet verified on Forever
**The probe has not been run on the real client** (there is no client in this environment), so markers are still OFF
(`markers: off (test not run)`). Nothing here claims `SetRaidTarget` works on Forever.
What the existing system did, and what was fixed (no rewrite; assignment logic unchanged: star = NOW's NPC, diamond = ALSO DO's NPC,
triangle = a relevant flight master, moon never set; only NPCs identified by creature id, never assumed turn-in NPCs, never objective areas):
- It could **replace** a different mark on the NPC, **re-set** a mark the player had removed, **claim** an identical icon it had not placed,
  and the probe could mark a player target. All fixed: Codex only places a mark on an **unmarked** NPC, records what it placed, never
  replaces or claims anything else, **yields** when its own mark disappears (until the plan for that symbol changes), and clears **only**
  marks recorded as its own (still cleaned up when markers are switched off).
- The probe now refuses a player target and an NPC that already carries a mark, places the star, reads it back, **clears it and checks it
  cleared**, and on success records "passed" and switches markers on. It cannot detect taint (the popup is shown by the client): the note says so.
To verify on Forever: target an unmarked NPC, type `/codex markers probe`, **watch for a blocked-action popup**, then target the NPC of
your current NOW (e.g. a quest giver) and check the star; change NOW and re-target the old NPC to see Codex's mark removed; remove it
yourself and confirm Codex does not put it back. Markers appear only while the NPC is your target or mouseover (that is when Codex sees its identity).

## 9. "The Weaver": looting Ataeric's Staff was not announced (Part 11)
**Diagnosis from the code (the real log of that session was not available, so the exact loss on the client is NOT yet proven):**
| Stage | Finding |
|---|---|
| WoW state | Item objectives are read with `C_QuestLog.GetQuestObjectives` (`numFulfilled/numRequired/finished`); M8.9 proved this is current at `UNIT_QUEST_LOG_CHANGED("player")` for item objectives (14 of 15 steps were items). No combat log is involved. |
| Observation | Boot marks the state dirty on `UNIT_QUEST_LOG_CHANGED("player")` and `QUEST_LOG_UPDATE`; the next Recompute rebuilds the context and diffs it. Both events were already wired (not accept/turn-in only). |
| Telemetry | Recorded only `QUEST_COMPLETE`; **no per-objective event existed** (now `QUEST_OBJECTIVE`). |
| Party | Detection by diff existed. **Default mode is `ui`, which sends only an invisible addon message and never writes in /party**: the most likely reason no /party line appeared. Chat text also carried no objective detail, and the quest name came only from ATT data ("a quest" for a quest the data lacks, as The Weaver may be). A planner error also skipped the party observer. |
| Unknown | whether the client reported the group (`GetNumGroupMembers/IsInGroup` are unprobed) and whether the objective really read 1/1 at that moment. |
**Changes (narrow):** the party line is now `Codex: Quest complete: The Weaver - 1/1 Ataeric's Staff` (all objectives listed; names from the quest log when the
data lacks them); a finished objective of a multi-objective quest says `Codex: Objective done: <quest> - 6/6 <objective>`; turn-in uses the last snapshot's name.
Party chat still needs mode `party` or `both` (Appendices > Settings > Party news): chat is never on by default. Context-only observers (party, journey,
new-for-you) now run before the planner, so a planner error cannot hide a finished objective. Telemetry gains `QUEST_OBJECTIVE` (one event when an objective finishes),
labelled proven only for what M8.9 proved (reading objectives); its diff is stated as untested on the client.
**`/codex party log`** prints the last decisions: what was seen, whether you were in a group, the mode, whether the addon message and chat were sent, and why not.
**To settle it on Forever:** set Party news to *Party chat* or *Both*, loot a quest item objective in a party, then `/codex party log` and `/codex telemetry events`.

## 10. Arrow never appeared (real-client debug)
`/codex arrow` said "on, no destination, calibrated: false". Findings:
1. The frame is a small 64x70 frame at the top-centre of the screen (140 px down), draggable (position saved).
2. It was built lazily, only when first shown, so with no destination it never existed.
3. `GetPlayerFacing` works on Forever: M8.14 v0.1 recorded 2301 samples between 0.007 and 6.283 (a normal heading in radians).
4. The self-calibration was only reached **after** the "has a destination" check, so with no NOW it could never start: a real flaw. It now learns while the arrow is on, whether or not there is a destination.
5. Hiding with no destination is intentional. The arrow needs a NOW with a known location. In Undercity the plan said `ONLY_DISTANT_UNMEASURED`, so there was no NOW and no arrow.
Changes: frame created (hidden) at the first tick; learning independent of destination; `/codex arrow` now prints destination yes/NO, frame created/shown and where, GetPlayerFacing available and its current value, learned or not and the samples this session;
`/codex arrow test` shows a spinning arrow for 10 s with no destination and no navigation involved, to prove the frame, texture and rotation on the real client.
To get a destination for a real check: `/codex add <quest id>` (a quest you add is always planned), or stand in a zone with quests. Still unverified on Forever: the frame's appearance, texture orientation, rotation sign (`/codex arrow flip`), and the learned convention.

## 11. The minimap button could not be moved
The button was visible but fixed. Causes (all found in the code, none needed a client change):
1. **No drag support at all.** `MinimapButton.lua` (a copy of the M8.13 button) never called `SetMovable` / `RegisterForDrag` and had no `OnDragStart` / `OnDragStop`, so nothing could start a drag.
2. **No saved position.** Nothing stored where the button was.
3. **A second path reset it.** `Boot.lua` re-anchored the button to a fixed spot (34 px down) at every login, which would have erased any saved position.
Changes: the button is movable, takes the mouse and is registered for left-button drag; `OnDragStop` always releases the drag first, then saves the anchor (point, relative point, x, y against UIParent) through
`Preferences` (validated on read: an unknown anchor, a non-number, NaN or a huge value falls back to the default spot, so a damaged file never loses the button); the position is applied by the button itself at build time
(saved, else the old default) and Boot no longer re-anchors it; releasing a drag over the button does not also toggle the window; the button stays clamped to the screen; `/codex minimap reset` restores the default spot.
The same mechanism (SetMovable + RegisterForDrag + StartMoving / StopMovingOrSizing + GetPoint saved to SavedVariables) is already proven on Forever for Codex's window and arrow. It is NOT proven for this button until it is tried in-game.
The position is not a ring-orbit one (that needs the minimap's geometry, unverified on Forever); the button is placed freely and stored against the screen.
**Real-client check:** `/reload`, drag the button somewhere, release (it must stop following the mouse and the window must not open), `/reload` (it stays), log out and in (it stays), `/codex minimap reset` (it goes back).

## 12. Player UI polish (presentation only)
A visual pass over the Codex page and the window shell. Nothing that decides or routes changed: the Presenter, Planner, data, QuestieDB bridge, telemetry, navigation, arrow, minimap button, SavedVariables and slash commands are untouched, and the page still only draws what the Presenter / Nearby / NewForYou / Party hand it.
* **NOW** is the strongest card: a warm gold 2 px edge, a slightly warmer fill, a 16 px gold action title over a 12 px location line, 11 px detail and 10 px "why". The marker square is hidden when there is nothing to recommend.
* **Objective progress**: when the Presenter reports counts ("4 / 6") a flat bar with the numbers beside it replaces the plain text; with no counts the old behaviour is kept and no number is made up.
* **NEARBY** is cooler (muted violet-blue edge), smaller, and fits its rows (56 px when it has nothing to say, was a fixed 168 px).
* **NEW FOR YOU** is narrower (192 px), has a quiet gold top edge, and fits its content instead of spanning NOW + NEARBY.
* **Shell**: a 1 px muted-gold border, a small title, a separator under the header. The window stays 520 x 430 (resizing it at run time would make a CENTER-anchored window jump).
* **Reusable**: `W.Card` + `W.STYLE_*`, `W.Stack`, `W.Progress`, `W.Label`, `W.Line` (Widgets.lua). A future panel is a new style plus its own lines; no feature for one exists.
* **Type sizes** come from the game's own font file (`GameFontNormal:GetFont()`); if the client will not say which file that is, the text keeps its normal size and the layout still works.

**Real-client check (screenshots, with the Hunter):** the Codex page with a NOW that has objective progress (bar + "4 / 6"), one with a turn-in (e.g. Deathstalkers), the empty NOW, NEARBY with and without rows, and NEW FOR YOU at an even level. Unverified until seen: whether the larger type sizes render, the exact colours against your UI, whether the 2 px edges are crisp.

## 13. Party chat announcements removed (0.2.1)
Questie already announces quest completion and similar status, so Codex no longer writes anything to party chat (or any chat channel): the `party` and `both` modes, the "Codex: Quest complete / Objective done / Turned in" lines and the chat rate limit are gone. Kept: the quest/objective detection and telemetry, the planner, and the **invisible** addon message plus the Party card (what other Codex users in your party finished), which are not chat. Party news is now `off` or `ui` (default `ui`); a saved `party` or `both` is read as `ui`. No replacement message was added. `/codex party off|ui|log`.

## 14. Release 0.2.2: planner and arrow fixes from the first 1-20 run

Install `forever-codex/dist/ForeverCodex-0.2.2.zip` (0.2.1 stays in `dist/`).

- **Turn-in destination.** A quest that completes instantly (shown as TURN_IN) used to be routed to its GIVER. The provider now routes to the
  turn-in NPC when the data names a different one with a position; with no position it is a reminder with no location; only a
  same-NPC / no-data quest is "assumed" at the giver. Giver, turn-in and objective places stay separate.
- **Skip on NOW.** A small Skip button on the NOW card (same as `/codex skip`); `/codex unskip` brings items back. NOW can no longer leave you stuck.
- **Local progression.** The planner prefers level-appropriate work in the player's current area before distant quests (`Pl.LOCAL_FIRST`);
  in-progress objectives here make a location-less NOW ("Finish X") rather than a trip elsewhere. Nothing is tied to a zone, level or class.
- **Turn-in before pickup.** A finished quest's hand-in outranks a new pickup at the same stop, or at a stop that costs little extra walking
  (`Pl.TURN_IN_FIRST`, 45 s margin, priced with real travel costs; far or unmeasurable hand-ins are never forced; objectives in progress keep
  their own batching rule). Tier order at one spot: hand-in, objectives, pickups. Stickiness does not override this.
- **NEW FOR YOU** is no longer a quest list. It shows only new class abilities verified from the Forever client; with no verified source none ships and the card stays hidden.
- **Arrow.** Plain left-drag moves it, Shift+left-drag resizes it (24-120, saved in SavedVariables), hover shows a tooltip (Drag / Shift + Drag / `/codex arrow flip`).
- **Direction only (not implemented): dungeon awareness.** A future "DUNGEON READY" card (N/M relevant dungeon quests) is a planner direction,
  built from existing quest knowledge and provenance, never a replacement for NOW. Future card order: NOW, NEARBY, NEW FOR YOU, DUNGEON READY.

Planner baseline: only scenario J changed (the hand-in now leads at the shared stop; identical net and time).

Real-client checks still owed: Shift-drag/tooltip on the arrow, the Skip button, local-first and turn-in-first on a fresh character, the turn-in route for a quest that completes instantly.

## 15. Release 0.2.3: the window fits the Codex page
The Codex page left a large empty area under its cards (the window was a fixed 430 px). The window height now fits the page content (never below 150 px); the other pages keep the full 430 px. The window's top edge stays where it was when the height changes (the saved position records the height it was saved at). Presentation only: the planner, data and 0.2.2 behaviour are untouched.
Real-client check: the Codex page with and without NEARBY rows / reminder line / party card, switching pages from the dropdown, and dragging then `/reload`.

## 16. Release 0.2.4: `/codex report` is the one thing to paste
`/codex report` opens a larger, scrolling window with the text already selected: press Ctrl+C, then paste it into the chat (Escape or Close dismisses it; "Select all" re-selects). The report holds what the Codex window shows (NOW / ALSO DO / THEN / NEARBY / NEW FOR YOU / not-placed quests), why the planner chose it (reason, flags such as localOnly / turnInFirst / stuck, net, each stop with its distance and the best plan starting there, rejected ALSO DOs), the quest log with objective progress and READY TO TURN IN marks, skipped keys, and then the full `/codex diag` text. The trace is a re-run on the same inputs: the live plan is not changed. No new command; `/codex diag` still prints to chat.
Real-client check: the window opens with text highlighted, Ctrl+C copies it all (scroll down to see it is long), Escape closes it.

## 17. Release 0.2.5: cleanup (no automatic markers, no Codex map pins) and a readable report
**Removed.** Automatic world markers: `Markers.lua`, every `SetRaidTarget` / `GetRaidTargetIndex` call, `/codex markers`, the Setup toggle, the target / mouse-over event handling and the marker diagnostics. The real client showed a blocked-action popup when the marker test ran (and the mark did not read back): the call is not available to addons on Forever. A test now fails if any addon file mentions a raid-target API or the marker-only events. Codex map pins: `Pins.lua`, `/codex pins`, the Setup toggle and the pin diagnostics; Codex no longer draws anything on the world map. **Kept:** the waypoint (Navigation, MapPin "show it on the map"), the arrow, and all coordinate / distance logic. Old saved `markers` / `pins` choices are ignored. A manual, context-aware skull button for named NPCs is a possible FUTURE feature and is not built.

**`/codex report`.** Sections: WHAT THE WINDOW SHOWS, WHY (reason, flags, net, time, unknown legs, sequences, rejected ALSO DO), SEQUENCE (plain instructions: "Travel to X / Turn in Y [Q:id]"), NEAREST RELEVANT STOPS (about 15, nearest first, with quest id, name, action and yards; unmeasured distances say so; the end counts how many farther / unmeasured stops were left out), NOT PLACED (see below), QUEST LOG, FULL DIAGNOSTICS.

**NOT PLACED: where could a location come from?** For each quest Codex cannot place the report now says, per layer: Codex's own data (observed / QuestieDB pack / ATT: giver place, turn-in place, objective places and which layer supplied them); QuestieDB directly (is the quest known, do its giver and turn-in NPCs have a position, how many entries each objective slot holds and how many NPCs among them have a position; which QuestieDB tables are exposed, i.e. whether object / item data is reachable); and the game's own quest-map points for the current map (`C_QuestLog.GetQuestsOnMap`: present on Forever, never probed). Nothing is guessed or added: it only shows which layer lacks the data.
Findings so far: none of Q:86784, 95314, 97558, 97959, 99134, 99141 (nor 91209, 96658) is in the observed pack or in ATT, so any location would have to come from QuestieDB; the bridge reads no objective locations at all (an objective is "unplaced" unless ATT supplied coordinates, which it cannot for these quests). That makes unplaced OBJECTIVEs a bridge gap first and missing data second; a real report from the client will say which.

## 18. Release 0.2.6: a compact right-side tracker, deferred turn-ins, the quest-log limit
**Tracker.** The Codex page is now a 270 px panel that opens at the right of the screen where the quest tracker normally sits (TOPRIGHT, below the minimap). It is movable and remembers where you put it (a position saved by the older big window is dropped once). Other pages (Setup, World, Journey, Appendices) keep the full size. Sections, each hidden when empty: **NOW** (the quest, and EVERY unfinished objective with its own count and thin bar; finished objectives drop out), **ALSO COMPLETE THIS** (other unfinished objectives that fit with NOW, a bar each, plus the planner's own ALSO DO line), **READY TO TURN IN** (finished quests waiting for the right moment), NEW FOR YOU (only with a verified source; none ships). The "why" sentence is no longer drawn; it is still computed and is in `/codex report`. NEARBY (flight-master hints) is no longer drawn in the window (the module and the report keep it). Bars are textures: the UI is ASCII-only, so block characters and check marks are not used.
**Overlap, honestly.** `Overlap.lua`. A quest overlaps NOW when NOW is an objective and the other quest's objective spot is known and within 300 yd of NOW's (or of you), or its spot is unknown but its ZONE is the one you are working in. Codex has no spawn points for most objectives, so "same zone" is the best the data supports; it is weaker than "same spot" and the code says so. Quests with no known zone are never offered. At most 3 quests.
**Deferred turn-ins (planner).** A finished quest is no longer sent to NOW just because it is finished. With work underway here (a located objective stop on your map, or an in-log quest in this area whose objective counts show it has been started) a hand-in that is not within 150 yd waits and is listed under READY TO TURN IN; when the work is done, or the hand-in is close, it becomes NOW, and hand-ins within 60 yd of each other are one stop (one trip). Never applies to a quest you added. Baseline changes (two, both intended): scenario A1 now continues "Sting of the Scorpid" instead of handing in; one sweep row defers "The ready quest" behind a local objective.
**Quest-log limit.** The normal quest log holds 40 quests (stated by the project owner, not probed from the client; `Engine.QUEST_LOG_MAX`). The count comes from the quest log itself (`ctx.logCount`). At 40/40 no new quest is recommended; at 38+ (two or fewer free) hand-ins are no longer deferred, since each frees a slot. A finished quest still holds its slot. Not built yet: quest-starting items (tracked separately from the 40 slots) and conditional drop opportunities; the report says so.
**Candidate funnel.** `/codex report` has a CANDIDATE FUNNEL section: known quests -> not for this character (faction / race / class / repeatable / completed / skipped) -> FUTURE (level too high, earlier chain quest unfinished) -> CURRENT pickups / objectives / hand-ins -> stops -> sequences, plus the quest-log count. The planner already filters this way (Engine / Providers/Quest eligibility); the funnel just makes it visible.
**Not implemented (data model cannot support it yet):** a compact collapsed mode (the panel is already small); overlap by spawn location for quests without objective coordinates; quest-starting items and drop opportunities; promoting a hand-in because it frees a slot beyond turning off deferral; any accept-batch re-planning beyond the existing recompute on quest events (a quest accept already triggers a recompute).
Real-client checks: the tracker's place and size on your UI, the objective rows and bars, ALSO COMPLETE THIS with a real overlap, READY TO TURN IN, and that finishing a quest while others are underway no longer sends you back.

## 19. Phase 3 finding: level 10 and the Paladin trainer (v0.2.5, real client, build 70170)
**What was observed.** At level 10 `/codex report` showed `LEVEL_UP[UNPROVEN reg=true rec=1]`: Codex recorded one level-up. The player then trained a new level-10 Paladin spell and ran the report again: `LEVEL_UP` stayed `rec=1`, no trainer-specific or spell-training event appeared, quest state and planner state were unchanged, the arrow stayed on and pointing, and Recomputes went from 987 to 1005.
**What it means.**
* Codex can observe the character reaching level 10 (the level-up event fired and was recorded). The `UNPROVEN` label comes from the capability table and has not been changed by this note.
* v0.2.5 does not observe the spell-training action. This is expected rather than a client finding: Codex registers no trainer or spell events at all (no `TRAINER_*`, `SPELLS_CHANGED` or `LEARNED_SPELL_*` registration), so the silence says nothing about whether the client raises them. It only says Codex was not listening.
* The recompute increase is planner activity, not a gameplay-event count, and must not be read as Codex detecting the trainer. Earlier trainer visits showed the same pattern (98 -> 121 -> 222 with no change in state).
**Decision.** No trainer support is added on the strength of this test, and NEW FOR YOU stays hidden (no verified ability source). If trainer or spell-learning events are ever wanted, the first step is a read-only probe of which events and trainer-window calls the client really provides (see the NEW FOR YOU investigation: a trainer-window snapshot is the only reliable source found, and it is unproven on Forever), not a feature. This note changes no code and no version.

## 20. Release 0.2.7: a larger tracker and an opt-in switch for the game's tracker
From the 0.2.6 screenshot: the panel was too small next to the game's tracker. The Codex page is now 330 px wide with larger type (title 16, rows and lists 12, details 11) and taller progress rows; READY TO TURN IN shows short distances ("350 yd", "nearby") so rows no longer cut off.
**Hiding the game's tracker (opt-in, OFF by default, UNVERIFIED on Forever).** `/codex tracker on|off` (and Settings > "Hide the game's quest tracker"). It calls only Hide / Show on the tracker's top frame (`ObjectiveTrackerFrame`, the retail-style "All Objectives" frame the client shows; the Classic names are the fallback) and keeps it hidden with a post-hook on that frame's Show. It never reparents, unregisters events, or touches child frames or alpha, and off restores it at once (a /reload always does). Not verified: that the frame has that name here, and that the game never re-shows it by another path. `/codex tracker` and `/codex report` say which frame was found and its state. Leave it off if Questie's own tracker is on (both would manage the same frame). If the real client raises a blocked-action popup when turning it on, tell us: the answer is to remove the switch, not to work around it.

## 21. Release 0.2.8: a round minimap badge, and no "not on the map" line
* The "Not on the map: ..." line under the Codex cards is gone from the window. Those quests are still listed, with where a location could come from, in `/codex report` (NOT PLACED).
* The minimap button is now a 32 px round badge: a gold ring around a "C" on an open book, a single picture (`ForeverCodex/Media/CodexIcon.tga`, 64 x 64, 32-bit TGA with transparent corners) so it is a circle with no dependence on a game texture path. The art is original, drawn by `generator/make_art.py` (pure Python; rerun it to regenerate the file; `--preview x.png` writes a picture). Dragging, saving the position, the tooltip and click behaviour are unchanged. It is a little brighter under the mouse.
* Not verified on the real client: that the game loads the TGA from `Interface\AddOns\ForeverCodex\Media\` on Forever (a missing file would show a plain white square). Screenshot please.

## 22. Release 0.2.9: tracker + a tabbed options window, no dropdown, no star box
* **Two windows.** The TRACKER (the compact Codex page) is all the old main window is now: a small title, an "Options" button and the cards. The OPTIONS window is a separate, movable, full-size window with tabs along the top (Codex Options, World, Journey, Appendices), the way most addons do it. The dropdown (and its arrow glyph) is gone.
* **Where things went.** Settings (first-time setup, then waypoint, arrow, the game's quest tracker, Hardcore, party news, "Run setup again") are the Codex Options tab and are no longer in Appendices. World, Journey and Appendices (Quests, Knowledge, Help Improve Codex, Party) are their own tabs.
* **Opening them.** Minimap button: left click shows/hides the tracker, right click opens the options (tooltip updated), drag moves it. `/codex` shows/hides the tracker; `/codex options | world | journey | appendices` open that tab; the tracker's own Options button. Before setup is finished `/codex` and the left click open the options (setup lives there) and the tracker shows a short "Set up Codex" prompt; Start opens the tracker.
* The yellow star box beside NOW is removed (just the NOW label).
* New frames are shown by default in WoW; both windows are hidden when built so the first toggle behaves.
Real-client checks: right click on the badge, the tabs, the settings tab, the tracker's Options button, and that the options window does not leave the tracker behind.

## 23. Findings from the 0.2.6 report (level 10, Undercity) and release 0.2.10
**Findings (real client, build 70170).**
* **Objective locations are a bridge gap, not missing QuestieDB data.** For the quests in the log that Codex could not place (Rear Guard Patrol, The Lich's Identity, A New Plague, At War With The Scarlet Crusade, Proof of Demise, The Family Crypt, The Mills Overrun) QuestieDB knows the quest, the giver and the turn-in NPC, all with positions, and lists objectives; for the kill objectives the NPCs have positions (e.g. 2 of 2, 3 of 3). The bridge reads no objective data, so Codex shows "objective places none". The QuestieDB tables exposed include `Npc`, `Object` and `Item`, so creature, object (herbs, containers) and item-drop objectives are all reachable in principle. (The counts are a ceiling: the slot meaning is unverified, and an item id can coincide with an NPC id.) Using this would be a planner-input change and needs its own decision.
* **Forever-only quests are genuinely unknown.** A Second Home, That Shadowvale Green Elixir, The Cult of the Damned, Remnants of War, Camping 101: Mining and Tomb Weed are in no layer (observed, QuestieDB, ATT). Only the game itself could place them.
* **The game's own quest-map points work.** `C_QuestLog.GetQuestsOnMap(1458)` returned 2 quests with positions (At War With The Scarlet Crusade, Proof of Demise): the call is usable on Forever, but it only answers for the map you are on. Probing the other maps is a possible next step, not done.
* **Event quests are candidates.** Lunar Festival "the Elder" quests, Winter Veil, Darkmoon Faire and Valentine's quests show up as current pickups (far away, so they lose on value; none was chosen). There is no seasonal-availability filter; whether QuestieDB exposes an event field is not yet checked.
* The plan itself (NOW 350 yd away in Undercity, then the Silverpine pickups and the Silverpine hand-in) is consistent: the in-log Tirisfal quests all have 0 progress and are not in the area, so nothing was deferred.
**0.2.10 (report only, no behaviour change).** The report's "Travel to X" line for a hand-in named the quest GIVER (it said Apothecary Johaan for a hand-in that is at the turn-in NPC); it now names the turn-in NPC. The report now lists READY TO TURN IN, and notes that the objective NPC counts are a ceiling.

## 24. Release 0.2.11: the quest-log counter
The tracker shows the quest-log count at the right end of the character line: "14/40". Grey normally, gold at 38/40 and above, red at 40/40; hidden when the quest log cannot be read (nothing is guessed). It is the count the quest log itself reports (a finished quest still holds its slot); 40 is the figure given by the project owner, not probed from the client. The same count is in `/codex report`.

## 25. Real-client result: hiding the game's quest tracker (v0.2.10, build 70170)
`/codex tracker on` hid the game's own quest tracker ("All Objectives") and `/codex tracker off` brought it back; both printed the expected message and no blocked-action popup appeared. The right-hand tracker area was clear, with the Codex tracker (top right, below the minimap) in its place. So `ObjectiveTrackerFrame` Hide / Show is a working, popup-free way to do this on Forever. Still unobserved: whether it survives a `/reload` / relog with the setting on (it is re-applied at login), whether the game ever re-shows it mid-session, and how it behaves with Questie's own tracker enabled. The "UNVERIFIED" notes in `BlizzardTracker.lua` and `/codex diag` are left as they are until those are seen.

## 26. Real-client results: the arrow (v0.2.10, build 70170)
Shift + drag resized the arrow, the hover tooltip (Drag / Shift + Drag / `/codex arrow flip`) showed in the minimap-tooltip style, the label read "330 yd", and the arrow pointed at the current NOW (Accept The Power to Destroy...) correctly. So the facing calibration, the rotation, the resize and the tooltip are all confirmed on the real client. The earlier "comes and goes" report is still open (see the arrow investigation: the destination is gated on the waypoint state; a `/codex report` taken when it vanishes will settle it).

## 27. Release 0.2.12: the minimap button rides the minimap's edge; the tracker survives a reload
* **Edge-riding button.** When the minimap's centre and width can be read, dragging the button slides it round the minimap's edge: it follows the mouse's angle from the minimap's centre at the ring's radius, so it can never come off the ring, and only the angle is saved (`ui.minimapAngle`). Default spot: 225 degrees (bottom-left of the ring). `/codex minimap reset` goes back to it. If the geometry cannot be read it falls back to the old free drag. The button is 28 px (was 32).
* **Tracker after a reload.** The tracker was gone after `/reload` because nothing reopened it. It now reopens at login unless the player closed it (the x or the minimap button's left click remembers the choice). A brand-new character is not shown a window until it asks.

## 28. Finding: what Questie's options window is built from (for the Codex options restyle)
Read from a local checkout of Questie (not copied; this only identifies the technique):
* Questie's options and its Journey are **Ace3**: `AceConfig-3.0` + `AceConfigDialog-3.0` build the tabbed options window out of `AceGUI-3.0` widgets (`Frame` container, `TabGroup`, `Button`, `CheckBox`, `Heading`, `Slider`, ...). The red "Questie Options" / "My Journey" / "Close" buttons are Blizzard's `UIPanelButtonTemplate`.
* What it looks like comes from standard Blizzard art and templates, not from Questie: the window is a `BackdropTemplate` frame with `Interface\DialogFrame\UI-DialogBox-Background` + `UI-DialogBox-Border`, the title plate is `Interface\DialogFrame\UI-DialogBox-Header`, the tabs use `Interface\OptionsFrame\UI-OptionsFrame-ActiveTab` / `InActiveTab`, the panes use `Interface\Tooltips\UI-Tooltip-Border`, and the Escape-to-close is `UISpecialFrames`. Every addon that uses AceGUI/AceConfig gets this same look, which is why they match.
* Options for using it in Codex: (A) the same Blizzard templates and textures drawn by Codex's own code, no library; (B) embed Ace3 (license: BSD-style, BUT "redistribution of a stand-alone version is strictly prohibited without prior written authorization from the Lead of the Ace3 Development Team": embedding inside an addon is the normal allowed use, the bundled copies and the licence file must travel with it); (C) use another addon's already-loaded copy through `LibStub` (an unannounced dependency on whichever addon loaded it: not recommended). Recommendation: A first. It needs no library and no Questie, and Blizzard's templates are proven to exist on this client because Questie's window uses them.

## 29. Release 0.2.13: Questie-style polish (own art), arrow choices, options restyle, world-map button
**Real-client report that prompted a fix.** After accepting "The Power to Destroy..." the arrow disappeared. A quest addon sets its own waypoint when a quest is accepted, which put Codex's waypoint in `paused-foreign`, and the arrow was tied to that state. `Navigation.Target()` now returns NOW's destination for `paused-foreign` and `dismissed` too: the arrow is Codex's own frame and does not depend on who owns the game's single waypoint. The arrow still hides on `arrived`, with navigation off, or when NOW has no location. (A `/codex report` taken next time it vanishes will show the arrow reason and the waypoint state.)
**Our own art** (`generator/make_art.py`, pure Python, original shapes, deterministic; run it to regenerate `ForeverCodex/Media/*.tga`, `--preview DIR` writes PNGs): `CodexLogo.tga` (C on an open book), `ArrowHead.tga` and `ArrowPointer.tga` (white with a dark outline, pointing up, tinted in the game), `IconBang.tga`, `IconQuery.tga`, `IconCheck.tga`. Nothing is copied from Questie's icons.
* **Minimap button** now uses the game's own pieces the way every minimap button does: the dark disc, the gold ring and the hover glow (`UI-Minimap-Background`, `MiniMap-TrackingBorder`, `UI-Minimap-ZoomButton-Highlight`; they exist on this client because other addons' buttons use them) with the Codex logo inside; 31 px; still rides the minimap's edge.
* **Arrow:** the default is now a bold arrowhead with a dark outline, 48 px (was the thin game arrow at 40); Codex Options has "Arrow style" (Arrowhead, Pointer, Classic = the game's own) and "Arrow colour" (Gold, White, Green, Cyan, Red). Rotation and tint work the same way as before; resizing, moving and the tooltip are unchanged.
* **Tracker icons:** a gold "!" beside a pickup in NOW, a gold "?" beside a hand-in in NOW and beside each READY TO TURN IN row; none on objectives (they have their progress rows).
* **Options window restyled** with the game's own dialog pieces (the technique Questie's and most addons' options use, written independently): the dialog frame (`UI-DialogBox` background and border), the gold title plate (`UI-DialogBox-Header`), tabs on the top edge of a bordered pane (`UI-OptionsFrame` tab pictures, `UI-Tooltip-Border` pane), the red `UIPanelButtonTemplate` buttons, check boxes for the settings (no more "[x]" text), a red Close button, and Escape closes it. If the backdrop or button template cannot be made it falls back to the flat look. The tracker keeps its small flat buttons.
* **World-map button:** a Codex button in the top-right corner of the world map (left click the tracker, right click the options); a toggle in Codex Options. It is a plain button (no pins, no overlays), takes the next free slot after other addons' map buttons it can see, and is feature-checked. NOT VERIFIED on Forever: the anchor and slot (`/codex diag` says what was found).
Real-client checks: the badge ring and logo, the arrow styles and colours, the "!" and "?" icons, the options window (frame, tabs, red buttons, check boxes, Escape), the map button's position next to Questie's, and the arrow staying up after accepting a quest.

## 30. Findings from the 0.2.10 report (level 10, Tirisfal) and release 0.2.14: the game's own quest-map points
**Findings.**
* `arrow: on (no destination)` with NOW = "Finish Rear Guard Patrol" (LOCAL_WORK): a NOW with no place has nothing to point at, so the arrow hides. That is the "comes and goes" case that does not need a waypoint to be involved.
* `C_QuestLog.GetQuestsOnMap(1420)` returned 12 quests with positions on the map, including every quest Codex could not place: the seven Classic quests (e.g. Rear Guard Patrol at 76.2, 60.8 while the player stood at 74.7, 62.0) and the Forever-only quests no data pack has (A Second Home, That Shadowvale Green Elixir, The Cult of the Damned, Remnants of War, Tomb Weed). So the game itself knows where to send the player for most of them; it answers only for the map the player is on.
**0.2.14 uses those points** (read-only; the planner, scoring and routing rules are unchanged):
* `Context`: `ctx.questPoints` = the game's quest-map points for the player's current map (only quests the call returns; (0,0) ignored).
* `Providers/Quest`: an in-log OBJECTIVE with no objective coordinates in any pack gets that point as its place (label "objective area (game quest map)", `src="game"`, `verified=false`); a quest no pack knows gets one too; a FINISHED quest whose hand-in NPC position is unknown (or only assumed at the giver) gets the point as its hand-in place. A hand-in NPC position from QuestieDB / observed data is never replaced.
* Effects: NOW for those quests now has a destination (the arrow points at it, the card says how far); the stop is a normal located stop (so ALSO COMPLETE THIS uses the real distance, within 300 yd, instead of "same zone"); READY TO TURN IN shows a distance for hand-ins that had none; the NOT PLACED list shrinks to quests whose point is on another map.
* Provenance: the points are the game's own quest-map positions (an area's centre or a hand-in), not an NPC or a spawn, and are labelled `game` and unverified. Quests on other maps stay unplaced until the player is on their map.
Real-client check: the arrow while working a quest whose objective Codex did not know (it should point to the game's spot), and `/codex report` NOT PLACED.

## 31. Seasonal filter investigation and release 0.2.15
**Question:** does QuestieDB expose an event / seasonal field Codex can use to stop offering holiday quests?
**What the data says (read from a local QuestieDB checkout; nothing copied):**
* The documented public API has **no event membership** and no active-event state. `specialFlags` in QuestieDB's own enum only defines NONE and REPEATABLE (the "needs event" bit mentioned in an old comment is not used); `questFlags` is a game bitmask unrelated to events (the Lunar Festival "Elder" quests carry 8).
* What the data does carry is the quest's **category**: a negative `zoneOrSort` is a QuestSort id (the game's own quest categories), and the holiday quests have holiday categories. Examples from the Forever data: Highpeak / Moonstrike / Meadowrun the Elder = -366 (Lunar Festival); Greatfather Winter is Here!, Dearest Colara, = -22 (Seasonal); Carnival Boots = -364 (Darkmoon Faire); A Light in Dark Places = -369 (Midsummer); Shadows of Doom = -368 (invasion); The Alliance Needs Copper Bars! = -365 (war effort). Class categories (-141 Paladin ...) and profession categories (-181 ...) use the same field and are NOT events.
* Which events are active is a calendar question (Questie asks `C_Calendar`); whether that works on Forever is unverified, so Codex does not guess.
**0.2.15:** the bridge now keeps the negative sort (`sort`) and marks a quest `event` when it is one of the holiday / world-event categories (a small fixed set of 15 game category ids in `QuestieBridge.lua`: Winter Veil, Harvest Festival, Children's Week, Love is in the Air, Pilgrim's Bounty, Noblegarden, Brewfest, Midsummer, Lunar Festival, Darkmoon Faire, Day of the Dead, Hallow's End, the generic Seasonal category, the invasion and the war effort; not a list of quests; unverified against the client itself). Event quests are not OFFERED as pickups (reason "event" in the report's funnel). Quests already in the log, or added by the player, still show. Limits: an event quest filed under a normal area instead of a category (for example "The Darkmoon Faire" itself) is not caught; and during an event the player can add a quest by id (`/codex add <id>`) to have it planned.
Also: the ALSO DO line under the NOW card uses the short distance ("1750 yd", "nearby") so it no longer cuts off.
Real-client check: the Lunar Festival / Winter Veil pickups should be gone from `/codex report` (the funnel line "holiday / world-event quests ... not offered: N").

## 32. Release 0.2.16: started work right here comes first, in every style
Two 0.2.15 reports from the same spot (Crusader Outpost) differed only in the route style. With `efficient` the plan was right (NOW = the started quest 39 yd away, ALSO COMPLETE THIS = the other one, arrow on the game's map point). With `fast` (time costs more) every local option scored a little below a far pickup trip, so NOW was "Accept Escorting Erland" 1800 yd away with two started quests 34 yd away. The existing "local work first" rule only applies when a local plan scores above zero, which it did not.
**Rule (`Pl.WORK_HERE`):** when the plan's first stop is more than 500 yd away (or on another map), has no objective of its own, and a stop with an objective of a quest in the log is within 150 yd on the player's map, the best plan starting at that nearby work is used instead. It applies in every style; it never overrides a quest the player added or a route zone the player chose; Skip still gets out of it. The regression test reproduces the fast-style case (without the rule NOW is the far pickup; with it, the started quest) and checks `efficient` is unchanged.
Real-client check: with `fast` selected, standing next to started quests, NOW should stay with them.

## 33. Release 0.2.17: the work-here rule also applies when the far stop has objectives of its own
Real report (v0.2.16, Venomweb Vale, `efficient`): NOW was "Finish The Cult of the Damned" 828 yd away while A New Plague (a started quest, objective 70 yd away, the player was fighting its spiders) was not chosen: the report shows "best plan from here" for A New Plague = net 9.0 over 130 s against 14.9 over 484 s for the far stop (two quests' objectives plus hand-ins). The 0.2.16 rule skipped any plan whose first stop already had an objective, so it did not fire. 0.2.17 drops that exception: when the first stop is more than 500 yd away (or on another map) and a stop with an objective of a quest in the log is within 150 yd on the player's map, the best plan starting at that nearby stop is used, whatever the far stop holds. Still never against a quest the player added or a route zone they chose; Skip still gets out of it. The regression test uses a far stop that mixes objectives and a hand-in (so the 0.2.16 rule would not have fired) and shows that without the rule the plan goes there.

## 34. Release 0.2.18: no hand-ins under ALSO COMPLETE THIS

Real report (0.2.16): NOW was "Finish The Cult of the Damned", ALSO COMPLETE THIS showed "Remnants of War 2/12" and, under it, "Turn in Tomb Weed - 750 yd".
Cause: the overlap list appended the planner's own ALSO DO as a plain row, and here that was a hand-in. It was drawn under the "complete this" label and duplicated READY TO TURN IN.
Fix: a hand-in is never listed as an extra (READY TO TURN IN has it); a pickup is listed only within 300 yd (`Overlap.ALSO_ACTION_YD`). The NOW line also uses the short distance form ("Here", "Nearby", "750 yd away").
Tested with the stub client only; not yet seen in the real client.

## 35. Release 0.2.19: nearby unfinished work stays visible when NOW is a close hand-in

Real report (0.2.18): NOW was "Turn in Remnants of War" (75 yd) while The Cult of the Damned (4/8, 6/8) was 71 yd away. Whether it showed under ALSO COMPLETE THIS depended on a planner tie-break (one report showed "nothing", a screenshot showed it).
Fix: when NOW is a hand-in within 150 yd (`Overlap.NOW_HANDIN_YD`), unfinished objectives within 300 yd of the player are listed (measured from the player, not the NPC). A far hand-in still lists nothing. The report's old `NEARBY:` line is relabelled "old nearby list (not shown in the window)".
Unverified: whether a `src=game` hand-in point is the real turn-in NPC (asked the user).

## 36. Release 0.4.0 (first numbered 0.2.20): a taller tracker

Real screenshot (0.2.19): READY TO TURN IN showed five hand-ins and "+ 1 more" with a lot of empty screen below. The window already grows to fit its content, so only the row caps limited it: READY TO TURN IN now draws up to 12 hand-ins (was 5) and a card draws up to 8 objective rows (was 6). Beyond that the "+ N more" line still appears.
Not changed: the window's width, and the planner (see the open note on deferred hand-ins in the 0.2.19 report analysis: a deferral that pushes near hand-ins behind a farther objective is awaiting a decision).

Version numbering changed with this release: the patch number runs 0-9 and then the next number up begins at 0 (see `RELEASING.md`). Older sections keep the numbers they shipped under (0.2.10 to 0.2.19 count as 0.3.0 to 0.3.9).

## 37. Release 0.4.1: quest tags, (Elite) labels and a red DUNGEON QUESTS card

Request: let players know which quests are elite, and show dungeon quests in a section of their own, red, split by dungeon.
How: Codex asks the GAME for each quest's tag (`C_QuestLog.GetQuestTagInfo`, or the older `GetQuestTagInfo`), the same technique Questie uses (no Questie code or data is copied). Nothing is guessed when the client does not answer: such a quest has no tag.
* Elite, Dungeon, Raid, Heroic and Legendary quests get the game's tag word after the name, e.g. "Finish The Foo (Elite)", wherever the name is shown (NOW, ALSO COMPLETE THIS, READY TO TURN IN, the report).
* Quests tagged Dungeon / Raid / Heroic / Raid 10 / Raid 25 / Legendary that are in the quest log go to a red DUNGEON QUESTS card below READY TO TURN IN, instead of the other cards. Each dungeon is its own group with a heading when there is more than one. A finished one says "ready to turn in" there.
* The dungeon is named by the game's name for the quest data's area (`C_Map.GetAreaInfo`), else by the quest log's own section heading, else the group is just "Dungeon quests". The report says which was used.
* Display only: the planner does not look at tags, so a dungeon quest can still be NOW (it is then labelled).
* The report prints `quest tags (game, unverified on Forever)`: which API exists, how many logged quests came back tagged, and `[tag id name]` on each tagged quest in the QUEST LOG list.
Unverified on the real client: whether the tag API exists, whether it answers for quests not in the log (so an Elite pickup may show no label), the tag ids (taken from the documented ids; the report prints the real ones), and whether the quest data's area gives the dungeon name.

## 38. Release 0.4.2: the 0.4.1 tag report, and a doubled count in ALSO COMPLETE THIS

First real report with tags (0.4.1, level 12): `C_QuestLog.GetQuestTagInfo` exists on Forever; 2 of 11 logged quests came back tagged: Rear Guard Patrol (Q:99156) tag 1 "Elite" and The Power to Destroy... (Q:5725) tag 81 "Dungeon", the latter named "Ragefire Chasm" by the game's area name (`C_Map.GetAreaInfo` is present). The window showed "Finish Rear Guard Patrol (Elite)" and a red DUNGEON QUESTS card with the "Ragefire Chasm" heading.
Now verified on the real client: the tag API, tag ids 1 and 81, the area-name lookup for a dungeon quest, and the labels and card. Still unverified: tags for quests NOT in the log (an Elite pickup), and the other tag ids (Raid, Heroic, ...).
Bug found in the same screenshot: ALSO COMPLETE THIS drew "0/1 Captain Vachon slain" with a second "0/1" bar count, because the game's objective text already carries the count and only NOW stripped it. The overlap list now cleans the label the same way (`Presenter.CleanObjective`). Test: `Overlap.Unfinished` strips "0/1 ..." and "...: 2/5".

## 39. Release 0.4.3: the hand-in-can-wait principle, in the planner

Request: READY TO TURN IN = finished but can wait; NOW = the best productive thing at this point in the route. Do not require the unfinished work to be physically close. Prioritise a hand-in when the player is already close to it, it is naturally on the route, several can be batched, the quest log is nearly full (38/40 and up), or there is no better work first. Reference: the 0.4.1 playtest (NOW Rear Guard Patrol 97 yd, THEN At War 228 yd, READY The Lich's Identity 1050 yd).
Inspection of the planner (`Planner.lua`, the deferral block after the work-here rule): it already deferred a far hand-in behind ANY located objective on the player's map (no distance limit on the work), switched off under slot pressure (`SLOT_PRESSURE_FREE = 2`, so 38/40 and above), and never deferred a hand-in within `DEFER_NEAR_YD` (150 yd). Two of the principles were missing, so a hand-in could be deferred when it was worth doing:
* on the route: the hand-in is kept when walking player -> hand-in -> work costs at most `ON_ROUTE_YD` (100 yd) more than going straight to the work (`diag.handInOnRoute`). Behind the player it is a backtrack and still waits.
* batch: the hand-in is kept when it starts a run of `BATCH_MIN` (2) or more hand-ins, each no more than `BATCH_YD` (250 yd) from the previous (`diag.handInBatched`).
Unchanged: no distance limit on the work, the 150 yd "close" rule, slot pressure, the work-here rule, scoring, every constant, and the Phase 2.5 baseline (`golden/planner_eval_baseline.txt` is byte-for-byte unchanged and passes).
An attempt to also require the work's own net value to be positive was dropped: in the `fast` style local work scores negative and the hand-in would then win over work 40 yd away (the baseline caught it).
Expected effect on the 0.2.19 report (hand-ins at 321, 360 and 489 yd, The Lich's Identity 556 yd): the first two are 40 yd apart, so they should now be a batch that comes first, then the work. Not run against that report, only against the fixtures.
Tests: `local_progress_tests.lua`, "hand-in can wait" sections (work + far lone hand-in defers, work not close; close hand-in promoted; on-route included and the same distance behind the player waits; batch NOW, the same hand-in alone waits, hand-ins on opposite sides are not a batch; 38, 39 and 40 of 40 do not defer, 37 does). The on-route and batch tests fail if those exemptions are switched off.
Verified on the stub client only; not yet seen in the real client. The report's flags line now also names deferredTurnIn, handInOnRoute, handInBatched, slotPressure and workHere.

## 40. Release 0.4.4: Stage 0 of the Reward Advisor, the read-only item/reward probe

Scope (decided in the design review, `CODEX_REWARD_ADVISOR_DESIGN.md`): find out what item and reward information the real Forever client exposes to Codex. NO advisor, scoring, stat valuation, keep/sell, combat-utility or reward recommendation was built, and the planner, strategies, presenter, overlap and providers are untouched (a test asserts that nothing but the report reads the probe).
New files: `Items.lua` (the one shared item-facts read path: pcall-guarded, per-field provenance, "blank/nil (not loaded yet)" reported as such) and `ItemProbe.lua` (proof tallies, the reward cache, the events, the report lines). `Diag.lua` adds the `--- ITEM PROBE ---` section at the end of `/codex report` (the report runs a fresh character probe first).
How a field is judged (`ForeverCodexDB.items.proof`, per field: tries, real values read, failures, late resolutions, a short sample, the build):
* PROVEN: a real value was read on this client at least once. An API merely existing is never enough.
* FAILED: the API is absent, errored, or returned nothing on every try (the reason is shown).
* UNPROVEN: not tried yet, or tried but there was nothing to read (for example no weapon sampled yet, or an item with no use effect).
* "late xN": the value only appeared after a retry; "failed xN": some reads failed even though others worked.
Fields: quest id (`GetQuestID`), reward counts, reward item name / id / link, item info (`GetItemInfo`, and the instant variant), class/subclass, item level, equip slot, required level, vendor value, stats (`GetItemStats`), usable (`IsUsableItem`), use effect (`GetItemSpell`), weapon info (subtype + dps stat), item count, equipped items, bag items, skill lines, weapon skill lines (English weapon names only).
Item data loads asynchronously: a blank name or nil info is queued and re-read on `GET_ITEM_INFO_RECEIVED` (and a short timer where `C_Timer` exists), at most 3 tries; the stored observation is completed in place.
Reward cache: every reward dialog Codex sees (`QUEST_DETAIL`, `QUEST_COMPLETE`, `QUEST_ITEM_UPDATE`), whether or not the quest is in the log, is stored in `ForeverCodexDB.items.rewards[questId]` with `src = "CODEX_OBSERVED"`: choices and guaranteed items (id, name, count, quality, the raw 5th `GetQuestItemInfo` value, a small info table), the event, build, first/last time and how many times it was seen. No item link is stored. Capped at 500 quests (oldest dropped). Nothing reads it yet.
Events registered (own frame, observation only, UNPROVEN until each fires, first arguments kept): `QUEST_DETAIL`, `QUEST_COMPLETE`, `QUEST_ITEM_UPDATE`, `GET_ITEM_INFO_RECEIVED`, `PLAYER_EQUIPMENT_CHANGED`, `BAG_UPDATE_DELAYED`, `SKILL_LINES_CHANGED`. Only the three quest events and the late-data event do any work (the capture and the retry); the others are counted only.
Evidence status: ALL of this is tested on the stub client only (2648 tests). Nothing in Stage 0 is yet proven on the real client by Codex itself. Earlier recorder probes (`forever-db`, `m4-*`, `m5-*`) already showed on Forever: `GetNumQuestChoices` / `GetNumQuestRewards` / `GetQuestItemInfo(kind, i)` work at the reward dialogs and return name, icon file id, count, quality, a boolean of unknown meaning, and a sixth value that matched the item id in the recorded rows; names can read as "" first and resolve later. Everything else is unproven until the first real report with this build.
Not probed (stated in the report): tooltip text (use-effect wording, class/race requirements), `IsSpellKnown` proficiencies, items the client has never seen.

## 41. Release 0.4.5: Stage 0.1, every reward choice inspected one by one

Why: the 0.4.4 real-client report proved the To Valanaar dialog (3 choices, ids, names, links, late-loading names), but the ITEM PROBE section only showed field tallies, where the "sample" of a field was whichever item was read last, mixed with equipped and bag items. Nothing listed the three choices separately.
Change (Stage 0 evidence only; no scoring, valuation, recommendation, keep/sell, utility, future-use or planner change):
* `ItemProbe.lua` keeps an in-memory detail of the latest reward dialog (`P.dialog`): per choice (and per guaranteed item) the id and where it came from, the link, and the full `Items.Read` result. The id is the one the dialog itself returned (`GetQuestItemInfo` and/or the link); QuestieDB is not consulted.
* The report gains `REWARD CHOICE DETAILS`: if a dialog is open when `/codex report` runs it is read live (this read stores nothing and counts nothing; only the quest events feed the reward cache); otherwise the last dialog seen this session is shown, labelled as closed. Per choice: id, name, link, info, class/subclass, item level, equip slot, required level, vendor value, stats, each PROVEN / UNPROVEN / FAILED, and stats may be EMPTY (the client returned an empty table). Only fields the existing `Items.lua` reader supports are shown.
* Late data: a choice whose item info is not loaded yet shows UNPROVEN "waiting for item data" (name, info, class, level, slot, vendor and stats alike), never FAILED and never "no info"; `GET_ITEM_INFO_RECEIVED` completes it through the existing retry. An item that is not equipment shows its empty equip slot as expected.
* The old per-field tallies stay, now under a heading saying they cover every item read since install.
Tested on the stub client only (the To Valanaar shape: three choices, one loading late, an empty stat table, stats unreadable, a closed dialog, no dialog).

## 42. Release 0.4.6: Stage 1, the shared Item Facts reader

Real-client evidence this stage rests on (0.4.5 on build 70205): all three To Valanaar choices read with id, name, link, item info, class/subclass, item level, equip slot, required level, vendor value and a stats response (`RESISTANCE0_NAME` = 28 / 7 / 61 for the leather wraps, cloth cloak and mail boots); late loading and `GET_ITEM_INFO_RECEIVED` work; `IsUsableItem`, `GetItemSpell` and weapon type/dps are available; equipped and bag reads work; the skill-line and weapon-skill APIs Codex checks are ABSENT (not solved here).
What Stage 1 is: infrastructure only. NO scoring, ranking, "take this", sell/keep logic, replacement horizon, class recommendations or planner change. Nothing but the report reads it.
Architecture (a small refactor of `Items.lua`, no new reader):
* `Items.Read(ref)` is unchanged (the raw read, per group, with the reason anything is missing).
* `Items.Normalize(raw)` turns one raw read into one normalized ItemFacts object. It is pure, so a read that completes later is simply normalized again. The late-loading retry is still ONLY `ItemProbe`'s existing `GET_ITEM_INFO_RECEIVED` mechanism (a test asserts `Items.lua` has no queue of its own).
* `Items.Facts(ref)` = Read + Normalize + the optional QuestieDB cross-reference (`Items.External`, `Items.Annotate`).
* `ItemProbe.DialogFacts(refresh)` returns the reward dialog's offered items as normalized facts. The dialog stays the source of truth for what was offered (its choices, guaranteed rewards and ids); QuestieDB never adds or removes an item.
ItemFacts shape: `{ schema, id, state = LOADED | WAITING | FAILED, waiting, fields = { id, name, link, quality, class, subclass, itemLevel, equipSlot, requiredLevel, vendorValue, stats, usable, useEffect, weaponType, weaponDps }, external = { questiedb }, conflicts, offered = { source = "reward_dialog", kind, index, quest } }`. Every field is `{ state, value, src, reason }` (class/subclass also `text`; stats also `list`, `byStat`, `raw`; useEffect also `spellId`; weaponDps also `key`).
States, never collapsed: PROVEN (a real usable value; `src` names the client function), UNPROVEN (not read yet: the item is still loading, "waiting for item data"; never a failure), FAILED (the API is absent, errored, or returned something unusable; `reason` says which), EMPTY (the API worked and returned an empty value, or the field does not apply: an empty stat table, an empty equip-slot string, no use effect, a weapon field on armor). EMPTY is not interpreted: an empty stat table does not mean "this item has no stats". While an item is loading, usable, use effect and stats are UNPROVEN rather than reported from a read that means nothing yet; class, subclass and equip slot may still be PROVEN from the cache-independent `GetItemInfoInstant`, labelled with that source.
Provenance: per-field `src`; client facts and QuestieDB data are kept apart (`external.questiedb = { src = "questiedb", verified = false, exists, name, class, subClass, itemLevel, requiredLevel }`, read only through the documented `LibQuestieDB.Item.Exists/Get`; `exists = false` means "unknown to QuestieDB", which is expected for Forever-added items). A disagreement is recorded in `conflicts` (field, client value, QuestieDB value) and the client's value is never changed.
Stats normalization: the stat table's keys and values come from the client; `Items.STAT_KEYS` only says what Codex believes a key means (armor, strength, agility, stamina, intellect, spirit) and names a client global string whose text should equal the key's own text. `RESISTANCE0_NAME` is therefore NOT assumed to be armor: the normalizer compares the client's own text for `RESISTANCE0_NAME` with its text for `ARMOR`. Result per stat entry: `label-match` (canonical stat set, corroborated), `label-missing` (mapping used, client texts not comparable, uncorroborated), `label-conflict` (texts differ: NO canonical stat, raw kept), `key-pattern` (the weapon dps key, matched by name), `unmapped` (raw only). The raw table is always preserved. The real values (28 / 7 / 61 for cloth, leather, mail items of equal level) are consistent with armor, but that is an inference; the report prints the client's text for the key so the match can be read off.
Unsupported / unresolved: resistances 1-6, secondary stats and any other key stay raw; no proficiency, class or skill check (clean extension point: a future module reads `ItemFacts.fields.class/subclass/weaponType` and the character separately; skill APIs are absent on Forever); no tooltip text (use-effect wording, class/race requirements); `usable` is only the client's `IsUsableItem` answer; whether an EMPTY stat table means "no stats" is deliberately undecided.
Report: the `ITEM PROBE` section keeps `REWARD CHOICE DETAILS` (raw, Stage 0.1) and adds a compact `ITEM FACTS (normalized ...)` block for the offered items; the per-field tallies are condensed to four lines (PROVEN / UNPROVEN / FAILED / resolved late), the character fields keep their samples. Version 0.4.6.

## 43. Release 0.4.7: Stage 2, the shared equipped / bag item facts reader

Stage 1 passed on the real client (build 70205). Stage 2 gives later systems a trustworthy way to compare an observed item with the character's equipment and bags. Facts only: NO scoring, ranking, upgrade categories, take/sell/keep advice, replacement logic, class or proficiency inference, planner change or QuestieDB change; nothing but the report reads it.
Architecture (no second item reader and no second loading queue):
* `Items.lua` gains slot-level raw reads: `EquipmentSlots()` (all 19 slots, each POPULATED / EMPTY / FAILED), `BagSlot(bag, slot)` (same three states, with the stack count) and `BagContainers()`. The existing `Equipped()` and `Bags()` keep their behaviour (the count code is shared).
* New `Gear.lua`: `Equipped()`, `BagSlot()`, `Bags()`, `Snapshot()`, summaries, and the comparison helpers. Every item goes through the Stage 1 `Items.Facts`.
* Late loading: an equipped or bag item whose facts are WAITING is registered on `ItemProbe`'s one queue with the new `ItemProbe.Watch(key, ref, onRead)`; the existing `GET_ITEM_INFO_RECEIVED` / timer retry refreshes the entry's `itemFacts` in place. Keys de-duplicate repeated snapshots.
* `ItemProbe.DialogFacts()` is untouched and remains what the reward dialog offered; `Gear.ReportLines` reads it only to line the offered items up against the equipment.
Shapes:
* `EquipmentFact { slot, slotName, state = POPULATED | EMPTY | FAILED, itemId, link, itemFacts, src, reason }`. EMPTY (read fine, nothing there) is never confused with FAILED (api absent, error, unusable result). `Gear.Equipped()` = `{ state = OK | FAILED, reason, slots[1..19], list }`.
* `BagFact { bag, slot, state, itemId, count, link, itemFacts, src, reason }`. `Gear.Bags()` = `{ state, reason, containers = { { bag, size, state, empty, populated, failed } }, stacks = { populated BagFacts } }`; empty slots are counted per container, `Gear.BagSlot` reads any single slot.
* `Gear.Compare(a, b)` (pure, two ItemFacts) = `{ schema, a, b, slot = { state = SAME | SHARED | DIFFERENT | NO_SLOT | UNKNOWN, shared }, class, subclass, itemLevel, requiredLevel, usable (each COMPARED with a, b, same, diff, or UNKNOWN with the reason), stats = { armor, strength, agility, stamina, intellect, spirit, weapon_dps }, unmapped }`. A stat result is COMPARED (a, b, diff, assumedZero per side, meaning per side), NOT_LISTED (neither lists it), NOT_APPLICABLE (weapon dps on a non-weapon) or UNKNOWN. Stats are compared only when both stat tables are PROVEN: an EMPTY table, a waiting or failed item, or a label-conflicted key gives UNKNOWN, never 0. When a side lists nothing for a stat in a PROVEN table the difference counts it as 0 and says so (`assumedZero`). Keys Codex does not name are listed in `unmapped`, so a later layer knows the comparison is partial.
* `Gear.CompareToEquipped(facts, equipped)` = `{ state = COMPARABLE | NO_SLOT | UNKNOWN, entries = { { slot, slotName, state = COMPARED | EMPTY_SLOT | UNKNOWN, equipment, comparison } } }`. Which inventory slots an equip location fits comes from `Gear.SLOTS_FOR`, a static table of the game's own slot ids (not item data; a location not in it is UNKNOWN, never guessed; two-handers are listed under the main hand only).
APIs used (all read-only, pcall-guarded, looked up at call time): `GetInventoryItemLink("player", slot)`, `C_Container` or global `GetContainerNumSlots` / `GetContainerItemLink` / `GetContainerItemInfo`, plus the Stage 1 item reads. Provenance: `src` on every slot and bag fact and on every itemFacts field; QuestieDB stays in `itemFacts.external` (unverified) and is never used in a comparison.
Unsupported / unproven: no class or proficiency logic, no tooltip text, no alt or bank inventory; the INVTYPE-to-slot table is a Codex table, only confirmed on the equip locations already seen (HAND, CLOAK, FEET, WEAPON as seen so far in reports); `GetInventoryItemLink` for other slots and the bag APIs' handling of bank bags are untested beyond the earlier reports.
Report: `/codex report` gains `EQUIPPED ITEM FACTS` (populated slots, empty, slot reads failed, normalized, waiting, failed), `BAG ITEM FACTS` (visible stacks, containers read, empty slots, normalized, waiting, failed) and, when a reward dialog was seen, a compact `COMPARISON FACTS` line per offered item and slot (differences only). About 8 lines.
Stub tests only (2876 in total).

## 44. Release 0.4.8: Stage 2 completed (events, listings, evidence)

Real report (0.4.6, level 9 Skyborne Rogue, build 70205): all of Stage 1 worked (three To Valanaar choices, late loading x2, `label-match` for `RESISTANCE0_NAME`, "unknown to QuestieDB" for all three Forever items). Equipped and bag reads were PROVEN (11 slots, 11 stacks); `BAG_UPDATE_DELAYED` fired 9 times and `SKILL_LINES_CHANGED` 5 times with no arguments; `PLAYER_EQUIPMENT_CHANGED` never fired (nothing was equipped in that session); the skill-line and weapon-skill APIs are absent.
Observed but unreliable: `IsUsableItem` returned `false` for all three reward choices, including a cloth cloak and a leather item for a Rogue, so its answer for items that are only offered (not owned) cannot be trusted. Nothing was changed on that basis; 0.4.8 only records the evidence next to the value: the second `IsUsableItem` return (`fields.usable.second`) and the dialog's own 5th `GetQuestItemInfo` value (`facts.offered.dialogFlag`), both printed in `ITEM FACTS` without interpretation.
Stage 2 core (0.4.7, `Gear.lua`) already gave equipped and bag facts and the facts-only comparison. 0.4.8 adds what that build lacked:
* Refresh: `ItemProbe.OnEvent` forwards `PLAYER_EQUIPMENT_CHANGED` and `BAG_UPDATE_DELAYED` to `Gear` (the existing event frame, no second one). `Gear.Get()` is the event-maintained snapshot: an equipment event re-reads only the changed slot (`Items.EquipmentSlot(slot)`; a missing slot argument marks the equipment dirty), a bag event marks the bags dirty and they are re-read the next time they are asked for; late item data still refreshes entries in place through the one `ItemProbe` queue. `Gear.Snapshot()` forces a fresh read (the report uses it, because `PLAYER_EQUIPMENT_CHANGED` is not yet proven to fire on Forever). Counters: `Gear.stats`.
* Report: `EQUIPPED ITEM FACTS` and `BAG ITEM FACTS` now list every occupied slot or stack compactly (actual slot name, item name and id, status, the item's own equip location; bag, slot, count) with `occupied`, `unique item ids`, `facts loaded`, `waiting`, `failed`, plus a refresh-event line. The actual equipment slot and the item's `equipSlot` stay separate fields.
* Counts stay on the stack: two stacks of one item are two entries with their own counts; the item's facts carry no count.
Stub tests only (2915 in total). Planner, strategies, presenter, QuestieDB and golden baselines untouched.

## 45. Release 0.4.9: Stage 3, the Reward Advisor (classification layer)

Real-client basis (0.4.8, build 70205): reward ItemFacts, equipped and bag facts and the reward-to-equipped comparison all worked; the dialog was tested open and closed. For the To Valanaar rewards `IsUsableItem` returned false for all three while the dialog's own flag was true, true, false.
New file `RewardAdvisor.lua` (`ns.Advisor`), read-only and independent of the planner, strategies, presenter and UI; only `/codex report` reads it. Layers, kept in separate functions:
ItemFacts (Stage 1) -> Gear comparison (Stage 2, facts only) -> `Advisor.Classify` (what kind of value, and why) -> `Advisor.Recommend` (an interface; the default gives NO opinion).
Classification = `{ schema, item = { id, name, state }, primary, categories = { { id, tag, family, certainty, reason, evidence } }, usability = { verdict, sources, reason }, comparison = { state, chosen, entries, note }, caveats, futureUse = { state, reason, source }, context }`. `primary` is a presentation order only (`Advisor.CATEGORIES`, an extensible table of tag, colour family and order), not a ranking and not a recommendation.
Categories: NOT_USABLE, UPGRADE, TEMPORARY_UPGRADE, SLIGHT_UPGRADE, MIXED, COMBAT_UTILITY, FUTURE_USE, VENDOR, UNKNOWN. An item can carry several. Own icons are still to come: each category has a plain ASCII tag and a colour family, no emoji.
Rules (no stat weights, no scores, no formula):
* The reward is matched to the ACTUAL equipped slot(s) through `Gear.CompareToEquipped` (INVTYPE_FEET -> slot 8, INVTYPE_HAND -> slot 10 ...). An empty slot it fits: UPGRADE "Fills your empty X slot". Several slots (rings, one-handers): the comparable one with the largest relative gain.
* Compared stats only (armor, strength, agility, stamina, intellect, spirit, weapon dps). Some higher and none lower: UPGRADE, or SLIGHT_UPGRADE when the largest relative gain is below `THRESHOLDS.slightRelative` (PROPOSED 0.25, untuned; relative to the current value, floored at `relativeFloor` 5). Some higher and some lower: MIXED ("Codex does not weigh different stats against each other"). None higher: not an upgrade. A stat missing from a proven table counts as 0 and is flagged (Stage 2 `assumedZero`).
* UNKNOWN stays UNKNOWN: an item that has not loaded, an unreadable or EMPTY stat table (not read as "no stats"), an equipment read that failed, an equipped item not loaded, an equip location not in Codex's slot table, or no equipment read, all give UNKNOWN with the reason; none becomes VENDOR or "not an upgrade". VENDOR needs the comparison to have been made (or no equip slot) AND a PROVEN vendor value; without a vendor value it is UNKNOWN, not 0c. VENDOR says "No known equipment or utility benefit" and gives the value; it never says sell.
* Usability keeps both evidence sources: IsUsableItem and the reward dialog's flag. NOT_USABLE only when both say false; they disagree: CONFLICT (a caveat, the upgrade is still described and marked PARTIAL); IsUsableItem alone, true or false, is UNKNOWN (it is never trusted alone on Forever). A not-usable item gets no upgrade category; its vendor value then appears. A required level above the character's is a caveat.
* COMBAT_UTILITY: a PROVEN use effect, with the honest reason "Codex does not know what the effect does" (certainty PARTIAL); a registered utility source can add its own reason. FUTURE_USE: only from a registered source (`Advisor.RegisterFutureUse`); Codex has none and says so (`futureUse.state = UNKNOWN`). Providers that error are ignored.
* TEMPORARY_UPGRADE: only from CONTEXT supplied to `Classify` (`context.replacement = { state = KNOWN, quests | minutes, certainty = GUARANTEED | POSSIBLE, source }`); nothing is predicted or invented. It is added next to UPGRADE or SLIGHT_UPGRADE, never instead.
`Advisor.Evaluate(opts)` evaluates the reward dialog: `live` and `available` are true ONLY while the dialog is open now (it reads the open dialog first); a dialog seen earlier and closed now is `live = false, available = false`, labelled "not currently offered", so a stored observation is never presented as an open reward.
`Advisor.Recommend(evaluation)`: default `{ state = "NO_OPINION" }` echoing each item's categories; `Advisor.SetRecommender(fn)` plugs a later layer in without touching classification (an erroring recommender falls back to no opinion).
Report: a `REWARD ADVISOR` block at the end of `/codex report` (per reward: tag, reason, certainty, other categories, caveats, usability evidence; the source label; `RECOMMENDATION: NO_OPINION`). No window card yet. Stub tests only (3036 in total). Not built: any recommendation, opportunity or route logic, future-use data, stat weights, class inference.

## 46. Release 0.5.0: Eligibility, "you can't use this" versus "you can't use this yet"

Design principle: Codex separates "cannot use" from "cannot use YET", and never makes up Forever-specific rules. Layers (each its own function, none merged):
ItemFacts -> Eligibility (current, future) -> Gear comparison -> Advisor classification -> Recommendation.
New file `Eligibility.lua` (`ns.Eligibility`), independent of the Reward Advisor, Gear, planner, strategies, presenter and UI, so other systems (a future opportunity system) can ask "this item becomes useful at level 40" without knowing anything about rewards. Version 0.5.0 because it is a new layer and it changes advisor behaviour.
Two answers, never one boolean:
* `current`: PROVEN_YES | PROVEN_NO | UNKNOWN (can the character use it now).
* `future`: NOT_RELEVANT (already usable, or never usable) | SOON | LATER | UNKNOWN. SOON is within `Eligibility.SOON_LEVELS` levels of the unlock (PROPOSED 2, untuned); further away is LATER; no evidence is UNKNOWN, never a guess.
Evaluation: `Eligibility.Evaluate(facts, character, { equipped, requirements })` -> `{ current = { state, blockers, conflicts }, future = { state, unlockLevel, levelsAway, basis, reason, referenceHint }, checks = { level, proficiency, class, race, faction, client }, caveats }`; `Eligibility.Describe` gives the one-line diagnostic. The character comes from the existing Context reader (`Eligibility.Character`), not a second one.
Evidence, each check keeping its own state and source:
* level: the item's required level (client fact) against the character's level.
* proficiency: there is NO class-to-armor table. Evidence is (a) an item of the same armor/weapon type that the character is wearing right now (the game allowed it) and (b) records registered with `Eligibility.AddEvidence({ class, itemClass, subClass, minLevel | never, proven, src })`; only `proven = true` records decide anything, and nothing registers any by itself yet. Standard Classic rules are four labelled REFERENCE records (Shaman and Hunter mail 40, Warrior and Paladin plate 40; `proven = false`, "Classic reference (not proven on Forever)") used only as a hint printed next to an UNKNOWN. Forever evidence wins; with none the answer is UNKNOWN.
* explicit class / race / faction restrictions: read from `facts.requirements` (or `opts.requirements`) when present. Nothing reads them from the client yet (tooltips are not probed), so the checks are NOT_READ, which is a caveat, not "no restriction".
* client usability: IsUsableItem and the reward dialog's flag side by side (moved here from the advisor, which delegates); IsUsableItem alone is never trusted.
Rules: a proven failure of an identified requirement (level not reached, a class/race/faction restriction, a proven proficiency threshold) overrides everything, including positive client answers (the contradiction is recorded in `current.conflicts`). Client answers both false with no identified reason are PROVEN_NO with an unknown unlock, so the future is UNKNOWN. A permanent blocker makes the future NOT_RELEVANT. One known requirement never makes the item usable while another is UNKNOWN: a level requirement that is the only known blocker, with proficiency unknown, gives a future of UNKNOWN. With several blockers the item unlocks at the latest level.
Advisor changes (0.4.9 behaviour that changed on purpose): upgrade-type categories (UPGRADE, SLIGHT_UPGRADE, MIXED, TEMPORARY) now require PROVEN_YES current eligibility. With UNKNOWN eligibility a better-looking item is UNKNOWN, stating what it would be if usable (conflicting usability answers used to give a PARTIAL upgrade). PROVEN_NO plus future SOON plus an item that would improve what is worn is the new FUTURE_UPGRADE (a slight gain is described as slight); PROVEN_NO with LATER, UNKNOWN or NOT_RELEVANT future is NOT_USABLE with the reason ("Not usable yet ... becomes usable at level 40 (10 level(s) away)", or that it does not change); a SOON item that is not an improvement stays NOT_USABLE with a caveat. Future eligibility never makes a recommendation; `Advisor.Recommend` still gives no opinion. The comparison with worn gear is still made whatever the eligibility, and an empty slot does not change eligibility.
Report: each reward in `REWARD ADVISOR` now has an `eligibility: now ... | future ...` line (with the Classic reference hint, labelled, when the answer is UNKNOWN), next to the usability evidence and the recommendation line.
Not built: any recording of what the client actually allows at each level (the natural next step to turn Classic reference rules into proven Forever evidence), tooltip reading for explicit restrictions, class or profession inference beyond this, recommendation logic, planner or opportunity changes. Stub tests only (3121 in total).

## 47. Release 0.5.1: proficiency-evidence recording (EligibilityEvidence.lua)

Goal: turn real Forever observations into proven eligibility facts over time ("Mail becomes usable at level 40 for Shaman on Forever") WITHOUT assuming Classic. Layers: ItemFacts -> Eligibility Evidence -> Eligibility -> Gear comparison -> Reward Advisor. Actual client evidence is authoritative; Classic rules stay a labelled reference (the four `proven = false` records in `Eligibility.lua`), used only as a hint beside an UNKNOWN. `EligibilityEvidence.lua` contains no class name, no armor-type rule and no level threshold (a test scans for them).
What is collected: one OBSERVATION = `{ class, level, race, faction } + { item id, item class/subclass, type text, equip slot, required level } + { usable true | false | nil, source } + { build, evidence source, time }`. Stored account-wide (no names) in `ForeverCodexDB.items.evidence` (capped at 2000 records). Missing information is never turned into a value: no class, level or item type means the observation is rejected (counted by reason); an unknown result is kept as state UNKNOWN and never counted.
Where observations come from (natural moments only, no polling, nothing for the player to do):
* the reward dialog (QUEST_DETAIL / QUEST_COMPLETE / QUEST_ITEM_UPDATE): each offered armor or weapon whose item data is loaded, with the client's usability answers read side by side (both true = usable, both false = not usable, anything else = no result; IsUsableItem alone is never used);
* worn items (PLAYER_EQUIPMENT_CHANGED and when /codex report is made): an item the character is wearing was allowed by the game, so it is a usable observation at the current level (shirt and tabard slots excluded).
Only items with a proficiency count (armor subclasses 1-4 and shields, and weapons). Observations are stamped with the character AS THEY ARE AT THAT MOMENT; a closed dialog is never re-observed later, because its level would be wrong.
Observation versus PROVEN. An observation is never a rule. A PROVEN answer needs the explicit policy (`Ev.POLICY`, shown in the report): YES at level L (usable from at most L, because proficiency does not disappear as the level rises) needs, at that level, 1 distinct worn item or 2 distinct client-flagged items; NO at level L (and every lower level) needs 3 distinct client-flagged items at that level, a higher bar because a hidden restriction on one item (a class-only item) would look identical; an observation whose item required level is above the character's (or unknown) is recorded but never counted; the exact unlock level is proven only by a proven NO at U-1 and a proven YES at U. Anything less is OBSERVED (recorded, not proven) or UNKNOWN. `Ev.GetProficiency(class, itemClass, subClass, level)` returns `{ state = PROVEN_YES | PROVEN_NO | UNKNOWN | CONFLICT, evidenceState = UNKNOWN | OBSERVED | PROVEN | CONFLICT, unlockLevel (exact only), unlockAtMost, bounds, evidenceCount, source = "observed_client", reason }`. Level requirement and proficiency stay separate throughout.
Conflicts: never overwritten, never resolved. The same item observed both usable and not usable at one level, or an unconfounded NO at a level at or above an unconfounded YES for the same class and type, makes the group CONFLICT; both observations stay stored. Eligibility treats a conflict as UNKNOWN for proficiency (never PROVEN_YES or PROVEN_NO). A hidden item restriction can cause a false conflict; that errs toward UNKNOWN, the safe side.
Duplicates: identical observations (class, level, race, faction, item, result, source, build) are one record with a repeat count and first/last time. A different build, item, level, result, source or race is a separate record, so builds stay distinguishable.
Eligibility integration (small): `Eligibility.proficiencyCheck` now also asks the recorder, after worn gear and registered evidence; PROVEN_YES / PROVEN_NO (with the exact unlock level when proven) are used, a CONFLICT or anything unproven stays UNKNOWN. The existence of recorded observations never raises certainty. 0.5.0 behaviour is unchanged when nothing is recorded.
Client signals (from the repository's own real-client evidence; nothing was invented): available and proven earlier: `IsUsableItem` (unreliable alone: false for items the dialog flagged usable), the reward dialog's usable flag (5th `GetQuestItemInfo` value), worn items (`GetInventoryItemLink`), `UnitClass` / `UnitLevel` / `UnitRace`; events `QUEST_DETAIL` / `QUEST_COMPLETE` proven, `PLAYER_EQUIPMENT_CHANGED` registered but not yet seen to fire. Absent on Forever: skill lines (`GetNumSkillLines` / `GetSkillLineInfo`) and so weapon-skill lines. Not probed: `IsSpellKnown` for proficiency spells (their Forever spell ids are unproven, so no id is hard-coded). A stronger proficiency signal may exist; none is known.
Report: a compact `ELIGIBILITY EVIDENCE` section (recording active, observations and merged repeats, groups, proven answers, conflicts, observations with no result, what was not recorded and why, the policy, the signals available / absent / not probed, one line per group, the events it relies on). The detail is in the saved variable: `/dump ForeverCodexDB.items.evidence` (`EligibilityEvidence.Dump()` formats it). No slash command was added.
Testing reality: no character above level 30 is available, so no unlock level can be proven now; with levels up to 30 the likely results are worn-item YES for the types the character wears and NO for types it is offered but cannot use (after 3 distinct items at one level). Higher-level observations will be recorded when they occur naturally, and friend exports can carry the same observation records (they hold no names), to be merged through `EligibilityEvidence.Record`. The full export workflow is not built. Stub tests only (3254 in total); planner, advisor classification and recommendation behaviour are unchanged.
