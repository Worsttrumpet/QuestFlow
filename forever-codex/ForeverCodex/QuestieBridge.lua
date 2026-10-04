-- ForeverCodex.QuestieBridge: reads quest knowledge from the QuestieDB addon AT RUNTIME, through its documented public API.
--
--   QuestieDB          the world / quest knowledge baseline (what quests exist, who gives them, where the NPC stands)
--   Forever Codex      the planner, player state, telemetry, Forever observations and evidence, UI
--
-- Nothing of QuestieDB (code or data) is copied into Codex: this file only CALLS it. QuestieDB is an OPTIONAL dependency
-- (## OptionalDeps in the .toc): without it Codex still loads and says so, and uses its own small built-in data.
--
-- Documented QuestieDB API used (QuestieDB docs/api.md), and nothing else:
--   LibQuestieDB.RequireContract(n)                  version-range check
--   LibQuestieDB.Quest.GetAll(id, keys) / .Get / .Exists / .GetAllIds()      (global shorthand: QuestDB)
--   LibQuestieDB.Npc.GetAll(id, keys) / .Get                                  (global shorthand: NpcDB)
--   LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId               (a Lua source string: AreaID -> UiMapID)
--   LibQuestieDB.readMode, LibQuestieDB.ModeIndicator.GetStatus()
--   the addon metadata of "QuestieDB" (Version, X-BUILD-COMMIT, X-Flavor, X-Mode) through GetAddOnMetadata
--
-- EVIDENCE RULES
--   * Missing from QuestieDB means UNKNOWN, never "does not exist". (The stable QuestieDB release lacks Forever-only quests
--     that a newer build has; absence proves nothing.) Nothing here turns a missing quest into a verdict.
--   * Everything read from QuestieDB is src="questiedb", verified=false. It is a baseline from Classic and community work, not
--     proof of how Forever behaves. QuestieDB's own provenance collapses its internal layers to "QuestieDB", so Codex does not
--     claim to know whether a value is original Classic data or a later Forever addition.
--   * Layering (Registry merges by pack priority, field by field): Codex-observed Forever data (100) over QuestieDB (50) over
--     Codex's own ATT-derived data (10, a TEMPORARY fallback while this bridge is proven on the real client). QuestieDB never
--     overwrites a field Codex has observed. QuestieTrace / community observations are not read, and never become "observed".
--
-- WHAT IS DELIBERATELY NOT USED YET (kept conservative; each is listed so it is a decision, not an accident)
--   * race masks: Forever's new races use bit positions that only QuestieDB's consumer (Questie) interprets, which is not part of the
--     documented database API. The mask is kept as `raceMask` for diagnostics but no race restriction is enforced from it.
--     The faction restriction is INFERRED from the starter NPC's friendliness (a QuestieDB NPC field), and labelled as such.
--   * (the turn-in NPC IS used since 0.2.2: the quest provider routes a hand-in to it when its position is known)
--   * objective areas, object / item starters, exclusivity, chains beyond prerequisites, Questie's own hide/blacklist policy.

local addonName, ns = ...
local C = ForeverCodex
local R = ns.Registry

local QB = {}
ns.QuestieBridge = QB

QB.CONTRACT = 1             -- the oldest QuestieDB contract this bridge is written against; RequireContract passes for any newer-or-equal supported one
QB.PACK_NAME = "questiedb"
QB.SRC = "questiedb"
QB.PRIORITY = 50            -- observed 100 > QuestieDB 50 > ATT 10 (temporary fallback)

-- indexes into the packed values of Quest.GetAll(id, QUEST_KEYS)
local QUEST_KEYS = { "name", "startedBy", "finishedBy", "requiredLevel", "questLevel", "requiredClasses", "requiredRaces",
	"objectivesText", "preQuestGroup", "preQuestSingle", "specialFlags", "breadcrumbForQuestId", "zoneOrSort" }
local K = {}
for i, k in ipairs(QUEST_KEYS) do K[k] = i end
local NPC_KEYS = { "name", "spawns", "zoneID", "friendlyToFaction" }

-- QuestSort ids (the game's own quest categories, which QuestieDB stores as a NEGATIVE zoneOrSort) that mean "a holiday or world event": the
-- seasonal festivals (Winter Veil, Harvest Festival, Children's Week, Love is in the Air, Pilgrim's Bounty, Noblegarden, Brewfest, Midsummer,
-- Lunar Festival, Darkmoon Faire, Day of the Dead, Hallow's End), the generic "Seasonal" category, and the Scourge Invasion / Ahn'Qiraj war effort
-- world events. A small fixed set of game categories, NOT a list of quests. Not verified against the Forever client itself; the ids are the ones
-- QuestieDB's Forever data uses for these quests (for example "Highpeak the Elder" is -366, "Greatfather Winter is Here!" is -22).
local EVENT_SORTS = {}
for _, id in ipairs({ -404, -402, -378, -376, -375, -374, -370, -369, -366, -364, -41, -22, -21, -368, -365 }) do EVENT_SORTS[id] = true end
QB.EVENT_SORTS = EVENT_SORTS

-- standard WoW class ids; the class mask bit for class id n is 2^(n-1) (the same convention QuestieDB's data uses)
local CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER" }

-- ---------------------------------------------------------------- the client's view of QuestieDB (replaceable in tests)

QB.api = {
	lib = function() return rawget(_G, "LibQuestieDB") end,
	metadata = function(key)
		local fn = (type(_G.C_AddOns) == "table" and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
		if type(fn) ~= "function" then return nil end
		local ok, v = pcall(fn, "QuestieDB", key)
		return ok and v or nil
	end,
	now = function() local f = _G.debugprofilestop; return type(f) == "function" and f() or nil end,
}

-- ---------------------------------------------------------------- status

QB.status = { state = "not checked", message = "QuestieDB has not been checked yet." }
local stats = { built = 0, withLocation = 0, errors = 0, ms = 0 }
local zoneMap, zoneMapOk                       -- AreaID -> UiMapID, decoded once
local npcCache = {}
local recCache = {}
local idList

local function reset()
	zoneMap, zoneMapOk, idList = nil, nil, nil
	npcCache, recCache = {}, {}
	stats = { built = 0, withLocation = 0, errors = 0, ms = 0 }
end

local function lower(v) return type(v) == "string" and v:lower() or "" end

--- Human text for the "QuestieDB is not usable" situations: what QuestieDB is for, and what to do.
local function setupText(state, detail)
	if state == "missing" then
		return "The QuestieDB addon was not found. Codex uses QuestieDB for its quest knowledge (which quests exist, who gives them and where they stand). "
			.. "Install QuestieDB (it comes with the Questie addon, or on its own) and Codex will use it. Until then Codex uses its own small built-in data, so its recommendations are limited."
	elseif state == "contract" then
		return "QuestieDB is installed but its data interface is not one this version of Codex understands (" .. tostring(detail) .. "). Update QuestieDB or Forever Codex. Codex is using its own small built-in data meanwhile."
	elseif state == "flavor" then
		return "QuestieDB is installed but is serving " .. tostring(detail) .. " data, not Forever data, so Codex is not using it. Codex is using its own small built-in data meanwhile."
	end
	return "QuestieDB could not be read (" .. tostring(detail) .. "). Codex is using its own small built-in data meanwhile."
end
QB.SetupText = setupText

-- ---------------------------------------------------------------- reading QuestieDB

local function entities()
	local lib = QB.api.lib()
	if type(lib) ~= "table" then return nil end
	local Q = type(lib.Quest) == "table" and lib.Quest or rawget(_G, "QuestDB")
	local N = type(lib.Npc) == "table" and lib.Npc or rawget(_G, "NpcDB")
	return lib, Q, N
end

--- AreaID -> UiMapID. QuestieDB publishes it as Lua source text (a documented quirk), so it is decoded once.
local function areaToMap(area)
	if zoneMapOk == nil then
		zoneMapOk = false
		local lib = QB.api.lib()
		local ok, src = pcall(function() return lib.Support.Get("ZoneDB").private.areaIdToUiMapId end)
		if ok and type(src) == "string" and type(loadstring) == "function" then
			local chunk = loadstring(src)
			if chunk then
				local okRun, t = pcall(chunk)
				if okRun and type(t) == "table" then zoneMap, zoneMapOk = t, true end
			end
		elseif ok and type(src) == "table" then
			zoneMap, zoneMapOk = src, true
		end
	end
	local m = zoneMapOk and zoneMap[area] or nil
	if type(m) == "number" and m > 0 then return m end
	return nil
end

--- { name, loc = { map, x, y } | nil, faction = "Horde" | "Alliance" | nil, zoneID } for one NPC; nil when QuestieDB does not know it.
local function npcInfo(N, npcId)
	if type(npcId) ~= "number" then return nil end
	local hit = npcCache[npcId]
	if hit ~= nil then return hit or nil end
	local v = N.GetAll(npcId, NPC_KEYS)
	if type(v) ~= "table" then npcCache[npcId] = false return nil end
	local info = { id = npcId, name = type(v[1]) == "string" and v[1] ~= "" and v[1] or nil }
	-- where it stands: the NPC's own primary area when it has spawns there, else the lowest mapped area (deterministic)
	local spawns, primary = v[2], v[3]
	if type(spawns) == "table" then
		local order, seen = {}, {}
		if type(primary) == "number" and primary > 0 and spawns[primary] then order[1] = primary seen[primary] = true end
		local rest = {}
		for area in pairs(spawns) do if type(area) == "number" and not seen[area] then rest[#rest + 1] = area end end
		table.sort(rest)
		for _, a in ipairs(rest) do order[#order + 1] = a end
		for _, area in ipairs(order) do
			local map = areaToMap(area)
			local pts = spawns[area]
			if map and type(pts) == "table" then
				for _, pt in ipairs(pts) do
					-- {-1,-1} is QuestieDB's "present inside an instance" marker, not a place
					if type(pt) == "table" and type(pt[1]) == "number" and type(pt[2]) == "number" and pt[1] >= 0 and pt[2] >= 0 then
						info.loc = { map = map, x = pt[1] / 100, y = pt[2] / 100 }
						break
					end
				end
			end
			if info.loc then break end
		end
	end
	-- a faction restriction INFERRED from who the NPC is friendly to ("H", "A", "AH" or nil)
	local f = v[4]
	if f == "H" then info.faction = "Horde" elseif f == "A" then info.faction = "Alliance" end
	npcCache[npcId] = info
	return info
end

local function firstNpc(slot)
	return type(slot) == "table" and type(slot[1]) == "table" and type(slot[1][1]) == "number" and slot[1][1] or nil
end

--- The first id in one slot of a QuestieDB `startedBy` value ({ creatureIds, objectIds, itemIds }), or nil.
local function slotId(slot, n)
	local s = type(slot) == "table" and slot[n] or nil
	return type(s) == "table" and type(s[1]) == "number" and s[1] or nil
end

--- The name of a QuestieDB item (documented Item.Get), or nil. Objects have no documented read here, so an object is kept by id only.
local function itemName(id)
	local lib = QB.api.lib()
	if type(id) ~= "number" or type(lib) ~= "table" or type(lib.Item) ~= "table" then return nil end
	local ok, n = pcall(lib.Item.Get, id, "name")
	return ok and type(n) == "string" and n ~= "" and n or nil
end

local function idsOf(t)
	if type(t) ~= "table" then return nil end
	local out = {}
	for _, id in ipairs(t) do if type(id) == "number" and id > 0 then out[#out + 1] = id end end
	return #out > 0 and out or nil
end

local function bit(mask, n) return math.floor(mask / 2 ^ (n - 1)) % 2 == 1 end

--- One Codex quest record (the pack-record shape the Registry already merges), or nil when QuestieDB has no such quest.
-- nil here means UNKNOWN, never "no such quest".
function QB.Record(id)
	local hit = recCache[id]
	if hit ~= nil then return hit or nil end
	local _, Q, N = entities()
	if not Q or not N then return nil end
	local t0 = QB.api.now()
	local ok, rec = pcall(function()
		local v = Q.GetAll(id, QUEST_KEYS)
		if type(v) ~= "table" then return nil end
		local r = { id = id }
		if type(v[K.name]) == "string" and v[K.name] ~= "" then r.name = v[K.name] end
		if type(v[K.requiredLevel]) == "number" and v[K.requiredLevel] > 0 then r.req = v[K.requiredLevel] end
		if type(v[K.questLevel]) == "number" and v[K.questLevel] > 0 then r.level = v[K.questLevel] end
		local lines = {}
		if type(v[K.objectivesText]) == "table" then
			for _, l in ipairs(v[K.objectivesText]) do if type(l) == "string" and l ~= "" then lines[#lines + 1] = l end end
		end
		if #lines > 0 then r.objectives = lines end
		-- prerequisites: "single" is any-of; "group" is all-of (also listed as any-of, the looser reading, so one list stays complete)
		local single, group = idsOf(v[K.preQuestSingle]), idsOf(v[K.preQuestGroup])
		r.prereq = single or group
		if group and #group > 1 then r.prereqAll = group end
		if type(v[K.specialFlags]) == "number" and math.floor(v[K.specialFlags]) % 2 == 1 then r.repeatable = true end
		if type(v[K.breadcrumbForQuestId]) == "number" and v[K.breadcrumbForQuestId] > 0 then r.breadcrumb = true end
		-- class restriction: a list of class tokens when every set bit is a known class; otherwise left alone (and kept as a mask)
		local cm = v[K.requiredClasses]
		if type(cm) == "number" and cm > 0 then
			r.classMask = cm
			local list = {}
			for n, token in ipairs(CLASS_TOKENS) do if bit(cm, n) then list[#list + 1] = token end end
			if #list > 0 and cm < 2 ^ #CLASS_TOKENS then r.classes = list end
		end
		if type(v[K.requiredRaces]) == "number" and v[K.requiredRaces] > 0 then r.raceMask = v[K.requiredRaces] end
		-- the broad area the quest belongs to (a positive zoneOrSort is an AreaID; a negative one is a category, not a place): lets the planner
		-- tell that an in-progress quest is "around here" even when its exact objective spot is not known
		local zs = v[K.zoneOrSort]
		if type(zs) == "number" and zs > 0 then
			r.areaId = zs                                  -- kept for naming a dungeon quest's dungeon (the game names the area)
			local zm = areaToMap(zs)
			if zm then r.zoneMap = zm end
		elseif type(zs) == "number" and zs < 0 then
			r.sort = zs
			if EVENT_SORTS[zs] then r.event = true end      -- a holiday / world-event quest: only possible while its event runs
		end
		-- WHAT starts it: an NPC, a world object or an item (QuestieDB's startedBy has one slot for each). A quest started by an object or an item is NOT given by the NPC who happens to
		-- stand beside it, so when there is no creature starter no giver is set at all; the source kind is kept so the player is told where it really starts.
		local sb = v[K.startedBy]
		local objId, itmId = slotId(sb, 2), slotId(sb, 3)
		if objId then r.startObject = objId end
		if itmId then r.startItem = itmId; r.startItemName = itemName(itmId) end
		r.startKind = (firstNpc(sb) and "NPC") or (itmId and "ITEM") or (objId and "OBJECT") or nil
		-- who gives it (and where they stand); who takes it back
		local giver = npcInfo(N, firstNpc(sb))
		if giver then
			r.giverNpc, r.giverName = giver.id, giver.name
			r.faction = giver.faction
			if giver.loc then r.map, r.x, r.y = giver.loc.map, giver.loc.x, giver.loc.y end
		end
		local taker = npcInfo(N, firstNpc(v[K.finishedBy]))
		if taker then
			-- atGiver: decided inside QuestieDB's own record (its finisher IS its starter), so a merged giver from another layer cannot confuse it
			r.turnIn = { npc = taker.id, name = taker.name, atGiver = giver ~= nil and giver.id == taker.id }
			if taker.loc then r.turnIn.map, r.turnIn.x, r.turnIn.y = taker.loc.map, taker.loc.x, taker.loc.y end
		end
		return r
	end)
	if not ok then
		stats.errors = stats.errors + 1
		recCache[id] = false
		return nil
	end
	stats.built = stats.built + 1
	if rec and rec.map then stats.withLocation = stats.withLocation + 1 end
	local t1 = QB.api.now()
	if t0 and t1 then stats.ms = stats.ms + (t1 - t0) end
	recCache[id] = rec or false
	return rec
end

--- Every quest id QuestieDB knows (ascending). A shared, read-only list: it is never modified here.
local function ids()
	if idList then return idList end
	local _, Q = entities()
	local ok, list = pcall(function() return Q.GetAllIds() end)
	idList = ok and type(list) == "table" and list or {}
	return idList
end

-- ---------------------------------------------------------------- start-up

--- Looks for QuestieDB, checks it, and registers it as a quest-data pack when usable. Safe to call again (it re-checks).
-- Returns true when QuestieDB is in use.
function QB.Init()
	R.RemovePack("quests", QB.PACK_NAME)
	reset()
	local lib, Q, N = entities()
	local st = { state = "missing", checkedLib = type(lib) == "table" }
	QB.status = st
	if type(lib) ~= "table" then
		st.message = setupText("missing")
		return false
	end
	-- version facts, for diagnostics (all optional)
	st.version = QB.api.metadata("Version")
	st.commit = QB.api.metadata("X-BUILD-COMMIT")
	st.mode = type(lib.readMode) == "string" and lib.readMode or QB.api.metadata("X-Mode")
	local okS, ms = pcall(function() return lib.ModeIndicator.GetStatus() end)
	if okS and type(ms) == "table" then st.mode = st.mode or ms.mode; st.flavor = ms.expansion; st.contract = ms.contractVersion end
	st.flavor = st.flavor or QB.api.metadata("X-Flavor")
	if type(lib.contractVersion) == "number" then st.contract = st.contract or lib.contractVersion end
	st.minContract = type(lib.minSupportedContract) == "number" and lib.minSupportedContract or nil
	-- contract
	if type(lib.RequireContract) ~= "function" then
		st.state, st.message = "error", setupText("error", "no RequireContract")
		return false
	end
	local okC, passed, why = pcall(lib.RequireContract, QB.CONTRACT)
	if not okC or not passed then
		st.state, st.detail = "contract", tostring(okC and why or passed)
		st.message = setupText("contract", st.detail)
		return false
	end
	if not Q or not N or type(Q.GetAll) ~= "function" or type(Q.GetAllIds) ~= "function" or type(N.GetAll) ~= "function" then
		st.state, st.message = "error", setupText("error", "the quest or NPC interface is missing")
		return false
	end
	-- flavor: Era-framed data on a Forever client would put a few zones in the wrong place
	local flavor = lower(st.flavor)
	if flavor ~= "" and flavor ~= "forever" then
		st.state, st.detail = "flavor", tostring(st.flavor)
		st.message = setupText("flavor", st.detail)
		return false
	end
	st.flavorKnown = flavor ~= ""
	local okN, n = pcall(function() return #Q.GetAllIds() end)
	st.quests = okN and n or nil
	st.state = "available"
	st.message = "QuestieDB is in use as Codex's quest knowledge."
	C.RegisterPack("quests", QB.PACK_NAME, {
		meta = { src = QB.SRC, verified = false, priority = QB.PRIORITY, guardGiver = true, restrictions = true,
			label = "QuestieDB (runtime; baseline knowledge, unverified on Forever)" },
		zones = {},
		get = QB.Record,
		ids = ids,
		stats = function() return { count = st.quests or 0, withLocation = stats.withLocation } end,
	})
	return true
end

function QB.Available() return QB.status.state == "available" end
function QB.Status() return QB.status end
function QB.Stats() return { built = stats.built, withLocation = stats.withLocation, errors = stats.errors, ms = stats.ms } end

-- ---------------------------------------------------------------- diagnostics: what does QuestieDB hold for ONE quest?

--- For the playtest report only (never used by the planner): what QuestieDB knows about one quest's giver, turn-in NPC and objectives,
-- as plain facts, so a quest Codex cannot place can be traced to the layer that lacks the data. Reads only documented fields
-- (`startedBy`, `finishedBy`, `objectives`, NPC `spawns`). It does NOT interpret objectives into places: it counts what is there.
-- Returns nil when QuestieDB is not usable; { known = false } when it does not have the quest (UNKNOWN, not "no such quest").
function QB.Describe(id)
	local lib, Q, N = entities()
	if type(lib) ~= "table" or not Q or not N then return nil end
	local ok, out = pcall(function()
		local d = { id = id }
		local exists = Q.Exists(id)
		d.known = exists == true
		if not d.known then return d end
		local function npcOf(key)
			local npc = firstNpc(Q.Get(id, key))
			if not npc then return nil end
			local info = npcInfo(N, npc)
			return { npc = npc, name = info and info.name or nil, known = info ~= nil, hasLocation = info ~= nil and info.loc ~= nil }
		end
		d.giver, d.turnIn = npcOf("startedBy"), npcOf("finishedBy")
		local obj = Q.Get(id, "objectives")
		d.objectives = {}
		if type(obj) == "table" then
			for slot, list in pairs(obj) do
				local n = type(list) == "table" and #list or 0
				if n > 0 then
					-- how many entries in this slot are NPCs QuestieDB knows a position for (assuming entries are { npcId, text }: unverified on Forever)
					local placed = 0
					for _, e in ipairs(list) do
						local info = type(e) == "table" and npcInfo(N, e[1]) or nil
						if info and info.loc then placed = placed + 1 end
					end
					d.objectives[#d.objectives + 1] = { slot = slot, entries = n, npcWithLocation = placed }
				end
			end
			table.sort(d.objectives, function(a, b) return tostring(a.slot) < tostring(b.slot) end)
		end
		return d
	end)
	if not ok then return { id = id, error = tostring(out) } end
	return out
end

--- The entity tables the installed QuestieDB exposes (names only), e.g. { "Npc", "Quest" }: tells whether object / item data is reachable.
function QB.Entities()
	local lib = QB.api.lib()
	if type(lib) ~= "table" then return nil end
	local out = {}
	for k, v in pairs(lib) do
		if type(k) == "string" and type(v) == "table" and k:match("^%u") then out[#out + 1] = k end
	end
	table.sort(out)
	return out
end

-- ---------------------------------------------------------------- development smoke check

--- A development / diagnostic check of the bridge, NOT used by the planner or any product logic: asks QuestieDB the four
-- questions a real check needs for one quest and one NPC and reports each answer. A quest that QuestieDB does not have is
-- reported as "absent in this QuestieDB build" (expected on a stable release for a Forever-only quest; a newer build may have it).
-- Returns a list of text lines.
function QB.Smoke(questId, npcId)
	local lines = {}
	local lib, Q, N = entities()
	if type(lib) ~= "table" or not Q or not N then
		lines[1] = "QuestieDB is not available, so there is nothing to check."
		return lines
	end
	local function try(f, ...)
		local ok, a = pcall(f, ...)
		if ok then return a end          -- (not `ok and a or ...`: a false answer, such as Exists = false, must stay false)
		return "error: " .. tostring(a)
	end
	local function show(v)
		if type(v) ~= "table" then return tostring(v) end
		local out = {}
		for k, x in pairs(v) do out[#out + 1] = tostring(k) .. "=" .. show(x) end
		table.sort(out)
		return "{" .. table.concat(out, ",") .. "}"
	end
	local exists = try(Q.Exists, questId)
	lines[#lines + 1] = string.format("Quest.Exists(%s) = %s%s", tostring(questId), tostring(exists),
		exists == false and "   (absent in this QuestieDB build: unknown to Codex, not a statement that the quest does not exist)" or "")
	lines[#lines + 1] = string.format("Quest.Get(%s, \"name\") = %s", tostring(questId), tostring(try(Q.Get, questId, "name")))
	lines[#lines + 1] = string.format("Npc.Get(%s, \"name\") = %s", tostring(npcId), tostring(try(N.Get, npcId, "name")))
	local spawns = try(N.Get, npcId, "spawns")
	lines[#lines + 1] = string.format("Npc.spawns(%s) = %s", tostring(npcId), show(spawns))
	if type(spawns) == "table" then
		for area in pairs(spawns) do
			if type(area) == "number" then lines[#lines + 1] = string.format("  area %d -> UiMap %s", area, tostring(areaToMap(area))) break end
		end
	end
	return lines
end
