-- ForeverLab.GuidUtil: parses a unit GUID into a creature/NPC ID.
--
-- SAFETY: this function NEVER returns the raw GUID string. Only the parsed
-- numeric ID (or nil + a reason) comes back. This is a deliberate,
-- permanent hardening from the M4 item-retry follow-up onward -- M3's
-- original probe kept the raw GUID to validate the parsing technique
-- itself; that technique is now proven ([V], 14 distinct NPCs, M3), so
-- there is no remaining reason for any code in this lab to ever see or
-- store a raw GUID. Any future module must call THIS function to get a
-- creature ID and must never call UnitGUID() directly and keep the result.

ForeverLab = ForeverLab or {}
ForeverLab.GuidUtil = {}

-- Technique: QuestieLearner-style, confirmed [V] on Forever (M3): split on
-- "-", the 6th field is the creature/NPC ID for Creature-/Vehicle-type GUIDs.
function ForeverLab.GuidUtil.CreatureIDFromUnit(unit)
	local ok, err, v = ForeverLab.SafeCall(UnitGUID, 1, unit)
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
