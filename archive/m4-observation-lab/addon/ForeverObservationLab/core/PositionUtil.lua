-- ForeverLab.PositionUtil: player position capture, same pattern proven
-- across every prior probe. C_Map.GetBestMapForUnit + C_Map.GetPlayerMapPosition
-- are plumbing helpers, not part of any audited API list -- needed to call
-- C_Map.GetPlayerMapPosition meaningfully.
--
-- IMPORTANT, added after the M4 repository audit: this always captures the
-- PLAYER's own position at the moment of interaction ("player" is the only
-- unit token passed below) -- it is NOT the NPC's/giver's world position.
-- In practice the two are usually close (you have to be standing near an
-- NPC to interact with it), but they are not the same value, and nothing
-- here attempts to resolve the NPC's own coordinates. Any module or future
-- reader treating this as "the giver's location" would be assuming
-- something this function does not actually provide.

ForeverLab = ForeverLab or {}
ForeverLab.PositionUtil = {}

function ForeverLab.PositionUtil.Capture()
	local out = { helper = "C_Map.GetBestMapForUnit + C_Map.GetPlayerMapPosition (plumbing only)" }
	local okMap, errMap, vMap = ForeverLab.SafeCall(C_Map and C_Map.GetBestMapForUnit, 1, "player")
	out.map_ok, out.map_id_or_error = okMap, okMap and vMap[1] or errMap
	if okMap and vMap[1] then
		local okPos, errPos, vPos = ForeverLab.SafeCall(C_Map and C_Map.GetPlayerMapPosition, 1, vMap[1], "player")
		out.position_ok = okPos
		if okPos and vPos[1] then
			local pos = vPos[1]
			local okXY, errXY, vXY = ForeverLab.SafeCall(pos.GetXY, 2, pos)
			out.position_getxy_ok, out.x, out.y = okXY, okXY and vXY[1] or nil, okXY and vXY[2] or nil
		else
			out.position_error = errPos
		end
	end
	return out
end
