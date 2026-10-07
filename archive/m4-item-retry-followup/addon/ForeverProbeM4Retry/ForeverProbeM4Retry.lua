-- ForeverProbeM4Retry: tiny follow-up fork of the M4 pre-experiment probe.
-- Forked from m4-pre-experiment/addon/ForeverProbeM4/ForeverProbeM4.lua, which is
-- NOT modified by this file (nor is m3-experiment/, nor M4_PLAN.md). Read-only.
-- Does not accept/complete/turn in quests, does not call GetQuestReward(), does
-- not move the player. Uninstall after this follow-up.
--
-- ONE question only: can a guaranteed quest reward whose item name initially reads
-- as an empty string ("") -- not nil -- resolve to a real name later, and at which
-- checkpoint/retry does that happen?
--
-- ONE behavioral change from the M4 pre-experiment: an item's name is now treated
-- as "unresolved" (and a retry armed) when it is nil OR an empty string, not just
-- nil. The M4 pre-experiment's real-client data showed guaranteed-reward items
-- (quests 92515, 92553) came back as "" rather than nil, so the old nil-only check
-- never armed a retry for them -- meaning that question was never actually tested.
-- This fork exists solely to test it. Choice-reward capture, gossip capture, NPC
-- capture, and everything else are unchanged from the M4 pre-experiment probe.
--
-- Renamed throughout (ForeverProbeM4Retry / ForeverProbeM4RetryDB / /fprobe4r) so
-- this can be installed alongside both m3-experiment's ForeverProbe and
-- m4-pre-experiment's ForeverProbeM4 without any file or SavedVariables collision.

local PROBE_VERSION = "m4-item-retry-followup-0.1"
-- Same assumption M3 recorded; unchanged, still just a check, not a requirement.
local EXPECTED_INTERFACE = 16001

ForeverProbeM4RetryDB = ForeverProbeM4RetryDB or {
	meta = {},
	api_scan = {},
	events = {},
	item_checkpoints = {},
}

----------------------------------------------------------------------
-- small helpers (unchanged from M3, copied)
----------------------------------------------------------------------

local function now()
	return date("%Y-%m-%d %H:%M:%S")
end

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
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[FProbeM4R]|r " .. msg)
	end
end

----------------------------------------------------------------------
-- build/interface assumptions (unchanged behavior from M3)
----------------------------------------------------------------------

local function printAssumptions()
	local version, build, buildDate, tocversion = GetBuildInfo()
	ForeverProbeM4RetryDB.meta = {
		probe_version = PROBE_VERSION,
		recorded_at = now(),
		observed_version = version,
		observed_build = build,
		observed_build_date = buildDate,
		observed_toc_version = tocversion,
		expected_toc_version = EXPECTED_INTERFACE,
		toc_version_matches_expectation = (tocversion == EXPECTED_INTERFACE),
	}
	say("probe " .. PROBE_VERSION .. " loaded. Read-only: does not accept/complete/turn in quests, "
		.. "never calls GetQuestReward().")
	say(string.format(
		"GetBuildInfo() = %s, %s, %s, %s",
		tostring(version), tostring(build), tostring(buildDate), tostring(tocversion)
	))
	if tocversion == EXPECTED_INTERFACE then
		say("Interface matches the M2/M3-recorded expectation (" .. EXPECTED_INTERFACE .. "). [V]")
	else
		say("Interface DIFFERS from the M2/M3-recorded expectation (" .. EXPECTED_INTERFACE
			.. "). Recording the real value; not treating this as an error.")
	end
end

----------------------------------------------------------------------
-- API existence scan
-- CHANGE FROM M3: added GetNumQuestChoices, GetQuestItemInfo, GetQuestID,
-- C_Timer.After, GET_ITEM_INFO_RECEIVED-related check. Removed nothing.
-- GetQuestReward is deliberately NEVER referenced anywhere in this file,
-- including here, so it cannot be called by accident.
----------------------------------------------------------------------

