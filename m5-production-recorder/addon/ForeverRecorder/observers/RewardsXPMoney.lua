-- Ported unchanged from the Observation Lab's proven RewardsXPMoney
-- module. M3 established (corrected from an initial wrong belief, with 15
-- real turn-ins) that QUEST_TURNED_IN's event arguments are the reliable
-- source. GetQuestLogRewardMoney/XP (no-argument query) are never called
-- here -- confirmed unreliable on 15 of 16 real quests tested, and
-- nothing since has changed that finding.

ForeverRecorder = ForeverRecorder or {}

ForeverRecorder.Registry:Register({
	name = "RewardsXPMoney",
	status = "proven",
	checkpoints = { "QUEST_TURNED_IN" },
	capture = function(ctx)
		local args = ctx.raw_event_args or {}
		return {
			ok = true,
			api_source = "QUEST_TURNED_IN event arguments",
			quest_id_arg = args[1],
			xp_reward = args[2],
			money_reward = args[3],
		}
	end,
})
