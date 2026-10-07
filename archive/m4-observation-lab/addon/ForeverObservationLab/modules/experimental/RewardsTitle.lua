-- EXPERIMENTAL. GetQuestLogRewardTitle has been present (type()=function)
-- since M3, and was called once there -- but at accept-time, the same
-- wrong lifecycle moment that made every other reward field read empty
-- before the checkpoint fix. Never retested at the corrected checkpoints.
-- A successful call here does NOT make this [V] -- only real, non-empty
-- data on a quest independently known to grant a title would.

ForeverLab = ForeverLab or {}

ForeverLab.Registry:Register({
	name = "RewardsTitle",
	status = "experimental",
	checkpoints = { "quest_complete_immediate", "quest_complete_delayed" },
	capture = function(ctx)
		local ok, err, v = ForeverLab.SafeCall(GetQuestLogRewardTitle, 1)
		return {
			ok = ok,
			api_source = "GetQuestLogRewardTitle (no-argument, current-dialog convention)",
			error = (not ok) and err or nil,
			title_value = ok and v[1] or nil,
		}
	end,
})
