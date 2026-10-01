-- ForeverRecorder.PositionUtil: ported unchanged from the Observation Lab.
--
-- IMPORTANT: this always captures the PLAYER's own position at the moment
-- of interaction ("player" is the only unit token used below) -- it is
-- NOT the NPC's/giver's world position. Never converted into an
-- NPC-location claim anywhere in this addon.

ForeverRecorder = ForeverRecorder or {}
ForeverRecorder.PositionUtil = {}

function ForeverRecorder.PositionUtil.Capture()
	local out = { helper = "C_Map.GetBestMapForUnit + C_Map.GetPlayerMapPosition (plumbing only)" }
	local okMap, errMap, vMap = ForeverRecorder.SafeCall(C_Map and C_Map.GetBestMapForUnit, 1, "player")
	out.map_ok, out.map_id_or_error = okMap, okMap and vMap[1] or errMap
	if okMap and vMap[1] then
		local okPos, errPos, vPos = ForeverRecorder.SafeCall(C_Map and C_Map.GetPlayerMapPosition, 1, vMap[1], "player")
		out.position_ok = okPos
		if okPos and vPos[1] then
			local pos = vPos[1]
			local okXY, errXY, vXY = ForeverRecorder.SafeCall(pos.GetXY, 2, pos)
			out.position_getxy_ok, out.x, out.y = okXY, okXY and vXY[1] or nil, okXY and vXY[2] or nil
		else
			out.position_error = errPos
		end
	end
	return out
end
