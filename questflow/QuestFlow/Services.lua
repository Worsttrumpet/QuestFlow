-- ForeverCodex.Services: what Quest Flow has SEEN of the world's services, learned from the player's own visits (account-wide, read-only).
--
-- Quest Flow ships quest data and 14 ATT flight nodes. It ships NO vendor, trainer, innkeeper or dungeon-entrance table, and it does not guess one.
-- What it can know is what it watched happen: when you open a merchant, a trainer, a flight master's map, or a gossip window whose options say
-- vendor / trainer / binder / taxi, the NPC (name, creature id) and the place you stood are recorded. When you enter a dungeon, the last outdoor
-- place you were seen is recorded as its entrance. That is evidence from this client, with the exact limits below:
--   * the NPC's position is where the PLAYER stood (within a few yards of the NPC), not a spawn table
--   * an entrance is "where you were seen shortly before the instance loaded"; it is dropped when that sighting is older than ENTRANCE_MAX_AGE seconds
--   * a service never seen is UNKNOWN, never "not there"; nothing here turns a visit into a rule about other characters
-- Also here: the BIND point (learned only from watching the character bind: CONFIRM_BINDER, then the client's "is now your home" message / HEARTHSTONE_BOUND).
--
-- Stored: ForeverCodexDB.world = { v, npcs = { key -> { id, name, map, x, y, kinds = { vendor = n, ... }, seen } }, entrances = { name -> { map, x, y, id, seen, n } } }.
-- Bounded; the oldest are dropped. Nothing here runs a gameplay action.

local addonName, ns = ...
local P = ns.Prefs

local S = {}
ns.Services = S

S.MAX_NPCS = 300
S.MAX_ENTRANCES = 60
S.ENTRANCE_MAX_AGE = 90
S.SAMPLE_SECONDS = 5
S.KINDS = { "vendor", "trainer", "flightmaster", "innkeeper", "repair" }
S.EVENTS = { "UNIT_SPELLCAST_SUCCEEDED", "MERCHANT_SHOW", "TRAINER_SHOW", "TAXIMAP_OPENED", "GOSSIP_SHOW", "CONFIRM_BINDER", "HEARTHSTONE_BOUND", "CHAT_MSG_SYSTEM", "PLAYER_ENTERING_WORLD" }
-- gossip option types (strings, where the client gives them) -> a service kind
S.GOSSIP_KINDS = { vendor = "vendor", trainer = "trainer", taxi = "flightmaster", binder = "innkeeper" }

local function wall() return type(time) == "function" and time() or 0 end
local function isSecret(v)
	local f = _G.issecretvalue
	if type(f) == "function" then
		local ok, r = pcall(f, v)
		if ok and r == true then return true end
	end
	return false
end
local function text(v, max)
	if type(v) ~= "string" or isSecret(v) then return nil end
	local ok, r = pcall(function() if v == "" then return nil end return v:sub(1, max or 60) end)
	return ok and r or nil
end

local function store()
	if not (P and P.Root) then return nil end
	local r = P.Root()
	if type(r) ~= "table" then return nil end
	local w = r.world
	if type(w) ~= "table" then w = {} r.world = w end
	if w.v == nil then w.v = 1 end
	w.npcs = type(w.npcs) == "table" and w.npcs or {}
	w.entrances = type(w.entrances) == "table" and w.entrances or {}
	return w
end

local function trim(tbl, max)
	local n = 0
	for _ in pairs(tbl) do n = n + 1 end
	while n > max do
		local oldK, oldT
		for k, v in pairs(tbl) do
			local t = type(v) == "table" and (v.seen or 0) or 0
			if oldT == nil or t < oldT then oldK, oldT = k, t end
		end
		if oldK == nil then break end
		tbl[oldK] = nil
		n = n - 1
	end
end

-- ---------------------------------------------------------------- where the player is

--- { map, x, y } from the client, or nil.
function S.PlayerPoint()
	if type(C_Map) ~= "table" or type(C_Map.GetBestMapForUnit) ~= "function" or type(C_Map.GetPlayerMapPosition) ~= "function" then return nil end
	local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
	if not ok or type(map) ~= "number" then return nil end
	local ok2, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
	if not ok2 or type(pos) ~= "table" then return nil end
	local x, y
	if type(pos.GetXY) == "function" then local o, a, b = pcall(pos.GetXY, pos) if o then x, y = a, b end end
	x, y = x or pos.x, y or pos.y
	if type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) and not isSecret(x) then return { map = map, x = x, y = y } end
	return nil
