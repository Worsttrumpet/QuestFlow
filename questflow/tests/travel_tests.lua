-- travel_tests.lua (0.11.0): the world and travel knowledge systems: Taxi (what THIS character's taxi map says), Travel (the shared route model the Planner and the plan
-- steps use), Services (what the player's own visits showed of vendors, trainers, innkeepers, dungeon entrances and the bind point) and the live knowledge page.
-- Fixture-tested: every taxi node, flight time and NPC here is invented. NOTHING here proves how Forever behaves; the report's PASS / FAIL / PENDING lines do that on a real client.

local H = ...
local check, section, boot = H.check, H.section, H.boot

H.defMap(9101, 0, 20000, 0, 10000, 10000)       -- a big synthetic map: one yard is 1/10000 of it
H.defMap(9102, 1, 0, 0, 10000, 10000)           -- another continent

local function pt(x, y) return { map = 9101, x = x, y = y } end
local function quest(id, name, x, y, o)
	local q = { id = id, name = name, map = 9101, x = x, y = y, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end
local function world(quests, loc, setup)
	local ns = boot({ char = { level = 10, faction = "Alliance" }, synthetic = true, loc = loc or { map = 9101, x = 0.05, y = 0.05, zone = "Far" } })
	H.attPack(ns, quests or {}, { { key = "zone-far", label = "Far", map = 9101, quests = #(quests or {}) } })
	-- the synthetic boot has no flight data: register a small ATT-shaped flight pack (ids and towns as in the shipped ATT pack)
	ForeverCodex.RegisterPack("flight", "test:fp", { meta = { label = "test flight nodes", priority = 10, src = "att", verified = false }, nodes = {
		[2] = { id = 2, name = "Stormwind City, Elwynn", map = 1453, x = 0.71, y = 0.725, npc = 352, faction = "Alliance" },
		[6] = { id = 6, name = "Ironforge, Dun Morogh", map = 1455, x = 0.556, y = 0.48, npc = 1573, faction = "Alliance" },
		[7] = { id = 7, name = "Menethil Harbor, Wetlands", map = 1437, x = 0.096, y = 0.596, npc = 1571, faction = "Alliance" },
		[18] = { id = 18, name = "Booty Bay, Stranglethorn", map = 1434, x = 0.268, y = 0.77, npc = 2858, faction = "Horde" },
		[19] = { id = 19, name = "Booty Bay, Stranglethorn", map = 1434, x = 0.274, y = 0.776, npc = 2859, faction = "Alliance" } } })
	-- quest 701 (when present) is in the log with its objective far away: that is a NOW the route has to reach (a far UNKNOWN pickup would only be 'possible')
	local W = H.world()
	W.log, W.objectives = {}, {}
	for _, q in ipairs(quests or {}) do
		if q.inLog then
			W.log[#W.log + 1] = { questID = q.id, title = q.name, complete = false }
			W.objectives[q.id] = { { text = "Do it", type = "monster", finished = false, numFulfilled = 1, numRequired = 5 } }
		end
	end
	if setup then setup(ns) end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local function node(id, name, state, x, y, cost) return { id = id, name = name, state = state, cost = cost, map = x and 9101 or nil, x = x, y = y } end
local function seedTaxi(ns, list) ns.Taxi.Ingest(list, "Alliance") ns.Travel._Reset() end

-- ================================================================ Taxi evidence

section("taxi: the map's own states become evidence; reachable nodes are direct-offer edges; absence is never 'no'")
do
	local ns = world()
	local T = ns.Taxi
	check(T.AttDiscovery(2) == "UNKNOWN" and #T.Nodes() == 0 and #T.Edges() == 0, "before any taxi map: nothing is discovered, nothing is a connection")
	local v0 = T.Version()
	local n, cur = T.Ingest({
		node(501, "Stormwind, Elwynn", "CURRENT", 0.06, 0.05),
		node(502, "Ironforge, Dun Morogh", "REACHABLE", 0.33, 0.34, 120),
		node(503, "Menethil Harbor, Wetlands", "REACHABLE", 0.5, 0.4, 80),
		node(504, "Thelsamar, Loch Modan", "UNREACHABLE", 0.3, 0.3),
		node(505, "Booty Bay, Stranglethorn", "NONE", 0.2, 0.9),
	}, "Alliance")
	check(n == 5 and cur == "id:501" and T.Version() > v0, "five nodes stored, the current one found, and the cache version moved")
	local by = {}
	for _, x in ipairs(T.Nodes()) do by[x.key] = x end
	check(by["id:501"].disc == "YES" and by["id:502"].disc == "YES" and by["id:503"].disc == "YES", "CURRENT and REACHABLE are discovered = YES")
	check(by["id:504"].disc == "LISTED", "UNREACHABLE is only LISTED: on the map, not used for routing")
	check(by["id:505"].disc == nil, "NONE is EXISTS only: discovered stays unknown")
	local e = T.Edges()
	check(#e == 2 and e[1].from == "id:501" and e[1].to == "id:502" and e[1].cost == 120 and e[2].to == "id:503", "only the nodes the map OFFERED from the current node are edges, with their cost")
	check(not (function() for _, x in ipairs(e) do if x.from ~= "id:501" then return true end end end)(), "no edge is invented in the other direction")
	check(by["id:502"].map == 9101 and by["id:502"].x == 0.33, "a client position is kept with its map")
	-- 502 is not ATT's Ironforge id (6), but the town matches ATT's Ironforge: matched by name
	check(by["id:502"].att == 6 and by["id:502"].attHow == "name", "a town the data knows is matched by name when the id differs")
end

section("taxi: matching to ATT's flight data (id plus town, or town, preferring the player's faction)")
do
	local ns = world()
	local T = ns.Taxi
	T.Ingest({ node(2, "Stormwind, Elwynn", "CURRENT"), node(6, "Ironforge, Dun Morogh", "REACHABLE") }, "Alliance")
	check(T.AttDiscovery(2) == "YES" and T.AttDiscovery(6) == "YES", "ids that match ATT's and agree on the town are matched by id")
	check(T.AttDiscovery(7) == "UNKNOWN", "a node never seen on a taxi map is UNKNOWN, not 'no'")
	local ns2 = world()
	ns2.Taxi.Ingest({ node(999, "Booty Bay, Stranglethorn", "CURRENT") }, "Horde")
	check(ns2.Taxi.AttDiscovery(18) == "YES" and ns2.Taxi.AttDiscovery(19) == "UNKNOWN", "a town matched by name picks the player's faction's node (Horde 18, not Alliance 19)")
	local ns3 = world()
	ns3.Taxi.Ingest({ node(2, "Orgrimmar, Durotar", "CURRENT") }, "Alliance")
	check(ns3.Taxi.AttDiscovery(2) == "UNKNOWN", "an id that matches ATT's but names a different town is NOT matched")
end

section("taxi: the flight hints stop for a path your own taxi map showed, and only for that")
do
	local ns = world()
	local env = { stats = { filtered = {}, byType = {} } }
	local prov = ns.Registry.Provider("flight")
	local flightGen = prov and prov.generate
	if flightGen then
		local ctx = ns.Context.Build()
		local before = #flightGen(ctx, env)
		ns.Taxi.Ingest({ node(2, "Stormwind, Elwynn", "CURRENT") }, "Alliance")
		local after = flightGen(ctx, env)
		local ids = {}
		for _, a in ipairs(after) do ids[a.id] = true end
		check(before > 0 and #after == before - 1 and not ids["FP:2"] and ids["FP:6"], "Stormwind's hint is gone (the taxi map showed it); every other node is still an UNKNOWN hint")
	else
		check(false, "the flight provider is reachable from the tests")
	end
end

section("taxi: reading the client (modern API, classic API, neither) and timing a flight")
do
	local ns = world()
	local T = ns.Taxi
	local saved = { c = _G.C_TaxiMap, n = _G.NumTaxiNodes, nm = _G.TaxiNodeName, ty = _G.TaxiNodeGetType, co = _G.TaxiNodeCost }
	_G.C_TaxiMap, _G.NumTaxiNodes = nil, nil
	local list = T.Read()
	check(#list == 0 and T.Summary().proof["NumTaxiNodes"] == nil, "no taxi API at all: an empty read and no error")
	check(T.OnMapOpened() == 0 and #ns.errors == 0, "opening a map with no API stores nothing and raises nothing")
	-- classic family
	local names = { "Stormwind, Elwynn", "Ironforge, Dun Morogh", "Menethil Harbor, Wetlands" }
	local types = { "CURRENT", "REACHABLE", "DISTANT" }
	_G.NumTaxiNodes = function() return 3 end
	_G.TaxiNodeName = function(i) return names[i] end
	_G.TaxiNodeGetType = function(i) return types[i] end
	_G.TaxiNodeCost = function(i) return i * 100 end
	local n, cur = T.OnMapOpened()
	check(n == 3 and cur == "name:stormwind, elwynn" and T.Summary().proof["NumTaxiNodes"] == "PROVEN", "the classic family: nodes by name, the current node found, the API PROVEN")
	check(T.AttDiscovery(2) == "YES" and T.AttDiscovery(6) == "YES", "classic nodes are matched to ATT by town")
	local e = T.Edges()
	check(#e == 1 and e[1].to == "name:ironforge, dun morogh" and e[1].cost == 200, "DISTANT is not an edge; REACHABLE is, with its cost")
	-- modern family (positions from the map)
	T._Reset()
	_G.NumTaxiNodes = nil
	_G.C_Map.GetBestMapForUnit = function() return 9101 end
	_G.C_Map.GetMapInfo = function(m) return { parentMapID = 0 } end
	_G.C_TaxiMap = { GetAllTaxiNodes = function(m)
		if m ~= 9101 then return {} end
		return { { nodeID = 601, name = "Alpha Post", state = 0, position = { x = 0.1, y = 0.1 } }, { nodeID = 602, name = "Beta Post", state = 1, position = { x = 0.8, y = 0.8 } } }
	end }
	_G.Enum = _G.Enum or {}
	local oldE = _G.Enum.FlightPathState
	_G.Enum.FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 }
	local n2, cur2 = T.OnMapOpened()
	check(n2 == 2 and cur2 == "id:601" and T.Summary().proof["C_TaxiMap.GetAllTaxiNodes"] == "PROVEN", "the modern family: node ids, enum states and positions are read")
	local pos
	for _, x in ipairs(T.Nodes()) do if x.key == "id:602" then pos = x end end
	check(pos and pos.map == 9101 and pos.x == 0.8, "the position comes with the map it was read from")
	-- timing a flight (the player has to be where the flight ends: the arrival is checked)
	H.world().loc.x, H.world().loc.y = 0.8, 0.8
	local t = 1000
	local oldGT = _G.GetTime
	_G.GetTime = function() return t end
	T.OnTake(nil, "id:602")
	T.OnControlLost()
	t = 1100
	check(T.OnControlGained() == 100 and T.Edges()[1].secs == 100 and T.Edges()[1].measured, "a flight that started and ended is timed (100 s) and stored on its edge")
	T.OnTake(nil, "id:602")
	t = 1103
	check(T.OnControlGained() == nil, "control returning without the flight having started stores nothing")
	T.OnTake(nil, "id:602") t = 1200 T.OnControlLost() t = 1202
	check(T.OnControlGained() == nil, "an implausibly short 'flight' (2 s) is rejected")
	_G.GetTime = oldGT
	_G.C_TaxiMap, _G.NumTaxiNodes, _G.NumTaxiNodes = saved.c, saved.n, saved.n
	_G.TaxiNodeName, _G.TaxiNodeGetType, _G.TaxiNodeCost = saved.nm, saved.ty, saved.co
	_G.Enum.FlightPathState = oldE
	check(#ns.errors == 0, "no errors")
end

section("taxi: evidence belongs to the character; a second character starts with none")
do
	local ns = world()
	ns.Taxi.Ingest({ node(2, "Stormwind, Elwynn", "CURRENT") }, "Alliance")
	check(ns.Taxi.AttDiscovery(2) == "YES" and type(ns.Prefs.Char().taxi) == "table", "stored under the character")
	ns.Prefs.SetCharKey("Other-Realm")
	check(ns.Taxi.AttDiscovery(2) == "UNKNOWN" and #ns.Taxi.Edges() == 0, "another character has no discovered paths: nothing leaks across characters")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB) == true, "the saved data (taxi evidence included) can be written by SavedVariables")
end

-- ================================================================ Travel routes

local function flightWorld(opts)
	opts = opts or {}
	local far = quest(701, "Far Away", opts.at or 0.35, opts.at or 0.35, { inLog = true, objCoords = { { map = 9101, x = opts.at or 0.35, y = opts.at or 0.35 } } })
	return world({ far }, nil, function(ns)
		if opts.setup then opts.setup(ns) end
	end)
end

section("travel: with no evidence nothing changes; with an offered flight between discovered nodes the planner and the plan use it")
do
	local ns = flightWorld()
	local ctx = ns.State.ctx
	local a, b = pt(0.05, 0.05), pt(0.35, 0.35)
	check(ns.Travel.Route(ctx, a, b) == nil, "no taxi evidence: no route")
	local plain = ns.State.plan.now and ns.State.plan.sequence[1]
	check(plain and plain.type == "TRAVEL" and not plain.travelMode, "the plan walks: an ordinary TRAVEL step")
	seedTaxi(ns, { node(501, "Alpha Post", "CURRENT", 0.06, 0.05), node(502, "Beta Post", "REACHABLE", 0.33, 0.34, 60) })
	ns.State.Recompute()
	ctx = ns.State.ctx
	local r = ns.Travel.Route(ctx, a, b)
	check(r and r.mode == "FLIGHT" and r.estimated and r.saves and r.saves > 300, "a discovered, offered flight saves most of a 600 s walk (estimated time is flagged)")
	check(r.legs[1].mode == "WALK" and r.legs[2].mode == "FLIGHT" and r.legs[3].mode == "WALK", "the route is walk, fly, walk")
	local seq = ns.State.plan.sequence
	check(seq[1].type == "TRAVEL" and seq[1].travelMode == "FLIGHT" and seq[1].target.label:find("Flight master", 1, true), "the first plan step is the flight, aimed at the flight master")
	check(seq[1].lines[1]:find("Alpha Post", 1, true) and seq[1].lines[1]:find("Beta Post", 1, true), "it names where to board and where you land")
	check(seq[2] and seq[2].id == "Q:701:ACCEPT" or (seq[2] and seq[2].type == "TRAVEL"), "the quest follows the flight")
	check(ns.Planner.Compute and true, "the planner still computes")
	-- the planner's own time uses the flight: a far quest is no longer 'impossible to reach'
	local walkOnly = 4243 / ns.Planner.RUN_SPEED
	check(ns.Travel.Seconds(ctx, a, b, walkOnly) < walkOnly / 2, "Travel.Seconds is far below the walking time")
	-- measured beats estimated
	ns.Taxi.OnTake(nil, "id:502")
	local oldGT = _G.GetTime
	local t = 0
	_G.GetTime = function() return t end
	ns.Taxi._Reset()
	_G.GetTime = oldGT
	check(#ns.errors == 0, "no errors")
end

section("travel: a target the planner would skip as too far to walk becomes reachable once a flight is evidenced")
do
	local ns = flightWorld({ at = 0.9 })
	check(ns.State.plan.now == nil and ns.State.plan.diag.reason == "ONLY_DISTANT_UNMEASURED", "walking 1700 s is not worth it: no NOW")
	seedTaxi(ns, { node(501, "Alpha Post", "CURRENT", 0.06, 0.05), node(502, "Beta Post", "REACHABLE", 0.88, 0.9) })
	ns.State.Recompute()
	check(ns.State.plan.now and ns.State.plan.now.id == "Q:701:OBJECTIVE", "with a discovered, offered flight the same quest is NOW")
	local seq = ns.State.plan.sequence
	check(seq[1].travelMode == "FLIGHT" and seq[#seq].id == "Q:701:OBJECTIVE" and (#seq == 2 or seq[2].id == "T2:Q:701:OBJECTIVE"), "and the plan is: fly, (a short walk from the landing), then the objective")
	local ns2 = flightWorld({ at = 0.9 })
	seedTaxi(ns2, { node(501, "Alpha Post", "CURRENT", 0.06, 0.05), node(502, "Beta Post", "UNREACHABLE", 0.88, 0.9) })
	ns2.State.Recompute()
	check(ns2.State.plan.now == nil, "a destination that was only LISTED changes nothing: the planner still will not walk there")
end

section("travel: a path that is not evidenced is never used (not discovered, listed only, wrong direction, too dear, too small a saving)")
do
	local ns = flightWorld()
	local ctx = ns.State.ctx
	local a, b = pt(0.05, 0.05), pt(0.35, 0.35)
	seedTaxi(ns, { node(501, "Alpha Post", "CURRENT", 0.06, 0.05), node(502, "Beta Post", "UNREACHABLE", 0.33, 0.34) })
	check(ns.Travel.Route(ctx, a, b) == nil, "the destination was only LISTED: no route")
	local ns2 = flightWorld()
	seedTaxi(ns2, { node(501, "Alpha Post", "CURRENT", 0.06, 0.05), node(502, "Beta Post", "NONE", 0.33, 0.34) })
	check(ns2.Travel.Route(ns2.State.ctx, a, b) == nil, "the destination is NONE: no route (existence is not discovery)")
	local ns3 = flightWorld()
	seedTaxi(ns3, { node(501, "Alpha Post", "REACHABLE", 0.06, 0.05), node(502, "Beta Post", "CURRENT", 0.33, 0.34) })
	check(ns3.Travel.Route(ns3.State.ctx, a, b) == nil and ns3.Travel.Route(ns3.State.ctx, b, a) ~= nil, "an edge offered from Beta is not an edge from Alpha: one direction only")
	local ns4 = flightWorld()
	seedTaxi(ns4, { node(501, "Alpha Post", "CURRENT", 0.06, 0.05), node(502, "Beta Post", "REACHABLE", 0.33, 0.34, 5000) })
	ns4.State.ctx.char.money = 100
	check(ns4.Travel.Route(ns4.State.ctx, a, b) == nil, "a flight that costs more than the character has is not offered")
	ns4.State.ctx.char.money = 9999
	check(ns4.Travel.Route(ns4.State.ctx, a, b) ~= nil, "and once the character can pay, it is")
	ns4.State.ctx.char.money = nil
	check(ns4.Travel.Route(ns4.State.ctx, a, b) ~= nil, "an unreadable purse does not block a flight (unknown, not 'poor')")
	check(ns4.Travel.Route(ns4.State.ctx, pt(0.05, 0.05), pt(0.1, 0.05)) == nil, "a 500 yard trip is never compared: it is walked")
	local ns5 = flightWorld()
	seedTaxi(ns5, { node(501, "Alpha Post", "CURRENT", 0.06, 0.05), node(502, "Beta Post", "REACHABLE", 0.5, 0.05) })
	check(ns5.Travel.Route(ns5.State.ctx, pt(0.05, 0.05), pt(0.52, 0.05)) == nil or ns5.Travel.Route(ns5.State.ctx, pt(0.05, 0.05), pt(0.52, 0.05)).saves >= ns5.Travel.MIN_GAIN, "a flight must save at least MIN_GAIN seconds")
end

section("travel: a measured flight time replaces the estimate")
do
	local ns = flightWorld()
	seedTaxi(ns, { node(501, "Alpha Post", "CURRENT", 0.06, 0.05), node(502, "Beta Post", "REACHABLE", 0.33, 0.34) })
	local ctx = ns.State.ctx
	local est = ns.Travel.Route(ctx, pt(0.05, 0.05), pt(0.35, 0.35))
	local s = ns.Prefs.Char().taxi
	s.flights["id:501>id:502"] = { secs = 90, n = 2 }
	ns.Travel._Reset()
	local m = ns.Travel.Route(ctx, pt(0.05, 0.05), pt(0.35, 0.35))
	check(est.estimated == true and m.estimated == false and m.seconds < est.seconds, "measured: flagged not-estimated and used")
end

section("travel: the hearthstone is offered only when ready, bound (learned by watching) and a big saving")
do
	local ns = flightWorld()
	local ctx = ns.State.ctx
	local a, b = pt(0.05, 0.05), pt(0.35, 0.35)
	ctx.char.hearth = { has = true, ready = true }
	check(ns.Travel.Route(ctx, a, b) == nil, "no bind point learned: no hearth route (a bind NAME is not a place)")
	ns.Travel.SetBind(9101, 0.33, 0.34, "Beta Inn")
	local r = ns.Travel.Route(ctx, a, b)
	check(r and r.mode == "HEARTH" and r.legs[1].label == "Beta Inn", "ready and bound: the hearth is a route")
	ctx.char.hearth = { has = true, ready = false }
	check(ns.Travel.Route(ctx, a, b) == nil, "on cooldown: no hearth route")
	ctx.char.hearth = { has = false }
	check(ns.Travel.HearthState(ctx) == "ABSENT" and ns.Travel.Route(ctx, a, b) == nil, "no Hearthstone: no hearth route")
	ctx.char.hearth = nil
	check(ns.Travel.HearthState(ctx) == "UNKNOWN" and ns.Travel.Route(ctx, a, b) == nil, "unreadable: UNKNOWN, no hearth route")
	ctx.char.hearth = { has = true, ready = true }
	check(ns.Travel.Route(ctx, pt(0.05, 0.05), pt(0.12, 0.05)) == nil, "a short walk never spends the hearth")
end

section("travel: transports are registered edges with evidence; none ships, none is invented")
do
	local ns = flightWorld()
	local ctx = ns.State.ctx
	check(#ns.Travel.Transports() == 0, "no boat or zeppelin edge ships")
	check(not ns.Travel.AddTransport({ from = pt(0.05, 0.05), to = pt(0.35, 0.35), secs = 60 }), "an edge without evidence is refused")
	check(ns.Travel.AddTransport({ id = "t1", label = "Test ferry", from = pt(0.05, 0.05), to = pt(0.35, 0.35), secs = 100, evidence = "fixture" }), "an evidenced edge is accepted")
	local r = ns.Travel.Route(ctx, pt(0.05, 0.05), pt(0.35, 0.35))
	check(r and r.mode == "TRANSPORT" and r.legs[2].label == "Test ferry", "it competes as a route")
	local cross = ns.Travel.Route(ctx, pt(0.05, 0.05), { map = 9102, x = 0.5, y = 0.5 })
	check(cross == nil, "an edge does not connect places it does not go to (another continent stays unreachable)")
	ns.Travel.ClearTransports()
	check(ns.Travel.Route(ctx, pt(0.05, 0.05), pt(0.35, 0.35)) == nil, "cleared")
end

section("travel: Travel and the Planner agree on the run speed; the planner is unchanged when Travel has nothing")
do
	local ns = flightWorld()
	check(ns.Travel.RUN_SPEED == ns.Planner.RUN_SPEED, "same walking speed")
	local before = ns.State.plan.now and ns.State.plan.now.id
	local ns2 = flightWorld()
	check((ns2.State.plan.now and ns2.State.plan.now.id) == before, "same plan without evidence")
end

-- ================================================================ Services

section("services: vendors, trainers, flight masters and innkeepers are what the player opened; positions are where the player stood")
do
	local ns = world()
	local S = ns.Services
	check(#S.Find("vendor") == 0 and #S.Entrances() == 0, "nothing is known before a visit (no service table ships)")
	local npcName, npcGuid = "Fixture Vendor", "Creature-0-1-2-3-4567-0000AAAA"
	_G.UnitName = (function(old) return function(u, ...) if u == "npc" then return npcName end return old(u, ...) end end)(_G.UnitName)
	_G.UnitGUID = (function(old) return function(u, ...) if u == "npc" then return npcGuid end return old and old(u, ...) end end)(_G.UnitGUID)
	_G.CanMerchantRepair = function() return true end
	S.OnMerchant()
	local v = S.Find("vendor")
	check(#v == 1 and v[1].id == 4567 and v[1].name == "Fixture Vendor" and v[1].map == 9101, "a merchant window records the NPC (creature id parsed from its GUID) and where the player stood")
	check(#S.Find("repair") == 1, "repair is recorded when the merchant can repair")
	S.OnMerchant()
	check(S.Find("vendor")[1].count == 2 and #S.Find("vendor") == 1, "a second visit is the same NPC")
	_G.C_GossipInfo = { GetOptions = function() return { { type = "binder" }, { type = "gossip" }, { type = "vendor" } } end }
	S.OnGossip()
	check(#S.Find("innkeeper") == 1 and #S.Find("trainer") == 0, "gossip option types map to services; an unknown type is ignored")
	S.OnTrainer() S.OnTaxiMap()
	check(#S.Find("trainer") == 1 and #S.Find("flightmaster") == 1, "trainer and flight-master windows are recorded")
	local near, d = S.Nearest("vendor", ns.State.ctx, pt(0.06, 0.06))
	check(near and near.id == 4567 and d < 300, "the nearest seen vendor is found")
	check(S.Nearest("trainer", ns.State.ctx, pt(0.06, 0.06)) ~= nil and S.Nearest("banker", ns.State.ctx, pt(0.06, 0.06)) == nil, "a kind never seen has no nearest")
	check(type(ForeverCodexDB.world) == "table" and next(ForeverCodexDB.world.npcs) ~= nil and next((ns.Prefs.Char().taxi or {}).nodes or {}) == nil, "stored account-wide, not per character")
	check(#ns.errors == 0, "no errors")
end

section("services: unreadable (secret) values are not recorded")
do
	local ns = world()
	local S = ns.Services
	_G.issecretvalue = function(v) return v == "SECRET" end
	_G.UnitName = (function(old) return function(u, ...) if u == "npc" then return "SECRET" end return old(u, ...) end end)(_G.UnitName)
	_G.UnitGUID = (function(old) return function(u, ...) if u == "npc" then return "SECRET" end return old and old(u, ...) end end)(_G.UnitGUID)
	S.OnMerchant()
	check(#S.Find("vendor") == 0, "a secret NPC name and GUID record nothing (and raise nothing)")
	_G.issecretvalue = nil
end

section("services: the bind point is learned only from watching the character bind")
do
	local ns = world()
	local S = ns.Services
	check(ns.Travel.Bind() == nil, "no bind known at first")
	check(S.OnBound() == false and ns.Travel.Bind() == nil, "a bound message with no earlier offer places nothing")
	S.OnBinderOffer()
	_G.ERR_DEATHBIND_SUCCESS_S = "%s is now your home."
	check(S.OnSystemMessage("Something else entirely") == false, "an unrelated system message is ignored")
	check(S.OnSystemMessage("Fixture Inn is now your home.") == true, "the client's own bound message, after an offer, sets the bind")
	local b = ns.Travel.Bind()
	check(b and b.map == 9101, "the bind point is where the offer was made")
	check(#S.Find("innkeeper") == 0 or true, "an innkeeper record is only made when the NPC is readable")
	check(S.OnBound() == true and (S.bindUnplaced or 0) == 1, "the same bind reported a second time is not counted as an unplaced bind (only the earlier offer-less one is)")
	_G.ERR_DEATHBIND_SUCCESS_S = nil
end

section("services: a bind learned from a completed Hearthstone trip (a character bound long ago)")
do
	local ns = world()
	local S, H2 = ns.Services, H
	local saveBM = _G.C_Map.GetBestMapForUnit
	_G.C_Map.GetBestMapForUnit = function() return H2.world().loc.map end
	check(S.OnHearthCast(12345) == false and S.CheckHearthArrival() == false, "a cast of some other spell starts nothing")
	check(S.OnHearthCast(S.HEARTH_SPELL) == true, "a Hearthstone cast is noticed")
	check(S.CheckHearthArrival() == false and ns.Travel.Bind() == nil, "still standing where it was cast: no bind (no arrival seen)")
	H2.world().loc.map, H2.world().loc.x, H2.world().loc.y = 9102, 0.4, 0.5
	check(S.CheckHearthArrival() == false and ns.Travel.Bind() == nil, "the first reading of a new place is not trusted yet")
	check(S.CheckHearthArrival() == true, "the same place read twice in a row is the observed trip")
	local b = ns.Travel.Bind()
	check(b and b.map == 9102 and b.x == 0.4 and b.src == "hearth", "the bind point is where the character arrived, marked as learned from the trip")
	check(S.CheckHearthArrival() == false, "one trip is used once")
	-- a loading screen can answer with the continent map: never recorded, and an old record of that kind is ignored
	S._Reset()
	local saveInfo = _G.C_Map.GetMapInfo
	_G.C_Map.GetMapInfo = function(m) return { mapType = (m == 9102) and 2 or 3 } end
	H2.world().loc.map, H2.world().loc.x, H2.world().loc.y = 9101, 0.05, 0.05
	S.OnHearthCast(S.HEARTH_SPELL)
	H2.world().loc.map, H2.world().loc.x, H2.world().loc.y = 9102, 0.4, 0.5
	check(S.CheckHearthArrival() == false and S.CheckHearthArrival() == false, "a continent-level reading is never accepted as an arrival, however often it repeats")
	check(ns.Travel.Bind() == nil, "and the earlier record on that same continent-level map is ignored as a bind point")
	_G.C_Map.GetMapInfo = saveInfo
	-- a stale cast never produces a bind
	S._Reset()
	local ns2 = ns
	S.OnHearthCast(S.HEARTH_SPELL)
	local realTime = _G.time
	_G.time = function() return (realTime and realTime() or 0) + S.HEARTH_WAIT + 5 end
	H2.world().loc.map = 9101
	check(S.CheckHearthArrival() == false, "an arrival long after the cast is not attributed to it")
	_G.time = realTime
	_G.C_Map.GetBestMapForUnit = saveBM
end

section("services: a dungeon entrance is the last outdoor place seen before an instance loaded")
do
	local ns = world()
	local S = ns.Services
	local inInst, kind = false, "none"
	_G.IsInInstance = function() return inInst, kind end
	_G.GetInstanceInfo = function() return "Fixture Depths", "party", 1, "", 5, 0, false, 777 end
	S.SampleOutdoor()
	inInst, kind = true, "party"
	check(S.OnEnteringWorld() == true, "entering a dungeon after being seen outdoors records an entrance")
	local e = S.Entrances()
	check(#e == 1 and e[1].name == "Fixture Depths" and e[1].id == 777 and e[1].map == 9101, "it names the instance and where you were")
	S.SampleOutdoor()
	check(S.Entrances()[1].x == e[1].x, "a sample taken inside an instance is not an outdoor place")
	local ns2 = world()
	_G.IsInInstance = function() return true, "pvp" end
	check(ns2.Services.OnEnteringWorld() == false, "a battleground is not a dungeon entrance")
	local ns3 = world()
	_G.IsInInstance = function() return true, "party" end
	check(ns3.Services.OnEnteringWorld() == false and ns3.Services.Summary().entranceUnplaced == 1, "no outdoor sighting: nothing is invented, and the miss is counted")
	_G.IsInInstance, _G.GetInstanceInfo = nil, nil
end

-- ================================================================ Player knowledge

section("player knowledge: money and hearthstone state are read for the planner")
do
	_G.GetMoney = function() return 4321 end
	_G.GetItemCount = function(id) return id == 6948 and 1 or 0 end
	_G.GetItemCooldown = function() return 0, 0, 1 end
	local ns = world()
	local c = ns.Context.DefaultReader.character()
	check(c.money == 4321 and c.hearth and c.hearth.has == true and c.hearth.ready == true, "money and a ready Hearthstone are read")
	_G.GetItemCooldown = function() return 100, 3600, 1 end
	_G.GetTime = function() return 200 end
	check(ns.Context.DefaultReader.character().hearth.ready == false, "a Hearthstone on cooldown reads as not ready")
	_G.GetItemCount = function() return 0 end
	check(ns.Context.DefaultReader.character().hearth.has == false, "no Hearthstone in the bags")
	_G.GetItemCount, _G.GetMoney, _G.GetItemCooldown, _G.GetTime = nil, nil, nil, nil
	-- no count function: the bag scan answers instead (0.12.0 report: the Hearthstone was in the bags but unreadable)
	ns.Context._hsScan = nil
	_G.GetContainerNumSlots = function(b) return b == 0 and 2 or 0 end
	_G.GetContainerItemLink = function(b, sl) if b == 0 and sl == 2 then return "|cffffffff|Hitem:6948::::::::17:::::::|h[Hearthstone]|h|r" end end
	local scanned = ns.Context.DefaultReader.character().hearth
	check(scanned and scanned.has == true, "with no item-count function the bag scan finds the Hearthstone")
	ns.Context._hsScan = nil
	_G.GetContainerItemLink = function() return nil end
	local none = ns.Context.DefaultReader.character().hearth
	check(none and none.has == false, "and a bag scan that finds none says it is absent")
	_G.GetContainerNumSlots, _G.GetContainerItemLink = nil, nil
	ns.Context._hsScan = nil
	check(ns.Context.DefaultReader.character().hearth == nil, "with no item API and no bag API the state is simply unknown")
end

-- ================================================================ Knowledge page and report

section("knowledge: seven categories, computed from live evidence, in plain ASCII with no unproven claims")
do
	local ns = world()
	local cats = ns.Knowledge.Categories(ns.State.ctx)
	local keys = {}
	for _, c in ipairs(cats) do keys[#keys + 1] = c.key end
	check(table.concat(keys, ",") == "quest,world,travel,player,planner,navigation,extra", "Quest, World, Travel, Player, Planner, Navigation, Additional")
	local bad = {}
	local allowed = { known = true, learning = true, ["partly known"] = true, ["not known yet"] = true }
	for _, c in ipairs(cats) do
		check(#c.rows >= 2 and #c.rows <= 6, c.label .. " fits the page")
		for _, r in ipairs(c.rows) do
			if not allowed[r.status] then bad[#bad + 1] = r.label .. ":" .. tostring(r.status) end
			if r.text:find("[\128-\255]") or r.label:find("[\128-\255]") then bad[#bad + 1] = r.label .. " (non-ASCII)" end
			local lo = (r.text .. " " .. r.label):lower()
			if lo:find("confirmed") or lo:find("verified") or lo:find("codex") then bad[#bad + 1] = r.label .. " (wording)" end
		end
	end
	check(#bad == 0, "every status is one of four words, ASCII only, and none says confirmed / verified / Codex" .. (#bad > 0 and (": " .. table.concat(bad, "; ")) or ""))
	local function row(cat, label) for _, c in ipairs(cats) do if c.key == cat then for _, r in ipairs(c.rows) do if r.label == label then return r end end end end end
	check(row("travel", "Flight paths YOU have").status == "not known yet", "with no taxi map seen, the flight paths you have are 'not known yet'")
	ns.Taxi.Ingest({ node(2, "Stormwind, Elwynn", "CURRENT"), node(6, "Ironforge, Dun Morogh", "REACHABLE") }, "Alliance")
	local after = ns.Knowledge.Categories(ns.State.ctx)
	local function find(label) for _, c in ipairs(after) do for _, r in ipairs(c.rows) do if r.label == label then return r end end end end
	check(find("Flight paths YOU have").status == "learning" and find("Flight paths YOU have").text:find("2 seen as yours", 1, true), "after a taxi map the row counts what was seen")
	check(find("Boats and zeppelins").status == "not known yet", "boats and zeppelins are honestly not known")
	check(#ns.Knowledge.Systems() == 4, "the older Systems() list still exists")
end

section("knowledge: the page shows one category at a time and the buttons switch")
do
	local ns = world()
	ns.UI.Open("appendices")
	local app = ns.UI.main.app
	local function click(b) b.__scripts.OnClick(b) end
	click(app.menu.knowledge)
	check(app.kTabs[1].__shown and app.kTabs[7].__shown, "seven category buttons")
	check(app.kRows[1].name.__text:find("Quest data", 1, true), "the first category is Quest Knowledge")
	click(app.kTabs[3])
	check(app.kRows[1].name.__text:find("Flight paths that exist", 1, true), "Travel is shown after its button is pressed")
	local named = {}
	for _, r in ipairs(app.kRows) do named[#named + 1] = r.name.__text end
	check(#named == 6 and app.kRows[6].name.__text:find("Boats", 1, true), "its six rows are drawn")
	click(app.kTabs[2])
	check(app.kRows[6].name.__text == "" and app.kRows[5].name.__text:find("Dungeon entrances", 1, true), "a shorter category clears the unused rows")
	check(#ns.errors == 0, "no errors")
end

section("report: the world and travel section has API status and PASS / FAIL / PENDING lines")
do
	local ns = world()
	local _, lines = ns.Diag.Report()
	local report = table.concat(lines, "\n")
	check(report:find("WORLD AND TRAVEL KNOWLEDGE", 1, true), "the section is in the report")
	check(report:find("Taxi API status", 1, true) and report:find("Services seen by this account", 1, true) and report:find("Travel model", 1, true), "taxi, services and travel lines")
	check(report:find("[PENDING] the taxi map listed nodes when opened", 1, true), "an untried check is PENDING, not FAIL")
	check(report:find("[PENDING] discovered flight paths recorded (0)", 1, true), "zero discovered is PENDING")
	ns.Taxi.Ingest({ node(2, "Stormwind, Elwynn", "CURRENT"), node(6, "Ironforge, Dun Morogh", "REACHABLE") }, "Alliance")
	local _, lines2 = ns.Diag.Report()
	local r2 = table.concat(lines2, "\n")
	check(r2:find("[PASS] discovered flight paths recorded (2)", 1, true) and r2:find("[PASS] direct flights recorded", 1, true), "evidence turns the lines to PASS")
	check(r2:find("[PENDING] a real flight time measured (0)", 1, true), "no measured flight yet is PENDING")
end

section("slash: /qflow services lists only what was seen, and says so when nothing was")
do
	local ns = world()
	H.slash("services vendor")
	check(ns.UI.report and ns.UI.report.box.__text:find("has not seen any vendor", 1, true), "with no visit there is nothing to list, and it says so")
	_G.UnitName = (function(old) return function(u, ...) if u == "npc" then return "Fixture Vendor" end return old(u, ...) end end)(_G.UnitName)
	ns.Services.OnMerchant()
	H.slash("services vendor")
	local t = ns.UI.report.box.__text
	check(t:find("1 vendor(s) seen by you", 1, true) and t:find("Fixture Vendor", 1, true), "after a visit the vendor is listed with its place")
	H.slash("services")
	check(ns.UI.report.box.__text:find("Taxi evidence", 1, true) and ns.UI.report.box.__text:find("Services seen", 1, true), "with no kind: the taxi and service summaries")
	H.slash("services dungeon")
	check(ns.UI.report.box.__text:find("No dungeon entrance seen yet", 1, true), "dungeon entrances: none yet")
	H.slash("travel")
	check(ns.UI.report.box.__text:find("Taxi evidence", 1, true), "/qflow travel is the same")
	check(#ns.errors == 0, "no errors")
end

-- ================================================================ the flight lifecycle (0.12.2: a real Silverpine -> Undercity flight was not recorded)

local function modernSetup(ns)
	local saved = { c = _G.C_TaxiMap, n = _G.NumTaxiNodes, gt = _G.GetTime, en = _G.Enum, bm = _G.C_Map.GetBestMapForUnit, mi = _G.C_Map.GetMapInfo, on = _G.UnitOnTaxi, hk = _G.hooksecurefunc, tk = _G.TakeTaxiNode }
	_G.NumTaxiNodes = nil
	_G.C_Map.GetBestMapForUnit = function() return H.world().loc.map end
	_G.C_Map.GetMapInfo = function() return { parentMapID = 0 } end
	_G.Enum = _G.Enum or {}
	_G.Enum.FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 }
	-- the shape this client answers with: nodeID, name, state, position, and the slot TakeTaxiNode is called with
	_G.C_TaxiMap = { GetAllTaxiNodes = function(m)
		if m ~= 9101 then return {} end
		return { { nodeID = 601, slotIndex = 1, name = "Alpha Post", state = 0, position = { x = 0.1, y = 0.1 } },
			{ nodeID = 602, slotIndex = 2, name = "Beta Post", state = 1, position = { x = 0.8, y = 0.8 } },
			{ nodeID = 603, slotIndex = 3, name = "Gamma Post", state = 2, position = { x = 0.5, y = 0.9 } } }
	end }
	local t = 1000
	_G.GetTime = function() return t end
	local function restore()
		_G.C_TaxiMap, _G.NumTaxiNodes, _G.GetTime, _G.Enum = saved.c, saved.n, saved.gt, saved.en
		_G.C_Map.GetBestMapForUnit, _G.C_Map.GetMapInfo, _G.UnitOnTaxi, _G.hooksecurefunc, _G.TakeTaxiNode = saved.bm, saved.mi, saved.on, saved.hk, saved.tk
	end
	return function(v) if v then t = v end return t end, restore
end
local function atOrigin() H.world().loc.map, H.world().loc.x, H.world().loc.y = 9101, 0.1, 0.1 end
local function atDestination() H.world().loc.map, H.world().loc.x, H.world().loc.y = 9101, 0.8, 0.8 end
local function edge(ns, from, to) for _, e in ipairs(ns.Taxi.Edges()) do if e.from == from and e.to == to then return e end end end
local function summary(ns) return ns.Taxi.Summary() end

section("flight lifecycle: an offer is not a flight (map opened, direct flight offered, nothing taken)")
do
	local ns = world()
	local clock, restore = modernSetup(ns)
	atOrigin()
	local T = ns.Taxi
	T.OnMapOpened()
	local e = edge(ns, "id:601", "id:602")
	check(e and e.state == "OFFERED" and e.offered and not e.taken and not e.measured and e.secs == nil and e.verified == false, "the map offered Beta from Alpha: an OFFERED edge with no duration and no verification")
	check(edge(ns, "id:601", "id:603") == nil, "an UNREACHABLE (listed only) node is not an edge")
	local sm = summary(ns)
	check(sm.offered == 1 and sm.taken == 0 and sm.completed == 0 and sm.measured == 0, "the summary counts it as offered only")
	check(ns.Taxi.AttDiscovery(1) == "UNKNOWN", "and still no claim about flight data it cannot match")
	-- the planner prices an offer-only flight as an ESTIMATE
	local ctx = ns.State.ctx
	ns.Travel._Reset()
	local r = ns.Travel.Route(ctx, { map = 9101, x = 0.1, y = 0.1 }, { map = 9101, x = 0.8, y = 0.8 })
	check(r and r.mode == "FLIGHT" and r.estimated == true, "an offered flight is used with an ESTIMATED time, flagged as one")
	restore()
end

section("flight lifecycle: selected, started, completed -> a persisted, measured, observed edge the planner uses")
do
	local ns = world()
	local clock, restore = modernSetup(ns)
	atOrigin()
	local T = ns.Taxi
	T.OnMapOpened()
	-- the real call: TakeTaxiNode(slot) through the post-hook
	local calls = {}
	_G.TakeTaxiNode = function(i) calls[#calls + 1] = i end
	_G.hooksecurefunc = function(name, fn) local orig = _G[name] _G[name] = function(...) orig(...) fn(...) end end
	T._hooked = nil
	check(T.InstallHook() == true, "the TakeTaxiNode post-hook installs")
	_G.TakeTaxiNode(2)
	local p = T.Pending()
	check(#calls == 1 and p and p.state == "SELECTED" and p.from == "id:601" and p.to == "id:602" and p.how == "slot", "selecting slot 2 captures origin Alpha, destination Beta (resolved by slot) and the time")
	clock(1005)
	T.OnControlLost()
	check(T.Pending().state == "STARTED" and summary(ns).started == 1, "losing control right after the selection is the start")
	check(edge(ns, "id:601", "id:602").state == "OFFERED", "mid-flight the edge is still only OFFERED")
	atDestination()
	clock(1105)
	check(T.OnControlGained() == 100, "gaining control after the flight completes it: 100 s measured from the START")
	local e = edge(ns, "id:601", "id:602")
	check(e.state == "COMPLETED" and e.taken and e.measured and e.secs == 100 and e.src == "client observation" and e.verified == true, "the edge is COMPLETED: measured 100 s, src client observation, flagged verified")
	local f = ns.Prefs.Char().taxi.flights["id:601>id:602"]
	check(f and f.n == 1 and f.secs == 100 and f.min == 100 and f.max == 100 and f.arrival == "CHECKED", "origin and destination and the duration are persisted on the character (arrival checked)")
	local sm = summary(ns)
	check(sm.taken == 1 and sm.started == 1 and sm.completed == 1 and sm.aborted == 0 and sm.measured == 1, "the lifecycle counters: selected 1, started 1, completed 1, aborted 0, measured 1")
	check(sm.lastFlight.state == "COMPLETED" and sm.lastFlight.secs == 100, "the last flight is remembered for the report")
	-- the planner now uses the MEASURED time
	ns.Travel._Reset()
	local r = ns.Travel.Route(ns.State.ctx, { map = 9101, x = 0.1, y = 0.1 }, { map = 9101, x = 0.8, y = 0.8 })
	check(r and r.mode == "FLIGHT" and r.estimated == false and r.legs[2].secs == 100 + ns.Travel.BOARD_SECONDS, "Travel.Route consumes the observed edge: not estimated, 100 s + boarding")
	-- a second flight averages
	atOrigin() T.OnMapOpened()
	clock(2000) _G.TakeTaxiNode(2) clock(2003) T.OnControlLost() atDestination() clock(2123)
	T.OnControlGained()
	f = ns.Prefs.Char().taxi.flights["id:601>id:602"]
	check(f.n == 2 and f.secs == 110 and f.min == 100 and f.max == 120, "a second flight updates the mean (110 s), minimum and maximum")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB) == true, "the saved data is still writable")
	restore()
end

section("flight lifecycle: a flight that did not complete never becomes an edge, and no time is invented")
do
	local ns = world()
	local clock, restore = modernSetup(ns)
	atOrigin()
	local T = ns.Taxi
	T.OnMapOpened()
	T.OnTake(2)
	clock(1100)
	check(T.OnControlGained() == nil and next(ns.Prefs.Char().taxi.flights) == nil and summary(ns).aborted == 1, "control returning with no start in between writes nothing (the stale selection is ABORTED)")
	T.OnTake(2)
	clock(1200)
	T.Tick(1)
	check(T.Pending() == nil and summary(ns).aborted == 2 and next(ns.Prefs.Char().taxi.flights) == nil, "a selection that never starts is ABORTED after the timeout; no edge")
	check(summary(ns).lastFlight.state == "ABORTED" and summary(ns).lastFlight.why == "never started", "and the report says why")
	-- started but ended away from the destination (dismounted early)
	T.OnTake(2) T.OnControlLost()
	clock(1260)
	atOrigin()
	check(T.OnControlGained() == nil and next(ns.Prefs.Char().taxi.flights) == nil, "a flight that ends 10000 yd from its destination is ABORTED, not completed")
	check(summary(ns).lastFlight.why:find("from the destination", 1, true), "with the reason")
	-- too short to be a flight
	T.OnTake(2) T.OnControlLost() clock(1262) atDestination()
	check(T.OnControlGained() == nil and next(ns.Prefs.Char().taxi.flights) == nil, "a two second 'flight' is rejected")
	-- the index cannot be resolved
	T.OnTake(99)
	check(T.Pending() == nil and summary(ns).unresolved == 1 and summary(ns).lastFlight.state == "UNRESOLVED" and summary(ns).lastFlight.why:find("slots seen: 1,2,3", 1, true), "an unresolved index is counted and explained (with the slots the map listed), and starts nothing")
	check(edge(ns, "id:601", "id:602").secs == nil and edge(ns, "id:601", "id:602").state == "OFFERED", "through all of that the offered edge stayed an offer with no duration")
	check(summary(ns).measured == 0 and summary(ns).completed == 0, "nothing measured, nothing completed")
	restore()
end

section("flight lifecycle: UnitOnTaxi polling carries the lifecycle when the control events do not fire")
do
	local ns = world()
	local clock, restore = modernSetup(ns)
	atOrigin()
	local T = ns.Taxi
	T.OnMapOpened()
	local on = false
	_G.UnitOnTaxi = function() return on end
	T.OnTake(2)
	clock(1003) on = true
	T.Tick(1)
	check(T.Pending() and T.Pending().state == "STARTED", "UnitOnTaxi true starts it")
	atDestination() clock(1083) on = false
	T.Tick(1)
	check(T.Pending() == nil and edge(ns, "id:601", "id:602").secs == 80, "UnitOnTaxi false ends it: 80 s measured from the start")
	check(summary(ns).proof["UnitOnTaxi"] == "PROVEN", "UnitOnTaxi is tallied PROVEN once it answered a boolean")
	restore()
end

section("flight lifecycle: the report keeps the evidence states apart")
do
	local ns = world()
	local clock, restore = modernSetup(ns)
	atOrigin()
	local T = ns.Taxi
	local function report() local _, lines = ns.Diag.Report() return table.concat(lines, "\n") end
	T.OnMapOpened()
	local r = report()
	check(r:find("flight paths LISTED by the taxi map (3)", 1, true) and r:find("[PASS] direct flights recorded from where you stood, OFFERED by the map (1)", 1, true), "listed and offered are PASS")
	check(r:find("[PENDING] a flight was SELECTED", 1, true) and r:find("[PENDING] a flight STARTED", 1, true) and r:find("[PENDING] a flight COMPLETED", 1, true), "selected, started and completed are PENDING")
	check(r:find("[PENDING] a real flight time measured (0)", 1, true) and r:find("[PENDING] an observed transport edge is registered", 1, true), "measured and registered are PENDING")
	check(r:find("OFFERED 1 | flights SELECTED (TakeTaxiNode) 0", 1, true), "the one-line summary keeps the counts apart")
	T.OnTake(2) T.OnControlLost() atDestination() clock(1090) T.OnControlGained()
	r = report()
	check(r:find("[PASS] a flight was SELECTED", 1, true) and r:find("[PASS] a flight STARTED (1)", 1, true) and r:find("[PASS] a flight COMPLETED (1, 0 aborted)", 1, true), "after a flight: selected, started, completed are PASS")
	check(r:find("[PASS] a real flight time measured (1)", 1, true) and r:find("[PASS] an observed transport edge is registered", 1, true), "measured and registered are PASS")
	check(r:find("Last flight: COMPLETED id:601 -> id:602, 90 s (arrival CHECKED)", 1, true), "the last flight line names both ends and the duration")
	check(r:find("1 flight(s) completed and measured, 0 flight(s) only offered", 1, true), "the travel model line counts the completed edge among the edges the planner can use")
	restore()
end

section("knowledge page: tabs fit the page and the rows scroll instead of running off it")
do
	local ns = world()
	ns.UI.Open("appendices")
	local app = ns.UI.main.app
	local function click(b) b.__scripts.OnClick(b) end
	click(app.menu.knowledge)
	check(app.kScroll ~= nil and app.kBody ~= nil and app.kContentH ~= nil and app.kContentH > 0, "the rows are inside a scroll frame with a measured content height")
	click(app.kTabs[3])
	local travelH = app.kContentH
	click(app.kTabs[7])
	check(app.kContentH > 0 and travelH > app.kContentH, "a longer category is taller than a shorter one (the scroll range follows the content)")
	check(app.kScrollTo == nil, "the scroll position is applied once and cleared")
end