local API_PATHS = {
	-- quest log / details (unchanged from M3)
	"C_QuestLog.GetInfo", "C_QuestLog.GetQuestObjectives", "GetQuestLogQuestText",
	"GetQuestLogCompletionText", "C_QuestLog.GetQuestInfo", "GetQuestLogTitle", "HaveQuestData",
	-- rewards (unchanged from M3)
	"GetNumQuestRewards", "GetQuestLogRewardInfo", "GetQuestLogRewardMoney", "GetQuestLogRewardXP",
	"GetQuestLogRewardTitle", "GetQuestLogChoiceInfo", "C_QuestInfoSystem.GetQuestRewardSpells",
	"GetRewardHonor",
	-- NEW for M4 pre-experiment: item-reward specific
	"GetNumQuestChoices", "GetQuestItemInfo",
	-- quest/map (unchanged from M3)
	"C_QuestLog.GetQuestsOnMap", "C_QuestLog.GetMapForQuestPOIs", "C_QuestLog.IsQuestFlaggedCompleted",
	"QuestPOIGetIconInfo", "C_TaskQuest.GetQuestLocation", "C_TaskQuest.GetQuestsOnMap",
	-- quest completion (unchanged from M3)
	"IsQuestComplete", "IsQuestCompletable", "GetQuestsCompleted", "C_QuestLog.IsOnQuest",
	-- NPC/gossip (unchanged from M3)
	"C_GossipInfo.GetAvailableQuests", "C_GossipInfo.GetActiveQuests", "GetQuestPortraitGiver",
	"GetQuestLogPortraitGiver", "GetQuestLogPortraitTurnIn",
	-- NPC/position (unchanged from M3)
	"UnitPosition", "C_Map.GetPlayerMapPosition", "UnitName", "UnitGUID", "UnitLevel",
	"UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "ClosestUnitPosition",
	"ClosestGameObjectPosition",
	-- taxi (unchanged from M3; not otherwise used in this pre-experiment)
	"C_TaxiMap.GetAllTaxiNodes", "C_TaxiMap.GetTaxiNodesForMap", "TaxiNodeName", "TaxiNodePosition",
	"GetTaxiNodeCost",
	-- helpers, not part of the audited API list (unchanged from M3, plus C_Timer.After, new)
	"C_QuestLog.GetNumQuestLogEntries", "C_Map.GetBestMapForUnit", "GetQuestID", "C_Timer.After",
}

local function scanAPIs()
	ForeverProbeM4RetryDB.api_scan = {}
	local present, missing = 0, 0
	for _, path in ipairs(API_PATHS) do
		local v = resolvePath(path)
		local ty = type(v)
		table.insert(ForeverProbeM4RetryDB.api_scan, { path = path, type = ty })
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
-- NPC/GUID capture
-- CHANGE FROM M3: raw GUID is no longer stored. M3 kept it deliberately to
-- validate the parsing technique itself; that technique is already proven
-- ([V], 14 NPCs, M3). This experiment tests different things and hardens
-- toward the harvest contract's "no raw GUIDs" principle (M4_PLAN.md §4.3)
-- early, since there is no remaining reason to keep it.
----------------------------------------------------------------------

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
	local out = { helper = "C_Map.GetBestMapForUnit + C_Map.GetPlayerMapPosition (plumbing only)" }
	local mapAPI = resolvePath("C_Map.GetBestMapForUnit")
	local ok1, mapID = safecall(mapAPI, "player")
	out.map_ok, out.map_id_or_error = ok1, mapID
	if ok1 and mapID then
		local posAPI = resolvePath("C_Map.GetPlayerMapPosition")
		local ok2, pos = safecall(posAPI, mapID, "player")
		out.position_ok = ok2
		if ok2 and pos then
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
	rec.guid_ok = ok
	-- NOTE: raw guid intentionally NOT stored here (see comment above this section).
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

----------------------------------------------------------------------
-- Quest-log field capture (unchanged from M3, needed for context only;
-- not the focus of this experiment)
----------------------------------------------------------------------

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
		if ok and type(info) == "table" then
			rec.C_QuestLog_GetInfo_title = info.title
			rec.C_QuestLog_GetInfo_level = info.level
			rec.C_QuestLog_GetInfo_questID = info.questID
		end
	end
	return rec
end

----------------------------------------------------------------------
-- NEW FOR M4 PRE-EXPERIMENT: item-reward checkpoint capture
--
-- Tests, at a given lifecycle checkpoint, whether item reward/choice data
-- is readable. Never calls GetQuestReward(). Records every return value
-- positionally (not by assumed name) since GetQuestItemInfo's exact return
-- order has not been confirmed on Forever -- recording positionally means
-- a different real order is visible in the data, not silently mislabeled.
----------------------------------------------------------------------

local function captureItemsForKind(kind, count)
	local itemInfoFn = resolvePath("GetQuestItemInfo")
	local out = {}
	local sawUnresolvedFirstValue = false
	for i = 1, count do
		local ok, v1, v2, v3, v4, v5, v6 = safecall(itemInfoFn, kind, i)
		-- Named fields, not a positional array: a plain {v1,...,v6} array would
		-- create an unrecoverable ambiguity here, since Lua cannot distinguish
		-- "index 1 is nil" from "index 1 was never set" once read back via
		-- ipairs() or serialized -- exactly the thing this experiment most needs
		-- to detect precisely. v1_unresolved is the unambiguous, explicit signal.
		--
		-- CHANGE FROM m4-pre-experiment (the one behavioral change in this fork):
		-- "unresolved" is now nil OR empty string, not just nil -- see file header.
		local row = {
			index = i, ok = ok, v1_unresolved = (ok and (v1 == nil or v1 == "")),
			v1 = v1, v2 = v2, v3 = v3, v4 = v4, v5 = v5, v6 = v6,
		}
		if row.v1_unresolved then
			sawUnresolvedFirstValue = true
		end
		table.insert(out, row)
	end
	return out, sawUnresolvedFirstValue