end

--- The NPC the open window belongs to: { id, name } (each may be nil).
function S.NpcNow()
	local name, id
	if type(UnitName) == "function" then local ok, n = pcall(UnitName, "npc") if ok then name = text(n) end end
	if type(UnitGUID) == "function" then
		local ok, g = pcall(UnitGUID, "npc")
		if ok and type(g) == "string" and not isSecret(g) then
			local okm, v = pcall(function() return g:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)") end)
			if okm and v then id = tonumber(v) end
		end
	end
	return { id = id, name = name }
end

-- ---------------------------------------------------------------- recording

--- Records that the NPC `npc` ({ id, name }) offered `kind` while the player stood at `point`. Returns true when stored.
function S.Observe(kind, npc, point)
	local w = store()
	if not w or type(kind) ~= "string" or type(npc) ~= "table" then return false end
	local key = type(npc.id) == "number" and ("id:" .. npc.id) or (npc.name and ("name:" .. npc.name:lower()) or nil)
	if not key then return false end
	local e = w.npcs[key]
	if type(e) ~= "table" then e = { kinds = {} } w.npcs[key] = e end
	e.kinds = type(e.kinds) == "table" and e.kinds or {}
	e.id = type(npc.id) == "number" and npc.id or e.id
	e.name = npc.name or e.name
	e.kinds[kind] = (e.kinds[kind] or 0) + 1
	e.seen = wall()
	if point and type(point.map) == "number" then e.map, e.x, e.y = point.map, point.x, point.y end
	trim(w.npcs, S.MAX_NPCS)
	S.version = (S.version or 0) + 1
	return true
end

function S.OnGossip()
	local npc, point = S.NpcNow(), S.PlayerPoint()
	if not (npc.id or npc.name) then return 0 end
	local n = 0
	local f = type(C_GossipInfo) == "table" and C_GossipInfo.GetOptions
	if type(f) ~= "function" then return 0 end
	local ok, opts = pcall(f)
	if not ok or type(opts) ~= "table" then return 0 end
	local seen = {}
	for _, o in ipairs(opts) do
		local t = type(o) == "table" and text(o.type, 20) or nil
		local kind = t and S.GOSSIP_KINDS[t:lower()]
		if kind and not seen[kind] then seen[kind] = true if S.Observe(kind, npc, point) then n = n + 1 end end
	end
	return n
end

function S.OnMerchant()
	local npc, point = S.NpcNow(), S.PlayerPoint()
	S.Observe("vendor", npc, point)
	if type(CanMerchantRepair) == "function" then
		local ok, r = pcall(CanMerchantRepair)
		if ok and r == true then S.Observe("repair", npc, point) end
	end
end

function S.OnTrainer() S.Observe("trainer", S.NpcNow(), S.PlayerPoint()) end
function S.OnTaxiMap() S.Observe("flightmaster", S.NpcNow(), S.PlayerPoint()) end

-- ---------------------------------------------------------------- bind point

local bindOffer          -- { point, t }: the character was asked to bind here
local lastBound          -- when the last bind was recorded (a duplicate report of it within seconds is not a new bind)

function S.OnBinderOffer() bindOffer = { point = S.PlayerPoint(), npc = S.NpcNow(), t = wall() } end

