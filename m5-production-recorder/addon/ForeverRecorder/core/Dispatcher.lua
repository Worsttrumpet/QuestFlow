-- ForeverRecorder.Dispatcher: ported from the Observation Lab's
-- Dispatcher.lua. The event-routing logic and observation envelope are
-- UNCHANGED in shape -- both already passed real-client testing. The only
-- removal: the Lab's /flab scan (api_scan) responsibility does not exist
-- here at all -- that was a research diagnostic, not a production need
-- (M5 design §2/§4).

ForeverRecorder = ForeverRecorder or {}
ForeverRecorder.Dispatcher = {}

local DELAYED_CHECKPOINT_SECONDS = 1.5

local function recordObservation(moduleDef, checkpointOrEvent, questID, ok, err, payload)
	table.insert(ForeverObservationLabDB.observations, {
		module_name = moduleDef.name,
		module_status = moduleDef.status, -- always "proven" in this build, enforced by Registry:Register
		checkpoint = checkpointOrEvent,
		quest_id = questID,
		-- Stamped from ForeverRecorder.CurrentSessionID / CurrentBuildInfo AT
		-- THE MOMENT this observation is created -- never read live from
		-- ForeverObservationLabDB.meta, which is overwritten every login. Same
		-- fix, same reasoning, as the Observation Lab's M4-audit fix.
		session_id = ForeverRecorder.CurrentSessionID,
		observed_build = ForeverRecorder.CurrentBuildInfo and ForeverRecorder.CurrentBuildInfo.observed_build,
		observed_toc_version = ForeverRecorder.CurrentBuildInfo and ForeverRecorder.CurrentBuildInfo.observed_toc_version,
		observed_version = ForeverRecorder.CurrentBuildInfo and ForeverRecorder.CurrentBuildInfo.observed_version,
		observed_build_date = ForeverRecorder.CurrentBuildInfo and ForeverRecorder.CurrentBuildInfo.observed_build_date,
		recorded_at = ForeverRecorder.Now(),
		ok = ok,
		error = (not ok) and err or nil,
		data = ok and payload or nil,
	})
end

local function runCapture(moduleDef, ctx)
	local okRun, result = pcall(moduleDef.capture, ctx)
	if not okRun then
		recordObservation(moduleDef, ctx.checkpoint, ctx.quest_id, false,
			"module capture() errored: " .. tostring(result), nil)
		return
	end
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
		recordObservation(moduleDef, ctx.checkpoint or eventName, ctx.quest_id, true, nil, result)
	end
end

local function dispatchCheckpoint(checkpoint, ctx)
	ctx.checkpoint = checkpoint
	for _, def in ipairs(ForeverRecorder.Registry:ModulesForCheckpoint(checkpoint)) do
		if def.capture then
			runCapture(def, ctx)
		end
	end
end

local function dispatchEvent(eventName, ctx, ...)
	for _, def in ipairs(ForeverRecorder.Registry:ModulesForEvent(eventName)) do
		if def.on_event then
			runOnEvent(def, ctx, eventName, ...)
		end
	end
end

local frame = CreateFrame("Frame")
ForeverRecorder.Dispatcher.frame = frame -- exposed for tests
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_FINISHED")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local loaded = ...
		if loaded == "ForeverRecorder" then
			ForeverRecorder.InitMeta()
			ForeverRecorder.PrintBanner()
		end
		return
	end

	if event == "PLAYER_LOGIN" then
		ForeverRecorder.Say("Slash commands: /fr status | /fr save | /fr clear")
		return
	end

	if event == "QUEST_DETAIL" then
		local okQ, _, vQ = ForeverRecorder.SafeCall(GetQuestID, 1)
		local ctx = { quest_id = okQ and vQ[1] or nil, npc_unit = "npc", target_unit = "target" }
		dispatchCheckpoint("quest_detail", ctx)
		return
	end

	if event == "QUEST_PROGRESS" then
		-- Same GetQuestID() mechanism QUEST_DETAIL already uses (M7.7): both are
		-- UI-frame-driven events, so the same frame-state-dependent lookup is the
		-- existing, precedented approach here -- not a new pattern. If it returns
		-- nil (unverified whether it does on this client at this checkpoint), the
		-- existing capture()/error-handling path already used everywhere else
		-- (QuestMeta returns ok=false, "no quest_id in context") applies exactly
		-- as-is -- no invented ID, no special-casing needed.
		local okQ, _, vQ = ForeverRecorder.SafeCall(GetQuestID, 1)
		local ctx = { quest_id = okQ and vQ[1] or nil, npc_unit = "npc", target_unit = "target" }
		dispatchCheckpoint("quest_progress", ctx)
		return
	end

	if event == "QUEST_COMPLETE" then
		local okQ, _, vQ = ForeverRecorder.SafeCall(GetQuestID, 1)
		local questID = okQ and vQ[1] or nil
		local ctx = { quest_id = questID, npc_unit = "npc", target_unit = "target" }
		dispatchCheckpoint("quest_complete_immediate", ctx)

		local okTimer, errTimer = ForeverRecorder.SafeCall(C_Timer and C_Timer.After, 0, DELAYED_CHECKPOINT_SECONDS, function()
			local delayedCtx = { quest_id = questID, npc_unit = "npc", target_unit = "target" }
			dispatchCheckpoint("quest_complete_delayed", delayedCtx)
		end)
		if not okTimer then
			for _, def in ipairs(ForeverRecorder.Registry:ModulesForCheckpoint("quest_complete_delayed")) do
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
		-- per turn-in (confirmed repeatedly, M3 through M4) and carries no data.
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
