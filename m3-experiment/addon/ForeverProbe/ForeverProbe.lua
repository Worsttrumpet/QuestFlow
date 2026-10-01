-- ForeverProbe: M3 disposable research probe.
-- Read-only. Does not accept/complete/turn in quests or move the player.
-- Uninstall after the M3 experiment.

local PROBE_VERSION = "m3-probe-0.1"
-- Observed via /dump GetBuildInfo() during M2 (2026-09-21) on 1.60.1.69913: interface 16001.
-- This is a recorded ASSUMPTION to check against, not something the probe requires to run.
local EXPECTED_INTERFACE = 16001

ForeverProbeDB = ForeverProbeDB or {
	meta = {},
	api_scan = {},
	events = {},
}

----------------------------------------------------------------------
-- small helpers
----------------------------------------------------------------------

local function now()
	return date("%Y-%m-%d %H:%M:%S")
end

-- Safely walk a dotted path like "C_QuestLog.GetInfo" off _G, without
-- erroring if any segment is missing.
local function resolvePath(path)
	local obj = _G
	for part in path:gmatch("[^.]+") do
		if type(obj) ~= "table" then
			return nil
		end
		obj = obj[part]
	end
	return obj
end

-- Call a possibly-missing function without ever throwing. Returns
-- ok, result1..resultN. A missing function is reported as a clean
-- "not a function" failure, never a silent nil.
local function safecall(fn, ...)
	if type(fn) ~= "function" then
		return false, "not a function (type=" .. type(fn) .. ")"
	end
	local results = { pcall(fn, ...) }
	local ok = table.remove(results, 1)
	if not ok then
		return false, tostring(results[1])
	end
	return true, unpack(results)
end

-- Compact, depth-limited stringification for chat output. Full detail
-- still goes into ForeverProbeDB for later inspection; this is only to
-- avoid flooding the chat frame per the "don't dump enormous data" rule.
local function describe(value, depth)
	depth = depth or 0
	local t = type(value)
	if t == "table" then
		if depth >= 2 then
			return "{...}"
		end
		local n = 0
		for _ in pairs(value) do
			n = n + 1
		end
		if n == 0 then
			return "{} (empty table)"
		end
		local parts = {}
		local shown = 0
		for k, v in pairs(value) do
			if shown >= 6 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, tostring(k) .. "=" .. describe(v, depth + 1))
			shown = shown + 1
		end
		return "{" .. table.concat(parts, ", ") .. "} (" .. n .. " keys)"
	elseif t == "string" then
		if #value > 80 then
			return string.format("%q", value:sub(1, 80) .. "...") .. " (" .. #value .. " chars)"
		end
		return string.format("%q", value)
	else
		return tostring(value) .. " (" .. t .. ")"
	end
end

