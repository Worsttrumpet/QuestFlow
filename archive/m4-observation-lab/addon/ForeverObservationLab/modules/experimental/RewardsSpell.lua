-- EXPERIMENTAL. C_QuestInfoSystem.GetQuestRewardSpells has been present
-- (type()=function) in every prior scan since M3, but no quest tested so
-- far has actually had a spell reward -- this module has never seen real
-- non-empty data. A successful, error-free call here does NOT make this
-- [V]; it only means the module ran without a Lua error against whatever
-- quest triggered it, which may still be a quest with no spell reward.

ForeverLab = ForeverLab or {}

ForeverLab.Registry:Register({
	name = "RewardsSpell",
	status = "experimental",
	checkpoints = { "quest_complete_immediate", "quest_complete_delayed" },
	capture = function(ctx)
		if type(ctx.quest_id) ~= "number" then
			return { ok = false, error = "no quest_id in context" }
		end
		local ok, err, v = ForeverLab.SafeCall(
			C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardSpells, 1, ctx.quest_id)
		return {
			ok = ok,
			api_source = "C_QuestInfoSystem.GetQuestRewardSpells",
			args = { ctx.quest_id },
			error = (not ok) and err or nil,
			spell_ids = ok and v[1] or nil, -- returned as-is; not interpreted
		}
	end,
})
