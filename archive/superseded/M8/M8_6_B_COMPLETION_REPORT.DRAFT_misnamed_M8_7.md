# M8.7 — Show on Map (add to docs/M8_0_SCOPE.md §2/§9)

## Confirmed on the live Forever client (manual /run probe, 2026-09-29)
- `C_Map.SetUserWaypoint` exists → true
- `C_SuperTrack` exists → true
- `C_Map.CanSetUserWaypointOnMap(1413)` (Barrens) → true
- `UiMapPoint.CreateFromCoordinates(1413, 0.449, 0.591)` + `SetUserWaypoint` + `SetSuperTrackedUserWaypoint(true)`
  placed a visible pin at Jorn Skyseer's camp, verified on the Kalimdor world map.
  (It first appeared to do nothing only because the map was open to Undercity, where a Barrens pin cannot draw.)

## Not yet confirmed
- Any map other than 1413 (1411 Durotar is the next obvious check)
- `WorldMapFrame:SetMapID` behaviour (the addon calls it best-effort, pcall-wrapped)
- Super-track arrow behaviour across continents

## Addon changes (m8-guide-addon-0.6)
- New `MapPin.lua`: feature-checked, pcall-wrapped pin placement; falls back to a plain
  `{ uiMapID, position }` point if `UiMapPoint` is ever missing; never raises a Lua error.
- QUESTS tab: Show on Map pins the selected quest's `pos` (recorder-observed player position).
- ROUTE tab: new Show on Map button pins the step's `destination` only; dimmed on steps with none
  (s1, s2, s3, s5 of the test route). No fallback to quest `pos` — route data stays authoritative.
- Chat confirmation always states provenance ("approximate, not a surveyed NPC location").
- Search row no longer overlaps the "Quests (N)" header (list moved down 22px, QUESTS tab only).
- Filtering the list clears a selected quest the filter hides.
- Preview toggle renamed "PREVIEW [-]" (was a duplicate "UP NEXT"), hidden on the final step.
- `build()` was at 59 of Lua 5.1's 60-upvalue limit; construction pieces moved to helpers (now 56).

Data.lua, RouteData.lua, Preferences.lua, MinimapButton.lua, WelcomePopup.lua: unchanged.
