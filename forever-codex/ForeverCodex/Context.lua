-- ForeverCodex.Context: one snapshot of "who is playing and where", built from read-only client calls.
--
-- Race ORIGIN (what the character is), ROUTE ZONE (where the player chose to level; lives in Preferences) and
-- CURRENT LOCATION (where the character is right now) are separate fields and are never derived from one another.
--
-- Every client call is feature-checked and pcall-wrapped. A missing API leaves its field nil and is listed in
-- ctx.char.missing / ctx.loc.available so the engine degrades (it never guesses) and /codex diag can say which
-- API this client lacks. UnitLevel / UnitName / C_Map position / C_QuestLog are verified on Forever (M8.x);
-- UnitClass / UnitRace / UnitFactionGroup / GetZoneText / GetSubZoneText / GetRealmName / GetNumGroupMembers are
-- standard Classic APIs that have NOT been probed on Forever yet, which is what the first real-client checkpoint
-- (/codex diag) is for.

local addonName, ns = ...
local P = ns.Prefs

local Ctx = {}
ns.Context = Ctx

local function try(fn, ...)
	if type(fn) ~= "function" then
		return nil, false
	end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		ns.RecordError("context", a)
		return nil, false
	end
	return a, true, b, c
end

--- ATT race symbols differ from the client's race tokens for one race; normalise to the ATT symbol space.
local RACE_ALIASES = { SCOURGE = "UNDEAD" }

local function raceKey(token)
	if type(token) ~= "string" then return nil end
	local k = token:upper():gsub("[%s_%-']", "")
	return RACE_ALIASES[k] or k
end
Ctx.RaceKey = raceKey

-- ---------------------------------------------------------------- default reader (real client)

local reader = {}

