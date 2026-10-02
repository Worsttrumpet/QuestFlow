-- ForeverCodex.Registry: the extension points. Everything that can grow later registers here, so new data and new
-- systems are ADDED, never wired into the engine by hand:
--
--   * data packs      ForeverCodex.RegisterPack(kind, name, pack)        quests, flight (more kinds later)
--   * action types    ForeverCodex.RegisterActionType(type, info)        QUEST, TRAVEL, FLIGHT, TRAINER, ...
--   * providers       ForeverCodex.RegisterProvider(def)                 generate candidate actions of one type
--   * strategies      ForeverCodex.RegisterStrategy(def)                 route styles = scoring over the same actions
--   * systems         ForeverCodex.RegisterSystem(def)                   player-facing on/off toggles
--
-- Provenance: every pack declares meta.src ("att" | "observed") and meta.verified. Quest packs are merged at READ
-- time by priority (observed 100 over att 10); nothing is merged or overwritten on disk, so the layers stay
-- separable and attributable.

local addonName, ns = ...
local C = ForeverCodex

local R = {}
ns.Registry = R

-- Coordinate precedence (documented decision, see CODEX_ARCHITECTURE.md): the observed layer's `pos` is the
-- PLAYER's position at a recorder checkpoint, not an NPC location, so it is used only as a FALLBACK when no ATT
-- coordinate exists. Name, quest level, objectives and giver identity are taken from observed data first.
R.COORD_PRECEDENCE = { "att", "observed_player_position" }

local packs = { quests = {}, flight = {} }
local cache = {}

local function invalidate()
	cache = {}
end

local function sortPacks(list)
	table.sort(list, function(a, b)
		local pa, pb = (a.meta and a.meta.priority) or 0, (b.meta and b.meta.priority) or 0
		if pa ~= pb then
			return pa > pb
		end
		return a.name < b.name
	end)
end

--- Registers (or replaces, by name) a data pack. Returns true on success.
function C.RegisterPack(kind, name, pack)
	if type(kind) ~= "string" or type(name) ~= "string" or type(pack) ~= "table" then
		return false
	end
	pack.kind, pack.name = kind, name
	pack.meta = type(pack.meta) == "table" and pack.meta or {}
	packs[kind] = packs[kind] or {}
	local list = packs[kind]
	for i, p in ipairs(list) do
		if p.name == name then
			list[i] = pack
			sortPacks(list)
			invalidate()
			return true
		end
	end
	table.insert(list, pack)
	sortPacks(list)
	invalidate()
	return true
end

--- Removes one pack by name (used when an optional data source turns out to be unusable). Returns true when it was there.
function R.RemovePack(kind, name)
	local list = packs[kind] or {}
	for i, p in ipairs(list) do
		if p.name == name then
			table.remove(list, i)
			invalidate()
			return true
		end
	end
	return false
end

--- Test seam: forget every pack of a kind (or all). Never used in-game.
function R.ClearPacks(kind)
	if kind then
		packs[kind] = {}
	else
		packs = { quests = {}, flight = {} }
	end
	invalidate()
end

function R.Packs(kind)
	return packs[kind] or {}
end

-- ---------------------------------------------------------------- merged quest view

