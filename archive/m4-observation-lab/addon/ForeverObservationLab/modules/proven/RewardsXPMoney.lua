-- Proven module: XP/money. M3 established (and the reputation follow-up's
-- own turn-ins reconfirmed) that QUEST_TURNED_IN's event arguments are the
-- reliable source, NOT GetQuestLogRewardMoney/XP called with no arguments
-- (those returned zero on 15 of 16 real quests tested). This module reads
-- only the event arguments -- it does not attempt the no-argument query.

ForeverLab = ForeverLab or {}

ForeverLab.Registry:Register({
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
