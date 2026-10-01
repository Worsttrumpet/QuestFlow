-- Ported unchanged from the Observation Lab's proven GiverIdentity module,
-- INCLUDING the real-data fix found during M4 integration: a GiverIdentity
-- observation may legitimately have no quest_id (most commonly at
-- GOSSIP_SHOW, since Dispatcher.lua never sets one there by design). This
-- must be first-class in M5 from the start, not rediscovered.
--
-- POSITION CAVEAT: `position` is always the PLAYER's position at the
-- moment of interaction, never the NPC's own world position.
--
-- KNOWN LIMITATION, unchanged, documented not fixed: a quest can show
-- different NPCs at different checkpoints (real example: quest 92528 --
-- Missionary Jasaan at quest_detail, Constable Aonda at turn-in). Both are
-- preserved as separate observations; "giver.npc" (assigned at import
-- time, not by this module) does not yet distinguish which role each
-- played.

ForeverRecorder = ForeverRecorder or {}

local function captureUnit(unit)
	local rec = { unit = unit }
	local creatureID, parseNote = ForeverRecorder.GuidUtil.CreatureIDFromUnit(unit)
	rec.parsed_creature_id, rec.parse_note = creatureID, parseNote

	local okN, errN, vN = ForeverRecorder.SafeCall(UnitName, 1, unit)
	rec.name_ok, rec.name = okN, okN and vN[1] or nil
	rec.name_error = (not okN) and errN or nil

	local okL, errL, vL = ForeverRecorder.SafeCall(UnitLevel, 1, unit)
	rec.level_ok, rec.level = okL, okL and vL[1] or nil
	rec.level_error = (not okL) and errL or nil

	for _, api in ipairs({ "UnitClassification", "UnitCreatureType", "UnitCreatureFamily" }) do
		local fn = _G[api]
		local ok, err, v = ForeverRecorder.SafeCall(fn, 1, unit)
		rec[api] = { ok = ok, value = ok and v[1] or nil, error = (not ok) and err or nil }
	end

	rec.position = ForeverRecorder.PositionUtil.Capture()
	return rec
end

ForeverRecorder.Registry:Register({
	name = "GiverIdentity",
	status = "proven",
	checkpoints = { "quest_detail", "quest_progress", "quest_complete_immediate", "quest_complete_delayed", "GOSSIP_SHOW" },
	capture = function(ctx)
		return {
			ok = true,
			api_source = "UnitGUID/UnitName/UnitLevel/... + C_Map position",
			npc = captureUnit(ctx.npc_unit or "npc"),
			target = captureUnit(ctx.target_unit or "target"),
		}
	end,
})
