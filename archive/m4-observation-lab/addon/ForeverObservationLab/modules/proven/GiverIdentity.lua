-- Proven module: NPC name, creature ID (parsed, never raw GUID), position.
-- The QuestieLearner-style GUID technique this relies on is [V] confirmed
-- across 14 distinct NPCs (M3). Raw GUIDs are never stored -- see
-- core/GuidUtil.lua's own safety note.
--
-- POSITION CAVEAT (see core/PositionUtil.lua for the full note): the
-- `position` field captured here is the PLAYER's own position at the
-- moment of interaction, not the giver NPC's world position. This module
-- does not resolve or claim to know where the NPC itself actually stands.

ForeverLab = ForeverLab or {}

local function captureUnit(unit)
	local rec = { unit = unit }
	local creatureID, parseNote = ForeverLab.GuidUtil.CreatureIDFromUnit(unit)
	rec.parsed_creature_id, rec.parse_note = creatureID, parseNote

	local okN, errN, vN = ForeverLab.SafeCall(UnitName, 1, unit)
	rec.name_ok, rec.name = okN, okN and vN[1] or nil
	rec.name_error = (not okN) and errN or nil

	local okL, errL, vL = ForeverLab.SafeCall(UnitLevel, 1, unit)
	rec.level_ok, rec.level = okL, okL and vL[1] or nil
	rec.level_error = (not okL) and errL or nil

	for _, api in ipairs({ "UnitClassification", "UnitCreatureType", "UnitCreatureFamily" }) do
		local fn = _G[api]
		local ok, err, v = ForeverLab.SafeCall(fn, 1, unit)
		rec[api] = { ok = ok, value = ok and v[1] or nil, error = (not ok) and err or nil }
	end

	rec.position = ForeverLab.PositionUtil.Capture()
	return rec
end

ForeverLab.Registry:Register({
	name = "GiverIdentity",
	status = "proven",
	checkpoints = { "quest_detail", "quest_complete_immediate", "quest_complete_delayed", "GOSSIP_SHOW" },
	capture = function(ctx)
		return {
			ok = true,
			api_source = "UnitGUID/UnitName/UnitLevel/... + C_Map position",
			npc = captureUnit(ctx.npc_unit or "npc"),
			target = captureUnit(ctx.target_unit or "target"),
		}
	end,
})
