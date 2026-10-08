-- ForeverCodex.FeatureProbe: a READ-ONLY look at what this client exposes for features Quest Flow does not have yet. Nothing here reaches the planner
-- or the window; it only fills a report section, so a later build can be designed from what the client really offers instead of from guesses.
--
-- It asks, and prints what came back, nothing more:
--   * the game's own achievement categories whose NAME mentions "Legacy", and the first achievements in them (name, completed or not);
--   * global names that mention Legacy / Attunement / Keystone, and any currency whose name mentions Legacy (Legacy Points);
--   * which talent / trait functions exist (existence only: nothing is read or changed).
-- Every call is wrapped; a missing or failing function is reported as such, never raised. Everything is UNPROVEN until a report shows real values.

local addonName, ns = ...

local F = {}
ns.FeatureProbe = F

F.MAX_LIST = 20

local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
local function safeText(v) if type(v) ~= "string" or isSecret(v) then return nil end return v:sub(1, 60) end
local function has(s, pat) return type(s) == "string" and s:lower():find(pat, 1, true) ~= nil end

local function call(fn, ...)
	if type(fn) ~= "function" then return false end
	local r = { pcall(fn, ...) }
	if not r[1] then return false end
	return true, r[2], r[3], r[4], r[5], r[6]
end

local function achievementLines(L)
	local api = type(C_AchievementInfo) == "table" and C_AchievementInfo or nil
	local getCats = _G.GetCategoryList or (api and api.GetCategoryList)
	local getInfo = _G.GetCategoryInfo or (api and api.GetCategoryInfo)
	if type(getCats) ~= "function" or type(getInfo) ~= "function" then
		L[#L + 1] = "  achievements: category functions not present (GetCategoryList / GetCategoryInfo): UNPROVEN"
		return
	end
	local ok, cats = call(getCats)
	if not ok or type(cats) ~= "table" then L[#L + 1] = "  achievements: GetCategoryList answered nothing usable: UNPROVEN" return end
	local legacy = {}
	for _, id in ipairs(cats) do
		local okI, name = call(getInfo, id)
		name = okI and safeText(name) or nil
		if name and has(name, "legacy") then legacy[#legacy + 1] = { id = id, name = name } end
	end
	L[#L + 1] = string.format("  achievements: %d categories listed by the game; %d with a name that mentions Legacy%s", #cats, #legacy,
		#legacy == 0 and " (none: the Legacy achievements may live elsewhere, or under another name)" or "")
	local numFn = _G.GetCategoryNumAchievements or (api and api.GetCategoryNumAchievements)
	local achFn = _G.GetAchievementInfo or (api and api.GetAchievementInfo)
	for i, c in ipairs(legacy) do
		if i > 6 then L[#L + 1] = "    ... more categories not listed" break end
		local okN, n = call(numFn, c.id)
		L[#L + 1] = string.format("    category %s (id %s): %s achievement(s)", c.name, tostring(c.id), okN and tostring(n) or "count not readable")
		if okN and type(n) == "number" and type(achFn) == "function" then
			for k = 1, math.min(n, 5) do
				-- the modern call takes the achievement id, the older one a category and an index: both are tried, whichever answers
				local okA, id, name, _, completed = call(achFn, c.id, k)
				if okA and name then
					L[#L + 1] = string.format("      %s | %s", safeText(name) or "?", completed == true and "completed" or "not completed")
				end
			end
		end
	end
end

local function nameScanLines(L)
	local found = { legacy = {}, attune = {}, keystone = {} }
	local ok = pcall(function()
		for k, v in pairs(_G) do
			if type(k) == "string" and (type(v) == "function" or type(v) == "table") then
				local lk = k:lower()
				if lk:find("legacy", 1, true) and #found.legacy < 60 then found.legacy[#found.legacy + 1] = k end
				if lk:find("attune", 1, true) and #found.attune < 60 then found.attune[#found.attune + 1] = k end
				if lk:find("keystone", 1, true) and #found.keystone < 60 then found.keystone[#found.keystone + 1] = k end
			end
		end
	end)
	if not ok then L[#L + 1] = "  global name scan: could not run" return end
	for _, w in ipairs({ "legacy", "attune", "keystone" }) do
		table.sort(found[w])
		local shown = {}
		for i = 1, math.min(#found[w], F.MAX_LIST) do shown[#shown + 1] = found[w][i] end
		L[#L + 1] = string.format("  global names mentioning %s: %d%s", w, #found[w], #shown > 0 and (" | " .. table.concat(shown, ", ")) or "")
	end
end

local function currencyLines(L)
	local api = type(C_CurrencyInfo) == "table" and C_CurrencyInfo or nil
	local sizeFn = _G.GetCurrencyListSize or (api and api.GetCurrencyListSize)
	local infoFn = (api and api.GetCurrencyListInfo) or _G.GetCurrencyListInfo
	local okS, n = call(sizeFn)
	if not okS or type(n) ~= "number" then L[#L + 1] = "  currencies: the currency list is not readable (GetCurrencyListSize): UNPROVEN" return end
	local hits = {}
	for i = 1, math.min(n, 200) do
		local okI, a = call(infoFn, i)
		local name
		if okI then name = type(a) == "table" and a.name or a end
		name = safeText(name)
		if name and has(name, "legacy") then hits[#hits + 1] = name end
	end
	L[#L + 1] = string.format("  currencies: %d entries in the currency list; %d with a name that mentions Legacy%s", n, #hits, #hits > 0 and (" | " .. table.concat(hits, ", ")) or "")
end

local function talentLines(L)
	local names = { "C_Traits", "GetTalentInfo", "GetNumTalentTabs", "C_SpecializationInfo", "GetNumTalentGroups", "GetActiveTalentGroup", "C_ClassTalents" }
	local present, absent = {}, {}
	for _, n in ipairs(names) do
		if _G[n] ~= nil then present[#present + 1] = n else absent[#absent + 1] = n end
	end
	L[#L + 1] = "  talent / trait functions (existence only): present " .. (#present > 0 and table.concat(present, ", ") or "none") .. " | absent " .. (#absent > 0 and table.concat(absent, ", ") or "none")
end

function F.ReportLines()
	local L = { "FEATURE PROBE (read-only; what this client exposes for features Quest Flow does not have yet. Nothing here changes the plan; every line is UNPROVEN until a report shows real values)" }
	for _, fn in ipairs({ achievementLines, nameScanLines, currencyLines, talentLines }) do
		local ok, err = pcall(fn, L)
		if not ok then L[#L + 1] = "  probe step failed: " .. tostring(err):sub(1, 80) end
	end
	return L
end
