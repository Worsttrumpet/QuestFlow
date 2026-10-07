-- EXPERIMENTAL placeholder. No candidate API name for currency quest
-- rewards has been identified or verified yet (unlike Spell/Title/Honor,
-- which at least have real, previously-scanned-present function names).
-- Per explicit instruction: do not invent or guess a currency API. This
-- module registers so the lab's architecture has a slot ready, and does
-- nothing else until real research (the same kind done for reputation --
-- checking a primary source like Blizzard's own FrameXML) identifies a
-- real name to test.

ForeverLab = ForeverLab or {}

ForeverLab.Registry:Register({
	name = "RewardsCurrency",
	status = "experimental",
	checkpoints = { "quest_complete_immediate", "quest_complete_delayed" },
	capture = function(ctx)
		return {
			ok = false,
			api_source = "none -- no candidate API identified",
			error = "placeholder module: no verified currency-reward API name exists yet; " ..
				"not attempting a guessed call",
		}
	end,
})
