-- ForeverLab.Slash: /flab command dispatch. Deliberately simple, per the
-- explicit instruction not to build a configuration system -- enable/
-- disable are the only knobs, and they only ever affect the current
-- session (ForeverLab.ActiveExperimental is never saved to disk).

ForeverLab = ForeverLab or {}

local API_PATHS = {
	-- proven surface, unchanged from prior probes' scans
	"C_QuestLog.GetInfo", "C_QuestLog.GetQuestObjectives", "GetQuestID",
	"GetNumQuestRewards", "GetQuestItemInfo", "GetNumQuestChoices",
	"GetNumQuestLogRewardFactions", "GetQuestLogRewardFactionInfo", "GetFactionInfoByID",
	"C_GossipInfo.GetAvailableQuests", "C_GossipInfo.GetActiveQuests",
	"UnitGUID", "UnitName", "C_Map.GetPlayerMapPosition", "C_Map.GetBestMapForUnit",
	"C_Timer.After", "GetLocale",
	-- Added after the M4 repository audit: these were real dependencies of
	-- GiverIdentity.lua and QuestMeta.lua that this diagnostic list had
	-- omitted. The modules worked fine regardless (they call SafeCall
	-- directly), but a future absence of one of these wouldn't have shown
	-- up here for a quick /flab scan check -- only buried inside an
	-- individual observation's ok=false field.
	"C_QuestLog.GetNumQuestLogEntries", "UnitLevel", "UnitClassification",
	"UnitCreatureType", "UnitCreatureFamily",
	-- experimental candidates, scanned but not called unless enabled
	"C_QuestInfoSystem.GetQuestRewardSpells", "GetQuestLogRewardTitle", "GetRewardHonor",
}

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

local function scanAPIs()
	ForeverObservationLabDB.api_scan = {}
	local present, missing = 0, 0
	for _, path in ipairs(API_PATHS) do
		local ty = type(resolvePath(path))
		table.insert(ForeverObservationLabDB.api_scan, { path = path, type = ty })
		if ty == "function" then present = present + 1 else missing = missing + 1 end
		ForeverLab.Say(string.format("%-42s type()=%s", path, ty))
	end
	ForeverLab.Say(string.format("API scan complete: %d present as functions, %d not.", present, missing))
end

SLASH_FOREVEROBSERVATIONLAB1 = "/flab"
SlashCmdList["FOREVEROBSERVATIONLAB"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, arg = msg:match("^(%S*)%s*(.-)$")

	if cmd == "scan" then
		scanAPIs()
	elseif cmd == "status" then
		ForeverLab.Say(string.format("observations recorded: %d", #ForeverObservationLabDB.observations))
	elseif cmd == "clear" then
		ForeverObservationLabDB.observations = {}
		ForeverObservationLabDB.api_scan = {}
		ForeverLab.Say("cleared observations and api_scan (meta kept).")
	elseif cmd == "save" then
		ForeverLab.Export.Save()
	elseif cmd == "list" then
		for _, m in ipairs(ForeverLab.Registry:List()) do
			ForeverLab.Say(string.format("%-22s status=%-12s active=%s", m.name, m.status, tostring(m.active)))
		end
	elseif cmd == "enable" then
		local realName = ForeverLab.ResolveModuleNameCaseInsensitive and ForeverLab.ResolveModuleNameCaseInsensitive(arg) or arg
		local ok, err = ForeverLab.Registry:EnableExperimental(realName)
		ForeverLab.Say(ok and ("enabled: " .. realName) or ("could not enable '" .. arg .. "': " .. tostring(err)))
	elseif cmd == "disable" then
		local realName = ForeverLab.ResolveModuleNameCaseInsensitive and ForeverLab.ResolveModuleNameCaseInsensitive(arg) or arg
		ForeverLab.Registry:DisableExperimental(realName)
		ForeverLab.Say("disabled: " .. realName)
	else
		ForeverLab.Say("usage: /flab scan | status | clear | save | list | enable <Module> | disable <Module>")
	end
end
