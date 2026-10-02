-- fake_questiedb.lua: a stand-in for the QuestieDB addon's DOCUMENTED public API, for the stub-client tests.
--
-- It implements only what Codex's bridge is allowed to call (QuestieDB docs/api.md): LibQuestieDB.RequireContract, Quest / Npc
-- .Get / .GetAll / .Exists / .GetAllIds, Support.Get("ZoneDB").private.areaIdToUiMapId (Lua source text), readMode,
-- ModeIndicator.GetStatus, and the addon metadata. It follows the documented read semantics: a numeric field that is not set reads 0 for
-- an entity that exists, an unknown id reads nil for every field, empty tables read nil (except startedBy / finishedBy / objectives, which
-- read {}), and GetAll returns a packed table carrying `n`.
--
-- It contains no QuestieDB data or code. It proves Codex's own use of the interface; it proves nothing about the real addon, which is
-- why the real-client checks are listed separately (docs/CODEX_REALCLIENT_FIXES.md).

local F = {}

local QUEST_FIELDS = { "name", "startedBy", "finishedBy", "requiredLevel", "questLevel", "requiredClasses", "requiredRaces",
	"objectivesText", "preQuestGroup", "preQuestSingle", "specialFlags", "breadcrumbForQuestId", "zoneOrSort" }
local QUEST_TYPE = { name = "string", startedBy = "table", finishedBy = "table", requiredLevel = "number", questLevel = "number", requiredClasses = "number",
	requiredRaces = "number", objectivesText = "table", preQuestGroup = "table", preQuestSingle = "table", specialFlags = "number", breadcrumbForQuestId = "number", zoneOrSort = "number" }
local NEVER_NIL_TABLE = { startedBy = true, finishedBy = true, objectives = true }
local NPC_TYPE = { name = "string", spawns = "table", zoneID = "number", friendlyToFaction = "string" }

local function copy(v) if type(v) ~= "table" then return v end local o = {} for k, x in pairs(v) do o[k] = copy(x) end return o end

local function read(rows, types, id, key)
	local row = rows[id]
	if row == nil then return nil end                -- unknown entity: nil for every field, numerics included
	local v = row[key]
	local t = types[key]
	if t == "number" then return v or 0 end
	if t == "table" then
		if v == nil or (next(v) == nil and not NEVER_NIL_TABLE[key]) then return NEVER_NIL_TABLE[key] and {} or nil end
		return copy(v)                                -- every table read is a fresh copy the caller owns
	end
	return v
end