end

local function captureItemRewardCheckpoint(checkpoint, questID)
	local rec = { checkpoint = checkpoint, quest_id = questID, recorded_at = now() }

	local okNR, numRewards = safecall(GetNumQuestRewards)
	rec.GetNumQuestRewards = { ok = okNR, value = numRewards }

	local okNC, numChoices = safecall(GetNumQuestChoices)
	rec.GetNumQuestChoices = { ok = okNC, value = numChoices }

	local sawUnresolved = false
	if okNR and type(numRewards) == "number" and numRewards > 0 then
		local items, unresolvedFlag = captureItemsForKind("reward", numRewards)
		rec.reward_items = items
		sawUnresolved = sawUnresolved or unresolvedFlag
	else
		rec.reward_items = {}
	end

	if okNC and type(numChoices) == "number" and numChoices > 0 then
		local items, unresolvedFlag = captureItemsForKind("choice", numChoices)
		rec.choice_items = items
		sawUnresolved = sawUnresolved or unresolvedFlag
	else
		rec.choice_items = {}
	end

	rec.saw_unresolved_first_value = sawUnresolved
	return rec
end

local function recordItemCheckpoint(rec)
	table.insert(ForeverProbeM4RetryDB.item_checkpoints, rec)
	say(string.format("item checkpoint recorded: %s (quest %s, rewards=%s, choices=%s, unresolved_seen=%s)",
		tostring(rec.checkpoint), tostring(rec.quest_id),
		tostring(rec.GetNumQuestRewards and rec.GetNumQuestRewards.value),
		tostring(rec.GetNumQuestChoices and rec.GetNumQuestChoices.value),
		tostring(rec.saw_unresolved_first_value)))
end

-- GET_ITEM_INFO_RECEIVED retry state. Bounded: at most MAX_RETRIES re-captures,
-- and only while we are actually waiting on a nil-name result from a checkpoint
-- above -- this event can fire for unrelated items during ordinary play, so it
-- must not trigger extra work unless we are genuinely waiting on it.
local pendingRetryQuestID = nil
local retryCount = 0
local MAX_RETRIES = 3

local function maybeArmRetry(checkpointRec)
	if checkpointRec.saw_unresolved_first_value then
		pendingRetryQuestID = checkpointRec.quest_id
		retryCount = 0
	end
end

----------------------------------------------------------------------
-- NEW FOR M4 PRE-EXPERIMENT: gossip quest-list capture
--
-- CHANGE FROM M3: M3's GOSSIP_SHOW handler summarized these two APIs'
-- return values with the generic describe() helper, capped at 6 arbitrary
-- keys -- the same class of truncation that caused the title-capture bug
-- M3 found and fixed. This records every key NAME present (so a schema
-- surprise is visible) and a small explicit whitelist of known scalar
-- fields, bounded to the first 5 entries. No personal/player data is
-- involved in either API's return shape.
----------------------------------------------------------------------

local GOSSIP_QUEST_KNOWN_FIELDS = {
	"questID", "questLevel", "isTrivial", "isLegendary", "isMeta", "isImportant",
	"isIgnored", "isTask", "isBounty", "isStory", "frequency", "title",
}

local function extractGossipQuestList(list)
	if type(list) ~= "table" then
		return { ok = false, note = "not a table", observed_type = type(list) }
	end
	local total = 0
	for _ in pairs(list) do
		total = total + 1
	end
	local sample = {}
	local shown = 0
	for _, entry in pairs(list) do
		if shown >= 5 then
			break
		end
		if type(entry) == "table" then
			local keys = {}
			for k in pairs(entry) do
				table.insert(keys, tostring(k))
			end
			local row = { all_keys = keys }
			for _, f in ipairs(GOSSIP_QUEST_KNOWN_FIELDS) do
				if entry[f] ~= nil then
					row[f] = entry[f]
				end
			end
			table.insert(sample, row)
		else
			table.insert(sample, { non_table_entry_type = type(entry) })
		end
		shown = shown + 1
	end
	return { ok = true, total_count = total, sample = sample }
end

