-- COPIED from m8-13-progression/ForeverQuestGuide/MapPin.lua (M8.13, real-client validated).
-- Only the exported namespace name / user-facing strings were changed; the logic is untouched.
-- Re-copy rather than editing logic here, so fixes stay traceable to the M8.13 original.

-- ForeverCodex.MapPin (was ForeverQuestGuide.MapPin): places ONE user waypoint (the game's own map pin + super-track arrow) on request.
--
-- M8.7: this replaces the M8.1-M8.6 "Show on Map: not implemented" placeholder. What was confirmed on the
-- live Forever client (manual /run probe, 2026-09-29) before any of this code was written:
--   * C_Map.SetUserWaypoint exists                      -> true
--   * C_SuperTrack exists                               -> true
--   * C_Map.CanSetUserWaypointOnMap(1413) (Barrens)     -> true
--   * UiMapPoint.CreateFromCoordinates(1413, 0.449, 0.591) + SetUserWaypoint + SetSuperTrackedUserWaypoint
--     placed a visible pin at Jorn Skyseer's camp (verified on the Kalimdor world map). It looked like it
--     "did nothing" at first only because the map was open to Undercity, where a Barrens pin cannot draw.
-- NOT confirmed: every map other than 1413, WorldMapFrame:SetMapID behavior, and the arrow's appearance
-- across continents. Every call below is therefore feature-checked and pcall-wrapped (ns.Safe), and every
-- failure path prints a plain reason instead of raising a Lua error.
--
-- READ-ONLY with respect to quests: a waypoint is a purely visual marker. Nothing here touches quest state.
-- Only ONE user waypoint exists at a time (a game rule, not ours) -- placing a new one replaces the old one.

local addonName, ns = ...

local function apisPresent()
	return type(C_Map) == "table"
		and type(C_Map.SetUserWaypoint) == "function"
		and type(C_Map.CanSetUserWaypointOnMap) == "function"
		and type(C_SuperTrack) == "table"
		and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function"
end

--- Builds the point table. Prefers Blizzard's UiMapPoint helper (confirmed present on Forever), but falls
-- back to the plain { uiMapID, position } shape SetUserWaypoint also accepts, in case a future build drops it.
local function makePoint(mapID, x, y)
	if type(UiMapPoint) == "table" and type(UiMapPoint.CreateFromCoordinates) == "function" then
		local ok, p = ns.Safe(UiMapPoint.CreateFromCoordinates, mapID, x, y)
		if ok and p then
			return p
		end
	end
	if type(CreateVector2D) == "function" then
		local ok, v = ns.Safe(CreateVector2D, x, y)
		if ok and v then
			return { uiMapID = mapID, position = v }
		end
	end
	return nil
end

--- Opens the world map directly to `mapID` so the pin is actually visible. Best-effort only: if any part
-- is unavailable the pin is still placed, and the player can open the map themselves.
local function openMapTo(mapID)
	if not WorldMapFrame then
		return
	end
	local okShown, shown = ns.Safe(WorldMapFrame.IsShown, WorldMapFrame)
	if okShown and not shown then
		if type(ToggleWorldMap) == "function" then
			ns.Safe(ToggleWorldMap)
		else
			ns.Safe(WorldMapFrame.Show, WorldMapFrame)
		end
	end
	ns.Safe(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
end

--- Places a pin. Returns (true, nil) on success or (false, reason) on any failure -- never errors.
-- `label` and `note` are only used in the chat confirmation; `note` states the coordinate's provenance.
local function place(mapID, x, y, label, note)
	if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
		return false, "no coordinates are recorded for this entry."
	end
	if not apisPresent() then
		return false, "this client does not expose the map-waypoint API."
	end
	local okCan, can = ns.Safe(C_Map.CanSetUserWaypointOnMap, mapID)
	if not okCan or not can then
		return false, string.format("the game does not allow pins on map %d.", mapID)
	end
	local point = makePoint(mapID, x, y)
	if not point then
		return false, "could not build a map point on this client."
	end
	local okSet, errSet = ns.Safe(C_Map.SetUserWaypoint, point)
	if not okSet then
		return false, "placing the pin failed: " .. tostring(errSet)
	end
	ns.Safe(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
	openMapTo(mapID)
	ns.Say(string.format("Pinned %s at %.1f, %.1f (map %d). %s",
		label or "location", x * 100, y * 100, mapID, note or "Approximate position."))
	return true, nil
end

--- Removes the current user waypoint, if the API exists. Returns true if the clear call ran.
local function clear()
	if type(C_Map) == "table" and type(C_Map.ClearUserWaypoint) == "function" then
		return (ns.Safe(C_Map.ClearUserWaypoint))
	end
	return false
end

ns.MapPin = {
	Place = place,
	Clear = clear,
	APIsPresent = apisPresent,
}
