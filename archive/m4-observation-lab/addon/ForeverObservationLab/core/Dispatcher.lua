-- ForeverLab.Dispatcher: the single event frame for this addon, and the
-- orchestration that turns a game event into checkpoint-tagged module
-- observations.
--
-- Every module call (capture or on_event) is itself wrapped in pcall here,
-- separately from SafeCall -- a broken EXPERIMENTAL module must never be
-- able to crash the dispatcher or stop proven modules from running.

ForeverLab = ForeverLab or {}
ForeverLab.Dispatcher = {}

local DELAYED_CHECKPOINT_SECONDS = 1.5

local function recordObservation(moduleDef, checkpointOrEvent, questID, ok, err, payload)
	table.insert(ForeverObservationLabDB.observations, {
		module_name = moduleDef.name,
		module_status = moduleDef.status, -- "proven" | "experimental" -- maturity of the MODULE
		checkpoint = checkpointOrEvent,
		quest_id = questID,
		-- Stamped from ForeverLab.CurrentSessionID AT THE MOMENT this
		-- observation is created, not read from meta.session_id (which is
		-- overwritten on the next login). This is what lets observations
		-- accumulated across multiple sessions in one file retain the
		-- session_id of whichever session actually captured each one.
		session_id = ForeverLab.CurrentSessionID,
		-- Same pattern, same reason, for build identity (added after the
		-- M4 adversarial review found this gap existed for build info even
		-- though the identical problem had already been fixed for
		-- session_id). Read from ForeverLab.CurrentBuildInfo, a plain
		-- snapshot table set once at InitMeta() time -- never from
		-- ForeverObservationLabDB.meta, which is overwritten every login.
		observed_build = ForeverLab.CurrentBuildInfo and ForeverLab.CurrentBuildInfo.observed_build,
		observed_toc_version = ForeverLab.CurrentBuildInfo and ForeverLab.CurrentBuildInfo.observed_toc_version,
		observed_version = ForeverLab.CurrentBuildInfo and ForeverLab.CurrentBuildInfo.observed_version,
		observed_build_date = ForeverLab.CurrentBuildInfo and ForeverLab.CurrentBuildInfo.observed_build_date,
		recorded_at = ForeverLab.Now(),
		ok = ok,             -- did the module's own capture succeed, at THIS observation
		error = (not ok) and err or nil,
		data = ok and payload or nil,
	})
end

-- Runs one module's capture() (checkpoint-driven) safely.
local function runCapture(moduleDef, ctx)
	local okRun, result = pcall(moduleDef.capture, ctx)
	if not okRun then
		recordObservation(moduleDef, ctx.checkpoint, ctx.quest_id, false,
			"module capture() errored: " .. tostring(result), nil)
		return
	end
	-- The module's own returned table is expected to carry its own
	-- ok/error/values fields (module-specific shape); the envelope here
	-- only tracks whether the module *ran* without a Lua error. A module
	-- that ran fine but whose underlying API call failed still reports
	-- ok=true at the envelope level with ok=false inside its own payload
	-- -- both are preserved, neither overwrites the other.
	recordObservation(moduleDef, ctx.checkpoint, ctx.quest_id, true, nil, result)
end

local function runOnEvent(moduleDef, ctx, eventName, ...)
	local okRun, result = pcall(moduleDef.on_event, ctx, eventName, ...)
	if not okRun then
		recordObservation(moduleDef, ctx.checkpoint or eventName, ctx.quest_id, false,
			"module on_event() errored: " .. tostring(result), nil)
		return
	end
	if result ~= nil then
		-- A module may set ctx.checkpoint inside on_event (e.g. a retry
		-- module wanting "retry_after_get_item_info_received_2" recorded
		-- instead of the bare raw event name); honor that if present.
		recordObservation(moduleDef, ctx.checkpoint or eventName, ctx.quest_id, true, nil, result)
	end
end

local function dispatchCheckpoint(checkpoint, ctx)
	ctx.checkpoint = checkpoint
	local mods = ForeverLab.Registry:ActiveModulesForCheckpoint(checkpoint)
	for _, def in ipairs(mods) do
		if def.capture then
			runCapture(def, ctx)
		end
	end
end

local function dispatchEvent(eventName, ctx, ...)
	local mods = ForeverLab.Registry:ActiveModulesForEvent(eventName)
	for _, def in ipairs(mods) do
		if def.on_event then
			runOnEvent(def, ctx, eventName, ...)
		end
	end
end

local frame = CreateFrame("Frame")
ForeverLab.Dispatcher.frame = frame -- exposed for tests
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_FINISHED")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local loaded = ...
		if loaded == "ForeverObservationLab" then
			ForeverLab.InitMeta()
			ForeverLab.PrintBanner()
		end
		return
	end

	if event == "PLAYER_LOGIN" then
		ForeverLab.Say("Slash commands: /flab scan | /flab status | /flab clear | /flab save | "
			.. "/flab list | /flab enable <Module> | /flab disable <Module>")
		return
	end

	if event == "QUEST_DETAIL" then
		local okQ, _, vQ = ForeverLab.SafeCall(GetQuestID, 1)
		local ctx = { quest_id = okQ and vQ[1] or nil, npc_unit = "npc", target_unit = "target" }
		dispatchCheckpoint("quest_detail", ctx)
		return
	end

	if event == "QUEST_COMPLETE" then
		local okQ, _, vQ = ForeverLab.SafeCall(GetQuestID, 1)
		local questID = okQ and vQ[1] or nil
		local ctx = { quest_id = questID, npc_unit = "npc", target_unit = "target" }
		dispatchCheckpoint("quest_complete_immediate", ctx)

		local okTimer, errTimer = ForeverLab.SafeCall(C_Timer and C_Timer.After, 0, DELAYED_CHECKPOINT_SECONDS, function()
			local delayedCtx = { quest_id = questID, npc_unit = "npc", target_unit = "target" }
			dispatchCheckpoint("quest_complete_delayed", delayedCtx)
		end)
		if not okTimer then
			-- Record the scheduling failure itself against every module that
			-- would have run at this checkpoint, so its absence is visible,
			-- not silent.
			for _, def in ipairs(ForeverLab.Registry:ActiveModulesForCheckpoint("quest_complete_delayed")) do
				recordObservation(def, "quest_complete_delayed", questID, false,
					"C_Timer.After unavailable: " .. tostring(errTimer), nil)
			end
		end
		return
	end

	if event == "QUEST_TURNED_IN" then
		local questID, xpReward, moneyReward = ...
		local ctx = { quest_id = questID, raw_event_args = { questID, xpReward, moneyReward } }
		dispatchCheckpoint("QUEST_TURNED_IN", ctx)
		return
	end

	if event == "QUEST_FINISHED" then
		-- Intentionally not dispatched to any module -- fires multiple times
		-- per turn-in (observed in every prior probe) and carries no data.
		return
	end

	if event == "GOSSIP_SHOW" then
		local ctx = { npc_unit = "npc", target_unit = "target" }
		dispatchCheckpoint("GOSSIP_SHOW", ctx)
		return
	end

	if event == "GET_ITEM_INFO_RECEIVED" then
		local ctx = {}
		dispatchEvent("GET_ITEM_INFO_RECEIVED", ctx, ...)
		return
	end
end)
