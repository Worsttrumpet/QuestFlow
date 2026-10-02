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
