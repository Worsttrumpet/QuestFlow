-- Minimal WoW API stand-ins, enough to load-test the full lab.

function date(fmt) return "2026-09-23 00:00:00" end
math.randomseed(42)
function strsplit(sep, str)
	local fields = {}
	for m in str:gmatch("([^" .. sep .. "]+)") do table.insert(fields, m) end
	return unpack(fields)
end

DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg) print(msg) end }

function GetBuildInfo() return "1.60.1", "69977", "Sep 22 2026", 16001 end
function GetLocale() return "enUS" end
function GetQuestID() return 111 end

function CreateFrame(kind)
	local f = {}
	local handlers = {}
	function f:RegisterEvent(e) end
	function f:SetScript(script, fn) handlers[script] = fn end
	f._fire = function(event, ...) if handlers.OnEvent then handlers.OnEvent(f, event, ...) end end
	_G.__lastFrame = f
	return f
end

_G.__pendingTimers = {}
C_Timer = {
	After = function(seconds, callback) table.insert(_G.__pendingTimers, callback) end,
}
function _G.__fireAllTimers()
	local timers = _G.__pendingTimers
	_G.__pendingTimers = {}
	for _, cb in ipairs(timers) do cb() end
end

C_QuestLog = {
	GetNumQuestLogEntries = function() return 1 end,
	GetInfo = function(i)
		if i == 1 then return { questID = 111, title = "Stub Quest", level = 5 } end
		return nil
	end,
	GetQuestObjectives = function(id) return { { text = "Kill 3 Boars", numFulfilled = 0, numRequired = 3 } } end,
}

GetNumQuestRewards = function() return 1 end
GetNumQuestChoices = function() return 0 end
_G.__itemInfoResolved = false
GetQuestItemInfo = function(kind, i)
	if kind == "reward" and i == 1 then
		if _G.__itemInfoResolved then
			return "Resolved Item", "tex", 1, 2, 12345
		end
		return "", "tex", 1, 2, 12345
	end
	return nil
end

GetNumQuestLogRewardFactions = function() return 2 end
GetQuestLogRewardFactionInfo = function(i)
	if i == 1 then return 2778, 10000 end
	if i == 2 then return 2779, 5000 end
	return nil
end
-- Confirmed absent on Forever; the stub matches that (nil = "not a function")
GetFactionInfoByID = nil

C_GossipInfo = {
	GetAvailableQuests = function() return { { questID = 500, title = "Avail", questLevel = 3 } } end,
	GetActiveQuests = function() return {} end,
}

UnitGUID = function(unit)
	if unit == "npc" then return "Creature-0-1234-5-6-98765-000012A3B4" end
	return nil
end
UnitName = function(unit) if unit == "npc" then return "Test NPC" end return nil end
UnitLevel = function(unit) if unit == "npc" then return 10 end return nil end
UnitClassification = function() return "normal" end
UnitCreatureType = function() return "Humanoid" end
UnitCreatureFamily = function() return nil end

C_Map = {
	GetBestMapForUnit = function() return 1429 end,
	GetPlayerMapPosition = function(mapID, unit)
		return { GetXY = function(self) return 0.5, 0.5 end }
	end,
}

C_QuestInfoSystem = { GetQuestRewardSpells = function(id) return {} end }
GetQuestLogRewardTitle = function() return nil end
GetRewardHonor = function() return 0 end

ReloadUI = function() print("(stub) ReloadUI() called") end
SlashCmdList = {}