local function recordEvent(eventName, data)
	table.insert(ForeverProbeM4RetryDB.events, {
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
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_FINISHED")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local loaded = ...
		if loaded == "ForeverProbeM4Retry" then
			printAssumptions()
		end
		return
	end

	if event == "PLAYER_LOGIN" then
		say("Slash commands: /fprobe4r scan | /fprobe4r status | /fprobe4r clear | /fprobe4r save")
		return
	end

	if event == "GET_ITEM_INFO_RECEIVED" then
		if pendingRetryQuestID and retryCount < MAX_RETRIES then
			retryCount = retryCount + 1
			local rec = captureItemRewardCheckpoint(
				"retry_after_get_item_info_received_" .. retryCount, pendingRetryQuestID)
			recordItemCheckpoint(rec)
			if not rec.saw_unresolved_first_value then
				pendingRetryQuestID = nil -- resolved; stop retrying
			end
		end
		return
	end

	if event == "GOSSIP_SHOW" then
		local data = {
			npc = captureNPCInfo("npc"),
			target = captureNPCInfo("target"),
		}
		local availFn = resolvePath("C_GossipInfo.GetAvailableQuests")
		local ok1, avail = safecall(availFn)
		data.GetAvailableQuests = ok1 and extractGossipQuestList(avail) or { ok = false, error = avail }
		local activeFn = resolvePath("C_GossipInfo.GetActiveQuests")
		local ok2, active = safecall(activeFn)
		data.GetActiveQuests = ok2 and extractGossipQuestList(active) or { ok = false, error = active }
		recordEvent("GOSSIP_SHOW", data)
		return
	end

	if event == "QUEST_DETAIL" then
		local data = { npc = captureNPCInfo("npc") }
		-- Whether GetQuestID() resolves during QUEST_DETAIL (as opposed to only
		-- QUEST_COMPLETE, which M3 already confirmed) is itself untested; recording
		-- the attempt either way is useful information, not assumed to work.
		local okQ, questID = safecall(resolvePath("GetQuestID"))
		data.GetQuestID = { ok = okQ, value = questID }
		recordEvent("QUEST_DETAIL", data)
		if okQ and type(questID) == "number" then
			local rec = captureItemRewardCheckpoint("quest_detail", questID)
			recordItemCheckpoint(rec)
			maybeArmRetry(rec)
		end
		return
	end

	if event == "QUEST_COMPLETE" then
		local data = { npc = captureNPCInfo("npc") }
		local okQ, questID = safecall(resolvePath("GetQuestID"))
		data.GetQuestID = { ok = okQ, value = questID }
		local okG, tex1 = safecall(resolvePath("GetQuestLogPortraitGiver"))
		data.GetQuestLogPortraitGiver = { ok = okG, texture = tex1 }
		local okT, tex2 = safecall(resolvePath("GetQuestLogPortraitTurnIn"))
		data.GetQuestLogPortraitTurnIn = { ok = okT, texture = tex2 }
		recordEvent("QUEST_COMPLETE", data)

		if okQ and type(questID) == "number" then
			local immediateRec = captureItemRewardCheckpoint("quest_complete_immediate", questID)
			recordItemCheckpoint(immediateRec)
			maybeArmRetry(immediateRec)

			-- Delayed checkpoint. C_Timer.After is a standard modern-client API;
			-- guarded with safecall like everything else. If unavailable, that
			-- absence itself is recorded rather than silently skipped.
			local timerFn = resolvePath("C_Timer.After")
			local okTimer, timerErr = safecall(timerFn, 1.5, function()
				local delayedRec = captureItemRewardCheckpoint("quest_complete_delayed", questID)
				recordItemCheckpoint(delayedRec)
				maybeArmRetry(delayedRec)
			end)
			if not okTimer then
				recordItemCheckpoint({
					checkpoint = "quest_complete_delayed", quest_id = questID, recorded_at = now(),
					scheduling_failed = true, scheduling_error = timerErr,
				})
			end
		end
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

SLASH_FOREVERPROBEM4RETRY1 = "/fprobe4r"
SlashCmdList["FOREVERPROBEM4RETRY"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "scan" then
		scanAPIs()
	elseif msg == "status" then
		say(string.format("events recorded: %d | item checkpoints recorded: %d",
			#ForeverProbeM4RetryDB.events, #ForeverProbeM4RetryDB.item_checkpoints))
	elseif msg == "clear" then
		ForeverProbeM4RetryDB.events = {}
		ForeverProbeM4RetryDB.api_scan = {}
		ForeverProbeM4RetryDB.item_checkpoints = {}
		pendingRetryQuestID = nil
		retryCount = 0
		say("cleared events, api_scan, and item_checkpoints (meta kept).")
	elseif msg == "save" then
		say("saving and reloading UI now...")
		ReloadUI()
	else
		say("usage: /fprobe4r scan | /fprobe4r status | /fprobe4r clear | /fprobe4r save")
	end
end
