-- ForeverRecorder.GuidUtil: ported unchanged from the Observation Lab.
-- SAFETY: never returns the raw GUID string, only the parsed numeric ID
-- (or nil + a reason). The QuestieLearner-style parsing technique this
-- relies on is [V] confirmed across 14+ distinct NPCs (M3/M4).

ForeverRecorder = ForeverRecorder or {}
ForeverRecorder.GuidUtil = {}

function ForeverRecorder.GuidUtil.CreatureIDFromUnit(unit)
	local ok, err, v = ForeverRecorder.SafeCall(UnitGUID, 1, unit)
	if not ok then
		return nil, "UnitGUID failed: " .. tostring(err)
	end
	local guid = v[1]
	if type(guid) ~= "string" then
		return nil, "guid not a string (unit not present?)"
	end
	local unitType, _, _, _, _, npcID = strsplit("-", guid)
	if unitType == "Creature" or unitType == "Vehicle" then
		return tonumber(npcID), nil
	end
	return nil, "unitType=" .. tostring(unitType)
end
