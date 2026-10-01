-- EXPERIMENTAL. GetRewardHonor has been present (type()=function) since
-- M3, called successfully every time, always returned 0. A successful
-- call returning 0 does NOT confirm the API works for a nonzero case --
-- no quest tested so far is independently known to grant honor.

ForeverLab = ForeverLab or {}

ForeverLab.Registry:Register({
	name = "RewardsHonor",
	status = "experimental",
	checkpoints = { "quest_complete_immediate", "quest_complete_delayed" },
	capture = function(ctx)
		local ok, err, v = ForeverLab.SafeCall(GetRewardHonor, 1)
		return {
			ok = ok,
			api_source = "GetRewardHonor",
			error = (not ok) and err or nil,
			honor_value = ok and v[1] or nil,
		}
	end,
})
