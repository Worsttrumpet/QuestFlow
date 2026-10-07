-- EXPERIMENTAL placeholder. GetFactionInfoByID is confirmed absent on
-- Forever (M4 reputation follow-up). Per explicit instruction, no
-- replacement faction-name API is invented or assumed here. This module
-- exists only so that IF a candidate is identified later through real
-- research (e.g. checking Blizzard's own FrameXML the way the original
-- reputation APIs were found), it has an obvious, pre-wired place to go
-- without another addon fork.

ForeverLab = ForeverLab or {}

ForeverLab.Registry:Register({
	name = "FactionNameResolution",
	status = "experimental",
	checkpoints = { "quest_complete_immediate", "quest_complete_delayed" },
	capture = function(ctx)
		return {
			ok = false,
			api_source = "none -- no verified alternative to GetFactionInfoByID identified",
			error = "placeholder module: GetFactionInfoByID is confirmed absent on Forever; " ..
				"no replacement API assumed or attempted",
		}
	end,
})