function reader.character()
	local c = { missing = {} }
	local lvl, okL = try(UnitLevel, "player")
	if okL and type(lvl) == "number" then c.level = lvl else c.missing[#c.missing + 1] = "UnitLevel" end
	local name, okN = try(UnitName, "player")
	if okN and type(name) == "string" then c.name = name else c.missing[#c.missing + 1] = "UnitName" end
	local realm, okR = try(GetRealmName)
	if okR and type(realm) == "string" then c.realm = realm else c.missing[#c.missing + 1] = "GetRealmName" end
	if type(UnitClass) == "function" then
		local ok, loc, token = pcall(UnitClass, "player")
		if ok and type(token) == "string" then c.class, c.classToken = loc, token else c.missing[#c.missing + 1] = "UnitClass" end
	else
		c.missing[#c.missing + 1] = "UnitClass"
	end
	if type(UnitRace) == "function" then
		local ok, loc, token = pcall(UnitRace, "player")
		if ok and type(token) == "string" then c.race, c.raceToken = loc, token else c.missing[#c.missing + 1] = "UnitRace" end
	else
		c.missing[#c.missing + 1] = "UnitRace"
	end
	if type(UnitFactionGroup) == "function" then
		local ok, fac = pcall(UnitFactionGroup, "player")
		if ok and type(fac) == "string" then c.faction = fac else c.missing[#c.missing + 1] = "UnitFactionGroup" end
	else
		c.missing[#c.missing + 1] = "UnitFactionGroup"
	end
	return c
end

function reader.location()
	local l = { available = false }
	local zone = try(GetZoneText)
	if type(zone) == "string" and zone ~= "" then l.zone = zone end
	local sub = try(GetSubZoneText)
	if type(sub) == "string" and sub ~= "" then l.subzone = sub end
	if type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function" then
		local map = try(C_Map.GetBestMapForUnit, "player")
		if type(map) == "number" then
			l.map = map
			local pos = try(C_Map.GetPlayerMapPosition, map, "player")
			if type(pos) == "table" then
				local x, y
				if type(pos.GetXY) == "function" then
					local ok, a, b = pcall(pos.GetXY, pos)
					if ok then x, y = a, b end
				end
				x, y = x or pos.x, y or pos.y
				if type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
					l.x, l.y = x, y
					l.available = true
				end
			end
		end
	end
	if l.available and ns.Eval and ns.Eval.DefaultReader then
		local cont, wx, wy = ns.Eval.DefaultReader.playerWorldPos()
		if cont and wx and wy then
			l.world = { continent = cont, x = wx, y = wy }
		end
	end
	return l
end

--- The client's objective list for a quest, or nil when it cannot be read. C_QuestLog.GetQuestObjectives is PROVEN on
-- Forever (M8.9): an array of { text, type, finished, numFulfilled, numRequired }, current at UNIT_QUEST_LOG_CHANGED.
-- Known quirks (M8.9): names are blank for ~0.2 s after accept (counts are right), and a quest reads un-done for a
-- moment at turn-in. Nothing here interprets them; ns.Contract.ObjectiveState normalises the list.
local function readObjectives(id)
	if type(C_QuestLog) ~= "table" or type(C_QuestLog.GetQuestObjectives) ~= "function" then return nil end
	local objs = try(C_QuestLog.GetQuestObjectives, id)
	if type(objs) ~= "table" then return nil end
	return objs
end

--- Quest log: { [questID] = { id, title, complete, objectives } }, count. `objectives` is nil when unreadable.
function reader.questLog()
	local log, n = {}, 0
	if type(C_QuestLog) ~= "table" or type(C_QuestLog.GetNumQuestLogEntries) ~= "function" then
		return log, 0, false
	end
	local entries = try(C_QuestLog.GetNumQuestLogEntries)
	if type(entries) ~= "number" then
		return log, 0, false
	end
	local header
	for i = 1, entries do
		local info = try(C_QuestLog.GetInfo, i)
		if type(info) == "table" and info.isHeader then header = type(info.title) == "string" and info.title or nil end
		if type(info) == "table" and not info.isHeader and type(info.questID) == "number" then
			local id = info.questID
			local complete = try(C_QuestLog.IsComplete, id) == true or try(C_QuestLog.ReadyForTurnIn, id) == true
			log[id] = { id = id, title = info.title, complete = complete, objectives = readObjectives(id), header = header }
			n = n + 1
		end
	end
	return log, n, true
end

--- The game's own quest-map points for ONE map (the map the player is on; the call only answers for a map): { [questID] = { map, x, y } }.
-- Read-only and unverified: they are where the game's quest map puts the quest (an area's centre or the turn-in), not an NPC or a spawn.
function reader.questPoints(map)
	local out = {}
	if type(map) ~= "number" or type(C_QuestLog) ~= "table" or type(C_QuestLog.GetQuestsOnMap) ~= "function" then return out end
	local list = try(C_QuestLog.GetQuestsOnMap, map)
	if type(list) ~= "table" then return out end
	for _, e in ipairs(list) do
		if type(e) == "table" and type(e.questID) == "number" and type(e.x) == "number" and type(e.y) == "number" and (e.x ~= 0 or e.y ~= 0) and out[e.questID] == nil then
			out[e.questID] = { map = map, x = e.x, y = e.y }
		end
	end
	return out
end

--- The game's own tag for a quest (Elite, Dungeon, Raid, ...): { id, name } or nil. READ-ONLY and UNVERIFIED on Forever: both the modern table form
-- (C_QuestLog.GetQuestTagInfo) and the older two-value form (GetQuestTagInfo) are tried; nothing is guessed when neither answers.
function reader.questTag(id)
	if type(id) ~= "number" then return nil end
	if type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestTagInfo) == "function" then
		local t = try(C_QuestLog.GetQuestTagInfo, id)
		if type(t) == "table" and type(t.tagID) == "number" then
			return { id = t.tagID, name = type(t.tagName) == "string" and t.tagName or nil }
		end
	end
	if type(GetQuestTagInfo) == "function" then
		local tid, tname = try(GetQuestTagInfo, id)
		if type(tid) == "number" then return { id = tid, name = type(tname) == "string" and tname or nil } end
	end
	return nil
end

--- The game's name for an area id (a dungeon's AreaID from the quest data), or nil.
function reader.areaName(areaId)
	if type(areaId) ~= "number" or type(C_Map) ~= "table" or type(C_Map.GetAreaInfo) ~= "function" then return nil end
	local n = try(C_Map.GetAreaInfo, areaId)
	return type(n) == "string" and n ~= "" and n or nil
end

function reader.isCompleted(id)
	if type(C_QuestLog) ~= "table" then return nil end
	local v = try(C_QuestLog.IsQuestFlaggedCompleted, id)
	if v == nil then return nil end
	return v == true
end

function reader.group()
	local g = { size = 1, inGroup = false }
	local n = try(GetNumGroupMembers)
	if type(n) == "number" and n > 0 then g.size = n end
	local ing = try(IsInGroup)
	if ing ~= nil then g.inGroup = ing == true end
	if g.size > 1 then g.inGroup = true end
	return g
end

Ctx.DefaultReader = reader

-- ---------------------------------------------------------------- build

--- Builds a context. `r` (optional) overrides any reader function (tests).
function Ctx.Build(r)
	r = setmetatable(r or {}, { __index = reader })
	local ctx = { time = type(GetTime) == "function" and GetTime() or 0 }
	local c = r.character()
	c.key = c.name and (c.name .. "-" .. (c.realm or "?")) or "unknown"
	c.raceKey = raceKey(c.raceToken)
	ctx.char = c
	ctx.loc = r.location()
	ctx.log, ctx.logCount, ctx.logAvailable = r.questLog()
	ctx.questPoints = (r.questPoints and ctx.loc and ctx.loc.map) and r.questPoints(ctx.loc.map) or {}
	ctx.group = r.group()
	ctx.prefs = P.Char()

	local tagCache, areaCache = {}, {}
	ctx.questTag = function(id)
		local v = tagCache[id]
		if v == nil then v = r.questTag(id) or false; tagCache[id] = v end
		return v or nil
	end
	ctx.areaName = function(areaId)
		local v = areaCache[areaId]
		if v == nil then v = r.areaName(areaId) or false; areaCache[areaId] = v end
		return v or nil
	end

	local completedCache = {}
	ctx.isCompleted = function(id)
		local v = completedCache[id]
		if v == nil then
			local got = r.isCompleted(id)
			if got == nil then got = false end
			completedCache[id] = got
			v = got
		end
		return v
	end

	-- Memoised map-position -> world-yard conversion (static for a given map/x/y), via the M8.13 converter.
	local worldCache = {}
	ctx.worldOf = function(map, x, y)
		if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
		local key = map .. ":" .. x .. ":" .. y
		local w = worldCache[key]
		if w == nil then
			w = false
			if r.worldOf then
				local cont, wx, wy = r.worldOf(map, x, y)
				if cont and wx and wy then w = { continent = cont, x = wx, y = wy } end
			elseif ns.Eval and ns.Eval.DefaultReader then
				local cont, wx, wy = ns.Eval.DefaultReader.destinationWorldPos({ ui_map_id = map, x = x, y = y })
				if cont and wx and wy then w = { continent = cont, x = wx, y = wy } end
			end
			worldCache[key] = w
		end
		return w or nil
	end

	if ctx.loc.available and not ctx.loc.world then
		ctx.loc.world = ctx.worldOf(ctx.loc.map, ctx.loc.x, ctx.loc.y)
	end
	return ctx
end