--- The client said the character is now bound. The bind point is the place the offer was made (the innkeeper's door), never a guess.
function S.OnBound()
	local o = bindOffer
	bindOffer = nil
	-- the client reports one bind twice (the event and the system message): the second is the same bind, not an unplaced one
	if not o and lastBound and wall() - lastBound <= 5 then return true end
	if not (o and o.point and wall() - o.t <= 120) then S.bindUnplaced = (S.bindUnplaced or 0) + 1 return false end
	lastBound = wall()
	local name
	if type(GetBindLocation) == "function" then local ok, v = pcall(GetBindLocation) if ok then name = text(v) end end
	if ns.Travel then ns.Travel.SetBind(o.point.map, o.point.x, o.point.y, name, "binder") end
	S.Observe("innkeeper", o.npc or {}, o.point)
	return true
end

function S.OnSystemMessage(msg)
	local fmt = _G.ERR_DEATHBIND_SUCCESS_S
	if type(fmt) ~= "string" or type(msg) ~= "string" or isSecret(msg) then return false end
	local ok, hit = pcall(function()
		local pat = fmt:gsub("%%s", "\1"):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("\1", ".+")
		return msg:match("^" .. pat .. "$") ~= nil
	end)
	if ok and hit then return S.OnBound() end
	return false
end


-- A character that was bound long ago never shows us the binder. The Hearthstone's own trip does: where the character ARRIVES after a
-- completed Hearthstone cast is the bind point. Learned only from that observed trip (cast succeeded, then the character really moved).
S.HEARTH_SPELL = 8690           -- the Hearthstone spell (also matched by the use-spell name of item 6948 when the client can tell us)
S.HEARTH_WAIT = 90              -- seconds after the cast in which the arrival is accepted
S.HEARTH_MOVED = 0.04           -- map-fraction jump (same map) that counts as having arrived somewhere else
local hearthCast                -- { point, t }

--- Is `map` a zone-level (or smaller) map, not a continent / world map? Unknown stays acceptable only when the client cannot say.
function S.IsAreaMap(map)
	if type(map) ~= "number" or type(C_Map) ~= "table" or type(C_Map.GetMapInfo) ~= "function" then return type(map) == "number" end
	local ok, info = pcall(C_Map.GetMapInfo, map)
	if not ok or type(info) ~= "table" or type(info.mapType) ~= "number" then return true end
	return info.mapType >= 3
end

local function isHearthSpell(spellId)
	if type(spellId) ~= "number" or isSecret(spellId) then return false end
	if spellId == S.HEARTH_SPELL then return true end
	if type(GetItemSpell) == "function" and type(GetSpellInfo) == "function" then
		local ok, nm = pcall(GetItemSpell, 6948)
		local ok2, sn = pcall(GetSpellInfo, spellId)
		if ok and ok2 and type(nm) == "string" and nm ~= "" and sn == nm then return true end
	end
	return false
end

function S.OnHearthCast(spellId)
	if not isHearthSpell(spellId) then return false end
	hearthCast = { point = S.PlayerPoint(), t = wall() }
	return true
end

--- Polled (about once a second): has the character arrived somewhere else since a completed Hearthstone cast?
function S.CheckHearthArrival()
	local h = hearthCast
	if not h then return false end
	if wall() - h.t > S.HEARTH_WAIT then hearthCast = nil return false end
	local p = S.PlayerPoint()
	if not (p and h.point) then return false end
	local moved = p.map ~= h.point.map or math.abs(p.x - h.point.x) + math.abs(p.y - h.point.y) > S.HEARTH_MOVED
	if not moved then return false end
	-- While a loading screen is ending the client can answer with the continent map: not a place to record. Keep waiting,
	-- and only accept an arrival that reads the same, on a zone-level map, twice in a row.
	if not S.IsAreaMap(p.map) then h.seen = nil return false end
	local q = h.seen
	h.seen = p
	if not (q and q.map == p.map and math.abs(q.x - p.x) + math.abs(q.y - p.y) <= 0.01) then return false end
	hearthCast = nil
	local name
	if type(GetBindLocation) == "function" then local ok, v = pcall(GetBindLocation) if ok then name = text(v) end end
	if ns.Travel then ns.Travel.SetBind(p.map, p.x, p.y, name, "hearth") end
	S.bindFromHearth = (S.bindFromHearth or 0) + 1
	return true
end

-- ---------------------------------------------------------------- dungeon entrances

local lastOutdoor
local sinceSample = 0

function S.SampleOutdoor()
	local inInst = false
	if type(IsInInstance) == "function" then local ok, v = pcall(IsInInstance) inInst = ok and (v == true or v == 1) end
	if inInst then return end
	local p = S.PlayerPoint()
	if p then lastOutdoor = { map = p.map, x = p.x, y = p.y, t = wall() } end
end

function S.OnEnteringWorld()
	if type(IsInInstance) ~= "function" then return false end
	local ok, inInst, kind = pcall(IsInInstance)
	if not ok or not (inInst == true or inInst == 1) then return false end
	local okk, k = pcall(function() return type(kind) == "string" and kind:sub(1, 10) or nil end)
	if not okk or (k ~= "party" and k ~= "raid") then return false end
	local name, id
	if type(GetInstanceInfo) == "function" then
		local o, n, _, _, _, _, _, _, iid = pcall(GetInstanceInfo)
		if o then name = text(n) if type(iid) == "number" and not isSecret(iid) then id = iid end end
	end
	local w = store()
	if not (w and name and lastOutdoor and wall() - lastOutdoor.t <= S.ENTRANCE_MAX_AGE) then S.entranceUnplaced = (S.entranceUnplaced or 0) + 1 return false end
	local e = w.entrances[name]
	if type(e) ~= "table" then e = { n = 0 } w.entrances[name] = e end
	e.map, e.x, e.y, e.id, e.seen, e.n = lastOutdoor.map, lastOutdoor.x, lastOutdoor.y, id or e.id, wall(), e.n + 1
	trim(w.entrances, S.MAX_ENTRANCES)
	S.version = (S.version or 0) + 1
	return true
end

-- ---------------------------------------------------------------- queries

--- Seen NPCs offering `kind`: array of { key, id, name, map, x, y, count }, sorted by name.
function S.Find(kind)
	local w = store()
	local out = {}
	if not w then return out end
	for k, e in pairs(w.npcs) do
		local c = type(e.kinds) == "table" and e.kinds[kind] or nil
		if c then out[#out + 1] = { key = k, id = e.id, name = e.name, map = e.map, x = e.x, y = e.y, count = c } end
	end
	table.sort(out, function(a, b) return (a.name or a.key) < (b.name or b.key) end)
	return out
end

function S.Entrances()
	local w = store()
	local out = {}
	if not w then return out end
	for name, e in pairs(w.entrances) do out[#out + 1] = { name = name, map = e.map, x = e.x, y = e.y, id = e.id, n = e.n } end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

--- The nearest seen service of `kind` to `from` ({map,x,y}): entry, yards or nil.
function S.Nearest(kind, ctx, from)
	local best, bd
	for _, e in ipairs(S.Find(kind)) do
		if e.map and e.x then
			local d = ns.Engine.Distance(ctx, from, { map = e.map, x = e.x, y = e.y })
			if d and d ~= ns.Engine.DIFFERENT_CONTINENT and (not bd or d < bd) then best, bd = e, d end
		end
	end
	return best, bd
end

function S.Summary()
	local out = { entrances = #S.Entrances(), bind = ns.Travel and ns.Travel.Bind() ~= nil or false, kinds = {} }
	for _, k in ipairs(S.KINDS) do out.kinds[k] = #S.Find(k) end
	out.entranceUnplaced, out.bindUnplaced = S.entranceUnplaced or 0, S.bindUnplaced or 0
	return out
end

function S.ReportLines()
	local sm = S.Summary()
	local parts = {}
	for _, k in ipairs(S.KINDS) do parts[#parts + 1] = k .. "=" .. sm.kinds[k] end
	return { "Services seen by this account (from the player's own visits): " .. table.concat(parts, ", ") .. "; dungeon entrances seen=" .. sm.entrances ..
		"; bind point " .. (sm.bind and "learned" or "not learned") .. "; entrances not placed=" .. sm.entranceUnplaced .. ", binds not placed=" .. sm.bindUnplaced .. "." }
end

function S._Reset() lastBound, hearthCast, bindOffer, lastOutdoor, sinceSample, S.version, S.entranceUnplaced, S.bindUnplaced, S.bindFromHearth = nil, nil, nil, nil, 0, 0, 0, 0, 0 end

-- ---------------------------------------------------------------- events

local frame = CreateFrame("Frame")
for _, ev in ipairs(S.EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
frame:SetScript("OnEvent", function(_, event, a1, a2, a3)
	local ok, err = pcall(function()
		if event == "MERCHANT_SHOW" then S.OnMerchant()
		elseif event == "TRAINER_SHOW" then S.OnTrainer()
		elseif event == "TAXIMAP_OPENED" then S.OnTaxiMap()
		elseif event == "GOSSIP_SHOW" then S.OnGossip()
		elseif event == "CONFIRM_BINDER" then S.OnBinderOffer()
		elseif event == "HEARTHSTONE_BOUND" then S.OnBound()
		elseif event == "CHAT_MSG_SYSTEM" then S.OnSystemMessage(a1)
		elseif event == "PLAYER_ENTERING_WORLD" then S.OnEnteringWorld(); S.CheckHearthArrival()
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then if a1 == "player" then S.OnHearthCast(a3) end
		end
	end)
	if not ok and ns.RecordError then ns.RecordError("services " .. tostring(event), err) end
end)
local sinceHearth = 0
frame:SetScript("OnUpdate", function(_, elapsed)
	if hearthCast then
		sinceHearth = sinceHearth + (elapsed or 0)
		if sinceHearth >= 1 then sinceHearth = 0 pcall(S.CheckHearthArrival) end
	end
	sinceSample = sinceSample + (elapsed or 0)
	if sinceSample < S.SAMPLE_SECONDS then return end
	sinceSample = 0
	pcall(S.SampleOutdoor)
end)
S.frame = frame