local function layersFor(id)
	local layers = {}
	for _, p in ipairs(packs.quests) do
		-- a pack is either a table of records (`quests`) or a live source: `get(id)` returns one record or nil (see QuestieBridge)
		local rec = p.get and p.get(id) or (p.quests and p.quests[id])
		if rec then
			layers[#layers + 1] = { pack = p, rec = rec, src = p.meta.src or "unknown", verified = p.meta.verified == true }
		end
	end
	return layers
end

local function firstWith(layers, field)
	for _, l in ipairs(layers) do
		if l.rec[field] ~= nil and not (field == "name" and l.rec.nameMissing) then
			return l.rec[field], l
		end
	end
	if field == "name" then
		for _, l in ipairs(layers) do
			if l.rec.name ~= nil then
				return l.rec.name, l
			end
		end
	end
	return nil, nil
end

local function merge(id, layers)
	local v = { id = id, prov = {}, layers = {}, hasObserved = false, hasAtt = false }
	for _, l in ipairs(layers) do
		v.layers[#v.layers + 1] = { pack = l.pack.name, src = l.src, verified = l.verified }
		if l.src == "observed" then v.hasObserved = true end
		if l.src == "att" then v.hasAtt = true end
	end
	local function take(field, as)
		local val, l = firstWith(layers, field)
		if val ~= nil then
			v[as or field] = val
			v.prov[as or field] = l.src
		end
	end
	take("name"); take("level"); take("objectives"); take("giverNpc"); take("giverName"); take("zone")
	take("req"); take("prereq"); take("faction"); take("races"); take("classes"); take("repeatable")
	take("breadcrumb"); take("objCoords"); take("restrictionUnparsed")
	take("prereqAll"); take("turnIn"); take("raceMask"); take("classMask"); take("zoneMap"); take("event"); take("sort"); take("areaId")
	-- location: the giver coordinate of the first layer that has one, observed player position only as a labelled fallback.
	-- A pack that sets meta.guardGiver (QuestieDB) is skipped when a higher layer names a DIFFERENT giver NPC: its coordinate
	-- belongs to the other NPC (the Forever-changed-the-giver case), so it must not be attached to the observed one.
	for i, l in ipairs(layers) do
		if l.rec.map and l.rec.x and l.rec.y then
			local contradicted
			if l.pack.meta.guardGiver and l.rec.giverNpc then
				for j = 1, i - 1 do
					local g = layers[j].rec.giverNpc
					if g and g ~= l.rec.giverNpc then contradicted = { giverNpc = g, by = layers[j].src, ignored = l.src, ignoredGiverNpc = l.rec.giverNpc } break end
				end
			end
			if contradicted then
				v.locConflict = contradicted
			else
				v.loc = { map = l.rec.map, x = l.rec.x, y = l.rec.y, src = l.src, verified = l.verified, kind = "giver" }
				break
			end
		end
	end
	if not v.loc then
		for _, l in ipairs(layers) do
			local p = l.rec.pos
			if p and p.map and p.x and p.y then
				v.loc = { map = p.map, x = p.x, y = p.y, src = l.src, verified = l.verified, kind = "player_position" }
				break
			end
		end
	end
	v.src = layers[1].src          -- highest-priority layer
	v.verified = layers[1].verified
	return v
end

--- Merged view of one quest (observed over ATT), or nil if no pack knows it.
function R.Quest(id)
	cache.q = cache.q or {}
	local v = cache.q[id]
	if v ~= nil then
		return v or nil
	end
	local layers = layersFor(id)
	if #layers == 0 then
		cache.q[id] = false
		return nil
	end
	v = merge(id, layers)
	cache.q[id] = v
	return v
end

--- Sorted list of every quest id any pack knows.
function R.QuestIds()
	if cache.ids then
		return cache.ids
	end
	local seen, ids = {}, {}
	for _, p in ipairs(packs.quests) do
		for id in pairs(p.quests or {}) do
			if not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
		if p.ids then
			for _, id in ipairs(p.ids() or {}) do
				if type(id) == "number" and not seen[id] then
					seen[id] = true
					ids[#ids + 1] = id
				end
			end
		end
	end
	table.sort(ids)
	cache.ids = ids
	return ids
end

--- Case-insensitive name search for the Add box. Returns up to `limit` { id, name } sorted by name then id.
function R.Search(text, limit)
	text = tostring(text or ""):lower()
	limit = limit or 8
	local out = {}
	if #text < 2 then
		return out
	end
	local asId = tonumber(text)
	for _, id in ipairs(R.QuestIds()) do
		local q = R.Quest(id)
		if q and ((q.name and q.name:lower():find(text, 1, true)) or (asId and id == asId)) then
			out[#out + 1] = { id = id, name = q.name or ("Quest " .. id) }
		end
	end
	table.sort(out, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		return a.id < b.id
	end)
	while #out > limit do
		out[#out] = nil
	end
	return out
end

-- ---------------------------------------------------------------- zones (route-zone choices come from data)

--- Zones declared by quest packs, merged by key, sorted by label. Adding a pack with new zones adds choices.
function R.Zones()
	if cache.zones then
		return cache.zones
	end
	local byKey, list = {}, {}
	for _, p in ipairs(packs.quests) do
		for _, z in ipairs(p.zones or {}) do
			local e = byKey[z.key]
			if not e then
				e = { key = z.key, label = z.label, map = z.map, quests = 0, srcs = {} }
				byKey[z.key] = e
				list[#list + 1] = e
			end
			e.quests = e.quests + (z.quests or 0)
			e.srcs[p.meta.src or "unknown"] = true
			if not e.map and z.map then e.map = z.map end
		end
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	cache.zones = list
	return list
end

function R.ZoneByKey(key)
	for _, z in ipairs(R.Zones()) do
		if z.key == key then
			return z
		end
	end
	return nil
end

--- Display label for a ui map id: a zone whose primary map it is, else "map <id>".
function R.MapLabel(map)
	for _, z in ipairs(R.Zones()) do
		if z.map == map then
			return z.label
		end
	end
	return "map " .. tostring(map)
end

-- ---------------------------------------------------------------- flight nodes

function R.FlightNodes()
	if cache.fp then
		return cache.fp
	end
	local out, seen = {}, {}
	for _, p in ipairs(packs.flight) do
		for id, n in pairs(p.nodes or {}) do
			if not seen[id] then
				seen[id] = true
				out[#out + 1] = { id = id, name = n.name, map = n.map, x = n.x, y = n.y, faction = n.faction, npc = n.npc,
					src = p.meta.src or "unknown", verified = p.meta.verified == true }
			end
		end
	end
	table.sort(out, function(a, b) return a.id < b.id end)
	cache.fp = out
	return out
end

--- Per-pack counts for diagnostics.
function R.Stats()
	local out = { packs = {}, quests = #R.QuestIds(), flightNodes = #R.FlightNodes(), zones = #R.Zones() }
	for _, kind in ipairs({ "quests", "flight" }) do
		for _, p in ipairs(packs[kind] or {}) do
			local n, withLoc = 0, 0
			if p.stats then
				local st = p.stats()
				n, withLoc = st.count or 0, st.withLocation or 0
			else
				for _, rec in pairs(p.quests or p.nodes or {}) do
					n = n + 1
					if rec.map or rec.pos then withLoc = withLoc + 1 end
				end
			end
			out.packs[#out.packs + 1] = { kind = kind, name = p.name, src = p.meta.src, verified = p.meta.verified == true,
				count = n, withLocation = withLoc, label = p.meta.label, sourceRef = p.meta.sourceRef }
		end
	end
	local overlap = 0
	for _, id in ipairs(R.QuestIds()) do
		local q = R.Quest(id)
		if q and q.hasObserved and q.hasAtt then overlap = overlap + 1 end
	end
	out.observedAndAtt = overlap
	return out
end

-- ---------------------------------------------------------------- action types, systems, providers, strategies

local actionTypes, typeOrder = {}, {}
local systems, systemOrder = {}, {}
local providers, providerOrder = {}, {}
local strategies, strategyOrder = {}, {}

function C.RegisterActionType(type_, info)
	if type(type_) ~= "string" then return false end
	info = info or {}
	if not actionTypes[type_] then typeOrder[#typeOrder + 1] = type_ end
	actionTypes[type_] = { type = type_, label = info.label or type_, planned = info.planned == true, system = info.system }
	return true
end

function R.ActionTypes() local o = {} for _, k in ipairs(typeOrder) do o[#o + 1] = actionTypes[k] end return o end
function R.ActionType(t) return actionTypes[t] end

function C.RegisterSystem(def)
	if type(def) ~= "table" or type(def.key) ~= "string" then return false end
	if not systems[def.key] then systemOrder[#systemOrder + 1] = def.key end
	systems[def.key] = { key = def.key, label = def.label or def.key, desc = def.desc, planned = def.planned == true, default = def.default == true }
	return true
end

function R.Systems() local o = {} for _, k in ipairs(systemOrder) do o[#o + 1] = systems[k] end return o end
function R.System(k) return systems[k] end

--- A provider turns a context into candidate actions of one type. `system` ties it to a toggle (nil = always on).
-- A provider with planned = true (or no generate function) is registered but inert: no data, no recommendations.
function C.RegisterProvider(def)
	if type(def) ~= "table" or type(def.key) ~= "string" then return false end
	if not providers[def.key] then providerOrder[#providerOrder + 1] = def.key end
	providers[def.key] = def
	return true
end

function R.Providers() local o = {} for _, k in ipairs(providerOrder) do o[#o + 1] = providers[k] end return o end
function R.Provider(k) return providers[k] end

function C.RegisterStrategy(def)
	if type(def) ~= "table" or type(def.key) ~= "string" then return false end
	if not strategies[def.key] then strategyOrder[#strategyOrder + 1] = def.key end
	strategies[def.key] = def
	return true
end

function R.Strategies() local o = {} for _, k in ipairs(strategyOrder) do o[#o + 1] = strategies[k] end return o end
function R.Strategy(k) return strategies[k] end

--- Test seam: forget every provider / system / strategy / type registration. Never used in-game.
function R.ResetExtensions()
	actionTypes, typeOrder, systems, systemOrder, providers, providerOrder, strategies, strategyOrder = {}, {}, {}, {}, {}, {}, {}, {}
end

-- ---------------------------------------------------------------- action constructor

--- Every recommendation is an Action. `src` / `verified` say where its data came from; `target.verified` says
-- whether its coordinates were observed on Forever. Nothing here upgrades ATT data to "verified".
function R.NewAction(f)
	f.reasons = f.reasons or {}
	f.lines = f.lines or {}
	if f.verified == nil then f.verified = false end
	return f
end
