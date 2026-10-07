# ForeverQuestGuide m8-guide-addon-0.6 — Real-Client Validation

Date: 2026-09-29
Client: WoW Forever beta (interface 16001), character in Undercity (player position 70.3, 10.1)
Evidence: two in-game screenshots taken during the session, plus the earlier manual `/run` API probe.
No new quest data was collected for this test; it exercises UI/navigation against existing M6 evidence only.

## Results

| Check | Result | Evidence |
|---|---|---|
| Quests-tab search row no longer overlaps "Quests (96 guide-ready)" header | PASS | Screenshot 2: search row and header on separate lines |
| Quests-tab Show on Map places a pin | PASS | Screenshot 2: chat "Pinned Innkeeper Grosk (A Peon's Burden) at 51.6, 41.7 (map 1411)" |
| Map opens to the destination zone | PASS | Screenshot 1 opened to Kalimdor > The Barrens; screenshot 2 to Kalimdor > Durotar, both from Undercity |
| Durotar pin (map 1411) — first map other than 1413 | PASS | Screenshot 2: pin at Razor Hill, matching Innkeeper Grosk's location |
| Route step 4 Show on Map | PASS | Screenshot 1: chat "Pinned Jorn Skyseer at 44.9, 59.1 (map 1413)", pin at Jorn's camp |
| Barrens pin (map 1413) | PASS | Screenshot 1 |
| Chat confirmation states provenance | PASS | Both screenshots: "Approximate: … not a surveyed NPC location" |
| Preview toggle reads "PREVIEW [-]" (no duplicate "UP NEXT") | PASS | Screenshot 1 |
| Steps without a destination show a dimmed button + explanation | PENDING | Not visible in the screenshots — confirm on steps 1, 2, 3 or 5 |
| No Lua errors during the session | PENDING | Not visible in the screenshots — confirm with `/console scriptErrors 1` enabled |
| Final-step preview toggle hidden | PENDING | Not visible in the screenshots — confirm on step 5 |

## APIs now confirmed on Forever (cumulative)

- `C_Map.SetUserWaypoint`, `C_Map.CanSetUserWaypointOnMap`, `C_Map.ClearUserWaypoint` (probe)
- `C_SuperTrack.SetSuperTrackedUserWaypoint`
- `UiMapPoint.CreateFromCoordinates`
- `WorldMapFrame:SetMapID` + `ToggleWorldMap` (map opened to the correct zone from another continent)
- Waypoints accepted on uiMapID 1413 (The Barrens) and 1411 (Durotar)

## Still unconfirmed

- Pins on Eastern Kingdoms maps (no guide-ready quest there has been pinned yet)
- Super-track arrow behaviour when the player is on the same continent as the pin

## Observation (not a failure of this release)

In both screenshots the left edge of the guide window is clipped — "Routes", "Step", "Quest" and the
list's quest IDs are cut off. The window was dragged to the right side of the screen and appears to sit
beneath another UI element. Candidate fix for a later milestone: `frame:SetFrameStrata("HIGH")` in `build()`,
or clamp the window to the screen with `frame:SetClampedToScreen(true)`. Neither is confirmed on Forever yet.

## Status

```text
m8-guide-addon-0.6: PASS on all screenshot-verified checks; 3 checks pending user confirmation.
```