local function say(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[FProbe]|r " .. msg)
	end
end

----------------------------------------------------------------------
-- 1. Print interface/build assumptions clearly
----------------------------------------------------------------------

local function printAssumptions()
	local version, build, buildDate, tocversion = GetBuildInfo()
	ForeverProbeDB.meta = {
		probe_version = PROBE_VERSION,
		recorded_at = now(),
		observed_version = version,
		observed_build = build,
		observed_build_date = buildDate,
		observed_toc_version = tocversion,
		expected_toc_version = EXPECTED_INTERFACE,
		toc_version_matches_expectation = (tocversion == EXPECTED_INTERFACE),
	}
	say("probe " .. PROBE_VERSION .. " loaded. Read-only: does not accept/complete/turn in quests.")
	say(string.format(
		"GetBuildInfo() = %s, %s, %s, %s",
		tostring(version), tostring(build), tostring(buildDate), tostring(tocversion)
	))
	if tocversion == EXPECTED_INTERFACE then
		say("Interface matches the M2-recorded expectation (" .. EXPECTED_INTERFACE .. "). [V]")
	else
		say("Interface DIFFERS from the M2-recorded expectation (" .. EXPECTED_INTERFACE
			.. "). Recording the real value; not treating this as an error.")
	end
end

----------------------------------------------------------------------
-- 2/3. API existence scan (type() only, on demand via slash command)
----------------------------------------------------------------------

local API_PATHS = {
	-- quest log / details
	"C_QuestLog.GetInfo", "C_QuestLog.GetQuestObjectives", "GetQuestLogQuestText",
	"GetQuestLogCompletionText", "C_QuestLog.GetQuestInfo", "GetQuestLogTitle", "HaveQuestData",
	-- rewards
	"GetNumQuestRewards", "GetQuestLogRewardInfo", "GetQuestLogRewardMoney", "GetQuestLogRewardXP",
	"GetQuestLogRewardTitle", "GetQuestLogChoiceInfo", "C_QuestInfoSystem.GetQuestRewardSpells",
	"GetRewardHonor",
	-- quest/map
	"C_QuestLog.GetQuestsOnMap", "C_QuestLog.GetMapForQuestPOIs", "C_QuestLog.IsQuestFlaggedCompleted",
	"QuestPOIGetIconInfo", "C_TaskQuest.GetQuestLocation", "C_TaskQuest.GetQuestsOnMap",
	-- quest completion
	"IsQuestComplete", "IsQuestCompletable", "GetQuestsCompleted", "C_QuestLog.IsOnQuest",
	-- NPC/gossip
	"C_GossipInfo.GetAvailableQuests", "C_GossipInfo.GetActiveQuests", "GetQuestPortraitGiver",
	"GetQuestLogPortraitGiver", "GetQuestLogPortraitTurnIn",
	-- NPC/position
	"UnitPosition", "C_Map.GetPlayerMapPosition", "UnitName", "UnitGUID", "UnitLevel",
	"UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "ClosestUnitPosition",
	"ClosestGameObjectPosition",
	-- taxi
	"C_TaxiMap.GetAllTaxiNodes", "C_TaxiMap.GetTaxiNodesForMap", "TaxiNodeName", "TaxiNodePosition",
	"GetTaxiNodeCost",
	-- helpers the probe itself needs to call some of the above meaningfully;
	-- NOT part of the M3-specified list, kept separate in the report
	"C_QuestLog.GetNumQuestLogEntries", "C_Map.GetBestMapForUnit",
}

local function scanAPIs()
	ForeverProbeDB.api_scan = {}
	local present, missing = 0, 0
	for _, path in ipairs(API_PATHS) do
		local v = resolvePath(path)
		local ty = type(v)
		table.insert(ForeverProbeDB.api_scan, { path = path, type = ty })
		if ty == "function" then
			present = present + 1
		else
			missing = missing + 1
		end
		say(string.format("%-42s type()=%s", path, ty))
	end
	say(string.format("API scan complete: %d present as functions, %d not.", present, missing))
end

----------------------------------------------------------------------
-- 4/5. Quest lifecycle event recording
----------------------------------------------------------------------

-- Extracts the numeric NPC/creature id from a GUID string, per the
-- widely-used "Creature-0-serverID-instanceID-zoneUID-npcID-spawnUID"
-- layout. This is the technique reported for QuestieLearner [2nd];
-- untested on Forever until this probe runs. The raw GUID is always
-- recorded alongside the parsed value so a wrong split is visible,
-- not hidden.
local function creatureIDFromGUID(guid)
	if type(guid) ~= "string" then
		return nil, "guid not a string"
	end
	local unitType, _, _, _, _, npcID = strsplit("-", guid)
	if unitType == "Creature" or unitType == "Vehicle" then
		return tonumber(npcID)
	end
	return nil, "unitType=" .. tostring(unitType)
end

local function capturePosition()
	local out = { helper = "C_Map.GetBestMapForUnit + C_Map.GetPlayerMapPosition (not in the audited API list; plumbing only)" }
	local mapAPI = resolvePath("C_Map.GetBestMapForUnit")
	local ok1, mapID = safecall(mapAPI, "player")
	out.map_ok, out.map_id_or_error = ok1, mapID
	if ok1 and mapID then
		local posAPI = resolvePath("C_Map.GetPlayerMapPosition")
		local ok2, pos = safecall(posAPI, mapID, "player")
		out.position_ok = ok2
		if ok2 and pos then
			-- WowPoint-like object; GetXY() is the documented accessor.
			local ok3, x, y = safecall(pos.GetXY, pos)
			out.position_getxy_ok, out.x, out.y = ok3, x, y
		else
			out.position_error = pos
		end
	end
	return out
end

local function captureNPCInfo(unit)
	local rec = { unit = unit }
	local ok, guid = safecall(UnitGUID, unit)
	rec.guid_ok, rec.guid = ok, guid
	if ok and guid then
		local id, note = creatureIDFromGUID(guid)
		rec.parsed_creature_id, rec.parse_note = id, note
	end
	local ok2, nm = safecall(UnitName, unit)
	rec.name_ok, rec.name = ok2, nm
	local ok3, lvl = safecall(UnitLevel, unit)
	rec.level_ok, rec.level = ok3, lvl
	for _, api in ipairs({ "UnitClassification", "UnitCreatureType", "UnitCreatureFamily" }) do
		local fn = resolvePath(api)
		local okf, val = safecall(fn, unit)
		rec[api] = { ok = okf, value = val }
	end
	rec.position = capturePosition()
	return rec
end

local function findQuestLogIndexByID(questID)
	local numFn = resolvePath("C_QuestLog.GetNumQuestLogEntries")
	local ok, n = safecall(numFn)
	if not ok or not n then
		return nil, "GetNumQuestLogEntries failed: " .. tostring(n)
	end
	local infoFn = resolvePath("C_QuestLog.GetInfo")
	for i = 1, n do
		local ok2, info = safecall(infoFn, i)
		if ok2 and type(info) == "table" and info.questID == questID then
			return i
		end
	end
	return nil, "not found among " .. tostring(n) .. " entries"
end

local function captureQuestLogFields(questID)
	local rec = { quest_id = questID }
	local index, indexErr = findQuestLogIndexByID(questID)
	rec.quest_log_index, rec.quest_log_index_error = index, indexErr

	if index then
		local infoFn = resolvePath("C_QuestLog.GetInfo")
		local ok, info = safecall(infoFn, index)
		rec.C_QuestLog_GetInfo = { ok = ok, value = ok and describe(info) or info }
		-- describe() caps table summaries at 6 arbitrary keys to avoid flooding output; that
		-- silently dropped the one field this experiment cares about most in an earlier run.
		-- Pull known-interesting fields out explicitly so they're never lost to the cap.
		if ok and type(info) == "table" then
			rec.C_QuestLog_GetInfo_title = info.title
			rec.C_QuestLog_GetInfo_level = info.level
			rec.C_QuestLog_GetInfo_questID = info.questID
		end
	end

	for _, api in ipairs({ "C_QuestLog.GetQuestInfo", "GetQuestLogTitle" }) do
		local fn = resolvePath(api)
		local okf, a, b, c, d = safecall(fn, index or questID)
		rec[api] = { ok = okf, values = { a, b, c, d } }
	end

	local objFn = resolvePath("C_QuestLog.GetQuestObjectives")
	local okObj, objectives = safecall(objFn, questID)
	rec.objectives = { ok = okObj, value = okObj and describe(objectives) or objectives }

	for _, api in ipairs({ "GetQuestLogQuestText", "GetQuestLogCompletionText" }) do
		local fn = resolvePath(api)
		local okf, a, b = safecall(fn)
		rec[api] = { ok = okf, values = { a, b } }
	end

	local haveFn = resolvePath("HaveQuestData")
	local okH, haveData = safecall(haveFn, questID)
	rec.HaveQuestData = { ok = okH, value = haveData }

	local flagFn = resolvePath("C_QuestLog.IsQuestFlaggedCompleted")
	local okF, flagged = safecall(flagFn, questID)
	rec.IsQuestFlaggedCompleted = { ok = okF, value = flagged }

	local onFn = resolvePath("C_QuestLog.IsOnQuest")
	local okOn, onQuest = safecall(onFn, questID)
	rec.IsOnQuest = { ok = okOn, value = onQuest }

	return rec
end

local function captureRewardFields(questID)
	local rec = { quest_id = questID }

	local numFn = resolvePath("GetNumQuestRewards")
	local okN, numRewards = safecall(numFn)
	rec.GetNumQuestRewards = { ok = okN, value = numRewards }

	if okN and type(numRewards) == "number" then
		local items = {}
		local infoFn = resolvePath("GetQuestLogRewardInfo")
		for i = 1, numRewards do
			local okI, name, texture, numItems, quality, isUsable = safecall(infoFn, i)
			table.insert(items, { ok = okI, name = name, texture = texture,
				numItems = numItems, quality = quality, isUsable = isUsable })
		end
		rec.reward_items = items
	end

	for _, api in ipairs({ "GetQuestLogRewardMoney", "GetQuestLogRewardXP", "GetQuestLogRewardTitle",
		"GetQuestLogChoiceInfo", "GetRewardHonor" }) do
		local fn = resolvePath(api)
		local okf, a, b, c = safecall(fn)
		rec[api] = { ok = okf, values = { a, b, c } }
	end

	local spellFn = resolvePath("C_QuestInfoSystem.GetQuestRewardSpells")
	local okS, spells = safecall(spellFn, questID)
	rec.C_QuestInfoSystem_GetQuestRewardSpells = { ok = okS, value = okS and describe(spells) or spells }

	return rec
end

local function recordEvent(eventName, data)
	table.insert(ForeverProbeDB.events, {
		event = eventName,
		recorded_at = now(),
		data = data,
	})
	say("recorded event: " .. eventName)
end

----------------------------------------------------------------------
-- event frame
----------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_FINISHED")

local questLogUpdateCount = 0

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local loaded = ...
		if loaded == "ForeverProbe" then
			printAssumptions()
		end
		return
	end

	if event == "PLAYER_LOGIN" then
		say("Slash commands: /fprobe scan | /fprobe status | /fprobe clear")
		return
	end

	if event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
		questLogUpdateCount = questLogUpdateCount + 1
		ForeverProbeDB.meta.quest_log_update_count = questLogUpdateCount
		return -- deliberately not recorded per-fire; would be noise, not evidence
	end

	if event == "QUEST_ACCEPTED" then
		local a1, a2 = ...
		local data = { raw_args = { a1, a2 } } -- labeled generically: the argument
			-- meaning (questLogIndex vs questID) differs across client versions
			-- and is not assumed here; check both against the quest log by hand.
		local questID = a2 or a1
		if type(questID) == "number" then
			data.assumed_quest_id = questID
			data.quest_log_fields = captureQuestLogFields(questID)
			data.reward_fields_at_accept = captureRewardFields(questID)
		end
		recordEvent("QUEST_ACCEPTED", data)
		return
	end

	if event == "GOSSIP_SHOW" then
		local data = {
			npc = captureNPCInfo("npc"),
			target = captureNPCInfo("target"),
		}
		local availFn = resolvePath("C_GossipInfo.GetAvailableQuests")
		local ok1, avail = safecall(availFn)
		data.GetAvailableQuests = { ok = ok1, value = ok1 and describe(avail) or avail }
		local activeFn = resolvePath("C_GossipInfo.GetActiveQuests")
		local ok2, active = safecall(activeFn)
		data.GetActiveQuests = { ok = ok2, value = ok2 and describe(active) or active }
		local portraitFn = resolvePath("GetQuestPortraitGiver")
		local ok3, texture, name = safecall(portraitFn)
		data.GetQuestPortraitGiver = { ok = ok3, texture = texture, name = name }
		recordEvent("GOSSIP_SHOW", data)
		return
	end

	if event == "QUEST_DETAIL" then
		local data = { npc = captureNPCInfo("npc") }
		recordEvent("QUEST_DETAIL", data)
		return
	end

	if event == "QUEST_COMPLETE" then
		local data = {
			npc = captureNPCInfo("npc"),
			GetQuestLogPortraitGiver = { ok = false },
			GetQuestLogPortraitTurnIn = { ok = false },
		}
		-- GetQuestID() (a plain global, not in the original M3 API list -- a small necessary
		-- helper, same category as GetBestMapForUnit) reports the quest currently open in the
		-- quest frame. Rewards aren't finalized at ACCEPT time; QUEST_COMPLETE is when the
		-- default UI itself shows real reward info, so this is the right moment to capture it.
		local okQ, questID = safecall(resolvePath("GetQuestID"))
		data.GetQuestID = { ok = okQ, value = questID }
		if okQ and type(questID) == "number" then
			data.reward_fields_at_complete = captureRewardFields(questID)
		end
		local okG, tex1 = safecall(resolvePath("GetQuestLogPortraitGiver"))
		data.GetQuestLogPortraitGiver = { ok = okG, texture = tex1 }
		local okT, tex2 = safecall(resolvePath("GetQuestLogPortraitTurnIn"))
		data.GetQuestLogPortraitTurnIn = { ok = okT, texture = tex2 }
		recordEvent("QUEST_COMPLETE", data)
		return
	end

	if event == "QUEST_TURNED_IN" then
		local questID, xpReward, moneyReward = ...
		recordEvent("QUEST_TURNED_IN", {
			quest_id = questID, xp_reward = xpReward, money_reward = moneyReward,
		})
		return
	end

	if event == "QUEST_FINISHED" then
		recordEvent("QUEST_FINISHED", {})
		return
	end
end)

----------------------------------------------------------------------
-- slash commands
----------------------------------------------------------------------

SLASH_FOREVERPROBE1 = "/fprobe"
SlashCmdList["FOREVERPROBE"] = function(msg)
	-- Plain-Lua trim, deliberately not relying on the WoW-provided
	-- string.trim extension, which was not verified to exist here.
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "scan" then
		scanAPIs()
	elseif msg == "status" then
		say(string.format("events recorded: %d | quest log updates seen: %d",
			#ForeverProbeDB.events, ForeverProbeDB.meta.quest_log_update_count or 0))
	elseif msg == "clear" then
		ForeverProbeDB.events = {}
		ForeverProbeDB.api_scan = {}
		say("cleared events and api_scan (meta kept).")
	elseif msg == "save" then
		-- Writes the SavedVariables file to disk without you having to /reload manually.
		-- Standard, widely-used addon pattern; reloads the UI, does not touch the game world
		-- or any character state.
		say("saving and reloading UI now...")
		ReloadUI()
	else
		say("usage: /fprobe scan | /fprobe status | /fprobe clear | /fprobe save")
	end
end
