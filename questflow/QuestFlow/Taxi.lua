-- ForeverCodex.Taxi: what the Forever client itself says about THIS character's flight paths (a read-only evidence layer).
--
-- WHY. Quest Flow's built-in data knows that some flight masters exist (ATT, unverified). That says nothing about whether THIS character has
-- discovered the path, and a route that flies from a node the character has never touched would be wrong. So two different facts are kept apart:
--   EXISTS      "Quest Flow knows this flight path exists"      (ATT data, or a node the client listed on a taxi map)
--   DISCOVERED  "this character has this flight path"           (only ever from the client's own taxi map: YES / LISTED / nothing)
-- DISCOVERED is never inferred from level, zone, faction or "they probably flew here". Not seen on a taxi map = UNKNOWN, never "no".
--
-- WHAT IT READS (nothing is assumed; every call is pcall'd and only made when it exists; each API is tallied PROVEN / UNPROVEN / ABSENT / FAILED
-- in the report). Two API families exist across WoW clients and BOTH are tried, because which one Forever answers with is a real-client question:
--   modern    C_TaxiMap.GetAllTaxiNodes(uiMapID) / C_TaxiMap.GetTaxiNodesForMap(uiMapID): { nodeID, name, state, position, ... }
--   classic   NumTaxiNodes(), TaxiNodeName(i), TaxiNodeGetType(i) ("CURRENT" / "REACHABLE" / "DISTANT" / "NONE"), TaxiNodeCost(i), TaxiNodePosition(i)
-- It reads on TAXIMAP_OPENED (a flight master's map is open: the only moment the client lists the nodes). Events are registered through pcall.
--
-- WHAT IT RECORDS (per character, ForeverCodexDB.chars[key].taxi; bounded):
--   nodes[key]   { id, name, map, x, y, state, disc, att, first, seen, cost }       key = "id:<nodeID>" or "name:<lowercase name>"
--   reach[from]  { to = { [toKey] = copper cost | true }, t }                       "standing at <from>, the map offered <to>": a DIRECT-offer edge, one direction only
--   flights[from..">"..to] = { secs, n }                                            the seconds a flight actually took (measured), never a guess
-- disc = "YES"    the node was CURRENT or REACHABLE on this character's taxi map (routing-grade)
--        "LISTED" the node was on the map but neither current nor reachable (known to the map; NOT used for routing)
-- A node the client calls NONE is recorded as EXISTS only.
-- Matching to ATT: by node id when ATT's id equals the client's AND the names are compatible, else by the town name (first part before the comma,
-- a trailing "City" ignored) preferring the player's faction. A match is stored as `att` (the ATT node id) with the method in the report.
--
-- What it does NOT do: take a flight, press a button, or read anything protected. TakeTaxiNode is only POST-hooked (hooksecurefunc) to time a flight.

local addonName, ns = ...
local P = ns.Prefs

local T = {}
ns.Taxi = T

T.SCHEMA = 1
T.MAX_NODES = 150
T.MAX_FLIGHTS = 200
T.EVENTS = { "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }
T.APIS = { "C_TaxiMap.GetAllTaxiNodes", "C_TaxiMap.GetTaxiNodesForMap", "NumTaxiNodes", "TaxiNodeName", "TaxiNodeGetType", "TaxiNodeCost",
	"TaxiNodePosition", "TakeTaxiNode", "UnitOnTaxi", "C_Map.GetBestMapForUnit", "C_Map.GetMapInfo" }
T.MIN_FLIGHT_SECS, T.MAX_FLIGHT_SECS = 8, 1200

local version = 0              -- raised when stored evidence changes, so caches built from it know to rebuild
function T.Version() return version end

local session = { opens = 0, reads = 0 }
local pending                  -- { from, to, t0, started }
local lastIndex = {}           -- classic index -> node key, from the latest read

local function wall() return type(time) == "function" and time() or 0 end
local function now() return type(GetTime) == "function" and GetTime() or 0 end

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
local function num(v)
	if type(v) ~= "number" or isSecret(v) then return nil end
	local ok, r = pcall(function() return v + 0 end)
	return ok and r or nil
end

--- A client function by name ("C_TaxiMap.GetAllTaxiNodes"), or nil.
function T.Resolve(name)
	local v = _G
	for part in tostring(name):gmatch("[^%.]+") do
		if type(v) ~= "table" then return nil end
		v = v[part]
	end
	return type(v) == "function" and v or nil
end

-- ---------------------------------------------------------------- store

local function store()
	if not (P and P.Char) then return nil end
	local c = P.Char()
	if type(c) ~= "table" then return nil end
	local s = c.taxi
	if type(s) ~= "table" then s = {} c.taxi = s end
	if s.v == nil then s.v = T.SCHEMA end
	s.nodes = type(s.nodes) == "table" and s.nodes or {}
	s.reach = type(s.reach) == "table" and s.reach or {}
	s.flights = type(s.flights) == "table" and s.flights or {}
	s.proof = type(s.proof) == "table" and s.proof or {}
	s.stats = type(s.stats) == "table" and s.stats or {}
	return s
end

local function bump(key)
	local s = store()
	if s then s.stats[key] = (s.stats[key] or 0) + 1 end
end

local function proof(api, state)
	local s = store()
	if not s then return end
	local old = s.proof[api]
	if old == "PROVEN" and state ~= "PROVEN" then return end      -- a later failure never erases a proven answer
	s.proof[api] = state
end

-- ---------------------------------------------------------------- ATT matching

local function town(name)
	if type(name) ~= "string" then return nil end
	local first = name:match("^([^,]+)") or name
	first = first:lower():gsub("%s+city$", ""):gsub("^%s+", ""):gsub("%s+$", "")
	return first ~= "" and first or nil
end
T._town = town

--- The ATT flight node (Registry.FlightNodes entry) a client node corresponds to: attNode, method ("id" | "name") or nil.
function T.MatchAtt(node, faction)
	local R = ns.Registry
	if not (R and R.FlightNodes) then return nil end
	local nodes = R.FlightNodes()
	local t = town(node.name)
	if type(node.id) == "number" then
		for _, n in ipairs(nodes) do
			if n.id == node.id then
				local tn = town(n.name)
				if not t or not tn or t == tn then return n, "id" end
			end
		end
	end
	if t then
		local best
		for _, n in ipairs(nodes) do
			if town(n.name) == t then
				if n.faction == nil or faction == nil or n.faction == faction then
					if not best or (best.faction == nil and n.faction ~= nil) then best = n end
				end
			end
		end
		if best then return best, "name" end
	end
	return nil
end

-- ---------------------------------------------------------------- recording

local function keyOf(n)
	if type(n.id) == "number" then return "id:" .. n.id end
	local nm = type(n.name) == "string" and n.name:lower() or nil
	return nm and ("name:" .. nm) or nil
end
T.KeyOf = keyOf

local function stateRank(state)
	if state == "CURRENT" or state == "REACHABLE" then return "YES" end
	if state == "UNREACHABLE" or state == "DISTANT" then return "LISTED" end
	return nil
end

--- Normalises a client state (string or the modern enum number) to CURRENT / REACHABLE / UNREACHABLE / NONE, or nil.
local function normState(v)
	if type(v) == "string" then
		local u = v:upper()
		if u == "CURRENT" or u == "REACHABLE" or u == "NONE" then return u end
		if u == "DISTANT" or u == "UNREACHABLE" then return "UNREACHABLE" end
		return nil
	end
	local e = _G.Enum and _G.Enum.FlightPathState
	if type(v) == "number" and type(e) == "table" then
		if v == e.Current then return "CURRENT" end
		if v == e.Reachable then return "REACHABLE" end
		if v == e.Unreachable then return "UNREACHABLE" end
	end
	return nil
end
T._normState = normState

local function trim(tbl, max, stamp)
	local n = 0
	for _ in pairs(tbl) do n = n + 1 end
	while n > max do
		local oldK, oldT
		for k, v in pairs(tbl) do
			local t = type(v) == "table" and (v[stamp] or 0) or 0
			if oldT == nil or t < oldT then oldK, oldT = k, t end
		end
		if oldK == nil then break end
		tbl[oldK] = nil
		n = n - 1
	end
end

--- Records one taxi-map reading. `list` = array of { id, name, state, cost, map, x, y } (state as the client gave it); `faction` for ATT matching.
-- The node whose state is CURRENT is where the character stands: every REACHABLE node becomes a direct-offer edge from it.
-- Returns the number of nodes stored, the current node key (or nil).
function T.Ingest(list, faction)
	local s = store()
	if not s or type(list) ~= "table" then return 0, nil end
	local t = wall()
	local stored, curKey, reachTo = 0, nil, {}
	for _, raw in ipairs(list) do
		local st = normState(raw.state)
		local key = keyOf(raw)
		if key and st then
			local n = s.nodes[key]
			if type(n) ~= "table" then n = { first = t } s.nodes[key] = n end
			n.id = type(raw.id) == "number" and raw.id or n.id
			n.name = text(raw.name, 60) or n.name
			if type(raw.x) == "number" and type(raw.y) == "number" and type(raw.map) == "number" then n.map, n.x, n.y = raw.map, raw.x, raw.y end
			n.state, n.seen = st, t
			local rank = stateRank(st)
			if rank == "YES" or (rank == "LISTED" and n.disc ~= "YES") then n.disc = rank end
			local c = num(raw.cost)
			if c then n.cost = c end
			local att, how = T.MatchAtt(n, faction)
			if att then n.att, n.attHow = att.id, how end
			stored = stored + 1
			if st == "CURRENT" then curKey = key
			elseif st == "REACHABLE" then reachTo[key] = num(raw.cost) or true end
		end
	end
	if curKey then
		s.reach[curKey] = { to = reachTo, t = t }
	end
	trim(s.nodes, T.MAX_NODES, "seen")
	if stored > 0 then version = version + 1 end
	return stored, curKey
end

-- ---------------------------------------------------------------- reading the client

local function posOf(p)
	if type(p) ~= "table" then return nil end
	local x, y
	if type(p.GetXY) == "function" then
		local ok, a, b = pcall(p.GetXY, p)
		if ok then x, y = a, b end
	end
	x, y = x or p.x, y or p.y
	x, y = num(x), num(y)
	if x and y and (x ~= 0 or y ~= 0) then return x, y end
	return nil
end

local function callProbe(name, ...)
	local f = T.Resolve(name)
	if not f then proof(name, "ABSENT") return nil, false end
	local ok, r = pcall(f, ...)
	if not ok then proof(name, "FAILED") return nil, false end
	return r, true
end

local function mapChain()
	local out = {}
	local m = callProbe("C_Map.GetBestMapForUnit", "player")
	m = num(m)
	local guard = 0
	while m and m > 0 and guard < 5 do
		out[#out + 1] = m
		local info = callProbe("C_Map.GetMapInfo", m)
		m = type(info) == "table" and num(info.parentMapID) or nil
		guard = guard + 1
	end
	return out
end

--- Reads the open taxi map: the modern API over the player's map and its parents, then the classic API. Returns the normalised list ({ id, name, state, cost, map, x, y })
-- and which families answered { modern = bool, classic = bool }.
function T.Read()
	local list, seen, got = {}, {}, { modern = false, classic = false }
	for _, fname in ipairs({ "C_TaxiMap.GetAllTaxiNodes", "C_TaxiMap.GetTaxiNodesForMap" }) do
		if T.Resolve(fname) and not got.modern then
			for _, map in ipairs(mapChain()) do
				local nodes, ok = callProbe(fname, map)
				if ok and type(nodes) == "table" then
					local any = false
					for _, n in ipairs(nodes) do
						if type(n) == "table" then
							local id = num(n.nodeID)
							local nm = text(n.name)
							local x, y = posOf(n.position)
							local item = { id = id, name = nm, state = n.state, cost = n.cost or n.money, map = x and map or nil, x = x, y = y, slot = num(n.slotIndex) }
							local k = keyOf(item)
							if k and not seen[k] then seen[k] = true list[#list + 1] = item any = true end
						end
					end
					if any then got.modern = true proof(fname, "PROVEN") break end
					proof(fname, "UNPROVEN")
				end
			end
		end
	end
	if got.modern then
		-- the index TakeTaxiNode will be called with: the node's slot when the API gives one (0.12.0 report: a real flight was lost because only the classic read filled this)
		lastIndex = {}
		for _, item in ipairs(list) do if item.slot then lastIndex[item.slot] = keyOf(item) end end
	end
	if T.Resolve("NumTaxiNodes") and not got.modern then
		local cnt, ok = callProbe("NumTaxiNodes")
		cnt = ok and num(cnt) or nil
		lastIndex = {}
		if cnt and cnt > 0 then
			for i = 1, math.min(cnt, 200) do
				local nm = text(select(1, (callProbe("TaxiNodeName", i))))
				local ty = callProbe("TaxiNodeGetType", i)
				local cost = callProbe("TaxiNodeCost", i)
				local item = { name = nm, state = ty, cost = cost }
				local k = keyOf(item)
				if k and normState(ty) and not seen[k] then
					seen[k] = true list[#list + 1] = item
					lastIndex[i] = k
					got.classic = true
				end
			end
			proof("NumTaxiNodes", got.classic and "PROVEN" or "UNPROVEN")
		else
			proof("NumTaxiNodes", "UNPROVEN")
		end
	end
	return list, got
end

--- The open taxi map has been read and stored. Safe to call at any time (does nothing when the client has no taxi API).
function T.OnMapOpened()
	session.opens = session.opens + 1
	bump("opened")
	local list, got = T.Read()
	session.reads = session.reads + 1
	session.last = { n = #list, modern = got.modern, classic = got.classic }
	local faction = type(UnitFactionGroup) == "function" and select(2, pcall(UnitFactionGroup, "player")) or nil
	local n, cur = T.Ingest(list, type(faction) == "string" and faction or nil)
	session.last.stored, session.last.current = n, cur
	if cur then pending = pending or nil end
	if n == 0 then bump("emptyRead") end
	-- the node the character is standing at, kept for a flight about to be taken
	session.standing = cur
	return n, cur
end

-- ---------------------------------------------------------------- flight lifecycle
--
-- One flight is a small state machine, and each state is separate evidence:
--   OFFERED    a taxi map offered B from A (Taxi.Ingest: s.reach). Not a flight.
--   SELECTED   TakeTaxiNode(index) was called and the index resolved to a known destination; the ORIGIN is the node the map was opened at.
--   STARTED    the client says the player is on the taxi: PLAYER_CONTROL_LOST right after the selection, or UnitOnTaxi("player") true.
--   COMPLETED  the flight ended (PLAYER_CONTROL_GAINED, or UnitOnTaxi false after it had started) AND, when both places can be measured, the player is near the destination.
--   ABORTED    never started within START_TIMEOUT, ended away from the destination, ran past MAX_FLIGHT_SECS, or the destination was never resolved: counted, never an edge.
-- Only COMPLETED writes s.flights[from>to] = { secs (the measured mean), n, last, min, max, src = "client observation", verified = true }. A duration is the time between STARTED and
-- the end; it is never taken from the selection time, an estimate or another flight. Nothing is written for an aborted or unresolved flight.
T.START_TIMEOUT = 12            -- seconds after the selection within which the flight must start
T.ARRIVAL_YD = 500              -- how close to the destination the player must be when the flight ends (when both can be measured)
T.POLL_SECONDS = 0.5

local function lastFlight(t) session.lastFlight = t return t end

--- Resolves the index TakeTaxiNode was called with to a node key: the slot of the last read, then a node id, else nil (with how it was tried).
function T.ResolveIndex(index)
	if lastIndex[index] then return lastIndex[index], "slot" end
	local s = store()
	if s and type(index) == "number" and s.nodes["id:" .. index] then return "id:" .. index, "node id" end
	return nil, "unresolved"
end

--- A flight is being selected. `toKey` is only for tests; the hook passes the index.
function T.OnTake(index, toKey)
	bump("taken")
	local to, how = toKey, "given"
	if not to then to, how = T.ResolveIndex(index) end
	local from = session.standing
	if not (from and to) then
		bump("takeUnresolved")
		pending = nil
		local slots = {}
		for k in pairs(lastIndex) do slots[#slots + 1] = tostring(k) end
		table.sort(slots)
		lastFlight({ state = "UNRESOLVED", why = (from and "destination" or "origin") .. " not known (index " .. tostring(index) .. ", slots seen: " .. (#slots > 0 and table.concat(slots, ",") or "none") .. ")" })
		return false
	end
	pending = { from = from, to = to, t0 = now(), state = "SELECTED", how = how }
	lastFlight({ state = "SELECTED", from = from, to = to, how = how })
	return true
end

local function abort(why)
	if pending then bump("aborted") lastFlight({ state = "ABORTED", from = pending.from, to = pending.to, why = why, started = pending.startedAt ~= nil }) end
	pending = nil
end

local function start()
	if pending and pending.state == "SELECTED" and now() - pending.t0 <= T.START_TIMEOUT then
		pending.state, pending.startedAt = "STARTED", now()
		bump("started")
		session.lastFlight = { state = "STARTED", from = pending.from, to = pending.to, how = pending.how }
		return true
	end
	return false
end

function T.OnControlLost() return start() end

local function nodePoint(key)
	local pts = ns.Travel and ns.Travel._nodePoints and ns.Travel._nodePoints() or nil
	return pts and pts[key] and pts[key].point or nil
end

--- Is the player near `key`'s place? true / false, or nil when either cannot be measured.
local function nearNode(key)
	local ctx = ns.State and ns.State.ctx
	local pt = nodePoint(key)
	if not (ctx and ns.Context and ns.Engine and pt) then return nil end
	local ok, loc = pcall(ns.Context.Position)
	if not (ok and type(loc) == "table" and loc.available and loc.map) then return nil end
	local d = ns.Engine.Distance(ctx, { map = loc.map, x = loc.x, y = loc.y }, pt)
	if d == nil or d == ns.Engine.DIFFERENT_CONTINENT then return nil end
	return d <= T.ARRIVAL_YD, d
end

--- The flight ended. Writes the edge only for a flight that was selected, started and (when measurable) arrived.
function T.OnControlGained() return T.Finish() end

function T.Finish()
	local p = pending
	if not p then return nil end
	if p.state ~= "STARTED" then
		-- control returned without the flight ever having started: nothing flew
		if now() - p.t0 > T.START_TIMEOUT then abort("never started") end
		return nil
	end
	local secs = now() - p.startedAt
	if secs < T.MIN_FLIGHT_SECS or secs > T.MAX_FLIGHT_SECS then abort("implausible duration " .. math.floor(secs) .. " s") bump("flightRejected") return nil end
	local near, d = nearNode(p.to)
	if near == false then abort("ended " .. math.floor(d) .. " yd from the destination") bump("endedAway") return nil end
	local s = store()
	if not s then pending = nil return nil end
	local k = p.from .. ">" .. p.to
	local f = s.flights[k]
	if type(f) ~= "table" then f = { n = 0, secs = secs, min = secs, max = secs } s.flights[k] = f end
	f.secs = f.n == 0 and secs or (f.secs * f.n + secs) / (f.n + 1)
	f.n = f.n + 1
	f.last, f.min, f.max = secs, math.min(f.min or secs, secs), math.max(f.max or secs, secs)
	f.src, f.verified, f.t = "client observation", true, wall()
	f.arrival = near == true and "CHECKED" or "UNCHECKED"
	-- both ends of a flight that was actually taken are paths this character has
	for _, key in ipairs({ p.from, p.to }) do
		local n = s.nodes[key]
		if type(n) == "table" then n.disc = "YES" end
	end
	trim(s.flights, T.MAX_FLIGHTS, "t")
	bump("completed")
	version = version + 1
	pending = nil
	lastFlight({ state = "COMPLETED", from = k:match("^(.-)>"), to = p.to, secs = secs, arrival = f.arrival, how = p.how })
	return secs
end

--- Called every frame by the frame below, and by tests. Polls UnitOnTaxi while a flight is pending (the events alone may not fire on every client).
function T.Tick(elapsed)
	if not pending then return end
	pending.acc = (pending.acc or 0) + (elapsed or 0)
	if pending.acc < T.POLL_SECONDS then return end
	pending.acc = 0
	local f = T.Resolve("UnitOnTaxi")
	local on
	if f then
		local ok, v = pcall(f, "player")
		if ok and type(v) == "boolean" then on = v proof("UnitOnTaxi", "PROVEN") elseif ok then proof("UnitOnTaxi", "UNPROVEN") else proof("UnitOnTaxi", "FAILED") end
	end
	if pending.state == "SELECTED" then
		if on == true then start()
		elseif now() - pending.t0 > T.START_TIMEOUT then abort("never started") end
	elseif pending.state == "STARTED" then
		if on == false and now() - pending.startedAt >= T.MIN_FLIGHT_SECS then T.Finish()
		elseif now() - pending.startedAt > T.MAX_FLIGHT_SECS then abort("ran past the longest plausible flight") end
	end
end

function T.Pending() return pending end

function T.InstallHook()
	if T._hooked or type(hooksecurefunc) ~= "function" or type(_G.TakeTaxiNode) ~= "function" then return false end
	T._hooked = pcall(hooksecurefunc, "TakeTaxiNode", function(index) pcall(T.OnTake, index) end)
	return T._hooked and true or false
end

-- ---------------------------------------------------------------- queries

--- Every stored node: array of { key, id, name, map, x, y, disc, att, state, cost }.
function T.Nodes()
	local s = store()
	local out = {}
	if not s then return out end
	for k, n in pairs(s.nodes) do
		out[#out + 1] = { key = k, id = n.id, name = n.name, map = n.map, x = n.x, y = n.y, disc = n.disc, att = n.att, attHow = n.attHow, state = n.state, cost = n.cost }
	end
	table.sort(out, function(a, b) return a.key < b.key end)
	return out
end

--- The character's evidence for an ATT flight node: "YES" (a taxi map offered it), "LISTED", or "UNKNOWN". NEVER "NO": absence is not evidence.
function T.AttDiscovery(attId)
	local s = store()
	if not s then return "UNKNOWN" end
	local best = "UNKNOWN"
	for _, n in pairs(s.nodes) do
		if n.att == attId then
			if n.disc == "YES" then return "YES" end
			if n.disc == "LISTED" then best = "LISTED" end
		end
	end
	return best
end

--- Flight edges, offered and taken, as one list: { from, to, cost, secs, measured, offered, taken, state, src, verified }.
--   state "COMPLETED"  a real flight from -> to was selected, started and ended (secs is its measured mean; src "client observation", verified true)
--   state "OFFERED"    a taxi map offered `to` while the player stood at `from` and no flight of it has completed (secs nil: there is nothing to measure)
-- An offer is never a completed flight, and a completed flight needs no offer on record (it happened).
function T.Edges()
	local s = store()
	local out, seen = {}, {}
	if not s then return out end
	for from, r in pairs(s.reach) do
		for to, c in pairs(r.to or {}) do
			local f = s.flights[from .. ">" .. to]
			local done = type(f) == "table" and (f.n or 0) > 0
			out[#out + 1] = { from = from, to = to, cost = type(c) == "number" and c or nil, secs = done and f.secs or nil, measured = done, offered = true, taken = done,
				state = done and "COMPLETED" or "OFFERED", src = done and f.src or "taxi map", verified = done and f.verified == true or false }
			seen[from .. ">" .. to] = true
		end
	end
	for k, f in pairs(s.flights) do
		if not seen[k] and type(f) == "table" and (f.n or 0) > 0 then
			local from, to = k:match("^(.-)>(.+)$")
			out[#out + 1] = { from = from, to = to, secs = f.secs, measured = true, offered = false, taken = true, state = "COMPLETED", src = f.src, verified = f.verified == true }
		end
	end
	table.sort(out, function(a, b) if a.from ~= b.from then return a.from < b.from end return a.to < b.to end)
	return out
end

--- Summary for the report and the knowledge page.
function T.Summary()
	local s = store()
	local out = { nodes = 0, discovered = 0, listed = 0, matched = 0, standings = 0, edges = 0, offered = 0, measured = 0, taken = 0, started = 0, completed = 0, aborted = 0, unresolved = 0, opens = session.opens, proof = {}, stats = {} }
	if not s then return out end
	for _, n in pairs(s.nodes) do
		out.nodes = out.nodes + 1
		if n.disc == "YES" then out.discovered = out.discovered + 1 elseif n.disc == "LISTED" then out.listed = out.listed + 1 end
		if n.att then out.matched = out.matched + 1 end
	end
	for _ in pairs(s.reach) do out.standings = out.standings + 1 end
	for _, e in ipairs(T.Edges()) do
		out.edges = out.edges + 1
		if e.offered then out.offered = out.offered + 1 end
		if e.measured then out.measured = out.measured + 1 end
	end
	out.taken, out.started, out.completed, out.aborted = s.stats.taken or 0, s.stats.started or 0, s.stats.completed or 0, s.stats.aborted or 0
	out.unresolved = s.stats.takeUnresolved or 0
	out.lastFlight = session.lastFlight
	out.proof, out.stats, out.last = s.proof, s.stats, session.last
	return out
end

function T.ReportLines()
	local sm = T.Summary()
	local L = {}
	L[#L + 1] = string.format("Taxi evidence (this character): %d nodes seen on a taxi map (%d discovered=YES, %d listed only), %d matched to ATT, %d standing points; map opened %d time(s) this session.",
		sm.nodes, sm.discovered, sm.listed, sm.matched, sm.standings, sm.opens)
	L[#L + 1] = string.format("Flight evidence, one state at a time: direct flights OFFERED %d | flights SELECTED (TakeTaxiNode) %d, of which unresolved %d | STARTED %d | COMPLETED %d | ABORTED %d | edges with a MEASURED duration %d.",
		sm.offered, sm.taken, sm.unresolved, sm.started, sm.completed, sm.aborted, sm.measured)
	local lf = sm.lastFlight
	if lf then
		L[#L + 1] = string.format("Last flight: %s%s%s%s.", lf.state, lf.from and (" " .. lf.from .. " -> " .. tostring(lf.to)) or "", lf.secs and string.format(", %.0f s (arrival %s)", lf.secs, lf.arrival or "?") or "",
			lf.why and (" (" .. lf.why .. ")") or (lf.how and (" (destination resolved by " .. lf.how .. ")") or ""))
	else
		L[#L + 1] = "Last flight: none seen this session."
	end
	local parts = {}
	for _, api in ipairs(T.APIS) do
		local present = T.Resolve(api) ~= nil
		parts[#parts + 1] = api .. "=" .. (sm.proof[api] or (present and "present, not yet called" or "ABSENT"))
	end
	L[#L + 1] = "Taxi API status: " .. table.concat(parts, ", ")
	if sm.last then
		L[#L + 1] = string.format("Last taxi read: %d node(s) listed (modern API=%s, classic API=%s), %d stored, standing at %s.", sm.last.n or 0, tostring(sm.last.modern), tostring(sm.last.classic), sm.last.stored or 0, tostring(sm.last.current or "unknown"))
	else
		L[#L + 1] = "Last taxi read: none yet (open a flight master's map once to record it)."
	end
	return L
end

function T.EventNames() return T.EVENTS end

function T._Reset() pending, lastIndex, session, version = nil, {}, { opens = 0, reads = 0 }, 0 end
function T._SetStanding(key) session.standing = key end

-- ---------------------------------------------------------------- events

local frame = CreateFrame("Frame")
for _, ev in ipairs(T.EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
frame:SetScript("OnEvent", function(_, event)
	local ok, err = pcall(function()
		if event == "TAXIMAP_OPENED" then T.OnMapOpened()
		elseif event == "PLAYER_CONTROL_LOST" then T.OnControlLost()
		elseif event == "PLAYER_CONTROL_GAINED" then T.OnControlGained()
		end
	end)
	if not ok and ns.RecordError then ns.RecordError("taxi " .. tostring(event), err) end
end)
frame:SetScript("OnUpdate", function(_, elapsed) if pending then pcall(T.Tick, elapsed) end end)
T.frame = frame