local function entity(rows, types, fields)
	local E = { calls = 0 }
	function E.Get(id, key) E.calls = E.calls + 1 return read(rows, types, id, key) end
	function E.GetAll(id, keys)
		E.calls = E.calls + 1
		if rows[id] == nil then return nil end
		local out = { n = #keys }
		for i, k in ipairs(keys) do out[i] = read(rows, types, id, k) end
		return out
	end
	function E.Exists(id) return rows[id] ~= nil end
	function E.GetAllIds()
		local list = {}
		for id in pairs(rows) do list[#list + 1] = id end
		table.sort(list)
		return list
	end
	for _, f in ipairs(fields) do E[f] = function(id) return read(rows, types, id, f) end end
	return E
end

--- o: { contract = 2, minContract = 1, flavor = "Forever", mode = "baked", version, commit }
function F.new(o)
	o = o or {}
	local fake = { quests = {}, npcs = {}, areas = {}, installed = false }
	local meta = { Version = o.version or "1.0.4", ["X-BUILD-COMMIT"] = o.commit or "0123456789abcdef0123456789abcdef01234567",
		["X-Flavor"] = o.flavor or "Forever", ["X-Mode"] = o.mode or "baked" }
	fake.meta = meta

	function fake.addNpc(id, t) fake.npcs[id] = t or {} end
	function fake.addQuest(id, t) fake.quests[id] = t or {} end
	function fake.mapArea(area, map) fake.areas[area] = map end

	local Q = entity(fake.quests, QUEST_TYPE, QUEST_FIELDS)
	local N = entity(fake.npcs, NPC_TYPE, { "name", "spawns", "zoneID", "friendlyToFaction" })
	fake.Quest, fake.Npc = Q, N

	local contract, minContract = o.contract or 2, o.minContract or 1
	local lib = {
		contractVersion = contract, minSupportedContract = minContract, readMode = o.mode or "baked",
		Quest = Q, Npc = N,
		ModeIndicator = { GetStatus = function() return { mode = o.mode or "baked", expansion = o.flavor or "Forever", contractVersion = contract } end },
		Support = { Get = function(name)
			if name ~= "ZoneDB" then return nil end
			local parts = {}
			for area, map in pairs(fake.areas) do parts[#parts + 1] = string.format("[%d]=%d", area, map) end
			table.sort(parts)
			return { zoneIDs = {}, private = { areaIdToUiMapId = "return {" .. table.concat(parts, ",") .. "}" } }
		end },
	}
	function lib.RequireContract(v)
		if type(v) ~= "number" or v < 1 or v % 1 ~= 0 then return false, "invalid contract requirement" end
		if v < minContract or v > contract then
			return false, string.format("QuestieDB contract mismatch: this consumer needs version %d, the installed QuestieDB provides %d (supporting consumers back to %d).", v, contract, minContract)
		end
		return true
	end
	fake.lib = lib

	function fake.install()
		_G.LibQuestieDB, _G.QuestDB, _G.NpcDB = lib, Q, N
		_G.C_AddOns = { GetAddOnMetadata = function(addon, key) if addon == "QuestieDB" then return meta[key] end end }
		fake.installed = true
	end
	function fake.uninstall()
		_G.LibQuestieDB, _G.QuestDB, _G.NpcDB, _G.C_AddOns = nil, nil, nil, nil
		fake.installed = false
	end
	return fake
end

-- ---------------------------------------------------------------- a fake derived from what Codex already knows

local CLASS_ID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, MONK = 10, DRUID = 11, DEMONHUNTER = 12 }

--- Builds a fake QuestieDB holding the ATT-sourced facts of every quest the Registry currently knows (the same baseline, in
-- QuestieDB's shape), installs it, and runs the bridge. mode "layered": QuestieDB + the existing packs. mode "only": the ATT
-- records are emptied (their zones stay) so QuestieDB is the only source besides the observed pack. Returns fake, needsAtt;
-- needsAtt is true when some quest carries ATT data the bridge does not read (objective areas, race lists), so "only" would not be equal.
function F.fromRegistry(ns, mode)
	local R, C = ns.Registry, ForeverCodex
	local fake = F.new()
	local usedNpc, needsAtt = {}, false
	local maps = {}
	for _, id in ipairs(R.QuestIds()) do
		local v = R.Quest(id)
		if v then
			local fromAtt = function(field) return v.prov[field] == "att" end
			if fromAtt("objCoords") or fromAtt("races") or fromAtt("restrictionUnparsed") then needsAtt = true end
			local q = {}
			if fromAtt("name") then q.name = v.name end
			if fromAtt("req") then q.requiredLevel = v.req end
			if fromAtt("level") then q.questLevel = v.level end
			if fromAtt("objectives") then q.objectivesText = v.objectives end
			if fromAtt("prereq") then q.preQuestSingle = v.prereq end
			if fromAtt("repeatable") and v.repeatable then q.specialFlags = 1 end
			if fromAtt("breadcrumb") and v.breadcrumb then q.breadcrumbForQuestId = 1 end
			if fromAtt("classes") then
				local mask = 0
				for _, token in ipairs(v.classes) do mask = mask + 2 ^ (CLASS_ID[token] - 1) end
				q.requiredClasses = mask
			end
			-- the giver: an NPC of its own (reusing the real NPC id only when it would not clash with a different coordinate)
			if fromAtt("giverName") or fromAtt("giverNpc") or (v.loc and v.loc.src == "att" and v.loc.kind == "giver") then
				local loc = v.loc and v.loc.src == "att" and v.loc.kind == "giver" and v.loc or nil
				local npcId = (type(v.giverNpc) == "number" and fromAtt("giverNpc")) and v.giverNpc or nil
				local key = loc and (loc.map .. ":" .. loc.x .. ":" .. loc.y) or "none"
				if not npcId or (usedNpc[npcId] and usedNpc[npcId] ~= key) then npcId = 8000000 + id end
				usedNpc[npcId] = key
				local npc = { name = fromAtt("giverName") and v.giverName or nil, zoneID = loc and loc.map or nil }
				if fromAtt("faction") then npc.friendlyToFaction = (v.faction == "Horde") and "H" or "A" end
				if loc then npc.spawns = { [loc.map] = { { loc.x * 100, loc.y * 100 } } }; maps[loc.map] = true end
				fake.addNpc(npcId, npc)
				q.startedBy = { { npcId } }
				q.finishedBy = { { npcId } }
			end
			fake.addQuest(id, q)
		end
	end
	for map in pairs(maps) do fake.mapArea(map, map) end        -- AreaID == UiMapID in the fake
	fake.install()
	ns.QuestieBridge.Init()
	if mode == "only" then
		for _, p in ipairs(R.Packs("quests")) do
			if p.meta.src == "att" and p.quests then C.RegisterPack("quests", p.name, { meta = p.meta, zones = p.zones, quests = {} }) end
		end
	end
	return fake, needsAtt
end

return F
