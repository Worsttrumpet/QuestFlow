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
